-- Directional movement and incoming damage are validated on the server.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Catalog = require(Shared.EquipmentCatalog)
local Progression = require(Shared.ProgressionRules)
local Rules = require(Shared.DefenceRules)

local Service = {}
Service.__index = Service
local function finite(value)
	return type(value) == "number" and value == value and math.abs(value) < math.huge
end
local function finiteVector(value)
	return typeof(value) == "Vector3" and finite(value.X) and finite(value.Y) and finite(value.Z)
end
local function parts(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root and (not root:IsA("BasePart") or not finiteVector(root.CFrame.Position)) then root = nil end
	return character, humanoid, root
end
local function event(parent, name)
	local remote = Instance.new("RemoteEvent")
	remote.Name, remote.Parent = name, parent
	return remote
end

function Service.new(profiles, remotes, options)
	options = options or {}
	assert(type(options.getResources) == "function", "Trusted combat resource getter required")
	local self = setmetatable({ profiles = profiles, options = options, entries = {}, destroyed = false,
		now = options.now or os.clock, physics = options.physics or workspace, elapsed = 0 }, Service)
	self.request = event(remotes, "DefenceRequest")
	self.stateEvent = event(remotes, "DefenceState")
	self.feedback = event(remotes, "DefenceFeedback")
	self.requestConnection = self.request.OnServerEvent:Connect(function(player, action, argument, ...)
		if select("#", ...) ~= 0 then return end
		self:_request(player, action, argument)
	end)
	if options.autoStep ~= false then
		self.heartbeat = (options.heartbeat or RunService.Heartbeat):Connect(function(delta)
			self.elapsed += delta
			if self.elapsed < 0.2 then return end
			self.elapsed = 0
			self:step(self.now())
		end)
	end
	return self
end

function Service:_context(player)
	local character, humanoid, root = parts(player)
	local profile = self.profiles[player]
	local item
	if profile then
		local uid = profile.equipped.OffHand
		local instance = uid and profile.inventory[uid]
		item = instance and Catalog.Items[instance.itemId]
	end
	-- Humanoid.MoveDirection is client-local and is not replicated to the server.
	-- Observe assembly motion here; the client still supplies only the sprint request.
	local velocity = root and root.AssemblyLinearVelocity
	local moving = finiteVector(velocity) and Vector3.new(velocity.X, 0, velocity.Z).Magnitude > 0.5
	return {
		alive = humanoid ~= nil and root ~= nil and humanoid.Health > 0,
		canAct = profile ~= nil and (not self.options.canAct or self.options.canAct(player) == true),
		hasShield = item ~= nil and item.family == "Shield",
		moving = moving == true,
	}, character, humanoid, root
end

function Service:_advance(player, now)
	local entry = self.entries[player]
	if not entry then return nil end
	local resources = self.options.getResources(player)
	if not resources then
		entry.defence.blocking, entry.defence.sprinting, entry.defence.dodgeUntil = false, false, 0
		return nil
	end
	local context = self:_context(player)
	Rules.tick(entry.defence, resources, now, context)
	return resources, context
end

function Service:_speed(player)
	local entry, profile = self.entries[player], self.profiles[player]
	local _, humanoid = parts(player)
	if not profile or not humanoid then return end
	local base = Progression.stats(profile).MoveSpeed
	local stance = entry and entry.defence
	humanoid.WalkSpeed = if stance and stance.blocking then Rules.Config.blockSpeed
		elseif stance and stance.sprinting then math.min(32, base * Rules.Config.sprintMultiplier) else base
end

function Service:_send(player, message)
	local entry = self.entries[player]
	if not entry or not self.stateEvent:IsDescendantOf(ReplicatedStorage) then return end
	local context = self:_context(player)
	local now = self.now()
	local resources = self.options.getResources(player)
	self.stateEvent:FireClient(player, {
		blocking = entry.defence.blocking, sprinting = entry.defence.sprinting,
		dodging = entry.defence.dodgeUntil > now,
		dodgeRemaining = math.max(0, entry.defence.nextDodge - now),
		guardRemaining = math.max(0, entry.defence.nextBlock - now),
		hasShield = context.hasShield, stamina = if resources then resources.stamina else 0,
		canPlay = context.canAct and context.alive, message = message,
	})
end

function Service:_characterAdded(player, character)
	local entry = self.entries[player]
	if not entry then return end
	entry.defence.blocking, entry.defence.sprinting, entry.defence.dodgeUntil = false, false, 0
	entry.defence.lastTick = self.now()
	task.spawn(function()
		local humanoid = character:WaitForChild("Humanoid", 10)
		if self.destroyed or self.entries[player] ~= entry or player.Character ~= character
			or not humanoid or not humanoid:IsA("Humanoid") then return end
		self:_speed(player)
		self:_send(player)
	end)
end

function Service:addPlayer(player)
	if self.destroyed or self.entries[player] then return end
	local now = self.now()
	local entry = { defence = Rules.newState(now), tokens = 12, tokenTime = now }
	self.entries[player] = entry
	entry.characterConnection = player.CharacterAdded:Connect(function(character) self:_characterAdded(player, character) end)
	if player.Character then self:_characterAdded(player, player.Character) end
	self:_send(player)
end

function Service:removePlayer(player)
	local entry = self.entries[player]
	if not entry then return end
	entry.defence.blocking, entry.defence.sprinting, entry.defence.dodgeUntil = false, false, 0
	self:_speed(player)
	entry.characterConnection:Disconnect()
	self.entries[player] = nil
end

function Service:staminaRegenScale(player)
	local entry = self.entries[player]
	return if entry then Rules.staminaRegenScale(entry.defence) else 1
end

function Service:equipmentChanged(player)
	if self.destroyed then return end
	self:_advance(player, self.now())
	self:_speed(player)
	self:_send(player)
end

function Service:_destination(character, root, direction)
	local flat = if direction then Vector3.new(direction.X, 0, direction.Z)
		else Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
	if flat.Magnitude < 0.01 then flat = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z) end
	if not finiteVector(flat) or flat.Magnitude < 0.01 then return nil end
	flat = flat.Unit
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character }
	local distance = Rules.Config.dodgeDistance
	local obstacle = self.physics:Blockcast(root.CFrame, Vector3.new(2.4, 4, 2.4), flat * distance, params)
	if obstacle then distance = math.max(0, math.min(distance, obstacle.Distance - 0.5)) end
	if distance < 1 then return nil end
	local destination = root.CFrame.Position + flat * distance
	local ground = self.physics:Raycast(destination, Vector3.new(0, -8, 0), params)
	if not ground or ground.Normal.Y < 0.5 then return nil end
	return destination
