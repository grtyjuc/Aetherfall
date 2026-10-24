-- Pure quest transitions, not live NPC interaction or DataStore tests.
local Rules = require("../src/shared/QuestRules")
local Progression = require("../src/shared/ProgressionRules")
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
local function profile(className)
	local result = Progression.newProfile(className or "Sentinel")
	Rules.ensure(result)
	return result
end
local function introduction(result)
	assert(Rules.interact(result, "Rowan"))
	assert(Rules.interact(result, "Blacksmith"))
	assert(Rules.interact(result, "Rowan"))
end
local function fields(result)
	introduction(result)
	assert(Rules.interact(result, "Rowan"))
	for _, kind in { "MeadowSlime", "WildBoar", "Thornling", "MeadowSlime" } do assert(Rules.recordDefeat(result, kind)) end
end
local function rejectedUnchanged(result, callback)
	local before = copy(result)
	assert(not callback())
	assert(equal(before, result), "Rejected action mutated profile")
end

test("ensure initializes missing quest state without touching existing profile fields", function()
	local result = Progression.newProfile("Ranger")
	local before = copy(result)
	Rules.ensure(result)
	assert(Rules.validate(result.quests))
	for key, value in before do assert(equal(result[key], value)) end
	result.quests.strangerStage = 1
	local owned = result.quests
	assert(Rules.ensure(result) == owned and result.quests.strangerStage == 1)
end)

test("new character objective points to Elder Rowan", function()
	local result = profile()
	local view = Rules.snapshot(result)
	assert(view.title == "A Stranger in Hearthglen" and string.find(view.objective, "Rowan"))
	assert(view.strangerStage == 0 and not view.strangerDone and not view.fieldsDone)
end)

test("stranger quest follows Rowan, Tessa, Rowan in order", function()
	local result = profile()
	assert(Rules.interact(result, "Rowan")); assert(result.quests.strangerStage == 1)
	assert(string.find(Rules.snapshot(result).objective, "Tessa"))
	assert(Rules.interact(result, "Blacksmith")); assert(result.quests.strangerStage == 2)
	local ok, text, summary = Rules.interact(result, "Rowan")
	assert(ok and type(text) == "string" and summary.xp == 100 and summary.gold == 20)
	assert(summary.items[1] == "wayfarer_lantern")
	assert(result.quests.strangerStage == 3 and result.claimedRewards.quest_stranger)
	assert(result.level == 2 and result.xp == 0 and result.gold == 20)
	assert(Rules.validateProfile(result))
end)

test("Tessa cannot skip the introduction or repeatedly advance it", function()
	local result = profile()
	rejectedUnchanged(result, function() return Rules.interact(result, "Blacksmith") end)
	Rules.interact(result, "Rowan"); Rules.interact(result, "Blacksmith")
	rejectedUnchanged(result, function() return Rules.interact(result, "Blacksmith") end)
	assert(result.quests.strangerStage == 2)
end)

test("Rowan guidance before meeting Tessa grants nothing", function()
	local result = profile(); Rules.interact(result, "Rowan")
	rejectedUnchanged(result, function() return Rules.interact(result, "Rowan") end)
	assert(result.level == 1 and result.gold == 0)
end)

test("field quest requires a separate acceptance after introduction", function()
	local result = profile(); introduction(result)
	assert(not result.quests.fieldsAccepted)
	assert(Rules.interact(result, "Rowan"))
	assert(result.quests.fieldsAccepted and result.quests.fieldsKills == 0)
	assert(Rules.validateProfile(result))
end)

test("defeats before field acceptance do not mutate quest or grant rewards", function()
	local result = profile()
	rejectedUnchanged(result, function() return Rules.recordDefeat(result, "MeadowSlime") end)
	introduction(result)
	rejectedUnchanged(result, function() return Rules.recordDefeat(result, "WildBoar") end)
end)

test("all three server creature kinds contribute and progress caps at four", function()
	local result = profile(); fields(result)
	assert(result.quests.fieldsKills == 4)
	rejectedUnchanged(result, function() return Rules.recordDefeat(result, "Thornling") end)
	assert(result.gold == 20, "Counting defeats must not award combat currency")
	assert(string.find(Rules.snapshot(result).objective, "Return to Elder Rowan"))
end)

test("unknown creature names, IDs and malformed types cannot advance objectives", function()
	local result = profile(); introduction(result); Rules.interact(result, "Rowan")
	for _, kind in { "TrainingDummy", "dummy_1", "WildBoar_123", "Unknown", {}, 100, true } do
		rejectedUnchanged(result, function() return Rules.recordDefeat(result, kind) end)
	end
end)

test("field turn-in cannot happen before four verified defeats", function()
	local result = profile(); introduction(result); Rules.interact(result, "Rowan")
	Rules.recordDefeat(result, "MeadowSlime")
	rejectedUnchanged(result, function() return Rules.interact(result, "Rowan") end)
	assert(not result.claimedRewards.quest_fields)
end)

