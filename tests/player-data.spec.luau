-- Actual PlayerDataService wrapper with injected store/network signals, task scheduling and time.
-- This does not call Roblox DataStoreService or simulate live network/physics behavior.
local fs = require("@lune/fs")
local Schema = require("../src/server/PlayerSchema")

local function signal()
	local event = { listeners = {} }
	function event:Connect(callback)
		local connection = { Connected = true }
		function connection:Disconnect() self.Connected = false end
		table.insert(self.listeners, { callback = callback, connection = connection })
		return connection
	end
	function event:Fire(...)
		for _, listener in self.listeners do
			if listener.connection.Connected then listener.callback(...) end
		end
	end
	return event
end

local function fixture(options)
	options = options or {}
	local f = { now = 100, profiles = {}, statuses = {}, loads = {}, saves = {}, abandons = {}, notices = {} }
	f.heartbeat = signal()
	f.store = {}
	function f.store:load(key)
		table.insert(f.loads, key)
		if f.onLoad then f.onLoad(key) end
		if options.loadCode then return nil, options.loadCode end
		f.statuses[key] = "Loaded"
		return Schema.newProfile("Sentinel"), "Loaded"
	end
	function f.store:status(key) return f.statuses[key] end
	function f.store:abandon(key)
		table.insert(f.abandons, key)
		f.statuses[key] = "Unavailable"
	end
	function f.store:save(key, profile, release)
		local record = { key = key, profile = profile, release = release, existed = next(f.profiles) ~= nil }
		table.insert(f.saves, record)
		if f.onSave then f.onSave(record) end
		if options.saveCode then
			if options.saveCode == "SessionLost" then f.statuses[key] = "Lost" end
			return false, options.saveCode
		end
		if release then f.statuses[key] = "Released" end
		return true, "Saved"
	end
	local mockStore = {}
	function mockStore.new(adapter, config)
		f.adapter, f.config = adapter, config
		return f.store
	end
	local services = {
		DataStoreService = { GetDataStore = function(_, name)
			f.storeName = name
			if options.noApi then error("API disabled") end
			return { UpdateAsync = function() error("Mock core must not call real adapter") end }
		end },
		HttpService = { GenerateGUID = function() return "test-session-unique-id" end },
		RunService = { Heartbeat = f.heartbeat },
	}
	local game = {}
	function game:GetService(name) return assert(services[name], "Unknown service " .. name) end
	local fakeTask = {}
	function fakeTask.spawn(callback) callback() end
	function fakeTask.wait(seconds)
		f.now += seconds or 0
		if f.onWait then f.onWait(seconds) end
	end
	local environment = setmetatable({
		game = game,
		script = { Parent = { SessionStore = mockStore, PlayerSchema = Schema } },
		require = function(module) return module end,
		task = fakeTask,
		os = setmetatable({ clock = function() return f.now end, time = function() return math.floor(f.now) end }, { __index = os }),
	}, { __index = getfenv() })
	local factory = assert(loadstring(fs.readFile("src/server/PlayerDataService.luau"), "PlayerDataService"))
	setfenv(factory, environment)
	f.Service = factory()
	f.service = f.Service.new(f.profiles, { onStatus = function(player)
		table.insert(f.notices, { player = player, mode = player.attributes.AetherfallSaveMode,
			message = player.attributes.AetherfallSaveMessage })
	end })
	function f:player(id)
		local player = { UserId = id or 123, attributes = {} }
		function player:SetAttribute(key, value) self.attributes[key] = value end
		return player
	end
	return f
end

local passed = 0
local function test(name, callback)
	local ok, reason = pcall(callback)
	assert(ok, "FAIL " .. name .. ": " .. tostring(reason))
	passed += 1
	print("PASS " .. name)
end

