-- Studio training combat. Inventory, damage, resources and cooldowns stay server-owned.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Catalog = require(Shared.EquipmentCatalog)
local EquipmentRules = require(Shared.EquipmentRules)
local Progression = require(Shared.ProgressionRules)
local Config = require(Shared.CombatConfig)
local Rules = require(Shared.CombatRules)

local CombatService = {}
CombatService.__index = CombatService

local function disconnect(connection)
	if connection then connection:Disconnect() end
end

local function finite(value)
	return type(value) == "number" and value == value and math.abs(value) < math.huge
end

local function characterParts(player)
	local character = player.Character
	if not character then return nil, nil, nil end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	if root and not root:IsA("BasePart") then root = nil end
	return character, humanoid, root
end

local function equippedItem(profile, slot)
	local uid = profile.equipped[slot]
	local instance = uid and profile.inventory[uid]
	return instance and Catalog.Items[instance.itemId]
end

local function remote(parent, name)
	local event = Instance.new("RemoteEvent")
	event.Name = name
	event.Parent = parent
	return event
end

function CombatService.new(profiles, remotes, trainingWorld, options)
	local self = setmetatable({
		profiles = profiles,
		options = options or {},
		states = {},
		targets = {},
		random = Random.new(),
		elapsed = 0,
		destroyed = false,
	}, CombatService)
	self.request = remote(remotes, "CombatRequest")
	self.stateEvent = remote(remotes, "CombatState")
	self.feedback = remote(remotes, "CombatFeedback")
	local targets = assert(trainingWorld:FindFirstChild("Targets"), "Training target folder required")
	for _, target in targets:GetChildren() do
		local id = target:GetAttribute("TargetId")
		if target:IsA("Model") and target.PrimaryPart and type(id) == "string" then
			assert(self.targets[id] == nil, "Duplicate training target id")
			local maximum = target:GetAttribute("MaxHealth")
			local defence = target:GetAttribute("Defence")
			assert(finite(maximum) and maximum > 0, "Invalid target health")
			assert(finite(defence) and defence >= 0, "Invalid target defence")
			self.targets[id] = target
			target:SetAttribute("Health", maximum)
			target:SetAttribute("DownUntil", 0)
			self:_label(target)
		end
	end
	self.requestConnection = self.request.OnServerEvent:Connect(function(player, action, targetId)
		self:_request(player, action, targetId)
	end)
	self.heartbeat = RunService.Heartbeat:Connect(function(delta)
		self.elapsed += delta
		if self.elapsed < 0.2 then return end
		self.elapsed = 0
		self:_tick(os.clock())
	end)
	return self
end

function CombatService:_label(target)
	local label = target:FindFirstChild("HealthText", true)
	if label and label:IsA("TextLabel") then
		local health = target:GetAttribute("Health")
		label.Text = if health > 0
			then string.format("%d / %d", math.ceil(health), target:GetAttribute("MaxHealth"))
			else if target:GetAttribute("Enemy") == true then "Defeated · returning soon" else "Recovering · 4 seconds"
	end
end

