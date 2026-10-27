-- Actual grove service and rules with mocked prompt signals/time; no live Studio RPCs.
local fs = require("@lune/fs")
local roblox = require("@lune/roblox")
local Progression = require("../src/shared/ProgressionRules")
local Quest = require("../src/shared/QuestRules")
local Grove = require("../src/shared/GroveRules")

local function signal()
	local event = { listeners = {} }
	function event:Connect(callback)
		local connection = { Connected = true }
		function connection:Disconnect() self.Connected = false end
		table.insert(self.listeners, { callback, connection })
		return connection
	end
	function event:Fire(...)
		for _, listener in self.listeners do if listener[2].Connected then listener[1](...) end end
	end
	return event
end
local function fixture()
	local f = { profiles = {}, now = 100, canPlay = true, changes = 0, messages = {} }
	local storage = { WaitForChild = function(_, name) assert(name == "Shared"); return { GroveRules = Grove } end }
	local factory = assert(loadstring(fs.readFile("src/server/GroveService.luau"), "GroveService"))
	setfenv(factory, setmetatable({
		game = { GetService = function(_, name) assert(name == "ReplicatedStorage"); return storage end },
		require = function(module) return module end,
	}, { __index = getfenv() }))
	local Service = factory()
	local stone = roblox.Instance.new("Part")
	stone.Position = roblox.Vector3.new(80, 3, -156)
	f.prompt = { Parent = stone, Triggered = signal(), IsA = function(_, name) return name == "ProximityPrompt" end }
	local world = { FindFirstChild = function(_, name, recursive)
		assert(name == "InspectGroveRune" and recursive); return f.prompt
	end }
	f.service = Service.new(f.profiles, {}, world, {
		now = function() return f.now end,
		canAct = function() return f.canPlay end,
		onChanged = function(player) assert(f.profiles[player]); f.changes += 1 end,
		onMessage = function(player, text) table.insert(f.messages, { player, text }) end,
	})
	function f:add(className, ready)
		local player = { UserId = 1 }
		local character = roblox.Instance.new("Model")
		local humanoid = roblox.Instance.new("Humanoid")
		humanoid.Health = 100
		humanoid.Parent = character
		local root = roblox.Instance.new("Part")
		root.Name = "HumanoidRootPart"
		root.Position = stone.Position + roblox.Vector3.new(0, 0, 2)
		root.Parent = character
		player.Character, player.humanoid, player.root = character, humanoid, root
		local profile = Progression.newProfile(className or "Sentinel")
		Quest.ensure(profile)
		if ready then
			profile.level = 3
			profile.quests.strangerStage, profile.quests.fieldsAccepted, profile.quests.fieldsKills = 3, true, 4
			profile.quests.groveStage = 1
			profile.claimedRewards.quest_stranger, profile.claimedRewards.quest_fields = true, true
		end
		f.profiles[player] = profile
		return player, profile
	end
	return f
end
local passed = 0
local function test(name, callback)
	local ok, message = pcall(callback)
	if not ok then error("FAIL " .. name .. ": " .. tostring(message), 0) end
	passed += 1
	print("PASS " .. name)
end

