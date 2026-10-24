-- Run from the repository root: lune run tests/equipment.spec.luau
local Catalog = require("../src/shared/EquipmentCatalog")
local Rules = require("../src/shared/EquipmentRules")

local passed = 0
local failed = 0
local function test(name, run)
	local ok, message = pcall(run)
	if ok then
		passed += 1
		print("PASS " .. name)
	else
		failed += 1
		warn("FAIL " .. name .. ": " .. tostring(message))
	end
end

local function eq(actual, expected)
	assert(actual == expected, "expected " .. tostring(expected) .. ", got " .. tostring(actual))
end

local function same(a, b)
	if type(a) ~= "table" or type(b) ~= "table" then
		return a == b
	end
	for k, v in a do
		if not same(v, b[k]) then return false end
	end
	for k in b do
		if a[k] == nil then return false end
	end
	return true
end

local function itemWhere(predicate)
	for _, itemId in Catalog.Order do
		local item = Catalog.Items[itemId]
		if predicate(item) then return item end
	end
	error("No matching catalog item")
end

local function uidFor(profile, itemId)
	for uid, instance in profile.inventory do
		if instance.itemId == itemId then return uid end
	end
	error("Missing owned item: " .. itemId)
end

local function sandbox(className)
	return Rules.newProfile(className or "Sentinel", 10, true)
end

local function valid(profile)
	local ok, reason = Rules.validateProfile(profile)
	assert(ok, reason)
end

