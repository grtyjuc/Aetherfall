-- Server-owned progression transactions. No persistence, network or Roblox APIs here.
local Catalog = if script then require(script.Parent.EquipmentCatalog) else require("./EquipmentCatalog")
local Equipment = if script then require(script.Parent.EquipmentRules) else require("./EquipmentRules")
local Rules = {}
local MAX_LEVEL, MAX_INVENTORY, MAX_CLAIMS = 60, 200, 128
local MAX_GOLD, MAX_SEQUENCE = 1000000000, 1000000000

local function integer(value, minimum, maximum)
	return type(value) == "number" and value == value and value % 1 == 0
		and value >= minimum and value <= maximum
end

local function rewardIdentifier(value)
	return type(value) == "string" and #value > 0 and #value <= 64
		and string.match(value, "^[%w_%-]+$") ~= nil
end

local function countBounded(dictionary, maximum)
	local count = 0
	for _ in dictionary do
		count += 1
		if count > maximum then return nil end
	end
	return count
end

function Rules.requiredXp(level)
	assert(integer(level, 1, MAX_LEVEL), "Level must be an integer from 1 to 60")
	return if level == MAX_LEVEL then 0 else math.floor(100 * level ^ 1.45)
end

function Rules.validate(profile)
	if type(profile) ~= "table" or type(profile.inventory) ~= "table" or type(profile.claimedRewards) ~= "table" then
		return false, "Missing player inventory or reward claims."
	end
	if not countBounded(profile.inventory, MAX_INVENTORY) then return false, "Inventory capacity exceeded." end
	if not countBounded(profile.claimedRewards, MAX_CLAIMS) then return false, "Reward history capacity exceeded." end
	if not integer(profile.nextId, 1, MAX_SEQUENCE) then return false, "Invalid inventory sequence." end
	local executed, valid, message = pcall(Equipment.validateProfile, profile)
	if not executed or not valid then return false, if executed then message else "Malformed equipment profile." end
	if not integer(profile.gold, 0, MAX_GOLD) then return false, "Invalid gold balance." end
	local required = Rules.requiredXp(profile.level)
	if not integer(profile.xp, 0, if profile.level == MAX_LEVEL then 0 else required - 1) then
		return false, "Invalid experience progress."
	end
	for uid in profile.inventory do
		if not string.match(uid, "^gear_%d%d%d%d%d%d%d*$") then return false, "Invalid persistent item identifier." end
		local sequence = tonumber(string.sub(uid, 6))
		if not integer(sequence, 1, MAX_SEQUENCE - 1) or profile.nextId <= sequence then
			return false, "Inventory sequence must follow all owned item identifiers."
		end
	end
	for id, claimed in profile.claimedRewards do
		if not rewardIdentifier(id) or claimed ~= true then return false, "Invalid reward claim." end
	end
	return true, "Player progression valid."
end

function Rules.newProfile(className)
	local profile = Equipment.newProfile(className, 1, false)
	profile.xp = 0
	profile.gold = 0
	profile.claimedRewards = {}
	return profile
end

function Rules.stats(profile)
	local stats = Equipment.stats(profile)
	local bonus = profile.level - 1
	stats.MaxHealth += bonus * 5
	stats.Attack += bonus
	stats.MagicPower += bonus
	stats.Defence += math.floor(bonus / 2)
	return stats
end

local function applyXp(profile, amount)
	local levels = 0
	if profile.level == MAX_LEVEL then return 0 end
	profile.xp += amount
	while profile.level < MAX_LEVEL do
		local needed = Rules.requiredXp(profile.level)
		if profile.xp < needed then break end
		profile.xp -= needed
		profile.level += 1
		levels += 1
	end
	if profile.level == MAX_LEVEL then profile.xp = 0 end
	return levels
end

function Rules.addXp(profile, amount)
	local valid, message = Rules.validate(profile)
	if not valid then return false, message, 0 end
	if not integer(amount, 1, 100000) then return false, "Experience reward must be an integer from 1 to 100000.", 0 end
	local levels = applyXp(profile, amount)
	return true, if levels > 0 then "Reached level " .. profile.level .. "." else "Experience awarded.", levels
end

