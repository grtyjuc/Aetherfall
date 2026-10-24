-- Actual SessionStore transactions against a fake UpdateAsync adapter.
-- This suite does not contact Roblox or prove live DataStore durability.
local Store = require("../src/server/SessionStore")
local Schema = require("../src/server/PlayerSchema")
local Progression = require("../src/shared/ProgressionRules")
local function copy(v)
	if type(v) ~= "table" then return v end
	local out = {}; for k, child in v do out[k] = copy(child) end
	return out
end
local function fixture(id)
	local f = { time = 1000, values = {}, calls = 0, fails = 0, waits = {}, callbackRepeats = 0 }
	f.adapter = {}
	function f.adapter:update(key, transform)
		f.calls += 1
		if f.fails > 0 then f.fails -= 1; error("simulated RPC error") end
		if f.before then f.before(key) end
		local result
		for _ = 1, f.callbackRepeats + 1 do
			result = transform(copy(f.values[key]))
		end
		if result ~= nil then f.values[key] = copy(result) end
		if f.after then f.after(key) end
		return copy(result)
	end
	function f:store(sessionId)
		return Store.new(self.adapter, { sessionId = sessionId or "server-a", now = function() return self.time end,
			wait = function(seconds) table.insert(self.waits, seconds); self.time += seconds end,
			leaseSeconds = 180, maxRetries = 3 })
	end
	f.store = f:store(id)
	return f
end
local passed = 0
local function test(name, body)
	local ok, err = pcall(body)
	if not ok then error("FAIL " .. name .. ": " .. tostring(err), 0) end
	passed += 1; print("PASS " .. name)
end
local function load(f, key)
	local profile, reason = f.store:load(key or "player_1")
	assert(profile, tostring(reason))
	return profile
end
local function record(profile, lock)
	return { format = 1, profile = Schema.encode(profile or Schema.newProfile()), revision = 1, writeId = "seed", lock = lock }
end

test("new account acquires a confirmed lease and returns independent level-one profile", function()
	local f = fixture(); local profile = load(f)
	assert(profile.level == 1 and profile.gold == 0 and f.store:status("player_1") == "Loaded")
	assert(f.store:leaseExpires("player_1") == 1180)
	assert(f.values.player_1.lock.id == "server-a" and f.values.player_1.revision == 1)
	profile.gold = 12
	assert(f.values.player_1.profile.data.gold == 0)
end)

test("save renews lease and preserves XP, gold and stable item identities", function()
	local f = fixture(); local profile = load(f)
	assert(Progression.grantReward(profile, "first", { xp = 125, gold = 40, items = {} }))
	local originalId = profile.equipped.MainHand
	f.time += 60
	local ok, reason = f.store:save("player_1", profile, false)
	assert(ok and reason == "Saved" and f.store:leaseExpires("player_1") == 1240)
	local saved = assert(Schema.decode(f.values.player_1.profile))
	assert(saved.gold == 40 and saved.level == 2 and saved.claimedRewards.first and saved.equipped.MainHand == originalId)
	assert(f.values.player_1.revision == 2)
end)

test("active foreign owner blocks loading without changing data or retrying", function()
	local f = fixture(); f.values.player_1 = record(nil, { id = "other", expires = 1100 })
	local profile, reason = f.store:load("player_1")
	assert(profile == nil and reason == "SessionLocked" and f.calls == 1)
	assert(f.values.player_1.lock.id == "other" and f.values.player_1.revision == 1)
	assert(not f.store:save("player_1", Schema.newProfile(), false))
end)

test("expired foreign lease can be acquired without discarding its profile", function()
	local f = fixture(); local profile = Schema.newProfile("Ranger"); profile.gold = 58
	f.values.player_1 = record(profile, { id = "old", expires = 999 })
	local loaded = load(f)
	assert(loaded.className == "Ranger" and loaded.gold == 58)
	assert(f.values.player_1.lock.id == "server-a" and f.values.player_1.revision == 2)
end)

test("corrupt and future records are rejected without replacement", function()
	for _, malformed in { { format = 99 }, { format = 1 }, record() } do
		local f = fixture()
		if malformed.profile then malformed.profile.version = 999 end
		f.values.player_1 = copy(malformed)
		local profile, reason = f.store:load("player_1")
		assert(profile == nil and reason == "CorruptData" and f.calls == 1)
		assert(f.values.player_1.format == malformed.format)
		assert(not f.store:save("player_1", Schema.newProfile(), false))
	end
end)