-- Only server-created targets enter this registry; no client can register an Instance.
function CombatService:registerTarget(target)
	assert(target and target:IsA("Model") and target.PrimaryPart, "Combat target requires a model and hitbox")
	local id = target:GetAttribute("TargetId")
	assert(type(id) == "string" and #id > 0 and #id <= 40, "Invalid target identifier")
	assert(not self.targets[id] or self.targets[id] == target, "Duplicate combat target identifier")
	local maximum, health, defence = target:GetAttribute("MaxHealth"), target:GetAttribute("Health"), target:GetAttribute("Defence")
	assert(finite(maximum) and maximum > 0 and maximum <= 1e6, "Invalid target maximum health")
	assert(finite(health) and health >= 0 and health <= maximum, "Invalid target health")
	assert(finite(defence) and defence >= 0 and defence <= 1e6, "Invalid target defence")
	self.targets[id] = target
	self:_label(target)
end

function CombatService:unregisterTarget(id)
	self.targets[id] = nil
end

function CombatService:_sendState(player)
	local entry, profile = self.states[player], self.profiles[player]
	if not entry or not profile then return end
	if not self.stateEvent:IsDescendantOf(ReplicatedStorage) then return end
	local _, humanoid = characterParts(player)
	local stats = Progression.stats(profile)
	local definition = Config.Classes[profile.className]
	local mainHand = equippedItem(profile, "MainHand")
	local basic = Config.getAction(profile.className, "Basic", mainHand and mainHand.family)
	local now = os.clock()
	self.stateEvent:FireClient(player, {
		className = profile.className,
		health = if humanoid then humanoid.Health else 0,
		maxHealth = stats.MaxHealth,
		mana = entry.combat.mana,
		maxMana = Config.maxMana,
		stamina = entry.combat.stamina,
		maxStamina = Config.maxStamina,
		basicRemaining = math.max(0, entry.combat.nextBasic - now),
		skillRemaining = math.max(0, entry.combat.nextSkill - now),
		basicName = basic.name,
		skillName = definition.skill.name,
		hasWeapon = mainHand ~= nil,
	})
end

function CombatService:_applyStats(player, fullHealth)
	local profile = self.profiles[player]
	local _, humanoid = characterParts(player)
	if not profile or not humanoid then return end
	local stats = Progression.stats(profile)
	local health = humanoid.Health
	humanoid.MaxHealth = stats.MaxHealth
	-- Equipment changes never heal or revive. A genuine respawn starts at full health.
	humanoid.Health = if fullHealth then stats.MaxHealth else math.min(health, stats.MaxHealth)
	humanoid.WalkSpeed = stats.MoveSpeed
end

function CombatService:_characterAdded(player, character)
	local entry = self.states[player]
	if not entry then return end
	disconnect(entry.healthConnection)
	entry.healthConnection = nil
	-- CharacterAdded can precede Humanoid creation. Never hold a request handler open.
	task.spawn(function()
		local humanoid = character:WaitForChild("Humanoid", 10)
		if self.destroyed or self.states[player] ~= entry or player.Character ~= character then return end
		if not humanoid or not humanoid:IsA("Humanoid") then return end
		self:_applyStats(player, true)
		character:SetAttribute("AetherfallSpawnProtectedUntil", os.clock() + 2)
		entry.combat.mana = Config.maxMana
		entry.combat.stamina = Config.maxStamina
		entry.combat.combo = 0
		entry.combat.comboUntil = 0
		-- Cooldowns survive death/class changes: they cannot be reset through either route.
		entry.healthConnection = humanoid.HealthChanged:Connect(function()
			self:_sendState(player)
		end)
		self:_sendState(player)
	end)
end

function CombatService:addPlayer(player)
	if self.destroyed or self.states[player] then return end
	local now = os.clock()
	self.states[player] = {
		combat = Rules.newState(now),
		tokens = 10,
		tokenTime = now,
	}
	local entry = self.states[player]
	entry.characterConnection = player.CharacterAdded:Connect(function(character)
		self:_characterAdded(player, character)
	end)
	if player.Character then self:_characterAdded(player, player.Character) end
	self:_sendState(player)
end

function CombatService:removePlayer(player)
	local entry = self.states[player]
	if not entry then return end
	disconnect(entry.characterConnection)
	disconnect(entry.healthConnection)
	self.states[player] = nil
end

function CombatService:equipmentChanged(player, classChanged)
	local entry = self.states[player]
	if not entry then return end
	if classChanged then
		entry.combat.combo = 0
		entry.combat.comboUntil = 0
	end
	self:_applyStats(player, false)
	self:_sendState(player)
end

function CombatService:_reject(player, message)
	self.feedback:FireClient(player, { kind = "Rejected", message = message })
end

function CombatService:_lineOfSight(character, origin, target)
	local delta = target.PrimaryPart.Position - origin
	if delta.Magnitude < 0.001 then return true end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character }
	local hit = workspace:Raycast(origin, delta, params)
	return hit == nil or hit.Instance:IsDescendantOf(target)
end

function CombatService:_dashDestination(character, root, distance)
	local forward = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
	if forward.Magnitude < 0.01 then return nil end
	forward = forward.Unit
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character }
	-- Cast a character-sized volume, not just a point, to avoid wall clipping.
	local obstacle = workspace:Blockcast(root.CFrame, Vector3.new(2.4, 4, 2.4), forward * distance, params)
	local allowed = if obstacle then math.max(0, obstacle.Distance - 0.5) else distance
	if allowed < 1 then return nil end
	local destination = root.Position + forward * allowed
	local ground = workspace:Raycast(destination, Vector3.new(0, -8, 0), params)
	if not ground or ground.Normal.Y < 0.5 then return nil end
	return destination
end

function CombatService:_damageTarget(player, action, result, target, origin, now)
	if target:GetAttribute("Health") <= 0 then return end
	local profile = self.profiles[player]
	local damage, critical = Rules.damage(Progression.stats(profile), result,
		target:GetAttribute("Defence"), self.random:NextNumber())
	local remaining = math.max(0, target:GetAttribute("Health") - damage)
	target:SetAttribute("Health", remaining)
	if target:GetAttribute("Enemy") == true and target:GetAttribute("Boss") ~= true and result.name == "Shield Bash" and remaining > 0 then
		target:SetAttribute("StunnedUntil", now + 1)
	end
	if remaining == 0 and target:GetAttribute("Enemy") ~= true then target:SetAttribute("DownUntil", now + 4) end
	self:_label(target)
	if self.options.onTargetDamaged then self.options.onTargetDamaged(player, target, damage, remaining == 0) end
	self.feedback:FireAllClients({
		kind = result.kind,
		actorUserId = player.UserId,
		className = profile.className,
		action = action,
		name = result.name,
		combo = result.combo,
		origin = origin,
		position = target.PrimaryPart.Position,
		damage = damage,
		critical = critical,
		targetId = target:GetAttribute("TargetId"),
	})