test("rune prompt changes a valid accepted grove stage once", function()
	local f = fixture(); local player, profile = f:add("Sentinel", true)
	f.prompt.Triggered:Fire(player)
	assert(profile.quests.groveStage == 2 and f.changes == 1 and #f.messages == 1)
	local xp, gold = profile.xp, profile.gold
	f.now += 1
	f.prompt.Triggered:Fire(player)
	assert(profile.quests.groveStage == 2 and f.changes == 1 and #f.messages == 2)
	assert(profile.xp == xp and profile.gold == gold)
	f.service:destroy()
end)

test("approaching before accepting the quest guides without granting progress", function()
	local f = fixture(); local player, profile = f:add("Sentinel", false)
	assert(not f.service:inspect(player))
	assert(profile.quests.groveStage == 0 and f.changes == 0)
	assert(f.messages[1][2]:find("Elder Rowan", 1, true))
	f.service:destroy()
end)

test("forged distant prompt triggers cannot inspect a rune", function()
	local f = fixture(); local player, profile = f:add("Sentinel", true)
	player.root.Position = roblox.Vector3.new(0, 3, 0)
	f.prompt.Triggered:Fire(player)
	assert(profile.quests.groveStage == 1 and f.changes == 0 and #f.messages == 0)
	f.service:destroy()
end)

test("dead, paused and missing characters cannot inspect", function()
	local f = fixture(); local player, profile = f:add("Sentinel", true)
	player.humanoid.Health = 0
	assert(not f.service:inspect(player))
	player.humanoid.Health = 100
	f.canPlay = false
	assert(not f.service:inspect(player))
	f.canPlay = true
	player.Character = nil
	assert(not f.service:inspect(player))
	assert(profile.quests.groveStage == 1 and f.changes == 0)
	f.service:destroy()
end)

test("unknown players and invalid clocks never mutate profiles", function()
	local f = fixture(); local player, profile = f:add("Sentinel", true)
	assert(not f.service:inspect({}))
	f.now = 0 / 0
	assert(not f.service:inspect(player) and profile.quests.groveStage == 1)
	f.service:destroy()
end)

test("rune interaction has a per-player server cooldown", function()
	local f = fixture(); local player = f:add("Sentinel", true)
	assert(f.service:inspect(player))
	assert(not f.service:inspect(player) and #f.messages == 1)
	f.now += 0.99
	assert(not f.service:inspect(player) and #f.messages == 1)
	f.now += 0.01
	assert(not f.service:inspect(player) and #f.messages == 2)
	f.service:destroy()
end)

test("first boss defeat grants fixed reward and later callbacks cannot repeat it", function()
	local f = fixture(); local player, profile = f:add("Sentinel", true)
	assert(f.service:inspect(player))
	local ok, _, summary = f.service:recordBossDefeat(player)
	assert(ok and summary.xp == 1300 and summary.gold == 180)
	assert(profile.quests.groveStage == 3 and profile.claimedRewards.boss_briarwarden)
	assert(profile.level >= 5 and profile.gold == 180)
	local count, nextId, xp, level = 0, profile.nextId, profile.xp, profile.level
	for _, instance in profile.inventory do if instance.itemId == "briarwarden_shield" then count += 1 end end
	assert(count == 1 and f.changes == 2)
	assert(not f.service:recordBossDefeat(player))
	assert(profile.nextId == nextId and profile.xp == xp and profile.level == level and profile.gold == 180 and f.changes == 2)
	f.service:destroy()
end)

test("each class receives its own first-defeat equipment", function()
	for className, itemId in { Sentinel = "briarwarden_shield", Spellweaver = "briarwarden_staff", Ranger = "briarwarden_bow" } do
		local f = fixture(); local player, profile = f:add(className, true)
		assert(f.service:inspect(player))
		assert(f.service:recordBossDefeat(player))
		local count = 0
		for _, instance in profile.inventory do if instance.itemId == itemId then count += 1 end end
		assert(count == 1)
		assert(Grove.validateProfile(profile))
		f.service:destroy()
	end
end)

test("unready or unwritable characters cannot receive boss rewards", function()
	local f = fixture(); local player, profile = f:add("Ranger", true)
	assert(not f.service:recordBossDefeat(player))
	assert(not profile.claimedRewards.boss_briarwarden)
	assert(f.service:inspect(player))
	f.canPlay = false
	assert(not f.service:recordBossDefeat(player) and profile.quests.groveStage == 2)
	assert(not f.service:recordBossDefeat({}))
	f.service:destroy()
end)

test("player rewards and inspection cooldowns remain isolated", function()
	local f = fixture(); local first, firstProfile = f:add("Sentinel", true)
	local second, secondProfile = f:add("Spellweaver", true)
	assert(f.service:inspect(first) and f.service:inspect(second))
	assert(f.service:recordBossDefeat(first))
	assert(secondProfile.gold == 0 and secondProfile.quests.groveStage == 2)
	assert(firstProfile.gold == 180)
	f.service:destroy()
end)

test("removal and destruction stop callbacks without altering saved progress", function()
	local f = fixture(); local player, profile = f:add("Sentinel", true)
	assert(f.service:inspect(player))
	f.service:removePlayer(player)
	assert(f.service.lastInspect[player] == nil)
	f.profiles[player] = nil
	f.now += 1
	f.prompt.Triggered:Fire(player)
	assert(f.changes == 1 and profile.quests.groveStage == 2)
	f.service:destroy()
	assert(not f.service.connection.Connected)
	f.profiles[player] = profile
	assert(not f.service:recordBossDefeat(player))
end)

print(passed .. " GroveService tests passed with mocked proximity and actual grove reward rules.")
