-- Actual pure server reward service; no live NPC, RemoteEvent or DataStore calls.
local Rewards = require("../src/server/EnemyRewards")
local Progression = require("../src/shared/ProgressionRules")
local Quest = require("../src/shared/QuestRules")
local Definitions = require("../src/shared/EnemyDefinitions")
local passed = 0
local function test(name, callback)
	local ok, message = pcall(callback)
	assert(ok, "FAIL " .. name .. ": " .. tostring(message))
	passed += 1; print("PASS " .. name)
end
local function copy(value)
	if type(value) ~= "table" then return value end
	local result = {}; for key, child in value do result[key] = copy(child) end; return result
end
local function equal(a, b)
	if type(a) ~= "table" or type(b) ~= "table" then return a == b end
	for key, value in a do if not equal(value, b[key]) then return false end end
	for key in b do if a[key] == nil then return false end end
	return true
end
local function fixture()
	local f = { player = {}, allowed = true, changed = 0, questCalls = 0 }
	f.profiles = { [f.player] = Progression.newProfile("Sentinel") }
	Quest.ensure(f.profiles[f.player])
	f.service = Rewards.new(f.profiles, {
		canAct = function() return f.allowed end,
		onQuestDefeat = function(player, kind)
			f.questCalls += 1; Quest.recordDefeat(f.profiles[player], kind)
		end,
		onChanged = function(player, summary)
			assert(player == f.player and summary.xp > 0 and summary.gold >= 0)
			f.changed += 1; f.summary = summary
		end,
	})
	return f, f.profiles[f.player]
end
local function noMutation(f, callback)
	local before, callbacks = copy(f.profiles[f.player]), f.changed
	assert(not callback()); assert(equal(f.profiles[f.player], before)); assert(f.changed == callbacks)
end

for _, kind in { "MeadowSlime", "WildBoar", "Thornling" } do
	test(kind .. " grants only its server-defined XP and gold", function()
		local f, profile = fixture()
		assert(f.service:recordDefeat(f.player, kind, "enemy_spawn:1"))
		assert(profile.xp == Definitions[kind].xp and profile.gold == Definitions[kind].gold)
		assert(f.changed == 1 and f.questCalls == 1)
		assert(f.summary.xp == Definitions[kind].xp and f.summary.gold == Definitions[kind].gold)
	end)
end

test("same generation and stale replays never repeat rewards or quest callbacks", function()
	local f = fixture()
	assert(f.service:recordDefeat(f.player, "MeadowSlime", "enemy_slime_1:1"))
	noMutation(f, function() return f.service:recordDefeat(f.player, "MeadowSlime", "enemy_slime_1:1") end)
	assert(f.service:recordDefeat(f.player, "MeadowSlime", "enemy_slime_1:2"))
	noMutation(f, function() return f.service:recordDefeat(f.player, "MeadowSlime", "enemy_slime_1:1") end)
	assert(f.changed == 2 and f.questCalls == 2)
end)

test("different spawns have independent generation credit", function()
	local f, profile = fixture()
	assert(f.service:recordDefeat(f.player, "MeadowSlime", "enemy_left:10"))
	assert(f.service:recordDefeat(f.player, "MeadowSlime", "enemy_right:1"))
	assert(profile.xp == 40 and profile.gold == 6)
end)

test("repeatable combat rewards do not grow permanent reward history", function()
	local f, profile = fixture()
	for index = 1, 128 do profile.claimedRewards["existing_" .. index] = true end
	for generation = 1, 180 do
		assert(f.service:recordDefeat(f.player, "MeadowSlime", "enemy_repeat:" .. generation))
	end
	local claims = 0; for _ in profile.claimedRewards do claims += 1 end
	assert(claims == 128 and profile.gold == 540 and profile.level > 1)
	assert(Progression.validate(profile))
end)

test("combat levelling updates derived statistics while preserving inventory identity", function()
	local f, profile = fixture()
	local items, stats = copy(profile.inventory), Progression.stats(profile)
	for generation = 1, 5 do assert(f.service:recordDefeat(f.player, "MeadowSlime", "enemy_slime:" .. generation)) end
	assert(profile.level == 2 and profile.xp == 0 and profile.gold == 15)
	assert(equal(items, profile.inventory))
	local grown = Progression.stats(profile)
	assert(grown.MaxHealth == stats.MaxHealth + 5 and grown.Attack == stats.Attack + 1)
	assert(grown.MagicPower == stats.MagicPower + 1)
end)

test("verified defeats advance an accepted field quest once", function()
	local f, profile = fixture()
	assert(Quest.interact(profile, "Rowan")); assert(Quest.interact(profile, "Blacksmith"))
	assert(Quest.interact(profile, "Rowan")); assert(Quest.interact(profile, "Rowan"))
	for generation = 1, 4 do assert(f.service:recordDefeat(f.player, "Thornling", "enemy_thorn:" .. generation)) end
	assert(profile.quests.fieldsKills == 4 and not profile.claimedRewards.quest_fields)
	assert(Quest.interact(profile, "Rowan"))
	assert(profile.claimedRewards.quest_fields and Quest.validateProfile(profile))
	assert(f.service:recordDefeat(f.player, "Thornling", "enemy_thorn:5"))
	assert(profile.quests.fieldsKills == 4)
end)

