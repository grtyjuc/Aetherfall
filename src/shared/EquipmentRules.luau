--!nonstrict
-- Shared rules; only the server owns and mutates player profiles.
local Catalog = if script then require(script.Parent.EquipmentCatalog) else require("./EquipmentCatalog")

local Rules = {}

local function contains(list, value)
	return table.find(list, value) ~= nil
end

local function validLevel(level)
	return type(level) == "number" and level == level and level % 1 == 0 and level >= 1 and level <= 60
end

local function copy(value)
	if type(value) ~= "table" then
		return value
	end
	local result = {}
	for key, child in value do
		result[key] = copy(child)
	end
	return result
end

local function slotFits(item, slot)
	return item.slot == slot or (item.slot == "Accessory" and (slot == "Accessory1" or slot == "Accessory2"))
end

local function ownedDefinition(profile, uid)
	local instance = profile.inventory[uid]
	return if instance then Catalog.Items[instance.itemId] else nil
end

local function offHandFits(mainHand, offHand)
	return not mainHand.twoHanded
		or (offHand.family == "Quiver" and (mainHand.family == "Bow" or mainHand.family == "Crossbow"))
end

function Rules.equip(profile, uid, slot)
	if type(uid) ~= "string" or #uid > 64 then
		return false, "Invalid equipment identifier."
	end
	if type(slot) ~= "string" or not contains(Catalog.Slots, slot) then
		return false, "Unknown equipment slot."
	end
	local item = ownedDefinition(profile, uid)
	if not item then
		return false, "You do not own that equipment."
	end
	if not slotFits(item, slot) then
		return false, "That item does not fit this slot."
	end
	if not contains(item.classes, profile.className) then
		return false, "Your class cannot equip this item."
	end
	if profile.level < item.level then
		return false, "Requires level " .. item.level .. "."
	end
	if slot == "OffHand" and profile.equipped.MainHand then
		local mainHand = ownedDefinition(profile, profile.equipped.MainHand)
		if mainHand and not offHandFits(mainHand, item) then
			return false, "Unequip your two-handed weapon before equipping off-hand gear."
		end
	end
	if item.slot == "Accessory" then
		local otherSlot = if slot == "Accessory1" then "Accessory2" else "Accessory1"
		local otherUid = profile.equipped[otherSlot]
		local other = if otherUid then ownedDefinition(profile, otherUid) else nil
		if other and other.id == item.id and otherUid ~= uid then
			return false, "Only one copy of each accessory can be equipped."
		end
	end

	-- All rejection paths precede mutations. Moving an instance never duplicates it.
	for equippedSlot, equippedUid in profile.equipped do
		if equippedUid == uid then
			profile.equipped[equippedSlot] = nil
		end
	end
	if slot == "MainHand" and item.twoHanded then
		local offHand = profile.equipped.OffHand and ownedDefinition(profile, profile.equipped.OffHand)
		if offHand and not offHandFits(item, offHand) then
			profile.equipped.OffHand = nil
		end
	end
	profile.equipped[slot] = uid
	return true, "Equipped " .. item.name .. "."
end

function Rules.unequip(profile, slot)
	if type(slot) ~= "string" or not contains(Catalog.Slots, slot) then
		return false, "Unknown equipment slot."
	end
	if not profile.equipped[slot] then
		return false, "This slot is already empty."
	end
	profile.equipped[slot] = nil
	return true, "Equipment removed."
end

local function applyStarterLoadout(profile)
	for _, itemId in Catalog.StarterLoadouts[profile.className] do
		local item = Catalog.Items[itemId]
		for uid, instance in profile.inventory do
			if instance.itemId == itemId then
				local slot = item.slot
				if slot == "Accessory" then
					slot = if profile.equipped.Accessory1 then "Accessory2" else "Accessory1"
				end
				Rules.equip(profile, uid, slot)
				break
			end
		end
	end
end

