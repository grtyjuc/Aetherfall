-- Trusted EnemyService death callbacks only. No client-facing reward endpoint exists.
local Shared = if script then game:GetService("ReplicatedStorage"):WaitForChild("Shared") else nil
local Progression = if Shared then require(Shared.ProgressionRules) else require("../shared/ProgressionRules")
local Definitions = if Shared then require(Shared.EnemyDefinitions) else require("../shared/EnemyDefinitions")
local Rewards = {}
Rewards.__index = Rewards

local function identity(killId)
	if type(killId) ~= "string" or #killId == 0 or #killId > 128 then return nil end
	local spawnId, digits = string.match(killId, "^(enemy_[%w_%-]+):(%d+)$")
	if not spawnId or not string.match(digits, "^[1-9]%d*$") then return nil end
	local generation = tonumber(digits)
	if not generation or generation ~= generation or generation > 1e9 or generation % 1 ~= 0 then return nil end
	return spawnId, generation
end

function Rewards.new(profiles, options)
	assert(type(profiles) == "table", "Server profiles required")
	return setmetatable({ profiles = profiles, options = options or {}, credited = {}, destroyed = false }, Rewards)
end

function Rewards:recordDefeat(player, kind, killId)
	if self.destroyed then return false, "Enemy rewards are unavailable." end
	local profile = self.profiles[player]
	if not profile then return false, "Player character is not loaded." end
	if self.options.canAct and self.options.canAct(player) ~= true then
		return false, "Player save session is not writable."
	end
	local definition = if type(kind) == "string" then Definitions[kind] else nil
	if not definition then return false, "Unknown server enemy kind." end
	local spawnId, generation = identity(killId)
	if not spawnId then return false, "Invalid server enemy defeat identifier." end
	local history = self.credited[player]
	if history and history[spawnId] and generation <= history[spawnId] then
		return false, "This enemy generation was already credited."
	end
	if not history or history[spawnId] == nil then
		local count = 0
		for _ in history or {} do count += 1 end
		if count >= 64 then return false, "Enemy spawn credit capacity exceeded." end
	end
	local ok, message, summary = Progression.grantCombatReward(profile, definition.xp, definition.gold)
	if not ok then return false, message end
	-- Credit only after the entire reward transaction has succeeded. Older generations
	-- cannot be replayed even after a newer respawn has earned a reward.
	if not history then history = {}; self.credited[player] = history end
	history[spawnId] = generation
	if self.options.onQuestDefeat then self.options.onQuestDefeat(player, kind) end
	if self.options.onChanged then self.options.onChanged(player, summary) end
	return true, message
end

function Rewards:removePlayer(player)
	if player ~= nil then self.credited[player] = nil end
end

function Rewards:destroy()
	self.destroyed = true
	table.clear(self.credited)
end

return Rewards
