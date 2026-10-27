-- Pure quest/reward transitions; boss geometry and prompt authority are tested separately.
local Grove = require("../src/shared/GroveRules")
local Quest = require("../src/shared/QuestRules")
local Progression = require("../src/shared/ProgressionRules")
local Schema = require("../src/server/PlayerSchema")
local passed = 0
local function test(name, callback)
	local ok, reason = pcall(callback)
	assert(ok, "FAIL " .. name .. ": " .. tostring(reason))
	passed += 1
	print("PASS " .. name)
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
local function unchanged(profile, callback)
	local before = copy(profile)
	assert(not callback())
	assert(equal(profile, before), "Rejected grove transition changed player data")
end
local function ready(className)
	local profile = Schema.newProfile(className or "Sentinel")
	assert(Progression.addXp(profile, 500))
	assert(Quest.interact(profile, "Rowan")); assert(Quest.interact(profile, "Blacksmith"))
	assert(Quest.interact(profile, "Rowan")); assert(Quest.interact(profile, "Rowan"))
	for _ = 1, 4 do assert(Quest.recordDefeat(profile, "MeadowSlime")) end
	assert(Quest.interact(profile, "Rowan"))
	return profile
end
local function challenge(className)
	local profile = ready(className)
	assert(Quest.interact(profile, "Rowan"))
	assert(Grove.inspectRune(profile))
	return profile
end

test("new and migrated quest profiles start at an unaccepted grove stage", function()
	local profile = Schema.newProfile()
	assert(profile.quests.groveStage == 0 and Grove.validateProfile(profile))
	profile.quests.groveStage = nil
	Grove.ensure(profile)
	assert(profile.quests.groveStage == 0)
	profile.quests.groveStage = 1
	assert(Grove.ensure(profile).groveStage == 1, "Ensure must preserve existing progress")
end)

test("the grove cannot skip unfinished village quests", function()
	local profile = Schema.newProfile()
	unchanged(profile, function() return Grove.interact(profile) end)
	unchanged(profile, function() return Grove.inspectRune(profile) end)
	unchanged(profile, function() return Grove.recordBossDefeat(profile) end)
	assert(not Grove.canChallenge(profile))
end)

test("Rowan offers the grove after the field quest without repeating its reward", function()
	local profile = ready()
	local gold = profile.gold
	assert(Quest.interact(profile, "Rowan") and profile.quests.groveStage == 1)
	assert(profile.gold == gold and profile.claimedRewards.quest_fields)
	unchanged(profile, function() return Quest.interact(profile, "Rowan") end)
	assert(string.find(Quest.snapshot(profile).objective, "runestone"))
end)

test("the runestone must be inspected before challenge eligibility", function()
	local profile = ready(); assert(Grove.interact(profile))
	assert(not Grove.canChallenge(profile))
	assert(Grove.inspectRune(profile) and profile.quests.groveStage == 2)
	assert(Grove.canChallenge(profile))
	unchanged(profile, function() return Grove.inspectRune(profile) end)
end)

test("level three gate is server-owned and rune inspection grants no experience", function()
	local profile = ready(); profile.level, profile.xp = 2, 0
	assert(Grove.interact(profile)); assert(Grove.inspectRune(profile))
	assert(profile.level == 2 and profile.xp == 0)
	unchanged(profile, function() return Grove.recordBossDefeat(profile) end)
	local available, message = Grove.canChallenge(profile)
	assert(not available and string.find(message, "level 3"))
	profile.level = 3
	assert(Grove.canChallenge(profile))
end)

test("an uninspected rune cannot receive a trusted defeat reward", function()
	local profile = ready(); assert(Grove.interact(profile))
	unchanged(profile, function() return Grove.recordBossDefeat(profile) end)
	assert(not profile.claimedRewards.boss_briarwarden)
end)

local expectedItems = { Sentinel = "briarwarden_shield", Spellweaver = "briarwarden_staff", Ranger = "briarwarden_bow" }
for className, itemId in expectedItems do
	test(className .. " first boss reward grants class gear and reaches its tier", function()
		local profile = challenge(className)
		local previousGold = profile.gold
		local ok, message, summary = Grove.recordBossDefeat(profile)
		assert(ok, message)
		assert(summary.xp == 1300 and summary.gold == 180 and summary.items[1] == itemId)
		assert(profile.gold == previousGold + 180 and profile.level >= 5)
		assert(profile.quests.groveStage == 3 and profile.claimedRewards.boss_briarwarden)
		assert(Quest.validateProfile(profile))
		unchanged(profile, function() return Grove.recordBossDefeat(profile) end)
	end)
end

