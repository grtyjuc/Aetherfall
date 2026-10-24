-- Development DataStore lifecycle. Failed loads are never eligible for later writes.
local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local SessionStore = require(script.Parent.SessionStore)
local Schema = require(script.Parent.PlayerSchema)

local Service = {}
Service.__index = Service

function Service.new(profiles, options)
	options = options or {}
	local self = setmetatable({ profiles = profiles, entries = {}, elapsed = 0,
		stopping = false, onStatus = options.onStatus or function() end }, Service)
	local ok, dataStore = pcall(function()
		return DataStoreService:GetDataStore("Aetherfall_Development_v1")
	end)
	if ok then
		self.store = SessionStore.new({ update = function(_, key, transform)
			return dataStore:UpdateAsync(key, transform)
		end }, { sessionId = HttpService:GenerateGUID(false), now = os.time, wait = task.wait,
			leaseSeconds = 180, maxRetries = 3 })
	end
	self.connection = RunService.Heartbeat:Connect(function(delta)
		self.elapsed += delta
		if self.elapsed < 5 then return end
		self.elapsed = 0
		for player, entry in self.entries do
			self:getStatus(player) -- Expiry freezes actions even while a save request is yielding.
			if entry.closing and entry.mode ~= "Loading" and not entry.busy
				and os.clock() - entry.lastAttempt >= 5 then
				task.spawn(function() self:removePlayer(player) end)
			elseif entry.mode == "Persistent" and not entry.closing and not entry.busy
				and os.clock() - entry.lastAttempt >= 60 then
				task.spawn(function() self:save(player, false) end)
			end
		end
	end)
	return self
end

function Service:_notify(player)
	local entry = self.entries[player]
	if not entry then return end
	player:SetAttribute("AetherfallSaveMode", entry.mode)
	player:SetAttribute("AetherfallSaveMessage", entry.message)
	self.onStatus(player)
end

function Service:getStatus(player)
	local entry = self.entries[player]
	if not entry then return { mode = "Loading", message = "Loading character…", canPlay = false } end
	if entry.mode == "Persistent" and self.store:status(entry.key) == "Lost" then
		entry.mode = "Lost"
		entry.message = "Save ownership expired. Rejoin to protect your character; actions are paused."
		self:_notify(player)
	end
	return { mode = entry.mode, message = entry.message,
		canPlay = not entry.closing and (entry.mode == "Persistent" or entry.mode == "SessionOnly") }
end

function Service:load(player)
	if self.stopping or self.entries[player] then return nil end
	local entry = { mode = "Loading", message = "Loading character…", key = "player_" .. player.UserId,
		generation = 0, busy = true, closing = false, lastAttempt = os.clock() }
	self.entries[player] = entry
	self:_notify(player)
	local profile, code
	if self.store and player.UserId > 0 then
		profile, code = self.store:load(entry.key)
	else
		code = "Unavailable"
	end
	entry.busy = false
	if profile then
		if entry.closing or self.stopping then
			self.store:save(entry.key, profile, true)
			self.entries[player] = nil
			return nil
		end
		entry.mode, entry.message = "Persistent", "Character loaded. Autosave runs every 60 seconds."
	elseif code == "Unavailable" then
		if self.store then self.store:abandon(entry.key) end
		if entry.closing or self.stopping then self.entries[player] = nil; return nil end
		profile = Schema.newProfile("Sentinel")
		entry.mode = "SessionOnly"
		entry.message = "Not saved: publish a test place and enable Studio API access to test saving. Rejoin after enabling it."
	else
		if entry.closing or self.stopping then self.entries[player] = nil; return nil end
		entry.mode = "Lost"
		entry.message = if code == "SessionLocked"
			then "Character is open in another server. Leave that session, then rejoin."
			else "Character could not be loaded safely (" .. tostring(code) .. "). Existing data was not replaced."
		self:_notify(player)
		return nil
	end
	self.profiles[player] = profile
	self:_notify(player)
	return profile
end

function Service:markDirty(player)
	local entry = self.entries[player]
	if not entry then return end
	entry.generation += 1
	if entry.mode == "Persistent" then
		entry.message = "Changes pending; next autosave within 60 seconds."
		self:_notify(player)
	end
end

function Service:save(player, release)
	local entry, profile = self.entries[player], self.profiles[player]
	if not entry or not profile or entry.mode ~= "Persistent" then return false, "NotPersistent" end
	if entry.busy then return false, "Busy" end
	entry.busy = true
	entry.lastAttempt = os.clock()
	local generation = entry.generation
	local ok, code = self.store:save(entry.key, profile, release)
	entry.busy = false
	if ok then
		if release then
			entry.mode, entry.message = "Lost", "Session closed."
		else
			entry.message = if generation == entry.generation
				then "Saved at " .. os.date("!%H:%M:%S", os.time()) .. " UTC."
				else "Earlier changes saved; newer changes are pending."
		end
	elseif self.store:status(entry.key) == "Lost" then
		entry.mode = "Lost"
		entry.message = "Save ownership lost. Rejoin; actions are paused to protect your character."
	else
		entry.message = "Save failed; progress is pending. Another attempt will run shortly."
		-- Retry on the next heartbeat, without a tight retry loop or lease extension claim.
		entry.lastAttempt = if entry.closing then os.clock() else os.clock() - 55
	end
	self:_notify(player)
	if entry.closing and not release then self:removePlayer(player) end
	return ok, code
end

function Service:removePlayer(player)
	local entry = self.entries[player]
	if not entry then return end
	entry.closing = true
	-- If load is in flight it releases its acquired lease when it returns.
	if entry.mode == "Loading" then return end
	local deadline = os.clock() + 15
	while entry.busy and os.clock() < deadline do task.wait(0.1) end
	-- Keep newer mutations available until an in-flight autosave can finish and flush them.
	if entry.busy then return end
	if entry.mode == "Persistent" then
		local saved = self:save(player, true)
		if not saved and self.store:status(entry.key) == "Loaded" then return end
	end
	self.entries[player] = nil
	self.profiles[player] = nil
end

function Service:close()
	if self.stopping then return end
	self.stopping = true
	self.connection:Disconnect()
	for player in self.entries do
		task.spawn(function() self:removePlayer(player) end)
	end
	local deadline = os.clock() + 25
	while next(self.entries) and os.clock() < deadline do
		for player, entry in self.entries do
			if entry.closing and entry.mode ~= "Loading" and not entry.busy
				and os.clock() - entry.lastAttempt >= 2 then
				task.spawn(function() self:removePlayer(player) end)
			end
		end
		task.wait(0.1)
	end
end

return Service