test("field turn-in awards configured XP, gold and charm once", function()
	local result = profile(); fields(result)
	local ok, _, summary = Rules.interact(result, "Rowan")
	assert(ok and summary.xp == 150 and summary.gold == 60 and summary.items[1] == "scouts_charm")
	assert(result.gold == 80 and result.claimedRewards.quest_fields)
	assert(Rules.snapshot(result).fieldsDone and Rules.snapshot(result).strangerDone)
	rejectedUnchanged(result, function() return Rules.interact(result, "Rowan") end)
	rejectedUnchanged(result, function() return Rules.recordDefeat(result, "WildBoar") end)
	assert(Rules.validateProfile(result))
end)

for _, className in { "Sentinel", "Spellweaver", "Ranger" } do
	test(className .. " completes both quests without class-specific gates", function()
		local result = profile(className); fields(result)
		assert(Rules.interact(result, "Rowan"))
		assert(Rules.validateProfile(result) and result.className == className)
	end)
end

test("unknown or malformed NPC identifiers preserve all player state", function()
	local result = profile()
	for _, id in { "Mira", "rowan", "quest_fields", {}, false, 3 } do
		rejectedUnchanged(result, function() return Rules.interact(result, id) end)
	end
end)

test("failed introduction reward leaves its objective ready for retry", function()
	local result = profile(); Rules.interact(result, "Rowan"); Rules.interact(result, "Blacksmith")
	result.gold = 1e9
	rejectedUnchanged(result, function() return Rules.interact(result, "Rowan") end)
	assert(result.quests.strangerStage == 2 and not result.claimedRewards.quest_stranger)
	result.gold = 0
	assert(Rules.interact(result, "Rowan") and result.quests.strangerStage == 3)
end)

test("failed field reward retains completed objective without claiming or incrementing", function()
	local result = profile(); fields(result); result.gold = 1e9
	rejectedUnchanged(result, function() return Rules.interact(result, "Rowan") end)
	assert(result.quests.fieldsKills == 4 and not result.claimedRewards.quest_fields)
	result.gold = 20
	assert(Rules.interact(result, "Rowan"))
end)

test("full inventory cannot consume introduction completion or its reward", function()
	local result = profile(); Rules.interact(result, "Rowan"); Rules.interact(result, "Blacksmith")
	local template = copy(result.inventory[next(result.inventory)])
	for index = result.nextId, 200 do
		local uid = string.format("gear_%06d", index)
		local instance = copy(template); instance.uid = uid
		result.inventory[uid] = instance
	end
	result.nextId = 201
	assert(Progression.validate(result))
	rejectedUnchanged(result, function() return Rules.interact(result, "Rowan") end)
	assert(result.quests.strangerStage == 2 and result.gold == 0 and not result.claimedRewards.quest_stranger)
end)

test("owned quest gear is not duplicated during a valid turn-in", function()
	local result = profile()
	assert(Progression.grantReward(result, "fixture_lantern", { xp = 0, gold = 0, items = { "wayfarer_lantern" } }))
	local count = 0; for _ in result.inventory do count += 1 end
	introduction(result)
	local after = 0; for _ in result.inventory do after += 1 end
	assert(after == count and result.gold == 20)
end)

test("quest snapshots contain values only and cannot mutate profiles", function()
	local result = profile(); local view = Rules.snapshot(result)
	view.strangerStage, view.fieldsKills, view.objective = 3, 4, "changed"
	assert(result.quests.strangerStage == 0 and result.quests.fieldsKills == 0)
end)

test("quest validation rejects missing, unknown, malformed and inconsistent fields", function()
	for _, value in { {}, { strangerStage = 4, fieldsAccepted = false, fieldsKills = 0 },
		{ strangerStage = 1.5, fieldsAccepted = false, fieldsKills = 0 },
		{ strangerStage = 3, fieldsAccepted = "true", fieldsKills = 0 },
		{ strangerStage = 0, fieldsAccepted = true, fieldsKills = 0 },
		{ strangerStage = 3, fieldsAccepted = false, fieldsKills = 1 },
		{ strangerStage = 3, fieldsAccepted = true, fieldsKills = 5 },
		{ strangerStage = 0, fieldsAccepted = false, fieldsKills = 0, extra = true } } do
		assert(not Rules.validate(value))
	end
	local value = { strangerStage = 0, fieldsAccepted = false, fieldsKills = 0 }
	setmetatable(value, {}); assert(not Rules.validate(value))
end)

test("reward claims and saved quest objectives cannot contradict one another", function()
	local result = profile(); result.claimedRewards.quest_stranger = true
	assert(not Rules.validateProfile(result))
	result = profile(); result.quests.strangerStage = 3
	assert(not Rules.validateProfile(result))
	result = profile(); introduction(result); result.claimedRewards.quest_fields = true
	assert(not Rules.validateProfile(result))
end)

print(passed .. " quest-rule tests passed; no live NPC or DataStore calls were made.")