function Rules.newProfile(className, level, grantAll)
	assert(type(className) == "string" and contains(Catalog.Classes, className), "Unknown class")
	assert(validLevel(level), "Level must be an integer from 1 to 60")
	assert(type(grantAll) == "boolean", "grantAll must be a boolean")
	local profile = {
		className = className,
		level = level,
		inventory = {},
		equipped = {},
		nextId = 1,
	}
	local itemIds = if grantAll then Catalog.Order else Catalog.StarterLoadouts[className]
	for _, itemId in itemIds do
		local uid = string.format("gear_%06d", profile.nextId)
		profile.nextId += 1
		profile.inventory[uid] = { uid = uid, itemId = itemId, upgradeLevel = 0, locked = false }
	end
	applyStarterLoadout(profile)
	return profile
end

function Rules.setClass(profile, className)
	if type(className) ~= "string" or not contains(Catalog.Classes, className) then
		return false, "Unknown class."
	end
	profile.className = className
	profile.equipped = {}
	applyStarterLoadout(profile)
	return true, "Selected " .. className .. ". Starter equipment restored."
end

function Rules.stats(profile)
	local result = copy(Catalog.BaseStats)
	for _, uid in profile.equipped do
		local item = ownedDefinition(profile, uid)
		if item then
			for stat, amount in item.stats do
				result[stat] += amount
			end
		end
	end
	result.CriticalChance = math.clamp(result.CriticalChance, 0, 0.6)
	result.MoveSpeed = math.clamp(result.MoveSpeed, 8, 24)
	return result
end

function Rules.snapshot(profile)
	local result = copy(profile)
	result.derivedStats = Rules.stats(profile)
	return result
end

function Rules.validateProfile(profile)
	if type(profile) ~= "table" then
		return false, "Profile must be a table."
	end
	if type(profile.className) ~= "string" or not contains(Catalog.Classes, profile.className) then
		return false, "Invalid profile class."
	end
	if not validLevel(profile.level) then
		return false, "Invalid profile level."
	end
	if type(profile.inventory) ~= "table" or type(profile.equipped) ~= "table" then
		return false, "Missing inventory or equipment."
	end
	if type(profile.nextId) ~= "number" or profile.nextId ~= profile.nextId or profile.nextId < 1 or profile.nextId % 1 ~= 0 then
		return false, "Invalid inventory sequence."
	end
	for uid, instance in profile.inventory do
		if type(uid) ~= "string" or #uid > 64 or type(instance) ~= "table" or instance.uid ~= uid then
			return false, "Invalid item instance."
		end
		if type(instance.itemId) ~= "string" or not Catalog.Items[instance.itemId] then
			return false, "Unknown inventory item."
		end
		if instance.upgradeLevel ~= 0 or type(instance.locked) ~= "boolean" then
			return false, "Unsupported item state."
		end
	end
	local seen = {}
	local accessories = {}
	for slot, uid in profile.equipped do
		if type(slot) ~= "string" or not contains(Catalog.Slots, slot) or type(uid) ~= "string" then
			return false, "Invalid equipped slot or identifier."
		end
		local item = ownedDefinition(profile, uid)
		if not item or seen[uid] then
			return false, "Unowned or duplicated equipment instance."
		end
		seen[uid] = true
		if not slotFits(item, slot) or not contains(item.classes, profile.className) or item.level > profile.level then
			return false, "Incompatible equipped item."
		end
		if item.slot == "Accessory" then
			if accessories[item.id] then
				return false, "Duplicate accessory definition."
			end
			accessories[item.id] = true
		end
	end
	local main = profile.equipped.MainHand and ownedDefinition(profile, profile.equipped.MainHand)
	local offHand = profile.equipped.OffHand and ownedDefinition(profile, profile.equipped.OffHand)
	if main and offHand and not offHandFits(main, offHand) then
		return false, "Two-handed weapon conflicts with off-hand gear."
	end
	return true, "Profile valid."
end

return table.freeze(Rules)