end

function CombatService:_request(player, action, targetId)
	local entry, profile = self.states[player], self.profiles[player]
	if self.destroyed or not entry or not profile then return end
	local now = os.clock()
	entry.tokens = math.min(10, entry.tokens + (now - entry.tokenTime) * 6)
	entry.tokenTime = now
	if entry.tokens < 1 then
		self:_reject(player, "Please slow down your combat requests.")
		return
	end
	entry.tokens -= 1
	if type(action) ~= "string" or (action ~= "Basic" and action ~= "Skill" and action ~= "Sync")
		or (targetId ~= nil and (type(targetId) ~= "string" or #targetId > 40)) then
		self:_reject(player, "Invalid combat request.")
		return
	end
	if self.options.canAct and not self.options.canAct(player) then
		self:_reject(player, "Your character is loading or save ownership was lost. Actions are paused.")
		return
	end
	Rules.refresh(entry.combat, now)
	if action == "Sync" then self:_sendState(player); return end
	local character, humanoid, root = characterParts(player)
	local mainHand, offHand = equippedItem(profile, "MainHand"), equippedItem(profile, "OffHand")
	local definition = Config.getAction(profile.className, action, mainHand and mainHand.family)
	local target = targetId and self.targets[targetId]
	local validTarget = target ~= nil and target.Parent ~= nil and target:GetAttribute("Health") > 0
	if validTarget and definition.kind ~= "Dash" and self.options.canTarget then
		local allowed, reason = self.options.canTarget(player, target)
		if not allowed then self:_reject(player, reason or "This target cannot be attacked here."); return end
	end
	local origin = if root then root.Position + Vector3.new(0, 1, 0) else Vector3.zero
	local distance, aimDot, lineOfSight = math.huge, -1, false
	if validTarget and root then
		local delta = target.PrimaryPart.Position - root.Position
		distance = delta.Magnitude
		aimDot = if distance < 0.001 then 1 else math.clamp(root.CFrame.LookVector:Dot(delta.Unit), -1, 1)
		lineOfSight = self:_lineOfSight(character, origin, target)
	end
	local alive = humanoid ~= nil and root ~= nil and humanoid.Health > 0
	local destination
	if definition.kind == "Dash" and alive then
		destination = self:_dashDestination(character, root, definition.dashDistance)
		if not destination then
			self:_reject(player, "Quickstep needs a clear, grounded path in front of you.")
			return
		end
	end
	local ok, message, result = Rules.tryAction(entry.combat, profile.className, action, now, {
		alive = alive,
		hasWeapon = mainHand ~= nil and table.find(mainHand.classes, profile.className) ~= nil,
		hasShield = offHand ~= nil and offHand.family == "Shield",
		weaponFamily = mainHand and mainHand.family,
		targetValid = validTarget,
		distance = distance,
		aimDot = aimDot,
		lineOfSight = lineOfSight,
	})
	if not ok then self:_reject(player, message); self:_sendState(player); return end
	if result.kind == "Dash" then
		local offset = destination - root.Position
		character:PivotTo(character:GetPivot() + offset)
		root.AssemblyLinearVelocity = Vector3.zero
		self.feedback:FireAllClients({
			kind = "Dash", actorUserId = player.UserId, className = profile.className,
			action = action, name = result.name, combo = result.combo,
			origin = origin, position = destination, damage = 0, critical = false,
		})
	elseif result.kind == "Area" then
		local center = target.PrimaryPart.Position
		for _, secondary in self.targets do
			if secondary.Parent and secondary:GetAttribute("Health") > 0
				and (secondary.PrimaryPart.Position - center).Magnitude <= result.radius
				and (not self.options.canTarget or self.options.canTarget(player, secondary))
				and self:_lineOfSight(character, origin, secondary) then
				self:_damageTarget(player, action, result, secondary, origin, now)
			end
		end
	else
		self:_damageTarget(player, action, result, target, origin, now)
	end
	if self.options.onAction then self.options.onAction(player, action, result) end
	self:_sendState(player)
end

function CombatService:_tick(now)
	for player, entry in self.states do
		Rules.refresh(entry.combat, now)
		self:_sendState(player)
	end
	for _, target in self.targets do
		if target:GetAttribute("Enemy") ~= true and target.Parent and target:GetAttribute("Health") <= 0 and now >= target:GetAttribute("DownUntil") then
			target:SetAttribute("Health", target:GetAttribute("MaxHealth"))
			target:SetAttribute("DownUntil", 0)
			self:_label(target)
		end
	end
end

function CombatService:destroy()
	if self.destroyed then return end
	self.destroyed = true
	disconnect(self.requestConnection)
	disconnect(self.heartbeat)
	for player in self.states do self:removePlayer(player) end
	self.request:Destroy()
	self.stateEvent:Destroy()
	self.feedback:Destroy()
end

return CombatService
