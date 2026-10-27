-- Rune prompts and first-defeat rewards are server-owned. No client claim endpoint exists.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Grove = require(ReplicatedStorage:WaitForChild("Shared").GroveRules)
local GroveService = {}
GroveService.__index = GroveService

local function finite(value)
	return type(value) == "number" and value == value and math.abs(value) < math.huge
end

function GroveService.new(profiles, remotes, groveWorld, options)
	options = options or {}
	local prompt = assert(groveWorld:FindFirstChild("InspectGroveRune", true), "Grove rune prompt required")
	assert(prompt:IsA("ProximityPrompt") and prompt.Parent and prompt.Parent:IsA("BasePart"), "Rune prompt requires a stone")
	local self = setmetatable({ profiles = profiles, options = options, prompt = prompt,
		now = options.now or os.clock, lastInspect = {}, destroyed = false }, GroveService)
	self.connection = prompt.Triggered:Connect(function(player) self:inspect(player) end)
	return self
end

function GroveService:_canAct(player)
	return not self.options.canAct or self.options.canAct(player) == true
end

function GroveService:_message(player, text)
	if self.options.onMessage then self.options.onMessage(player, text) end
end

function GroveService:inspect(player)
	local profile = self.profiles[player]
	if self.destroyed or not profile or not self:_canAct(player) then return false, "Your character is not ready." end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local stone = self.prompt.Parent
	if not humanoid or humanoid.Health <= 0 or not root or not root:IsA("BasePart")
		or not stone or not stone:IsA("BasePart") then return false, "Approach the runestone while alive." end
	local distance, now = (root.Position - stone.Position).Magnitude, self.now()
	if not finite(distance) or distance > 10 or not finite(now) then return false, "Approach the runestone." end
	if now - (self.lastInspect[player] or -math.huge) < 1 then return false, "Please wait before inspecting again." end
	self.lastInspect[player] = now
	local changed, message = Grove.inspectRune(profile)
	if changed and self.options.onChanged then self.options.onChanged(player) end
	self:_message(player, message)
	return changed, message
end

-- Called only by BossService after validating encounter participation and contribution.
function GroveService:recordBossDefeat(player)
	local profile = self.profiles[player]
	if self.destroyed or not profile or not self:_canAct(player) then return false, "Your character is not ready." end
	local changed, message, summary = Grove.recordBossDefeat(profile)
	if not changed then return false, message end
	if self.options.onChanged then self.options.onChanged(player) end
	self:_message(player, string.format("Briarwarden defeated: +%d XP, +%d gold and grove equipment. Return to Elder Rowan.", summary.xp, summary.gold))
	return true, message, summary
end

function GroveService:removePlayer(player)
	if player ~= nil then self.lastInspect[player] = nil end
end

function GroveService:destroy()
	if self.destroyed then return end
	self.destroyed = true
	self.connection:Disconnect()
	table.clear(self.lastInspect)
end

return GroveService