test("the boss reward and Rowan completion are separate once-only transactions", function()
	local profile = challenge()
	assert(Grove.recordBossDefeat(profile))
	assert(not profile.claimedRewards.quest_grove)
	assert(string.find(Quest.snapshot(profile).objective, "Return to Elder Rowan"))
	local gold = profile.gold
	local ok, message, summary = Quest.interact(profile, "Rowan")
	assert(ok, message)
	assert(summary.xp == 400 and summary.gold == 120 and #summary.items == 0)
	assert(profile.gold == gold + 120 and profile.quests.groveStage == 4 and profile.claimedRewards.quest_grove)
	assert(Quest.snapshot(profile).groveDone and Grove.snapshot(profile).bossDefeated)
	unchanged(profile, function() return Quest.interact(profile, "Rowan") end)
	unchanged(profile, function() return Grove.recordBossDefeat(profile) end)
end)

test("completed characters can help again without receiving duplicate first-clear rewards", function()
	local profile = challenge(); assert(Grove.recordBossDefeat(profile)); assert(Grove.interact(profile))
	assert(Grove.canChallenge(profile))
	unchanged(profile, function() return Grove.recordBossDefeat(profile) end)
	assert(profile.quests.groveStage == 4)
end)

test("boss currency-cap failure leaves the reward and quest ready for retry", function()
	local profile = challenge(); profile.gold = 1e9
	unchanged(profile, function() return Grove.recordBossDefeat(profile) end)
	assert(profile.quests.groveStage == 2 and not profile.claimedRewards.boss_briarwarden)
	profile.gold = 0
	assert(Grove.recordBossDefeat(profile))
end)

test("full inventory cannot consume the boss first-clear reward", function()
	local profile = challenge()
	local template = copy(profile.inventory[next(profile.inventory)])
	for index = profile.nextId, 200 do
		local uid = string.format("gear_%06d", index)
		local item = copy(template); item.uid = uid; profile.inventory[uid] = item
	end
	profile.nextId = 201
	unchanged(profile, function() return Grove.recordBossDefeat(profile) end)
	assert(profile.quests.groveStage == 2 and not profile.claimedRewards.boss_briarwarden)
end)

test("already-owned boss gear is preserved rather than duplicated", function()
	local profile = challenge()
	assert(Progression.grantReward(profile, "fixture_gear", { xp = 0, gold = 0, items = { "briarwarden_shield" } }))
	local uid, count = nil, 0
	for id, instance in profile.inventory do if instance.itemId == "briarwarden_shield" then uid = id; count += 1 end end
	assert(count == 1)
	assert(Grove.recordBossDefeat(profile))
	count = 0
	for id, instance in profile.inventory do
		if instance.itemId == "briarwarden_shield" then assert(id == uid); count += 1 end
	end
	assert(count == 1)
end)

test("failed Rowan turn-in retains the defeated stage and first-clear claim", function()
	local profile = challenge(); assert(Grove.recordBossDefeat(profile)); profile.gold = 1e9
	unchanged(profile, function() return Grove.interact(profile) end)
	assert(profile.quests.groveStage == 3 and profile.claimedRewards.boss_briarwarden and not profile.claimedRewards.quest_grove)
	profile.gold = 0
	assert(Grove.interact(profile) and profile.quests.groveStage == 4)
end)

test("impossible stages and reward claims fail without repair", function()
	for _, value in { -1, 1.5, 5, 0 / 0, math.huge, "2", false } do
		local profile = challenge(); profile.quests.groveStage = value
		assert(not Grove.validateProfile(profile))
	end
	local profile = challenge(); profile.claimedRewards.boss_briarwarden = true
	assert(not Grove.validateProfile(profile))
	profile = challenge(); profile.quests.groveStage = 3
	assert(not Grove.validateProfile(profile))
	profile = challenge(); profile.claimedRewards.quest_grove = true
	assert(not Grove.validateProfile(profile))
	profile = challenge(); profile.claimedRewards.quest_fields = nil
	assert(not Grove.validateProfile(profile))
end)

test("all grove stages survive save round-trips with stable reward state", function()
	local profile = ready()
	for value = 0, 4 do
		assert(profile.quests.groveStage == value)
		local loaded = assert(Schema.decode(Schema.encode(profile)))
		assert(equal(profile, loaded))
		if value == 0 then assert(Grove.interact(profile))
		elseif value == 1 then assert(Grove.inspectRune(profile))
		elseif value == 2 then assert(Grove.recordBossDefeat(profile))
		elseif value == 3 then assert(Grove.interact(profile)) end
	end
end)

test("snapshots contain values only and cannot mutate persisted progress", function()
	local profile = challenge()
	local snapshot = Grove.snapshot(profile)
	snapshot.groveStage, snapshot.title = 4, "changed"
	assert(profile.quests.groveStage == 2)
	local empty = Grove.snapshot(nil)
	assert(empty.groveStage == 0 and not empty.groveDone)
end)

print(passed .. " grove quest tests passed; live boss encounters are not simulated here.")
