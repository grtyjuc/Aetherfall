-- Pure progression/inventory transactions. No live DataStore or Roblox engine calls.
local Catalog = require("../src/shared/EquipmentCatalog")
local Equipment = require("../src/shared/EquipmentRules")
local Rules = require("../src/shared/ProgressionRules")
local passed = 0
local function test(name, callback)
	local ok, problem = pcall(callback)
	assert(ok, "FAIL " .. name .. ": " .. tostring(problem))
	passed += 1
	print("PASS " .. name)
end
local function copy(value)
	if type(value) ~= "table" then return value end
	local result = {}
	for key, child in value do result[key] = copy(child) end
	return result
end
local function equal(first, second)
	if type(first) ~= type(second) then return false end
	if type(first) == "number" and first ~= first and second ~= second then return true end
	if type(first) ~= "table" then return first == second end
	for key, value in first do if not equal(value, second[key]) then return false end end
	for key in second do if first[key] == nil then return false end end
	return true
end
local function rejected(profile, callback)
	local before = copy(profile)
	local ok = callback()
	assert(not ok, "Expected rejected transaction")
	assert(equal(before, profile), "Rejected transaction mutated profile")
end
local function inventoryCount(profile)
	local count = 0
	for _ in profile.inventory do count += 1 end
	return count
end
local function itemCount(profile, itemId)
	local count = 0
	for _, item in profile.inventory do if item.itemId == itemId then count += 1 end end
	return count
end
local function fullInventory(profile)
	while inventoryCount(profile) < 200 do
		local uid = string.format("gear_%06d", profile.nextId)
		profile.nextId += 1
		profile.inventory[uid] = { uid = uid, itemId = "training_sword", upgradeLevel = 0, locked = false }
	end
end

