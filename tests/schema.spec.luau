local Schema = require("../src/server/PlayerSchema")
local Equipment = require("../src/shared/EquipmentRules")
local Progression = require("../src/shared/ProgressionRules")
local Quest = require("../src/shared/QuestRules")
local passed = 0
local function test(name, run)
	local ok, reason = pcall(run)
	assert(ok, "FAIL " .. name .. ": " .. tostring(reason))
	passed += 1
	print("PASS " .. name)
end
local function copy(value)
	if type(value) ~= "table" then return value end
	local result = {}
	for key, child in value do result[key] = copy(child) end
	return result
end
local function equal(a, b)
	if type(a) ~= "table" or type(b) ~= "table" then return a == b end
	for key, value in a do if not equal(value, b[key]) then return false end end
	for key in b do if a[key] == nil then return false end end
	return true
end
local function fresh() return Schema.encode(Schema.newProfile()) end
local function reject(raw)
	local result, reason = Schema.decode(raw)
	assert(result == nil and type(reason) == "string" and #reason > 0)
end

test("nil record alone creates a level-one Sentinel with starter gear", function()
	local profile = Schema.decode(nil)
	assert(profile.className == "Sentinel" and profile.level == 1)
	assert(profile.xp == 0 and profile.gold == 0 and next(profile.claimedRewards) == nil)
	assert(Equipment.validateProfile(profile))
end)
for _, className in { "Sentinel", "Spellweaver", "Ranger" } do
	test(className .. " round-trips with stable item identifiers", function()
		local profile = Schema.newProfile(className)
		local raw = Schema.encode(profile)
		local decoded, reason = Schema.decode(raw)
		assert(decoded, reason)
		assert(equal(profile, decoded))
		assert(decoded.nextId == profile.nextId)
	end)
end
test("saved and loaded records share no mutable state", function()
	local profile = Schema.newProfile()
	local raw = Schema.encode(profile)
	local loaded = assert(Schema.decode(raw))
	local uid = next(profile.inventory)
	profile.inventory[uid].locked = true
	loaded.inventory[uid].locked = true
	assert(raw.data.inventory[uid].locked == false)
	loaded.claimedRewards.independent = true
	assert(raw.data.claimedRewards.independent == nil and profile.claimedRewards.independent == nil)
end)
test("XP, gold, claimed rewards and selected equipment survive round-trip", function()
	local profile = Schema.newProfile("Ranger")
	assert(Progression.addXp(profile, 320))
	profile.gold = 147
	profile.claimedRewards.curriculum_basic = true
	local raw = Schema.encode(profile)
	assert(equal(profile, assert(Schema.decode(raw))))
end)
test("unknown, missing and malformed envelopes never reset to starter data", function()
	for _, raw in { false, 5, "bad", {}, { version = 1 }, { data = {} }, { version = 2, data = {} },
		{ version = "1", data = {} }, { version = 0 / 0, data = {} }, { version = 1, data = {}, extra = true } } do
		reject(raw)
	end
end)
test("unknown profile and inventory instance fields are rejected", function()
	local raw = fresh(); raw.data.secretBlob = "not part of schema"; reject(raw)
	raw = fresh(); raw.data.inventory[next(raw.data.inventory)].arbitrary = true; reject(raw)
end)
test("unknown item definitions and unsupported upgrades are preserved as errors", function()
	local raw = fresh(); raw.data.inventory[next(raw.data.inventory)].itemId = "removed_item"; reject(raw)
	raw = fresh(); raw.data.inventory[next(raw.data.inventory)].upgradeLevel = 1; reject(raw)
end)
test("nonfinite, negative and fractional numeric fields cannot enter live state", function()
	for _, key in { "level", "xp", "gold", "nextId" } do
		for _, value in { 0 / 0, math.huge, -math.huge, -1, 1.5 } do
			local raw = fresh(); raw.data[key] = value; reject(raw)
		end
	end
	local raw = fresh(); raw.data.gold = 1e9 + 1; reject(raw)
	raw = fresh(); raw.data.nextId = 1e9 + 1; reject(raw)
end)
test("XP must be normalized for its level and zero at the level cap", function()
	local raw = fresh(); raw.data.xp = Progression.requiredXp(1); reject(raw)
	raw = fresh(); raw.data.level = 60; raw.data.xp = 1; reject(raw)
	raw.data.xp = 0; assert(Schema.decode(raw))
end)
test("sequence collisions with existing gear IDs are rejected", function()
	local raw = fresh(); raw.data.nextId = 1; reject(raw)
	raw = fresh(); raw.data.nextId = 8; reject(raw)
	raw = fresh()
	local uid = next(raw.data.inventory)
	local instance = raw.data.inventory[uid]
	raw.data.inventory[uid] = nil
	instance.uid = "gear_1000000000"
	raw.data.inventory[instance.uid] = instance
	reject(raw)
end)
test("item instance identity and equipped ownership cannot be forged", function()
	local raw = fresh(); raw.data.inventory[next(raw.data.inventory)].uid = "different"; reject(raw)
	raw = fresh(); raw.data.equipped.MainHand = "not_owned"; reject(raw)
	raw = fresh(); raw.data.equipped.OffHand = raw.data.equipped.MainHand; reject(raw)
end)
test("class, level and hand compatibility are enforced on saved equipment", function()
	local raw = fresh(); raw.data.className = "Ranger"; reject(raw)
	raw = fresh(); raw.data.level = 0; reject(raw)
	local sandbox = Equipment.newProfile("Sentinel", 10, true)
	sandbox.xp, sandbox.gold, sandbox.claimedRewards = 0, 0, {}
	local twoHand
	for uid, item in sandbox.inventory do if item.itemId == "grove_greatsword" then twoHand = uid end end
	sandbox.equipped.MainHand = twoHand
	reject({ version = 1, data = sandbox })
end)
test("duplicate equipped accessories cannot pass schema validation", function()
	local raw = fresh()
	raw.data.equipped.Accessory2 = raw.data.equipped.Accessory1
	reject(raw)
end)
test("inventories over 200 entries are rejected before copying", function()
	local raw = fresh()
	local template = copy(raw.data.inventory[next(raw.data.inventory)])
	raw.data.inventory, raw.data.equipped, raw.data.nextId = {}, {}, 202
	for index = 1, 201 do
		local uid = string.format("gear_%06d", index)
		local item = copy(template); item.uid = uid
		raw.data.inventory[uid] = item
	end
	reject(raw)
end)
test("reward history rejects false, oversized, empty or unbounded entries", function()
	local raw = fresh(); raw.data.claimedRewards.test = false; reject(raw)
	raw = fresh(); raw.data.claimedRewards[""] = true; reject(raw)
	raw = fresh(); raw.data.claimedRewards[string.rep("x", 65)] = true; reject(raw)
	raw = fresh(); for index = 1, 129 do raw.data.claimedRewards["reward_" .. index] = true end; reject(raw)
end)
test("cycles, unsupported values, numeric keys and metatables fail without recursion errors", function()
	local raw = fresh(); raw.data.inventory.cycle = raw; reject(raw)
	raw = fresh(); raw.data.extra = function() end; reject(raw)
	raw = fresh(); raw.data.inventory[1] = {}; reject(raw)
	raw = fresh(); setmetatable(raw.data, {}); reject(raw)
	raw = fresh(); raw.data.className = string.rep("x", 65); reject(raw)
end)
test("explicit version-zero migration preserves gear, class and level", function()
	local profile = Equipment.newProfile("Spellweaver", 8, false)
	local original = copy(profile)
	local loaded, reason = Schema.decode({ version = 0, data = profile })
	assert(loaded, reason)
	assert(loaded.className == "Spellweaver" and loaded.level == 8 and loaded.xp == 0 and loaded.gold == 0)
	assert(equal(loaded.inventory, original.inventory) and equal(loaded.equipped, original.equipped))
	assert(equal(profile, original), "Migration mutated saved record")
	assert(Schema.encode(loaded).version == 2)
	assert(Quest.validate(loaded.quests))
end)
test("ambiguous unversioned records and malformed legacy data are not migrated", function()
	reject(Equipment.newProfile("Sentinel", 1, false))
	local legacy = Equipment.newProfile("Ranger", 1, false)
	legacy.inventory[next(legacy.inventory)].itemId = "unknown"
	reject({ version = 0, data = legacy })
end)
test("encoding malformed live state fails instead of writing corrupt records", function()
	local profile = Schema.newProfile(); profile.gold = -1
	assert(not pcall(Schema.encode, profile))
	profile = Schema.newProfile(); profile.inventory.cycle = profile
	assert(not pcall(Schema.encode, profile))
end)
test("version-one migration preserves earned training progress and gear", function()
	local old = Progression.newProfile("Ranger")
	assert(Progression.grantReward(old, "curriculum_basic", { xp = 100, gold = 10, items = {} }))
	local before = copy(old)
	local loaded, reason = Schema.decode({ version = 1, data = old })
	assert(loaded, reason)
	for key, value in before do assert(equal(loaded[key], value)) end
	assert(Quest.validate(loaded.quests) and loaded.quests.strangerStage == 0)
	assert(equal(old, before), "Migration mutated stored version-one data")
	assert(Schema.encode(loaded).version == 2)
end)
test("encoding a fresh progression profile adds quests to a copy only", function()
	local source = Progression.newProfile("Spellweaver")
	assert(source.quests == nil)
	local encoded = Schema.encode(source)
	assert(encoded.version == 2 and Quest.validate(encoded.data.quests))
	assert(source.quests == nil)
end)
test("version-two data requires quest state while old versions reject unknown quest fields", function()
	local raw = fresh(); raw.data.quests = nil; reject(raw)
	raw = fresh(); raw.version = 1; reject(raw)
	local old = Equipment.newProfile("Sentinel", 1, false); old.quests = {}
	reject({ version = 0, data = old })
end)
test("quest progress and claimed quest rewards survive a version-two round-trip", function()
	local source = Schema.newProfile()
	assert(Quest.interact(source, "Rowan")); assert(Quest.interact(source, "Blacksmith"))
	assert(Quest.interact(source, "Rowan")); assert(Quest.interact(source, "Rowan"))
	for _ = 1, 4 do assert(Quest.recordDefeat(source, "MeadowSlime")) end
	assert(Quest.interact(source, "Rowan"))
	local encoded = Schema.encode(source)
	local loaded = assert(Schema.decode(encoded))
	assert(equal(source, loaded) and loaded.claimedRewards.quest_stranger and loaded.claimedRewards.quest_fields)
	assert(not Quest.interact(loaded, "Rowan"), "Reloaded quest could grant twice")
end)
test("inconsistent quest claims and invalid quest fields are rejected without repair", function()
	local raw = fresh(); raw.data.quests.strangerStage = 3; reject(raw)
	raw = fresh(); raw.data.claimedRewards.quest_stranger = true; reject(raw)
	raw = fresh(); raw.data.claimedRewards.quest_fields = true; reject(raw)
	raw = fresh(); raw.data.quests.fieldsKills = 1; reject(raw)
	raw = fresh(); raw.data.quests.strangerStage = 0 / 0; reject(raw)
	raw = fresh(); raw.data.quests.unknown = true; reject(raw)
	raw = fresh(); raw.data.quests.fieldsAccepted = true; reject(raw)
end)
test("future schema versions do not become new profiles", function()
	local raw = fresh(); raw.version = 3; reject(raw)
end)
print(passed .. " save-schema tests passed; no live DataStore calls were made.")