end

function Service:_request(player, action, argument)
	local entry = self.entries[player]
	if self.destroyed or not entry then return end
	if action ~= "Dodge" and action ~= "Block" and action ~= "Sprint" and action ~= "Sync" then return end
	if (action == "Block" or action == "Sprint") and type(argument) ~= "boolean" then return end
	if action == "Sync" and argument ~= nil then return end
	if action == "Dodge" and argument ~= nil and (not finiteVector(argument)
		or math.abs(argument.Y) > 0.01 or argument.Magnitude > 1.2) then return end
	local now = self.now()
	if not finite(now) or now < 0 then return end
	local release = (action == "Block" or action == "Sprint") and argument == false
	if not release then
		entry.tokens = math.min(12, entry.tokens + math.max(0, now - entry.tokenTime) * 8)
		entry.tokenTime = now
		if entry.tokens < 1 then return end
		entry.tokens -= 1
	end
	local resources, context = self:_advance(player, now)
	if not resources then return end
	if action == "Sync" then self:_send(player); return end
	local character, _, root = parts(player)
	local destination, origin
	if action == "Dodge" and context.alive and context.canAct then
		destination = self:_destination(character, root, argument)
		origin = root.CFrame.Position
	end
	context.pathClear = destination ~= nil
	local changed = if action == "Block" then entry.defence.blocking elseif action == "Sprint" then entry.defence.sprinting else true
	local ok, message = Rules.act(entry.defence, resources, action, if action == "Dodge" then nil else argument, now, context)
	if ok and destination then
		character:PivotTo(character:GetPivot() + (destination - root.CFrame.Position))
		root.AssemblyLinearVelocity = Vector3.zero
		self.feedback:FireClient(player, { kind = "Dodge", origin = origin, position = destination, victimUserId = player.UserId })
	end
	self:_speed(player)
	if not release or changed then self:_send(player, message) end
end

function Service:allowsAttack(player)
	local entry = self.entries[player]
	if self.destroyed or not entry then return false, "Your defence controls are not ready." end
	local now = self.now()
	self:_advance(player, now)
	if entry.defence.dodgeUntil > now then return false, "Finish your dodge before attacking." end
	if entry.defence.blocking then return false, "Release your shield guard before attacking." end
	if entry.defence.sprinting then
		entry.defence.sprinting = false
		self:_speed(player)
		self:_send(player)
	end
	return true
end

function Service:applyDamage(player, damage, sourcePosition)
	if self.destroyed or not finite(damage) or damage < 1 or damage > 10000 then return 0, "Invalid" end
	local entry = self.entries[player]
	if not entry then return 0, "Paused" end
	local now = self.now()
	local resources, context = self:_advance(player, now)
	if not resources then return 0, "Paused" end
	local _, humanoid, root = parts(player)
	context.facingDot = -1
	if root and finiteVector(sourcePosition) then
		local delta = Vector3.new(sourcePosition.X - root.CFrame.Position.X, 0, sourcePosition.Z - root.CFrame.Position.Z)
		local facing = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
		if delta.Magnitude >= 0.001 and facing.Magnitude >= 0.001 then
			context.facingDot = math.clamp(facing.Unit:Dot(delta.Unit), -1, 1)
		end
	end
	local amount, outcome = Rules.resolveDamage(entry.defence, resources, damage, now, context)
	local before = if humanoid then humanoid.Health else 0
	if humanoid and amount > 0 then humanoid:TakeDamage(amount) end
	local actual = math.max(0, before - (if humanoid then humanoid.Health else before))
	self:_speed(player)
	self.feedback:FireClient(player, { kind = outcome, damage = actual,
		position = if root then root.CFrame.Position else nil, victimUserId = player.UserId })
	self:_send(player)
	return actual, outcome
end

function Service:step(now)
	if self.destroyed or not finite(now) then return end
	for player in self.entries do
		self:_advance(player, now)
		self:_speed(player)
		self:_send(player)
	end
end

function Service:destroy()
	if self.destroyed then return end
	self.destroyed = true
	self.requestConnection:Disconnect()
	if self.heartbeat then self.heartbeat:Disconnect() end
	for player in self.entries do self:removePlayer(player) end
	self.request:Destroy()
	self.stateEvent:Destroy()
	self.feedback:Destroy()
end

return Service
