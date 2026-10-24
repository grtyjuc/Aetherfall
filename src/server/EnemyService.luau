-- Bounded server AI for a small, open field. No client controls movement or rewards.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Definitions = require(Shared.EnemyDefinitions)
local Progression = require(Shared.ProgressionRules)

local EnemyService = {}
EnemyService.__index = EnemyService
local FIELD_EDGE = 48
local function finite(value)
	return type(value) == "number" and value == value and math.abs(value) < math.huge
end
local function finiteVector(value)
	return typeof(value) == "Vector3" and finite(value.X) and finite(value.Y) and finite(value.Z)
end
local function position(part) return part.CFrame.Position end
local function flat(vector) return Vector3.new(vector.X, 0, vector.Z) end

local function buildModel(kind, id, definition)
	local model = Instance.new("Model")
	model.Name = definition.name
	model:SetAttribute("TargetId", id)
	model:SetAttribute("EnemyKind", kind)
	model:SetAttribute("Enemy", true)
	model:SetAttribute("Health", definition.health)
	model:SetAttribute("MaxHealth", definition.health)
	model:SetAttribute("Defence", definition.defence)
	model:SetAttribute("AliveGeneration", 1)
	model:SetAttribute("DownUntil", 0)
	local primary = Color3.fromRGB(table.unpack(definition.color))
	local accent = Color3.fromRGB(table.unpack(definition.accent))
	local function part(name, size, offset, tint, shape, material, rotation)
		local object = Instance.new("Part")
		object.Name = name
		object.Size = size
		object.CFrame = CFrame.new(offset) * (rotation or CFrame.identity)
		object.Color = tint
		object.Shape = shape or Enum.PartType.Block
		object.Material = material or Enum.Material.SmoothPlastic
		object.Anchored = true
		object.CanCollide = false
		object.CanTouch = false
		object.CanQuery = name == "Hitbox"
		object.TopSurface = Enum.SurfaceType.Smooth
		object.BottomSurface = Enum.SurfaceType.Smooth
		object.Parent = model
		return object
	end
	local body
	if kind == "MeadowSlime" then
		body = part("Hitbox", Vector3.new(3.4, 2.6, 3), Vector3.zero, primary, Enum.PartType.Ball)
		body.Transparency = 0.12
		part("SlimeCrown", Vector3.new(1.5, 0.8, 1.5), Vector3.new(0, 1.2, 0.1), accent, Enum.PartType.Ball)
		for _, side in { -1, 1 } do
			part("SlimeLobe", Vector3.new(1.3, 1.4, 1.5), Vector3.new(side * 1.3, -0.5, 0.2), primary, Enum.PartType.Ball)
			part("Eye", Vector3.new(0.3, 0.4, 0.15), Vector3.new(side * 0.6, 0.25, -1.4), Color3.fromRGB(27, 49, 33), Enum.PartType.Ball)
		end
	elseif kind == "WildBoar" then
		body = part("Hitbox", Vector3.new(2.6, 2.1, 4.1), Vector3.zero, primary, Enum.PartType.Ball)
		part("Head", Vector3.new(2.2, 1.8, 1.7), Vector3.new(0, 0, -1.9), primary, Enum.PartType.Ball)
		part("Snout", Vector3.new(1.3, 0.9, 0.6), Vector3.new(0, -0.15, -2.8), accent, Enum.PartType.Ball)
		part("Ridge", Vector3.new(0.4, 0.5, 2.7), Vector3.new(0, 1.03, 0.1), Color3.fromRGB(69, 49, 37))
		for _, side in { -1, 1 } do
			for _, z in { -1.2, 1.2 } do
				part("Leg", Vector3.new(0.55, 1.25, 0.65), Vector3.new(side * 0.9, -1.15, z), primary)
			end
			part("Ear", Vector3.new(0.7, 0.6, 0.25), Vector3.new(side * 0.8, 0.95, -1.65), primary,
				nil, nil, CFrame.Angles(0, 0, side * 0.4))
			part("Tusk", Vector3.new(0.2, 0.7, 0.2), Vector3.new(side * 0.75, -0.1, -2.65), accent,
				nil, nil, CFrame.Angles(-0.4, 0, side * -0.2))
		end
	else
		body = part("Hitbox", Vector3.new(1.9, 2.7, 1.4), Vector3.zero, primary, nil, Enum.Material.Wood)
		part("RootHead", Vector3.new(1.5, 1.3, 1.3), Vector3.new(0, 1.85, 0), primary, Enum.PartType.Ball, Enum.Material.Wood)
		for _, side in { -1, 1 } do
			part("RootLeg", Vector3.new(0.55, 1.4, 0.6), Vector3.new(side * 0.6, -1.7, 0), primary,
				nil, Enum.Material.Wood, CFrame.Angles(0, 0, side * -0.18))
			part("BranchArm", Vector3.new(0.55, 2, 0.5), Vector3.new(side * 1.25, 0.3, 0), primary,
				nil, Enum.Material.Wood, CFrame.Angles(0, 0, side * 0.5))
			part("LeafCrown", Vector3.new(1.7, 0.65, 1.3), Vector3.new(side * 0.5, 2.5, 0), accent,
				Enum.PartType.Ball, Enum.Material.Grass, CFrame.Angles(0, 0, side * 0.4))
			part("AetherEye", Vector3.new(0.22, 0.25, 0.14), Vector3.new(side * 0.35, 1.9, -0.61),
				Color3.fromRGB(229, 214, 133), Enum.PartType.Ball)
		end
	end
	model.PrimaryPart = body
	local warning = part("AttackWarning", Vector3.new(0.3, 0.8, 0.3), Vector3.new(0, 4, 0),
		Color3.fromRGB(255, 190, 86), nil, Enum.Material.Neon)
	warning.Transparency = 1
	local bill = Instance.new("BillboardGui")
	bill.Name = "EnemyBillboard"
	bill.Adornee = body
	bill.StudsOffset = Vector3.new(0, 4.1, 0)
	bill.Size = UDim2.fromOffset(180, 54)
	bill.MaxDistance = 95
	bill.Parent = body
	local name = Instance.new("TextLabel")
	name.Name = "EnemyName"
	name.Text = definition.name
	name.Size = UDim2.new(1, 0, 0.5, 0)
	name.BackgroundColor3 = Color3.fromRGB(41, 45, 36)
	name.BackgroundTransparency = 0.1
	name.TextColor3 = Color3.fromRGB(239, 228, 192)
	name.TextSize = 13
	name.Font = Enum.Font.GothamMedium
	name.Parent = bill
	local health = name:Clone()
	health.Name = "HealthText"
	health.Position = UDim2.fromScale(0, 0.5)
	health.Text = definition.health .. " / " .. definition.health
	health.Parent = bill
	return model