local function rejectedUnchanged(profile, action)
	local before = Rules.snapshot(profile)
	local ok, reason = action()
	eq(ok, false)
	assert(type(reason) == "string" and #reason > 0, "Missing rejection reason")
	assert(same(before, Rules.snapshot(profile)), "Rejected operation mutated the profile")
end

test("catalog IDs, slots, stats and visual definitions are internally consistent", function()
	local ids = {}
	local count = 0
	for _, id in Catalog.Order do
		assert(not ids[id], "Duplicate catalog ID")
		ids[id] = true
		local item = assert(Catalog.Items[id])
		eq(item.id, id)
		assert(type(item.name) == "string" and #item.name > 0)
		assert(type(item.description) == "string" and #item.description > 0)
		assert(Catalog.Rarities[item.rarity])
		assert(item.slot == "Accessory" or table.find(Catalog.Slots, item.slot))
		assert(item.level >= 1 and item.level <= 10 and item.level % 1 == 0)
		assert(item.sellValue >= 0)
		assert(type(item.twoHanded) == "boolean")
		if item.twoHanded then eq(item.slot, "MainHand") end
		assert(#item.classes > 0)
		for _, className in item.classes do assert(table.find(Catalog.Classes, className)) end
		for stat, amount in item.stats do
			assert(Catalog.BaseStats[stat] ~= nil, "Unknown stat: " .. stat)
			assert(type(amount) == "number" and amount == amount and math.abs(amount) < math.huge)
		end
		assert(type(item.model.shape) == "string")
		for _, color in { item.model.primary, item.model.accent } do
			eq(#color, 3)
			for _, channel in color do assert(channel >= 0 and channel <= 255) end
		end
		count += 1
	end
	local dictionaryCount = 0
	for id in Catalog.Items do
		assert(ids[id], "Catalog item missing from display order")
		dictionaryCount += 1
	end
	eq(count, dictionaryCount)
	assert(count >= 30, "Equipment variety unexpectedly reduced")
end)

for _, className in Catalog.Classes do
	test(className .. " has a usable level-one starter loadout", function()
		local profile = Rules.newProfile(className, 1, false)
		valid(profile)
		assert(profile.equipped.MainHand)
		eq(profile.inventory[profile.equipped.MainHand].itemId, Catalog.StarterWeapons[className])
		for _, slot in { "Helmet", "Chest", "Gloves", "Boots", "Accessory1", "Accessory2" } do
			assert(profile.equipped[slot], "Missing starter slot: " .. slot)
		end
		local count = 0
		for _ in profile.inventory do count += 1 end
		eq(count, #Catalog.StarterLoadouts[className])
	end)
end

test("sandbox grants exactly one distinct instance per catalog definition", function()
	local profile = sandbox()
	local count, ids = 0, {}
	for uid, instance in profile.inventory do
		eq(uid, instance.uid)
		assert(not ids[instance.itemId])
		ids[instance.itemId] = true
		count += 1
	end
	eq(count, #Catalog.Order)
	eq(profile.nextId, count + 1)
	valid(profile)
end)

test("profiles and snapshots share no mutable state", function()
	local profile = sandbox()
	local other = sandbox()
	local snapshot = Rules.snapshot(profile)
	local uid = profile.equipped.MainHand
	snapshot.inventory[uid].locked = true
	snapshot.equipped.MainHand = nil
	snapshot.derivedStats.Attack = -100
	eq(profile.inventory[uid].locked, false)
	assert(profile.equipped.MainHand)
	profile.inventory[uid].locked = true
	eq(other.inventory[uid].locked, false)
	eq(Catalog.BaseStats.Attack > 0, true)
end)

test("unowned and nonexistent instances are rejected atomically", function()
	local profile = sandbox()
	rejectedUnchanged(profile, function() return Rules.equip(profile, "not_owned", "MainHand") end)
	rejectedUnchanged(profile, function() return Rules.equip(profile, Catalog.StarterWeapons.Sentinel, "MainHand") end)
end)

test("remote-shaped malformed identifiers and slots are rejected atomically", function()
	local profile = sandbox()
	local uid = profile.equipped.MainHand
	for _, value in { false, 12, {}, string.rep("x", 100) } do
		rejectedUnchanged(profile, function() return Rules.equip(profile, value, "MainHand") end)
	end
	rejectedUnchanged(profile, function() return Rules.equip(profile, nil, "MainHand") end)
	for _, value in { false, 12, {}, "Unknown", "Accessory" } do
		rejectedUnchanged(profile, function() return Rules.equip(profile, uid, value) end)
		rejectedUnchanged(profile, function() return Rules.unequip(profile, value) end)
	end
	rejectedUnchanged(profile, function() return Rules.equip(profile, uid, nil) end)
end)

test("valid owned gear still requires the correct slot", function()
	local profile = sandbox()
	rejectedUnchanged(profile, function() return Rules.equip(profile, profile.equipped.MainHand, "Helmet") end)
end)

test("level requirement rejects owned equipment without changing stats", function()
	local profile = Rules.newProfile("Sentinel", 1, true)
	local item = itemWhere(function(item)
		return item.level > 1 and table.find(item.classes, "Sentinel") and item.slot ~= "Accessory"
	end)
	rejectedUnchanged(profile, function() return Rules.equip(profile, uidFor(profile, item.id), item.slot) end)
end)

test("class requirement rejects owned equipment without changing loadout", function()
	local profile = sandbox("Sentinel")
	local item = itemWhere(function(item) return not table.find(item.classes, "Sentinel") end)
	local slot = if item.slot == "Accessory" then "Accessory1" else item.slot
	rejectedUnchanged(profile, function() return Rules.equip(profile, uidFor(profile, item.id), slot) end)
end)

test("equipping gear applies its exact modifiers and unequipping removes them", function()
	local profile = sandbox()
	for _, slot in Catalog.Slots do if profile.equipped[slot] then Rules.unequip(profile, slot) end end
	assert(same(Rules.stats(profile), Catalog.BaseStats))
	local item = itemWhere(function(item)
		return item.slot == "MainHand" and table.find(item.classes, "Sentinel")
	end)
	assert(Rules.equip(profile, uidFor(profile, item.id), "MainHand"))
	local actual = Rules.stats(profile)
	for stat, base in Catalog.BaseStats do
		local expected = base + (item.stats[stat] or 0)
		if stat == "CriticalChance" then expected = math.clamp(expected, 0, 0.6) end
		if stat == "MoveSpeed" then expected = math.clamp(expected, 8, 24) end
		eq(actual[stat], expected)
	end
	assert(Rules.unequip(profile, "MainHand"))
	assert(same(Rules.stats(profile), Catalog.BaseStats))
	valid(profile)
end)

test("repeated equip is idempotent and cannot stack statistics", function()
	local profile = sandbox()
	local uid = profile.equipped.MainHand
	local before = Rules.stats(profile)
	for _ = 1, 20 do assert(Rules.equip(profile, uid, "MainHand")) end
	assert(same(before, Rules.stats(profile)))
	valid(profile)
end)

test("two-handed weapon clears off-hand without deleting either item", function()
	local profile = sandbox()
	local offUid = assert(profile.equipped.OffHand)
	local weapon = itemWhere(function(item)
		return item.slot == "MainHand" and item.twoHanded and table.find(item.classes, "Sentinel")
	end)
	assert(Rules.equip(profile, uidFor(profile, weapon.id), "MainHand"))
	eq(profile.equipped.OffHand, nil)
	assert(profile.inventory[offUid])
	rejectedUnchanged(profile, function() return Rules.equip(profile, offUid, "OffHand") end)
	assert(Rules.unequip(profile, "MainHand"))
	assert(Rules.equip(profile, offUid, "OffHand"))
	valid(profile)
end)

test("bows and crossbows allow quivers and preserve them when switching", function()
	local profile = sandbox("Ranger")
	local quiver = itemWhere(function(item) return item.family == "Quiver" end)
	local uid = uidFor(profile, quiver.id)
	assert(Rules.equip(profile, uid, "OffHand"))
	for _, family in { "Bow", "Crossbow" } do
		local weapon = itemWhere(function(item) return item.family == family end)
		assert(Rules.equip(profile, uidFor(profile, weapon.id), "MainHand"))
		eq(profile.equipped.OffHand, uid)
		valid(profile)
	end
	local lantern = itemWhere(function(item) return item.family == "Lantern" end)
	rejectedUnchanged(profile, function() return Rules.equip(profile, uidFor(profile, lantern.id), "OffHand") end)
end)

test("switching to a non-bow two-handed family clears a stale quiver", function()
	-- Simulate a retained equipment slot from an earlier class schema. Normal class
	-- changes clear equipment first, but main-hand replacement must still be safe.
	local profile = sandbox("Sentinel")
	local quiver = itemWhere(function(item) return item.family == "Quiver" end)
	local quiverUid = uidFor(profile, quiver.id)
	profile.equipped.OffHand = quiverUid
	local weapon = itemWhere(function(item)
		return item.twoHanded and table.find(item.classes, "Sentinel")
	end)
	assert(Rules.equip(profile, uidFor(profile, weapon.id), "MainHand"))
	eq(profile.equipped.OffHand, nil)
	assert(profile.inventory[quiverUid])
	valid(profile)
end)

test("accessory instance moves between slots without duplication", function()
	local profile = sandbox()
	local uid = profile.equipped.Accessory1
	assert(Rules.equip(profile, uid, "Accessory2"))
	eq(profile.equipped.Accessory1, nil)
	eq(profile.equipped.Accessory2, uid)
	valid(profile)
end)

test("two instances of one accessory definition cannot occupy both slots", function()
	local profile = sandbox()
	local first = profile.inventory[profile.equipped.Accessory1]
	profile.inventory.extra_copy = { uid = "extra_copy", itemId = first.itemId, upgradeLevel = 0, locked = false }
	rejectedUnchanged(profile, function() return Rules.equip(profile, "extra_copy", "Accessory2") end)
	valid(profile)
end)

test("class selection restores owned appropriate starters and grants no items", function()
	local profile = sandbox()
	local inventory = Rules.snapshot(profile).inventory
	for _, className in Catalog.Classes do
		assert(Rules.setClass(profile, className))
		eq(profile.className, className)
		eq(profile.inventory[profile.equipped.MainHand].itemId, Catalog.StarterWeapons[className])
		assert(same(inventory, profile.inventory))
		valid(profile)
	end
	rejectedUnchanged(profile, function() return Rules.setClass(profile, "Unknown") end)
	rejectedUnchanged(profile, function() return Rules.setClass(profile, {}) end)
end)

test("unequipping an empty slot is rejected without mutation", function()
	local profile = sandbox()
	assert(Rules.unequip(profile, "MainHand"))
	rejectedUnchanged(profile, function() return Rules.unequip(profile, "MainHand") end)
end)

test("invalid constructor inputs fail instead of producing corrupt state", function()
	for _, level in { 0, 61, -1, 1.5, math.huge, 0/0, "10" } do
		eq(pcall(Rules.newProfile, "Sentinel", level, true), false)
	end
	eq(pcall(Rules.newProfile, "Unknown", 1, true), false)
	eq(pcall(Rules.newProfile, "Sentinel", 1, "true"), false)
end)

test("validator detects unknown items, invalid levels and duplicated equipped UIDs", function()
	local profile = sandbox()
	local uid = profile.equipped.Accessory1
	profile.equipped.Accessory2 = uid
	eq(Rules.validateProfile(profile), false)
	profile = sandbox()
	profile.inventory[profile.equipped.MainHand].itemId = "unknown"
	eq(Rules.validateProfile(profile), false)
	profile = sandbox()
	profile.level = 0/0
	eq(Rules.validateProfile(profile), false)
	eq(Rules.validateProfile(false), false)
end)

test("every catalog item can be equipped by an eligible class at its required level", function()
	for _, id in Catalog.Order do
		local item = Catalog.Items[id]
		local profile = Rules.newProfile(item.classes[1], item.level, true)
		for _, slot in Catalog.Slots do if profile.equipped[slot] then Rules.unequip(profile, slot) end end
		local slot = if item.slot == "Accessory" then "Accessory1" else item.slot
		local ok, reason = Rules.equip(profile, uidFor(profile, id), slot)
		assert(ok, id .. ": " .. tostring(reason))
		valid(profile)
	end
end)

test("mixed equip, unequip and class transitions retain all inventory instances", function()
	local profile = sandbox()
	local originalInventory = Rules.snapshot(profile).inventory
	for _ = 1, 3 do
		for _, className in Catalog.Classes do
			Rules.setClass(profile, className)
			for _, id in Catalog.Order do
				local item = Catalog.Items[id]
				local slot = if item.slot == "Accessory" then "Accessory1" else item.slot
				Rules.equip(profile, uidFor(profile, id), slot)
				valid(profile)
			end
			for _, slot in Catalog.Slots do Rules.unequip(profile, slot); valid(profile) end
		end
	end
	assert(same(originalInventory, profile.inventory), "Equipment operation changed inventory ownership")
end)

print(string.format("Equipment rules: %d passed, %d failed", passed, failed))
assert(failed == 0, "Equipment rules test failures")
