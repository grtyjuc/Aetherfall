-- A safe village rest point. Prompt signals still require server-side validation.
local RestService = {}
RestService.__index = RestService

function RestService.new(profiles, village, options)
	options = options or {}
	local prompt = assert(village:FindFirstChild("RestAtWell", true), "Village rest prompt required")
	local self = setmetatable({ profiles = profiles, options = options, prompt = prompt,
		now = options.now or os.clock, lastRest = {}, destroyed = false }, RestService)
	self.connection = prompt.Triggered:Connect(function(player) self:rest(player) end)
	return self
end

function RestService:rest(player)
	if self.destroyed or not self.profiles[player] or (self.options.canAct and not self.options.canAct(player)) then return false end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local well = self.prompt.Parent
	if not humanoid or humanoid.Health <= 0 or not root or not root:IsA("BasePart")
		or not well or not well:IsA("BasePart") then return false end
	local distance = (root.Position - well.Position).Magnitude
	local now = self.now()
	if distance ~= distance or distance > 10 or root.Position.X >= 48 or now ~= now
		or now - (self.lastRest[player] or -math.huge) < 10 then return false end
	self.lastRest[player] = now
	humanoid.Health = humanoid.MaxHealth
	if self.options.onRest then self.options.onRest(player) end
	return true
end

function RestService:removePlayer(player)
	self.lastRest[player] = nil
end

function RestService:destroy()
	if self.destroyed then return end
	self.destroyed = true
	self.connection:Disconnect()
	table.clear(self.lastRest)
end

return RestService
