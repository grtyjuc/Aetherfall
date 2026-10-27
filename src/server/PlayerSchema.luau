-- Saved data is validated before it can become a live profile. Invalid saves are never reset.
local Shared = if script then game:GetService("ReplicatedStorage"):WaitForChild("Shared") else nil
local Equipment = if Shared then require(Shared.EquipmentRules) else require("../shared/EquipmentRules")
local Progression = if Shared then require(Shared.ProgressionRules) else require("../shared/ProgressionRules")

local Quest = if Shared then require(Shared.QuestRules) else require("../shared/QuestRules")

local Schema = { version = 3 }
local MAX_ITEMS = 200
local MAX_CLAIMS = 128
local MAX_SEQUENCE = 1e9
local currentFields = { className = true, level = true, inventory = true, equipped = true,
	nextId = true, xp = true, gold = true, claimedRewards = true, quests = true }
local versionOneFields = { className = true, level = true, inventory = true, equipped = true,
	nextId = true, xp = true, gold = true, claimedRewards = true }
local legacyFields = { className = true, level = true, inventory = true, equipped = true, nextId = true }
local instanceFields = { uid = true, itemId = true, upgradeLevel = true, locked = true }

local function integer(value, minimum, maximum)
	return type(value) == "number" and value == value and value >= minimum and value <= maximum
		and value % 1 == 0
end

local function onlyFields(value, fields)
	if type(value) ~= "table" then return false end
	for key in value do if not fields[key] then return false end end
	return true
end

-- Bound traversal before copying, including hostile/corrupt cycles and unknown subtrees.
local function boundedTree(value)
	local visiting = {}
	local nodes = 0
	local function visit(child, depth)
		nodes += 1
		if nodes > 2000 or depth > 5 then return false end
		local kind = type(child)
		if kind == "number" then return child == child and math.abs(child) < math.huge end
		if kind == "string" then return #child <= 64 end
		if kind == "boolean" then return true end
		if kind ~= "table" or getmetatable(child) ~= nil or visiting[child] then return false end
		visiting[child] = true
		local count = 0
		for key, item in child do
			count += 1
			if count > MAX_ITEMS or type(key) ~= "string" or #key == 0 or #key > 64
				or not visit(item, depth + 1) then return false end
		end
		visiting[child] = nil
		return true
	end
	return visit(value, 0)
end

local function copy(value)
	if type(value) ~= "table" then return value end
	local result = {}
	for key, child in value do result[key] = copy(child) end
	return result
end

local function profileShape(profile, version)
	local legacy = version == 0
	local fields = if legacy then legacyFields elseif version == 1 then versionOneFields else currentFields
	if not onlyFields(profile, fields) then
		return false, "Profile contains unknown fields."
	end
	if not integer(profile.nextId, 1, MAX_SEQUENCE) then return false, "Invalid inventory sequence." end
	if type(profile.inventory) ~= "table" or type(profile.equipped) ~= "table" then
		return false, "Missing inventory or equipment."
	end
	local count = 0
	for uid, instance in profile.inventory do
		count += 1
		if count > MAX_ITEMS then return false, "Inventory exceeds its save limit." end
		if type(uid) ~= "string" or #uid == 0 or #uid > 64 or not onlyFields(instance, instanceFields) then
			return false, "Invalid inventory instance shape."
		end
		local numericId = string.match(uid, "^gear_(%d+)$")
		if numericId then
			local sequence = tonumber(numericId)
			if not integer(sequence, 1, MAX_SEQUENCE) or sequence >= profile.nextId then
				return false, "Inventory sequence would reuse an existing identifier."
			end
		end
	end
	if not legacy then
		if not integer(profile.xp, 0, 1e9) or not integer(profile.gold, 0, 1e9)
			or type(profile.claimedRewards) ~= "table" then
			return false, "Invalid progression fields."
		end
		local claims = 0
		for id, claimed in profile.claimedRewards do
			claims += 1
			if claims > MAX_CLAIMS or type(id) ~= "string" or #id == 0 or #id > 64 or claimed ~= true then
				return false, "Invalid reward history."
			end
		end
	end
	return Equipment.validateProfile(profile)
end

function Schema.newProfile(className)
	local profile = Progression.newProfile(className or "Sentinel")
	Quest.ensure(profile)
	return profile
end

function Schema.encode(profile)
	assert(boundedTree(profile), "Profile is not bounded serializable data.")
	-- Callers constructing new progression profiles may not yet have quest state.
	-- Normalize a copy; encoding must never mutate live state.
	local normalized = copy(profile)
	Quest.ensure(normalized)
	local ok, reason = profileShape(normalized, Schema.version)
	assert(ok, reason)
	ok, reason = Quest.validateProfile(normalized)
	assert(ok, reason)
	return { version = Schema.version, data = normalized }
end

function Schema.decode(raw)
	-- Only a missing record means a new account. Other failures must preserve existing data.
	if raw == nil then return Schema.newProfile("Sentinel") end
	if not boundedTree(raw) or not onlyFields(raw, { version = true, data = true }) then
		return nil, "Save envelope contains unsupported or oversized data."
	end
	if raw.version ~= 0 and raw.version ~= 1 and raw.version ~= 2 and raw.version ~= Schema.version then
		return nil, "Unsupported save version."
	end
	local ok, reason = profileShape(raw.data, raw.version)
	if not ok then return nil, reason end
	local profile = copy(raw.data)
	if raw.version == 2 then
		local oldQuests = profile.quests
		if type(oldQuests) ~= "table" or oldQuests.groveStage ~= nil then return nil, "Invalid version-two quest fields." end
		for key in oldQuests do
			if key ~= "strangerStage" and key ~= "fieldsAccepted" and key ~= "fieldsKills" then return nil, "Unknown version-two quest field." end
		end
	end
	if raw.version == 0 then
		-- Explicit equipment-only migration; no old production saves are assumed.
		profile.xp, profile.gold, profile.claimedRewards = 0, 0, {}
	end
	if raw.version < Schema.version then Quest.ensure(profile) end
	ok, reason = Quest.validateProfile(profile)
	if not ok then return nil, reason end
	return profile
end

return table.freeze(Schema)