end

local function moveModel(model, destination)
	local previous = model.PrimaryPart.CFrame
	for _, child in model:GetDescendants() do
		if child:IsA("BasePart") then child.CFrame = destination * previous:ToObjectSpace(child.CFrame) end
	end
end

function EnemyService.new(profiles, combat, villageWorld, options)
	options = options or {}
	local spawns = assert(villageWorld:FindFirstChild("EnemySpawns"), "Enemy spawn folder required")
	local planned, ids = {}, {}
	for _, marker in spawns:GetChildren() do
		local kind, spawnId = marker:GetAttribute("EnemyKind"), marker:GetAttribute("SpawnId")
		assert(marker:IsA("BasePart") and Definitions[kind], "Invalid enemy spawn definition")
		assert(type(spawnId) == "string" and spawnId:match("^[%w_]+$") and #spawnId <= 28 and not ids[spawnId], "Invalid or duplicate enemy spawn identity")
		assert(finiteVector(position(marker)) and position(marker).X >= 65, "Enemy spawns must be in the field")
		ids[spawnId] = true
		table.insert(planned, { kind = kind, spawnId = spawnId, home = position(marker) + Vector3.new(0, 1, 0) })
	end
	assert(#planned >= 3 and #planned <= 8, "Enemy count must be between three and eight")
	local parent = options.worldParent or workspace
	assert(not parent:FindFirstChild("AetherfallEnemies"), "Enemy world name is already in use")
	local folder = Instance.new("Folder")
	folder.Name = "AetherfallEnemies"
	folder:SetAttribute("AetherfallEnemyOwned", true)
	local targets = Instance.new("Folder")
	targets.Name = "Targets"
	targets.Parent = folder
	local self = setmetatable({ profiles = profiles, combat = combat, options = options,
		now = options.now or os.clock, physics = options.physics or workspace,
		world = folder, targets = targets, entries = {}, elapsed = 0, destroyed = false }, EnemyService)
	for index, spawn in planned do
		local definition = Definitions[spawn.kind]
		local id = "enemy_" .. spawn.spawnId
		local model = buildModel(spawn.kind, id, definition)
		model:SetAttribute("SpawnHome", spawn.home)
		model:SetAttribute("LeashDistance", definition.leash)
		model:SetAttribute("StunnedUntil", 0)
		moveModel(model, CFrame.new(spawn.home))
		model.Parent = targets
		local now = self.now()
		self.entries[id] = { model = model, kind = spawn.kind, id = id, home = spawn.home,
			definition = definition, generation = 1, rewardedGeneration = 0, contributors = {},
			state = "Idle", untilTime = now + index * 0.2, nextAttack = now, stuckSince = nil }
		model:SetAttribute("AIState", "Idle")
		combat:registerTarget(model)
	end
	folder.Parent = parent
	if options.autoStep ~= false then
		self.connection = (options.heartbeat or RunService.Heartbeat):Connect(function(delta)
			self.elapsed += delta
			if self.elapsed < 0.2 then return end
			local elapsed = math.min(self.elapsed, 0.4)
			self.elapsed = 0
			self:step(self.now(), elapsed)
		end)
	end
	return self
end

function EnemyService:_player(player)
	if not self.profiles[player] or (self.options.canAct and not self.options.canAct(player)) then return nil end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not humanoid or not root or not root:IsA("BasePart") or humanoid.Health <= 0 or not finiteVector(position(root)) then return nil end
	return character, humanoid, root
end

function EnemyService:_state(entry, state, untilTime)
	entry.state, entry.untilTime = state, untilTime or 0
	entry.model:SetAttribute("AIState", state)
	-- Recovering bodies are unselectable and must not occlude rays to living targets.
	entry.model.PrimaryPart.CanQuery = state ~= "Dead"
	local warning = entry.model:FindFirstChild("AttackWarning")
	if warning then warning.Transparency = if state == "Windup" then 0.2 else 1 end
	local name = entry.model:FindFirstChild("EnemyName", true)
	if name then name.Text = entry.definition.name .. (if state == "Windup" then " · DODGE!" elseif state == "Dead" then " · Recovering" elseif state == "Stunned" then " · STUNNED" else "") end
end

function EnemyService:_lineOfSight(entry, character, origin, destination)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { entry.model }
	local delta = destination - origin
	if delta.Magnitude < 0.01 then return true end
	local hit = self.physics:Raycast(origin, delta, params)
	return hit == nil or (character and hit.Instance:IsDescendantOf(character))
end

function EnemyService:_move(entry, destination, dt, now)
	local current = position(entry.model.PrimaryPart)
	local delta = flat(destination - current)
	if delta.Magnitude < 0.25 then entry.stuckSince = nil; return true end
	local step = delta.Unit * math.min(delta.Magnitude, entry.definition.speed * dt)
	local proposed = current + step
	if proposed.X < FIELD_EDGE or (proposed - entry.home).Magnitude > entry.definition.leash + 1 then return false end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { entry.model }
	local obstacle = self.physics:Raycast(current, step.Unit * (step.Magnitude + 1.8), params)
	local ground = self.physics:Raycast(proposed + Vector3.new(0, 2, 0), Vector3.new(0, -7, 0), params)
	if obstacle or not ground or ground.Normal.Y < 0.5 then
		entry.stuckSince = entry.stuckSince or now
		return false
	end
	entry.stuckSince = nil
	moveModel(entry.model, CFrame.lookAt(proposed, proposed + delta.Unit))
	return true
end

function EnemyService:_nearest(entry)
	local current = position(entry.model.PrimaryPart)
	local chosen, nearest = nil, entry.definition.detectRange
	for player in self.profiles do
		local character, _, root = self:_player(player)
		if root and position(root).X >= FIELD_EDGE then
			local distance = (position(root) - current).Magnitude
			if distance <= nearest and (position(root) - entry.home).Magnitude <= entry.definition.leash
				and self:_lineOfSight(entry, character, current, position(root)) then chosen, nearest = player, distance end
		end
	end
	return chosen
end

function EnemyService:_impact(entry, now)
	local character, humanoid, root = self:_player(entry.target)
	if not root or position(root).X < FIELD_EDGE
		or (position(root) - position(entry.model.PrimaryPart)).Magnitude > entry.definition.impactRange
		or (position(root) - entry.home).Magnitude > entry.definition.leash
		or (character:GetAttribute("AetherfallSpawnProtectedUntil") or 0) > now
		or not self:_lineOfSight(entry, character, position(entry.model.PrimaryPart), position(root)) then return end
	local defence = Progression.stats(self.profiles[entry.target]).Defence
	local damage = math.max(1, entry.definition.damage * (100 / (100 + math.max(0, defence))))
	humanoid:TakeDamage(damage)
end

function EnemyService:onDamaged(player, target, damage, wasDefeated)
	if self.destroyed or not target then return end
	local entry = self.entries[target:GetAttribute("TargetId")]
	if not entry or entry.model ~= target or entry.state == "Dead" or not finite(damage) or damage <= 0 then return end
	local now = self.now()
	local _, _, root = self:_player(player)
	if root and position(root).X >= FIELD_EDGE and (position(root) - entry.home).Magnitude <= entry.definition.leash then
		local contribution = entry.contributors[player] or { damage = 0 }
		contribution.damage += damage
		contribution.lastHit = now
		entry.contributors[player] = contribution
		if not wasDefeated then
			entry.target = player
			if entry.state ~= "Windup" and entry.state ~= "Recover" and entry.state ~= "Stunned" then
				self:_state(entry, "Chase")
			end
		end
	end
	if not wasDefeated or target:GetAttribute("Health") > 0 or entry.rewardedGeneration == entry.generation then return end
	entry.rewardedGeneration = entry.generation
	entry.target = nil
	self:_state(entry, "Dead", now + entry.definition.respawn)
	target:SetAttribute("DownUntil", entry.untilTime)
	local killId = entry.id .. ":" .. entry.generation
	for contributor, contribution in entry.contributors do
		local _, _, root = self:_player(contributor)
		if root and now - contribution.lastHit <= 20
			and (position(root) - position(target.PrimaryPart)).Magnitude <= 100
			and self.options.onDefeat then self.options.onDefeat(contributor, entry.kind, killId) end
	end
	table.clear(entry.contributors)
end

function EnemyService:step(now, dt)
	if self.destroyed or not finite(now) or not finite(dt) or dt <= 0 then return end
	dt = math.min(dt, 0.4)
	for _, entry in self.entries do
		local model = entry.model
		if not model.Parent or not model.PrimaryPart then continue end
		if entry.state == "Dead" then
			if now >= entry.untilTime then
				entry.generation += 1
				entry.target, entry.stuckSince = nil, nil
				table.clear(entry.contributors)
				model:SetAttribute("AliveGeneration", entry.generation)
				model:SetAttribute("Health", entry.definition.health)
				model:SetAttribute("DownUntil", 0)
				model:SetAttribute("StunnedUntil", 0)
				local label = model:FindFirstChild("HealthText", true)
				if label then label.Text = entry.definition.health .. " / " .. entry.definition.health end
				moveModel(model, CFrame.new(entry.home))
				self:_state(entry, "Idle", now + 0.5)
			end
			continue
		end
		if model:GetAttribute("Health") <= 0 then
			-- Defensive recovery if another trusted system depletes health without attribution.
			entry.target = nil
			self:_state(entry, "Dead", now + entry.definition.respawn)
			continue
		end
		local stunnedUntil = model:GetAttribute("StunnedUntil")
		if finite(stunnedUntil) and stunnedUntil > now then
			self:_state(entry, "Stunned", stunnedUntil)
			continue
		elseif entry.state == "Stunned" then
			self:_state(entry, "Chase")
		end
		local current = position(model.PrimaryPart)
		if entry.state == "Return" then
			if (current - entry.home).Magnitude <= 1 or (entry.stuckSince and now - entry.stuckSince >= 4) then
				moveModel(model, CFrame.new(entry.home))
				entry.stuckSince = nil
				self:_state(entry, "Idle", now + 0.5)
			else self:_move(entry, entry.home, dt, now) end
			continue
		end
		if entry.state == "Windup" then
			if now >= entry.untilTime then
				self:_impact(entry, now)
				entry.nextAttack = now + entry.definition.cooldown
				self:_state(entry, "Recover", now + 0.6)
			end
			continue
		end
		if entry.state == "Recover" and now < entry.untilTime then continue end
		local _, _, root = self:_player(entry.target)
		if not root or position(root).X < FIELD_EDGE or (position(root) - entry.home).Magnitude > entry.definition.leash then
			entry.target = self:_nearest(entry)
			_, _, root = self:_player(entry.target)
		end
		if entry.target and root then
			local distance = (position(root) - current).Magnitude
			if distance <= entry.definition.attackRange and now >= entry.nextAttack then
				self:_state(entry, "Windup", now + entry.definition.windup)
			else
				self:_state(entry, "Chase")
				self:_move(entry, position(root), dt, now)
				if entry.stuckSince and now - entry.stuckSince >= 4 then entry.target = nil; self:_state(entry, "Return") end
			end
		else
			if (current - entry.home).Magnitude > 8 then self:_state(entry, "Return")
			elseif now >= entry.untilTime then
				self:_state(entry, "Patrol")
				local phase = now * 0.22 + entry.home.X
				self:_move(entry, entry.home + Vector3.new(math.sin(phase) * 4, 0, math.cos(phase) * 4), dt, now)
			end
		end
	end
end

function EnemyService:removePlayer(player)
	for _, entry in self.entries do
		entry.contributors[player] = nil
		if entry.target == player then entry.target = nil; self:_state(entry, "Return") end
	end
end

function EnemyService:destroy()
	if self.destroyed then return end
	self.destroyed = true
	if self.connection then self.connection:Disconnect() end
	for id in self.entries do self.combat:unregisterTarget(id) end
	table.clear(self.entries)
	self.world:Destroy()
end

return EnemyService