-- Plan all new instances before committing. Existing item identity is never replaced.
local function planItems(profile, itemIds)
	local owned = {}
	local total = 0
	for _, instance in profile.inventory do
		owned[instance.itemId] = true
		total += 1
	end
	local planned, nextId = {}, profile.nextId
	for _, id in itemIds do
		if not owned[id] then
			if total >= MAX_INVENTORY then return nil, nil, "Your inventory is full." end
			local uid
			repeat
				if nextId >= MAX_SEQUENCE then return nil, nil, "Inventory sequence exhausted." end
				uid = string.format("gear_%06d", nextId)
				nextId += 1
			until not profile.inventory[uid]
			table.insert(planned, { uid = uid, itemId = id, upgradeLevel = 0, locked = false })
			owned[id] = true
			total += 1
		end
	end
	return planned, nextId
end

local function commitItems(profile, planned, nextId)
	for _, instance in planned do profile.inventory[instance.uid] = instance end
	profile.nextId = nextId
end

function Rules.grantReward(profile, rewardId, rewardSpec)
	local valid, message = Rules.validate(profile)
	if not valid then return false, message end
	if not rewardIdentifier(rewardId) then return false, "Invalid reward identifier." end
	if profile.claimedRewards[rewardId] then return false, "This reward has already been claimed." end
	if countBounded(profile.claimedRewards, MAX_CLAIMS - 1) == nil then return false, "Reward history is full." end
	if type(rewardSpec) ~= "table" or not integer(rewardSpec.xp, 0, 100000)
		or not integer(rewardSpec.gold, 0, MAX_GOLD) or type(rewardSpec.items) ~= "table" then
		return false, "Invalid server reward specification."
	end
	if profile.gold + rewardSpec.gold > MAX_GOLD then return false, "Gold balance would exceed its limit." end
	local itemCount = countBounded(rewardSpec.items, MAX_INVENTORY)
	if itemCount == nil then return false, "Reward item list is too large." end
	for index, id in rewardSpec.items do
		if not integer(index, 1, itemCount) or type(id) ~= "string" or not Catalog.Items[id] then
			return false, "Reward contains an unknown item or malformed list."
		end
	end
	local planned, nextId, problem = planItems(profile, rewardSpec.items)
	if not planned then return false, problem end
	-- All rejection paths precede this non-yielding commit.
	commitItems(profile, planned, nextId)
	profile.gold += rewardSpec.gold
	local levels = applyXp(profile, rewardSpec.xp)
	profile.claimedRewards[rewardId] = true
	local items = {}
	for _, instance in planned do table.insert(items, instance.itemId) end
	return true, "Reward earned.", {
		xp = rewardSpec.xp, gold = rewardSpec.gold, items = items,
		levelsGained = levels, level = profile.level,
	}
end

-- Repeatable enemy rewards use a separate trusted path. Kill identity is deduplicated
-- by EnemyRewards; per-kill claims are deliberately not stored in reward history.
function Rules.grantCombatReward(profile, xp, gold)
	local valid, message = Rules.validate(profile)
	if not valid then return false, message end
	if not integer(xp, 1, 1000) or not integer(gold, 0, 100) then
		return false, "Invalid server combat reward."
	end
	if profile.gold + gold > MAX_GOLD then return false, "Gold balance would exceed its limit." end
	-- No rejection or yielding occurs after this point.
	profile.gold += gold
	local levels = applyXp(profile, xp)
	return true, "Enemy reward earned.", { xp = xp, gold = gold, levelsGained = levels, level = profile.level }
end

function Rules.selectClass(profile, className)
	local valid, message = Rules.validate(profile)
	if not valid then return false, message end
	if type(className) ~= "string" or not table.find(Catalog.Classes, className) then return false, "Unknown class." end
	local planned, nextId, problem = planItems(profile, Catalog.StarterLoadouts[className])
	if not planned then return false, problem end
	commitItems(profile, planned, nextId)
	return Equipment.setClass(profile, className)
end

function Rules.snapshot(profile)
	local snapshot = Equipment.snapshot(profile)
	snapshot.derivedStats = Rules.stats(profile)
	snapshot.requiredXp = Rules.requiredXp(profile.level)
	return snapshot
end

return table.freeze(Rules)