test("missing profile inside an envelope never counts as a new account", function()
	local f = fixture(); f.values.player_1 = { format = 1, revision = 1, writeId = "seed" }
	local profile, reason = f.store:load("player_1")
	assert(not profile and reason == "CorruptData" and f.values.player_1.profile == nil)
end)

test("transient errors have bounded backoff and retry the real operation", function()
	local f = fixture(); f.fails = 2
	load(f)
	assert(f.calls == 3 and #f.waits == 2 and f.waits[1] == 0.5 and f.waits[2] == 1)
	assert(f.values.player_1.revision == 1)
end)

test("failed loads can never save a fallback over existing data", function()
	local f = fixture(); f.fails = 3
	local profile, reason = f.store:load("player_1")
	assert(not profile and reason == "Unavailable" and f.calls == 3)
	local calls = f.calls
	assert(not f.store:save("player_1", Schema.newProfile(), false))
	assert(f.calls == calls and f.values.player_1 == nil)
end)

test("reexecuted UpdateAsync callbacks do not duplicate item grants or revisions", function()
	local f = fixture(); f.callbackRepeats = 4
	local profile = load(f)
	assert(f.values.player_1.revision == 1)
	assert(Progression.grantReward(profile, "once", { xp = 10, gold = 9, items = { "iron_longsword" } }))
	assert(f.store:save("player_1", profile, false))
	assert(f.values.player_1.revision == 2)
	local saved = assert(Schema.decode(f.values.player_1.profile)); local count = 0
	for _, item in saved.inventory do if item.itemId == "iron_longsword" then count += 1 end end
	assert(count == 1 and saved.gold == 9)
end)

test("lost responses after committed load or save are idempotent on retry", function()
	local f = fixture(); local failures = 0
	f.after = function()
		if failures == 0 then failures += 1; error("response lost after commit") end
	end
	local profile = load(f)
	assert(f.values.player_1.revision == 1 and f.calls == 2)
	failures = 0; profile.gold = 17
	assert(f.store:save("player_1", profile, false))
	assert(f.values.player_1.revision == 2 and f.values.player_1.profile.data.gold == 17)
end)

test("final save releases only after its returned write is confirmed", function()
	local f = fixture(); local profile = load(f); profile.gold = 88
	local ok, reason = f.store:save("player_1", profile, true)
	assert(ok and reason == "Released" and f.store:status("player_1") == "Released")
	assert(f.values.player_1.lock == nil and f.values.player_1.profile.data.gold == 88)
	local calls = f.calls
	assert(not f.store:save("player_1", profile, false) and f.calls == calls)
end)

test("failed final save retains local lease and profile for a safe retry", function()
	local f = fixture(); local profile = load(f); profile.gold = 77; f.fails = 3
	local ok, reason = f.store:save("player_1", profile, true)
	assert(not ok and reason == "Unavailable" and f.store:status("player_1") == "Loaded")
	assert(profile.gold == 77 and f.values.player_1.lock.id == "server-a")
	assert(f.store:save("player_1", profile, true))
	assert(f.values.player_1.profile.data.gold == 77 and f.values.player_1.lock == nil)
end)

test("lost final-save response can confirm release without needing a current lock", function()
	local f = fixture(); local profile = load(f); local failures = 0
	f.after = function() if failures == 0 then failures += 1; error("lost release response") end end
	assert(f.store:save("player_1", profile, true))
	assert(f.store:status("player_1") == "Released" and f.values.player_1.revision == 2)
end)

test("expired local leases stop gameplay status and cannot write", function()
	local f = fixture(); local profile = load(f); local calls = f.calls
	f.time = 1180
	assert(f.store:status("player_1") == "Lost" and f.store:leaseExpires("player_1") == nil)
	assert(not f.store:save("player_1", profile, false) and f.calls == calls)
	assert(not f.store:load("player_1"))
end)

test("foreign takeover during a save marks the session lost without changing its data", function()
	local f = fixture(); local profile = load(f)
	f.values.player_1.lock = { id = "new-server", expires = 1300 }
	f.values.player_1.writeId = "new-server:1"; f.values.player_1.revision += 1
	profile.gold = 100
	local ok, reason = f.store:save("player_1", profile, false)
	assert(not ok and reason == "SessionLost" and f.store:status("player_1") == "Lost")
	assert(f.values.player_1.lock.id == "new-server" and f.values.player_1.profile.data.gold == 0)
end)

test("a callback losing a conflict race cannot infer ownership from an earlier callback", function()
	local f = fixture()
	function f.adapter:update(key, transform)
		f.calls += 1
		assert(transform(nil).lock.id == "server-a")
		local foreign = record(nil, { id = "winner", expires = 1200 })
		local final = transform(foreign)
		f.values[key] = copy(final)
		return copy(final)
	end
	local profile, reason = f.store:load("player_1")
	assert(not profile and reason == "SessionLocked")
	assert(f.values.player_1.lock.id == "winner")
end)

test("operation that returns after its confirmed lease expires cannot become playable", function()
	local f = fixture(); f.after = function() f.time += 181 end
	local profile, reason = f.store:load("player_1")
	assert(not profile and reason == "LeaseExpired" and f.store:status("player_1") == "Lost")
end)

test("abandon performs no writes and invalidates future saves", function()
	local f = fixture(); local profile = load(f); local calls = f.calls
	assert(f.store:abandon("player_1"))
	assert(f.store:status("player_1") == "Unavailable")
	assert(not f.store:save("player_1", profile, false) and f.calls == calls)
end)

test("abandon while an RPC is in flight cannot resurrect its entry", function()
	local f = fixture()
	f.after = function() f.store:abandon("player_1") end
	local profile, reason = f.store:load("player_1")
	assert(not profile and reason == "Abandoned" and f.store:status("player_1") == "Unavailable")
end)

test("concurrent save or final-save calls return Busy without overlapping writes", function()
	local f = fixture(); local profile = load(f); local nestedReason
	f.before = function()
		local ok, reason = f.store:save("player_1", profile, true)
		assert(not ok); nestedReason = reason
	end
	assert(f.store:save("player_1", profile, false))
	assert(nestedReason == "Busy" and f.calls == 2)
end)

test("invalid keys and profiles are rejected before datastore access", function()
	local f = fixture()
	for _, key in { "", "bad key", string.rep("x", 51), 3, {} } do
		local profile, reason = f.store:load(key)
		assert(not profile and reason == "InvalidKey")
	end
	assert(f.calls == 0)
	local profile = load(f); local calls = f.calls; profile.gold = -1
	local ok, reason = f.store:save("player_1", profile, false)
	assert(not ok and reason == "InvalidProfile" and f.calls == calls)
end)

test("save snapshots are independent of mutations while an RPC yields", function()
	local f = fixture(); local profile = load(f); profile.gold = 40
	f.before = function() profile.gold = 99 end
	assert(f.store:save("player_1", profile, false))
	assert(f.values.player_1.profile.data.gold == 40 and profile.gold == 99)
end)

test("corruption after loading cannot be overwritten with the old local snapshot", function()
	local f = fixture(); local profile = load(f)
	f.values.player_1.profile.version = 1000
	local ok, reason = f.store:save("player_1", profile, false)
	assert(not ok and reason == "SessionLost" and f.store:status("player_1") == "Lost")
	assert(f.values.player_1.profile.version == 1000)
end)

test("invalid or backward clocks fail closed", function()
	local f = fixture(); local profile = load(f)
	f.time = 999
	local ok, reason = f.store:save("player_1", profile, false)
	assert(not ok and reason == "InvalidTime")
	assert(f.store:status("player_1") == "Lost")
	local bad = fixture(); bad.time = 0/0
	assert(not bad.store:load("player_1") and bad.calls == 0)
end)

test("expiry observed while a save is in flight cannot resurrect the lost session", function()
	local f = fixture(); local profile = load(f); profile.gold = 50
	f.before = function()
		f.time = 1181
		assert(f.store:status("player_1") == "Lost")
	end
	local ok, reason = f.store:save("player_1", profile, false)
	assert(not ok and reason == "SessionLost" and f.store:status("player_1") == "Lost")
	assert(f.values.player_1.profile.data.gold == 0 and f.values.player_1.revision == 1)
end)

test("nil UpdateAsync results never authorize loading or saving", function()
	local f = fixture()
	function f.adapter:update() return nil end
	local profile, reason = f.store:load("player_1")
	assert(not profile and reason == "Unavailable")
	local other = fixture(); local valid = load(other)
	function other.adapter:update() return nil end
	local ok, code = other.store:save("player_1", valid, false)
	assert(not ok and code == "SessionLost" and other.store:status("player_1") == "Lost")
end)

test("revision rollback under an apparently owned lease is rejected", function()
	local f = fixture(); local profile = load(f)
	assert(f.store:save("player_1", profile, false))
	assert(f.values.player_1.revision == 2)
	f.values.player_1.revision = 1; f.values.player_1.writeId = "old-write"
	profile.gold = 52
	assert(not f.store:save("player_1", profile, false))
	assert(f.store:status("player_1") == "Lost" and f.values.player_1.profile.data.gold == 0)
end)

print(passed .. " session-store tests passed with a fake datastore; live persistence remains unverified.")