test("profiles install only after successful load and initial state never claims a save", function()
	local f = fixture(); local player = f:player()
	assert(f.service:getStatus(player).mode == "Loading" and not f.service:getStatus(player).canPlay)
	f.onLoad = function()
		assert(f.profiles[player] == nil)
		assert(f.service.entries[player].busy and f.service:getStatus(player).mode == "Loading")
	end
	local profile = f.service:load(player)
	assert(profile and f.profiles[player] == profile)
	assert(f.service:getStatus(player).canPlay and f.service:getStatus(player).mode == "Persistent")
	assert(not string.find(f.service:getStatus(player).message, "Saved at", 1, true))
	assert(#f.saves == 0 and f.storeName == "Aetherfall_Development_v1")
	assert(f.config.leaseSeconds == 180 and f.config.maxRetries == 3)
	assert(f.service:load(player) == nil and #f.loads == 1)
	f.service:close()
end)

test("unavailable loads create explicit session-only profiles with zero later writes", function()
	local f = fixture({ loadCode = "Unavailable" }); local player = f:player()
	assert(f.service:load(player))
	assert(f.service:getStatus(player).mode == "SessionOnly" and f.service:getStatus(player).canPlay)
	assert(string.find(player.attributes.AetherfallSaveMessage, "Not saved", 1, true))
	assert(#f.abandons == 1)
	f.service:markDirty(player)
	assert(not f.service:save(player, false))
	f.now += 120; f.heartbeat:Fire(5)
	f.service:removePlayer(player)
	f.service:close()
	assert(#f.saves == 0 and f.profiles[player] == nil)
end)

test("disabled DataStore API falls back without constructing an adapter or writing", function()
	local f = fixture({ noApi = true }); local player = f:player()
	assert(f.service.store == nil and f.config == nil)
	assert(f.service:load(player))
	assert(f.service:getStatus(player).mode == "SessionOnly")
	f.service:close()
	assert(#f.loads == 0 and #f.saves == 0)
end)

test("locked, corrupt and lost load failures never create default replacement profiles", function()
	for _, code in { "SessionLocked", "CorruptData", "SessionLost", "InvalidTime" } do
		local f = fixture({ loadCode = code }); local player = f:player()
		assert(f.service:load(player) == nil)
		assert(f.profiles[player] == nil and f.service:getStatus(player).mode == "Lost")
		assert(not f.service:getStatus(player).canPlay and #f.abandons == 0)
		assert(not f.service:save(player, true))
		f.service:removePlayer(player)
		assert(f.service.entries[player] == nil and #f.saves == 0)
		f.service:close()
	end
end)

test("dirty and saved status messages reflect actual completed writes", function()
	local f = fixture(); local player = f:player()
	f.service:load(player)
	f.service:markDirty(player)
	assert(f.service.entries[player].generation == 1)
	assert(string.find(f.service:getStatus(player).message, "pending", 1, true))
	assert(f.service:save(player, false))
	assert(string.find(f.service:getStatus(player).message, "Saved at", 1, true))
	assert(#f.saves == 1 and not f.saves[1].release)
	f.service:close()
end)

test("mutation during a yielding save leaves newer progress visibly pending", function()
	local f = fixture(); local player = f:player()
	f.service:load(player)
	f.service:markDirty(player)
	f.onSave = function(record)
		if not record.release then
			f.profiles[player].gold += 5
			f.service:markDirty(player)
		end
	end
	assert(f.service:save(player, false))
	assert(f.service.entries[player].generation == 2)
	assert(f.service:getStatus(player).message == "Earlier changes saved; newer changes are pending.")
	f.onSave = nil; f.service:close()
end)

test("ownership expiry reported by core freezes play and updates save attributes", function()
	local f = fixture(); local player = f:player()
	f.service:load(player)
	f.statuses["player_123"] = "Lost"
	local status = f.service:getStatus(player)
	assert(status.mode == "Lost" and not status.canPlay)
	assert(player.attributes.AetherfallSaveMode == "Lost")
	assert(f.profiles[player] ~= nil and #f.saves == 0)
	assert(not f.service:save(player, false))
	f.service:close(); assert(#f.saves == 0)
end)

test("removal releases while profile still exists then removes live state", function()
	local f = fixture(); local player = f:player()
	f.service:load(player)
	local profile = f.profiles[player]
	f.onSave = function(record)
		assert(record.release and f.profiles[player] == profile)
		assert(not f.service:getStatus(player).canPlay)
	end
	f.service:removePlayer(player)
	assert(#f.saves == 1 and f.saves[1].release)
	assert(f.profiles[player] == nil and f.service.entries[player] == nil)
	f.service:close()
end)

test("leaving during a successful load releases acquired ownership without installing profile", function()
	local f = fixture(); local player = f:player()
	f.onLoad = function() f.service:removePlayer(player) end
	assert(f.service:load(player) == nil)
	assert(f.profiles[player] == nil and f.service.entries[player] == nil)
	assert(#f.saves == 1 and f.saves[1].release and not f.saves[1].existed)
	f.service:close()
end)

test("leaving during unavailable or rejected loads removes pending entries without writes", function()
	for _, code in { "Unavailable", "SessionLocked", "CorruptData" } do
		local f = fixture({ loadCode = code }); local player = f:player()
		f.onLoad = function() f.service:removePlayer(player) end
		assert(f.service:load(player) == nil)
		assert(f.profiles[player] == nil and f.service.entries[player] == nil,
			"Departed player retained a pending entry after " .. code)
		assert(#f.saves == 0)
		f.service:close()
	end
end)

test("autosave renews idle persistent sessions at sixty seconds only", function()
	local f = fixture(); local player = f:player()
	f.service:load(player)
	f.now += 59; f.heartbeat:Fire(5)
	assert(#f.saves == 0)
	f.now += 1; f.heartbeat:Fire(5)
	assert(#f.saves == 1 and not f.saves[1].release)
	f.service:close()
end)

test("failed saves retain pending state and retry on the following heartbeat interval", function()
	local f = fixture({ saveCode = "Unavailable" }); local player = f:player()
	f.service:load(player); f.service:markDirty(player)
	assert(not f.service:save(player, false))
	assert(f.service:getStatus(player).mode == "Persistent")
	assert(string.find(f.service:getStatus(player).message, "Save failed", 1, true))
	f.now += 4; f.heartbeat:Fire(5); assert(#f.saves == 1)
	f.now += 1; f.heartbeat:Fire(5); assert(#f.saves == 2)
	f.service:close()
end)

test("save-time ownership loss freezes further play and prevents further writes", function()
	local f = fixture({ saveCode = "SessionLost" }); local player = f:player()
	f.service:load(player)
	assert(not f.service:save(player, false))
	assert(f.service:getStatus(player).mode == "Lost" and not f.service:getStatus(player).canPlay)
	assert(not f.service:save(player, false) and #f.saves == 1)
	f.service:close()
end)

test("removal waits for an in-flight autosave before a final release save", function()
	local f = fixture(); local player = f:player()
	f.service:load(player)
	local yielded = false
	f.onSave = function(record)
		if not record.release and not yielded then yielded = true; coroutine.yield("save_pending") end
	end
	local autosave = coroutine.create(function() f.service:save(player, false) end)
	local ok, state = coroutine.resume(autosave)
	assert(ok and state == "save_pending" and f.service.entries[player].busy)
	f.onWait = function()
		if coroutine.status(autosave) == "suspended" then assert(coroutine.resume(autosave)) end
	end
	f.service:removePlayer(player)
	assert(coroutine.status(autosave) == "dead")
	assert(#f.saves == 2 and not f.saves[1].release and f.saves[2].release)
	assert(f.profiles[player] == nil)
	f.service:close()
end)

test("negative and zero Studio user IDs use session-only data without load RPCs", function()
	for _, id in { -1, 0 } do
		local f = fixture(); local player = f:player(id)
		assert(f.service:load(player))
		assert(f.service:getStatus(player).mode == "SessionOnly")
		assert(#f.loads == 0 and #f.saves == 0)
		f.service:close(); assert(#f.saves == 0)
	end
end)

test("removal timeout retains newer progress until the yielding autosave can release it", function()
	local f = fixture(); local player = f:player()
	f.service:load(player)
	local yielded = false
	f.onSave = function(record)
		if not record.release and not yielded then yielded = true; coroutine.yield("save_pending") end
		if record.release then assert(record.profile.gold == 37, "Final save lost newer progress") end
	end
	local autosave = coroutine.create(function() f.service:save(player, false) end)
	local ok, state = coroutine.resume(autosave)
	assert(ok and state == "save_pending")
	f.profiles[player].gold = 37
	f.service:markDirty(player)
	f.service:removePlayer(player) -- Mock wait advances 15 seconds; autosave stays suspended.
	assert(f.service.entries[player] and f.service.entries[player].closing and f.service.entries[player].busy)
	assert(f.profiles[player] and f.profiles[player].gold == 37)
	assert(not f.service:getStatus(player).canPlay and #f.saves == 1)
	assert(coroutine.resume(autosave))
	assert(coroutine.status(autosave) == "dead")
	assert(#f.saves == 2 and f.saves[2].release)
	assert(f.profiles[player] == nil and f.service.entries[player] == nil)
	f.service:close()
end)

test("shutdown releases active profiles, disconnects heartbeat and rejects new loads", function()
	local f = fixture(); local first, second = f:player(1), f:player(2)
	f.service:load(first); f.service:load(second)
	assert(f.service.connection.Connected)
	f.service:close()
	assert(f.service.stopping and not f.service.connection.Connected)
	assert(next(f.service.entries) == nil and next(f.profiles) == nil)
	assert(#f.saves == 2 and f.saves[1].release and f.saves[2].release)
	f.now += 120; f.heartbeat:Fire(100)
	assert(#f.saves == 2)
	assert(f.service:load(f:player(3)) == nil)
	f.service:close(); assert(#f.saves == 2)
end)

test("failed final flush retains closing progress until heartbeat retry succeeds", function()
	local options = { saveCode = "Unavailable" }
	local f = fixture(options); local player = f:player()
	f.service:load(player)
	f.profiles[player].gold = 91
	f.service:markDirty(player)
	f.service:removePlayer(player)
	assert(#f.saves == 1 and f.saves[1].release)
	assert(f.service.entries[player].closing and f.profiles[player].gold == 91)
	assert(not f.service:getStatus(player).canPlay)
	options.saveCode = nil
	f.now += 5; f.heartbeat:Fire(5)
	assert(#f.saves == 2 and f.saves[2].release and f.saves[2].profile.gold == 91)
	assert(f.profiles[player] == nil and f.service.entries[player] == nil)
	f.service:close()
end)

test("shutdown keeps waiting after a busy removal times out and finishes its latest flush", function()
	local f = fixture(); local player = f:player()
	f.service:load(player)
	local yielded = false
	f.onSave = function(record)
		if not record.release and not yielded then yielded = true; coroutine.yield("save_pending") end
		if record.release then assert(record.profile.gold == 53) end
	end
	local autosave = coroutine.create(function() f.service:save(player, false) end)
	local ok, state = coroutine.resume(autosave)
	assert(ok and state == "save_pending")
	f.profiles[player].gold = 53
	f.service:markDirty(player)
	f.onWait = function()
		if f.now >= 120 and coroutine.status(autosave) == "suspended" then
			assert(coroutine.resume(autosave))
		end
	end
	f.service:close()
	assert(f.now >= 120, "Shutdown returned before in-flight save had a chance to finish")
	assert(coroutine.status(autosave) == "dead")
	assert(next(f.service.entries) == nil and next(f.profiles) == nil)
	assert(#f.saves == 2 and f.saves[2].release)
	assert(not f.service.connection.Connected)
end)

test("shutdown spaces failed final-flush retries by at least two seconds", function()
	local options = { saveCode = "Unavailable" }
	local f = fixture(options); local player = f:player()
	f.service:load(player)
	local firstAttempt
	f.onSave = function(record)
		assert(record.release)
		if not firstAttempt then firstAttempt = f.now
		else
			assert(f.now - firstAttempt >= 2, "Shutdown retried a failed flush too quickly")
			options.saveCode = nil
		end
	end
	f.service:close()
	assert(#f.saves == 2 and f.now - firstAttempt >= 2)
	assert(next(f.service.entries) == nil and next(f.profiles) == nil)
end)

print(passed .. " PlayerDataService wrapper tests passed with mocked store, clock and scheduling.")
