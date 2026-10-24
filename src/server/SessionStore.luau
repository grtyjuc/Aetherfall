-- Synchronous, dependency-injected lease store. The adapter supplies UpdateAsync semantics.
-- A unique sessionId is required for each server process. No client controls these methods.
local Schema = if script then require(script.Parent.PlayerSchema) else require("./PlayerSchema")
local SessionStore = {}
SessionStore.__index = SessionStore

local function finite(value)
	return type(value) == "number" and value == value and math.abs(value) < math.huge
end
local function integer(value)
	return finite(value) and value % 1 == 0
end
local function validKey(key)
	return type(key) == "string" and #key > 0 and #key <= 50 and key:match("^[%w_:%-]+$") ~= nil
end
local function copy(value)
	if type(value) ~= "table" then return value end
	local result = {}
	for key, child in value do result[key] = copy(child) end
	return result
end

local function inspect(raw)
	if type(raw) ~= "table" or raw.format ~= 1 then return nil, "CorruptData" end
	for key in raw do
		if key ~= "format" and key ~= "profile" and key ~= "lock" and key ~= "revision" and key ~= "writeId" then
			return nil, "CorruptData"
		end
	end
	if not integer(raw.revision) or raw.revision < 1 or raw.revision > 1e12
		or type(raw.writeId) ~= "string" or #raw.writeId == 0 or #raw.writeId > 180 then
		return nil, "CorruptData"
	end
	local lock = raw.lock
	if lock ~= nil then
		if type(lock) ~= "table" or type(lock.id) ~= "string" or #lock.id == 0 or #lock.id > 128
			or not finite(lock.expires) or lock.expires <= 0 then return nil, "CorruptData" end
		for key in lock do if key ~= "id" and key ~= "expires" then return nil, "CorruptData" end end
	end
	-- Schema.decode(nil) is a new account, but a missing stored profile is corruption.
	if raw.profile == nil then return nil, "CorruptData" end
	local ok, profile = pcall(Schema.decode, raw.profile)
	if not ok or not profile then return nil, "CorruptData" end
	return profile
end

function SessionStore.new(adapter, options)
	options = options or {}
	assert(type(adapter) == "table" and type(adapter.update) == "function", "Update adapter required")
	assert(type(options.sessionId) == "string" and #options.sessionId > 0 and #options.sessionId <= 128
		and not options.sessionId:find("%c"), "Unique session id required")
	assert(type(options.now) == "function" and type(options.wait) == "function", "Clock and wait adapters required")
	local retries, lease = options.maxRetries or 3, options.leaseSeconds or 180
	assert(integer(retries) and retries >= 1 and retries <= 5, "Retry count must be from one to five")
	assert(finite(lease) and lease >= 30 and lease <= 600, "Lease must be from 30 to 600 seconds")
	return setmetatable({ adapter = adapter, sessionId = options.sessionId, now = options.now, wait = options.wait,
		maxRetries = retries, leaseSeconds = lease, entries = {}, busy = {}, sequence = 0 }, SessionStore)
end

function SessionStore:_time()
	local ok, now = pcall(self.now)
	return if ok and finite(now) and now >= 0 then now else nil
end
function SessionStore:_operation()
	self.sequence += 1
	return self.sessionId .. ":" .. tostring(self.sequence)
end
function SessionStore:_update(key, transform)
	for attempt = 1, self.maxRetries do
		local ok, result = pcall(function() return self.adapter:update(key, transform) end)
		if ok then return true, result end
		if attempt < self.maxRetries then
			local waited = pcall(self.wait, 0.5 * 2 ^ (attempt - 1))
			if not waited then break end
		end
	end
	return false, nil
end

function SessionStore:status(key)
	local entry = self.entries[key]
	if entry and entry.status == "Loaded" then
		local now = self:_time()
		if not now or now < entry.lastNow or now >= entry.expires then entry.status = "Lost" end
	end
	return if entry then entry.status else nil
end
function SessionStore:leaseExpires(key)
	if self:status(key) ~= "Loaded" then return nil end
	return self.entries[key].expires
end
function SessionStore:abandon(key)
	if not validKey(key) then return false, "InvalidKey" end
	-- Never writes the datastore or attempts to release an unconfirmed lease.
	self.entries[key] = { status = "Unavailable" }
	return true, "Unavailable"
end