test("missing players and unwritable sessions cannot receive rewards", function()
	local f = fixture()
	assert(not f.service:recordDefeat({}, "MeadowSlime", "enemy_slime:1"))
	f.allowed = false
	noMutation(f, function() return f.service:recordDefeat(f.player, "MeadowSlime", "enemy_slime:1") end)
	f.allowed = true
	assert(f.service:recordDefeat(f.player, "MeadowSlime", "enemy_slime:1"), "Refused save must not consume credit")
end)

test("unknown kinds and malformed server kill IDs preserve all state", function()
	local f = fixture()
	for _, kind in { "TrainingDummy", "Unknown", {}, true, 100 } do
		noMutation(f, function() return f.service:recordDefeat(f.player, kind, "enemy_slime:1") end)
	end
	for _, id in { "", "dummy_1:1", "enemy_slime", "enemy_slime:0", "enemy_slime:-1", "enemy_slime:1.5",
		"enemy_slime:01", "enemy_:1", "enemy_slime:1000000001", "enemy_slime:1:2", string.rep("x", 129), {}, true, 9 } do
		noMutation(f, function() return f.service:recordDefeat(f.player, "MeadowSlime", id) end)
	end
end)

test("a failed currency-cap reward stays atomic and does not consume kill credit", function()
	local f, profile = fixture(); profile.gold = 1e9
	noMutation(f, function() return f.service:recordDefeat(f.player, "MeadowSlime", "enemy_slime:1") end)
	assert(f.questCalls == 0)
	profile.gold = 0
	assert(f.service:recordDefeat(f.player, "MeadowSlime", "enemy_slime:1"))
	assert(profile.xp == 20 and profile.gold == 3)
end)

test("per-player credits never suppress another eligible player's reward", function()
	local f, first = fixture(); local secondPlayer = {}
	local second = Progression.newProfile("Ranger"); Quest.ensure(second)
	f.profiles[secondPlayer] = second
	f.service.options.onChanged = function() end
	assert(f.service:recordDefeat(f.player, "WildBoar", "enemy_boar:1"))
	assert(f.service:recordDefeat(secondPlayer, "WildBoar", "enemy_boar:1"))
	assert(first.xp == 35 and second.xp == 35 and first.gold == 5 and second.gold == 5)
end)

test("spawn credit map is bounded and cannot be filled past 64 entries", function()
	local f = fixture()
	for index = 1, 64 do assert(f.service:recordDefeat(f.player, "MeadowSlime", "enemy_spawn_" .. index .. ":1")) end
	noMutation(f, function() return f.service:recordDefeat(f.player, "MeadowSlime", "enemy_spawn_65:1") end)
	assert(f.service:recordDefeat(f.player, "MeadowSlime", "enemy_spawn_1:2"))
end)

test("removal and destruction clean ephemeral credit without mutating persistent claims", function()
	local f, profile = fixture()
	assert(f.service:recordDefeat(f.player, "MeadowSlime", "enemy_slime:1"))
	f.service:removePlayer(f.player)
	assert(f.service.credited[f.player] == nil and next(profile.claimedRewards) == nil)
	f.service:destroy()
	noMutation(f, function() return f.service:recordDefeat(f.player, "MeadowSlime", "enemy_slime:2") end)
	assert(next(f.service.credited) == nil)
end)

test("combat reward helper rejects malformed and excessive amounts atomically", function()
	local f, profile = fixture()
	for _, amounts in { { 0, 1 }, { -1, 1 }, { 1001, 1 }, { 1.5, 1 }, { 0/0, 1 }, { math.huge, 1 },
		{ 1, -1 }, { 1, 101 }, { 1, 1.5 }, { 1, 0/0 }, { "20", 3 }, { 20, "3" } } do
		noMutation(f, function() return Progression.grantCombatReward(profile, amounts[1], amounts[2]) end)
	end
	assert(Progression.grantCombatReward(profile, 1, 0))
	assert(profile.xp == 1 and profile.gold == 0)
end)

test("level-cap combat rewards keep XP normalized without growing claims", function()
	local _, profile = fixture(); profile.level, profile.xp = 60, 0
	local ok, _, summary = Progression.grantCombatReward(profile, 1000, 100)
	assert(ok and profile.level == 60 and profile.xp == 0 and profile.gold == 100)
	assert(summary.levelsGained == 0 and summary.level == 60 and next(profile.claimedRewards) == nil)
end)

print(passed .. " enemy-reward tests passed; rewards originate only from trusted server defeat callbacks.")