test("all classes start at level one with only owned compatible starter equipment", function()
	for _, className in Catalog.Classes do
		local profile = Rules.newProfile(className)
		assert(Rules.validate(profile))
		assert(profile.level == 1 and profile.xp == 0 and profile.gold == 0)
		assert(next(profile.claimedRewards) == nil)
		assert(inventoryCount(profile) == #Catalog.StarterLoadouts[className])
		assert(Equipment.validateProfile(profile))
	end
end)

test("experience curve increases and caps explicitly at level sixty", function()
	local previous = 0
	for level = 1, 59 do
		local required = Rules.requiredXp(level)
		assert(required == math.floor(100 * level ^ 1.45) and required > previous)
		previous = required
	end
	assert(Rules.requiredXp(1) == 100 and Rules.requiredXp(60) == 0)
	for _, invalid in { 0, 61, -1, 1.5, math.huge, 0 / 0, "1" } do
		assert(not pcall(Rules.requiredXp, invalid))
	end
end)

test("exact level threshold advances once and clears current level experience", function()
	local profile = Rules.newProfile("Sentinel")
	local ok, _, gained = Rules.addXp(profile, 100)
	assert(ok and gained == 1 and profile.level == 2 and profile.xp == 0)
	assert(Rules.validate(profile))
end)

test("one reward supports multiple levels and retains the exact remainder", function()
	local profile = Rules.newProfile("Ranger")
	local total = Rules.requiredXp(1) + Rules.requiredXp(2) + Rules.requiredXp(3) + 17
	local ok, _, gained = Rules.addXp(profile, total)
	assert(ok and gained == 3 and profile.level == 4 and profile.xp == 17)
end)

test("level sixty discards overflow and subsequent experience cannot exceed the cap", function()
	local profile = Rules.newProfile("Spellweaver")
	profile.level = 59
	profile.xp = Rules.requiredXp(59) - 2
	local ok, _, gained = Rules.addXp(profile, 100000)
	assert(ok and gained == 1 and profile.level == 60 and profile.xp == 0)
	local before = copy(profile)
	local added, _, more = Rules.addXp(profile, 100)
	assert(added and more == 0 and equal(before, profile))
	assert(Rules.validate(profile))
end)

test("malformed or oversized XP grants are atomic rejections", function()
	local profile = Rules.newProfile("Sentinel")
	for _, amount in { 0, -1, 0.5, 100001, math.huge, -math.huge, 0 / 0, "100", {} } do
		rejected(profile, function() return Rules.addXp(profile, amount) end)
	end
end)

test("level bonuses add to gear statistics without mutating catalogue or equipment", function()
	local profile = Rules.newProfile("Sentinel")
	local initial = Equipment.stats(profile)
	profile.level = 10
	local stats = Rules.stats(profile)
	assert(stats.MaxHealth == initial.MaxHealth + 45)
	assert(stats.Attack == initial.Attack + 9 and stats.MagicPower == initial.MagicPower + 9)
	assert(stats.Defence == initial.Defence + 4)
	assert(stats.MoveSpeed == initial.MoveSpeed and stats.CriticalChance == initial.CriticalChance)
	assert(equal(Equipment.stats(profile), initial), "Base equipment stats mutated")
end)

test("reward atomically grants currency, XP, unique item instances and claim", function()
	local profile = Rules.newProfile("Sentinel")
	local count, nextId = inventoryCount(profile), profile.nextId
	local ok, _, summary = Rules.grantReward(profile, "curriculum_basic", { xp = 100, gold = 25, items = { "iron_longsword" } })
	assert(ok and profile.gold == 25 and profile.level == 2 and profile.xp == 0)
	assert(profile.claimedRewards.curriculum_basic == true)
	assert(inventoryCount(profile) == count + 1 and profile.nextId == nextId + 1)
	local item = profile.inventory[string.format("gear_%06d", nextId)]
	assert(item and item.itemId == "iron_longsword" and item.uid == string.format("gear_%06d", nextId))
	assert(summary.xp == 100 and summary.gold == 25 and summary.levelsGained == 1 and summary.items[1] == "iron_longsword")
	assert(Rules.validate(profile))
end)

test("a claimed reward cannot duplicate XP, currency or inventory", function()
	local profile = Rules.newProfile("Ranger")
	local spec = { xp = 150, gold = 40, items = { "hunting_knife" } }
	assert(Rules.grantReward(profile, "curriculum_basic", spec))
	for _ = 1, 10 do rejected(profile, function() return Rules.grantReward(profile, "curriculum_basic", spec) end) end
end)

test("known owned or repeated reward item definitions never create duplicate instances", function()
	local profile = Rules.newProfile("Sentinel")
	local count = inventoryCount(profile)
	local ok, _, summary = Rules.grantReward(profile, "unique_gear", {
		xp = 0, gold = 1, items = { "training_sword", "iron_longsword", "iron_longsword" },
	})
	assert(ok and inventoryCount(profile) == count + 1 and #summary.items == 1)
	assert(itemCount(profile, "training_sword") == 1 and itemCount(profile, "iron_longsword") == 1)
	assert(profile.gold == 1 and profile.xp == 0)
end)

test("unknown reward items reject before any currency, XP, items or claim changes", function()
	local profile = Rules.newProfile("Sentinel")
	rejected(profile, function()
		return Rules.grantReward(profile, "bad_item", { xp = 500, gold = 50, items = { "iron_longsword", "forged_item" } })
	end)
end)

test("reward specifications reject negative, nonfinite, sparse and dictionary values atomically", function()
	local profile = Rules.newProfile("Sentinel")
	local specs = {
		{ xp = -1, gold = 10, items = {} }, { xp = 100001, gold = 0, items = {} },
		{ xp = 0, gold = -1, items = {} }, { xp = 0, gold = math.huge, items = {} },
		{ xp = 0 / 0, gold = 0, items = {} }, { xp = 0, gold = 0.5, items = {} },
		{ xp = 0, gold = 0, items = { [2] = "iron_longsword" } },
		{ xp = 0, gold = 0, items = { id = "iron_longsword" } },
		{ xp = 0, gold = 0, items = { {} } }, { xp = 0, gold = 0, items = "iron_longsword" }, {},
	}
	for _, spec in specs do rejected(profile, function() return Rules.grantReward(profile, "invalid", spec) end) end
end)

test("invalid reward IDs cannot create arbitrary claim keys", function()
	local profile = Rules.newProfile("Ranger")
	for _, id in { "", string.rep("x", 65), "bad/path", "a b", {}, 10 } do
		rejected(profile, function() return Rules.grantReward(profile, id, { xp = 0, gold = 0, items = {} }) end)
	end
end)

test("currency limit rejects overflowing rewards and accepts exact boundary", function()
	local profile = Rules.newProfile("Sentinel")
	profile.gold = 999999999
	rejected(profile, function() return Rules.grantReward(profile, "overflow", { xp = 0, gold = 2, items = {} }) end)
	assert(Rules.grantReward(profile, "boundary", { xp = 0, gold = 1, items = {} }))
	assert(profile.gold == 1000000000)
end)

test("full inventory prevents item grants but allows already-owned items and currency", function()
	local profile = Rules.newProfile("Sentinel")
	fullInventory(profile)
	assert(Rules.validate(profile))
	rejected(profile, function() return Rules.grantReward(profile, "full", { xp = 100, gold = 10, items = { "iron_longsword" } }) end)
	assert(Rules.grantReward(profile, "owned", { xp = 1, gold = 10, items = { "training_sword" } }))
	assert(inventoryCount(profile) == 200 and profile.xp == 1 and profile.gold == 10)
end)

test("reward claim history is bounded without deleting previous claims", function()
	local profile = Rules.newProfile("Sentinel")
	for index = 1, 128 do profile.claimedRewards["claim_" .. index] = true end
	assert(Rules.validate(profile))
	rejected(profile, function() return Rules.grantReward(profile, "claim_129", { xp = 0, gold = 1, items = {} }) end)
	assert(profile.claimedRewards.claim_1 and profile.claimedRewards.claim_128)
end)

test("class selection grants only missing starters and preserves progression and item identity", function()
	local profile = Rules.newProfile("Sentinel")
	assert(Rules.grantReward(profile, "first", { xp = 150, gold = 33, items = {} }))
	local oldInventory = table.clone(profile.inventory)
	assert(Rules.selectClass(profile, "Spellweaver"))
	assert(profile.className == "Spellweaver" and profile.level == 2 and profile.xp == 50 and profile.gold == 33)
	assert(profile.claimedRewards.first)
	for uid, instance in oldInventory do assert(profile.inventory[uid] == instance) end
	for _, id in Catalog.StarterLoadouts.Spellweaver do assert(itemCount(profile, id) == 1) end
	assert(Equipment.validateProfile(profile))
end)

test("repeated transitions across all classes never duplicate starter gear", function()
	local profile = Rules.newProfile("Sentinel")
	for _ = 1, 5 do
		for _, className in Catalog.Classes do
			assert(Rules.selectClass(profile, className))
			assert(Rules.validate(profile))
		end
	end
	local unique = {}
	for _, instance in profile.inventory do assert(not unique[instance.itemId]); unique[instance.itemId] = true end
	assert(itemCount(profile, "hearthstone_pendant") == 1 and itemCount(profile, "copper_band") == 1)
end)

test("full inventory and invalid class selection reject without partial class or starter changes", function()
	local profile = Rules.newProfile("Sentinel")
	rejected(profile, function() return Rules.selectClass(profile, "ForgedClass") end)
	fullInventory(profile)
	rejected(profile, function() return Rules.selectClass(profile, "Ranger") end)
	assert(profile.className == "Sentinel")
end)

test("snapshots include level-adjusted statistics and independent progression data", function()
	local profile = Rules.newProfile("Sentinel")
	assert(Rules.grantReward(profile, "first", { xp = 150, gold = 20, items = {} }))
	local snapshot = Rules.snapshot(profile)
	assert(snapshot.requiredXp == Rules.requiredXp(2) and snapshot.xp == 50 and snapshot.gold == 20)
	assert(snapshot.derivedStats.MaxHealth == Rules.stats(profile).MaxHealth)
	snapshot.claimedRewards.first = nil
	snapshot.inventory[next(snapshot.inventory)].locked = true
	snapshot.derivedStats.Attack = -99
	assert(profile.claimedRewards.first and not profile.inventory[next(snapshot.inventory)].locked)
	assert(Rules.stats(profile).Attack >= 0)
end)

test("validator rejects malformed progression, excessive bounds and incompatible equipment", function()
	local invalids = {
		function(p) p.xp = -1 end, function(p) p.xp = Rules.requiredXp(p.level) end,
		function(p) p.gold = 1000000001 end, function(p) p.gold = 0 / 0 end,
		function(p) p.level = 60; p.xp = 1 end,
		function(p) p.claimedRewards = nil end, function(p) p.claimedRewards.bad = false end,
		function(p) p.claimedRewards["bad/key"] = true end,
		function(p) p.nextId = 1 end, function(p) p.nextId = math.huge end,
		function(p) p.equipped.MainHand = "forged" end,
		function(p) fullInventory(p); local uid = string.format("gear_%06d", p.nextId); p.nextId += 1; p.inventory[uid] = { uid = uid, itemId = "training_sword", upgradeLevel = 0, locked = false } end,
	}
	for _, mutate in invalids do
		local profile = Rules.newProfile("Sentinel")
		mutate(profile)
		local ran, valid = pcall(Rules.validate, profile)
		assert(ran and not valid, "Malformed profile was accepted or crashed")
		rejected(profile, function() return Rules.grantReward(profile, "bad_profile", { xp = 1, gold = 1, items = {} }) end)
	end
	assert(not Rules.validate(nil) and not Rules.validate({}))
end)

print(passed .. " progression tests passed.")