function SessionStore:load(key)
	if not validKey(key) then return nil, "InvalidKey" end
	if self.busy[key] then return nil, "Busy" end
	local previous = self.entries[key]
	if previous and previous.status == "Lost" then return nil, "SessionLost" end
	if previous and previous.status == "Loaded" then return nil, "AlreadyLoaded" end
	local now = self:_time()
	if not now then return nil, "InvalidTime" end
	local entry = { status = "Loading", lastNow = now }
	self.entries[key], self.busy[key] = entry, true
	local operation = self:_operation()
	local ok, raw = self:_update(key, function(current)
		local clock = self:_time()
		if not clock or self.entries[key] ~= entry then return nil end
		local profile, revision = nil, 0
		if current == nil then
			profile = Schema.newProfile("Sentinel")
		else
			profile = inspect(current)
			-- Returning unchanged data lets the final returned record explain a rejection.
			-- No callback-local flag is used to establish that a lease was acquired.
			if not profile then return current end
			local lock = current.lock
			if lock and lock.expires > clock and lock.id ~= self.sessionId then return current end
			if current.writeId == operation then return current end
			revision = current.revision
		end
		return { format = 1, profile = Schema.encode(profile), revision = revision + 1,
			writeId = operation, lock = { id = self.sessionId, expires = clock + self.leaseSeconds } }
	end)
	self.busy[key] = nil
	if self.entries[key] ~= entry then return nil, "Abandoned" end
	if not ok or raw == nil then entry.status = "Unavailable"; return nil, "Unavailable" end
	local profile, reason = inspect(raw)
	if not profile then entry.status = "Unavailable"; return nil, reason end
	local clock = self:_time()
	if raw.writeId ~= operation or not raw.lock or raw.lock.id ~= self.sessionId then
		entry.status = "Unavailable"
		return nil, "SessionLocked"
	end
	if not clock or clock < entry.lastNow or raw.lock.expires <= clock then
		entry.status = "Lost"; return nil, "LeaseExpired"
	end
	entry.status, entry.revision, entry.expires, entry.lastNow = "Loaded", raw.revision, raw.lock.expires, clock
	return profile, "Loaded"
end

function SessionStore:save(key, profile, release)
	if not validKey(key) then return false, "InvalidKey" end
	if type(release) ~= "boolean" then return false, "InvalidRelease" end
	if self.busy[key] then return false, "Busy" end
	local entry = self.entries[key]
	if not entry or entry.status ~= "Loaded" then
		return false, if entry and entry.status == "Lost" then "SessionLost" else "NotLoaded"
	end
	local now = self:_time()
	if not now or now < entry.lastNow then return false, "InvalidTime" end
	if entry.expires <= now then entry.status = "Lost"; return false, "LeaseExpired" end
	local encodedOk, encoded = pcall(Schema.encode, profile)
	if not encodedOk or not encoded then return false, "InvalidProfile" end
	local operation = self:_operation()
	self.busy[key] = true
	local ok, raw = self:_update(key, function(current)
		local clock = self:_time()
		if not clock or self.entries[key] ~= entry or entry.status ~= "Loaded" then return nil end
		local currentProfile = inspect(current)
		if not currentProfile then return current end
		-- A response may have been lost after the previous callback committed. A retry of
		-- this same operation returns its record without incrementing revision twice.
		if current.writeId == operation then return current end
		local lock = current.lock
		if not lock or lock.id ~= self.sessionId or lock.expires <= clock
			or current.revision < entry.revision then return current end
		return { format = 1, profile = copy(encoded), revision = current.revision + 1,
			writeId = operation, lock = if release then nil else { id = self.sessionId, expires = clock + self.leaseSeconds } }
	end)
	self.busy[key] = nil
	if self.entries[key] ~= entry then return false, "Abandoned" end
	if entry.status ~= "Loaded" then return false, "SessionLost" end
	if not ok then
		-- An unconfirmed final save never locally releases ownership. Retry while the
		-- known lease remains valid; a confirmed missing/foreign lease instead fails closed.
		local clock = self:_time()
		if clock and clock >= entry.expires then entry.status = "Lost" end
		return false, "Unavailable"
	end
	local confirmed = raw ~= nil and inspect(raw) ~= nil
	if not confirmed then entry.status = "Lost"; return false, "SessionLost" end
	if raw.writeId ~= operation or raw.revision < entry.revision then
		entry.status = "Lost"; return false, "SessionLost"
	end
	local clock = self:_time()
	if release then
		if raw.lock ~= nil then entry.status = "Lost"; return false, "SessionLost" end
		entry.status, entry.revision = "Released", raw.revision
		return true, "Released"
	end
	if not clock or clock < entry.lastNow or not raw.lock or raw.lock.id ~= self.sessionId or raw.lock.expires <= clock then
		entry.status = "Lost"; return false, "LeaseExpired"
	end
	entry.revision, entry.expires, entry.lastNow = raw.revision, raw.lock.expires, clock
	return true, "Saved"
end

return SessionStore
