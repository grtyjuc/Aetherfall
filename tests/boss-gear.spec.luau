-- Boss gear uses the normal inventory/slot rules; no special equip authority exists.
local Catalog = require("../src/shared/EquipmentCatalog")
local Rules = require("../src/shared/EquipmentRules")
local passed = 0
local function test(name, callback)
	callback()
	passed += 1
	print("PASS " .. name)
end
local function uidFor(profile, id)
	for uid, item in profile.inventory do if item.itemId == id then return uid end end
	error("Missing item " .. id)
end
local function snapshot(profile)
	return Rules.snapshot(profile)
end
local function same(a, b)
	if type(a) ~= "table" or type(b) ~= "table" then return a == b end
	for key, value in a do if not same(value, b[key]) then return false end end
	for key in b do if a[key] == nil then return false end end
	return true
end
local function rejected(profile, action)
	local before = snapshot(profile)
	local ok, reason = action()
	assert(not ok and type(reason) == "string" and #reason > 0)
	assert(same(before, snapshot(profile)), "Rejected boss gear equip mutated state")
end
local rewards = {
	Sentinel = "briarwarden_shield", Spellweaver = "briarwarden_staff", Ranger = "briarwarden_bow",
}

test("three immutable guardian rewards preserve the existing starter loadouts", function()
	assert(#Catalog.Order == 39)
	local seen = {}
	for _, id in Catalog.Order do assert(not seen[id]); seen[id] = true end
	for class, id in rewards do
		local item = assert(Catalog.Items[id])
		assert(item.level == 5 and item.rarity == "Epic")
		assert(#item.classes == 1 and item.classes[1] == class)
		assert(table.isfrozen(item) and table.isfrozen(item.stats) and table.isfrozen(item.model))
		assert(not table.find(Catalog.StarterLoadouts[class], id), "Boss reward must be earned")
		for key in item.stats do assert(Catalog.BaseStats[key] ~= nil, "Unknown stat modifier") end
	end
	assert(Catalog.StarterWeapons.Sentinel == "training_sword")
	assert(Catalog.StarterWeapons.Spellweaver == "apprentice_wand")
	assert(Catalog.StarterWeapons.Ranger == "longbow")
end)

for class, id in rewards do
	test(class .. " reward requires ownership and level five", function()
		local starter = Rules.newProfile(class, 5, false)
		rejected(starter, function() return Rules.equip(starter, id, Catalog.Items[id].slot) end)
		local profile = Rules.newProfile(class, 4, true)
		rejected(profile, function() return Rules.equip(profile, uidFor(profile, id), Catalog.Items[id].slot) end)
		profile.level = 5
		assert(Rules.equip(profile, uidFor(profile, id), Catalog.Items[id].slot))
		local valid, reason = Rules.validateProfile(profile)
		assert(valid, reason)
	end)
	test(class .. " reward rejects incompatible classes without mutation", function()
		local otherClass = if class == "Sentinel" then "Ranger" else "Sentinel"
		local profile = Rules.newProfile(otherClass, 5, true)
		rejected(profile, function() return Rules.equip(profile, uidFor(profile, id), Catalog.Items[id].slot) end)
	end)
end

test("guardian shield replaces starter defence and remains incompatible with greatswords", function()
	local profile = Rules.newProfile("Sentinel", 8, true)
	local before = Rules.stats(profile)
	assert(Rules.equip(profile, uidFor(profile, "briarwarden_shield"), "OffHand"))
	local after = Rules.stats(profile)
	assert(after.Defence == before.Defence + 6 and after.MaxHealth == before.MaxHealth + 15)
	assert(after.MagicResistance == before.MagicResistance + 4)
	assert(Rules.equip(profile, uidFor(profile, "grove_greatsword"), "MainHand"))
	assert(profile.equipped.OffHand == nil)
	rejected(profile, function() return Rules.equip(profile, uidFor(profile, "briarwarden_shield"), "OffHand") end)
end)

test("guardian staff reserves both hands and applies its exact magical bonuses", function()
	local profile = Rules.newProfile("Spellweaver", 5, true)
	local wand = Catalog.Items.apprentice_wand.stats.MagicPower
	local focus = Catalog.Items.novice_focus.stats
	local before = Rules.stats(profile)
	assert(Rules.equip(profile, uidFor(profile, "briarwarden_staff"), "MainHand"))
	assert(profile.equipped.OffHand == nil)
	local after = Rules.stats(profile)
	assert(after.MagicPower == before.MagicPower - wand - focus.MagicPower + 36)
	assert(after.MagicResistance == before.MagicResistance - focus.MagicResistance + 6)
	rejected(profile, function() return Rules.equip(profile, uidFor(profile, "novice_focus"), "OffHand") end)
end)

test("guardian bow retains the quiver and provides its visible precision bonus", function()
	local profile = Rules.newProfile("Ranger", 5, true)
	assert(Rules.equip(profile, uidFor(profile, "trail_quiver"), "OffHand"))
	local before = Rules.stats(profile)
	local quiver = profile.equipped.OffHand
	assert(Rules.equip(profile, uidFor(profile, "briarwarden_bow"), "MainHand"))
	assert(profile.equipped.OffHand == quiver)
	local after = Rules.stats(profile)
	assert(after.Attack == before.Attack - Catalog.Items.longbow.stats.Attack + 34)
	assert(math.abs(after.CriticalChance - before.CriticalChance - 0.04) < 0.000001)
	local valid, reason = Rules.validateProfile(profile)
	assert(valid, reason)
end)

print(passed .. " boss equipment tests passed; no live Studio rendering was run.")
