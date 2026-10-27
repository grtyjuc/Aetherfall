-- Server-owned Briarwarden encounter. Clients receive presentation state only.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Progression = require(ReplicatedStorage:WaitForChild("Shared").ProgressionRules)
local BossService = {}
BossService.__index = BossService
local ID = "boss_briarwarden"
local function finite(value)
	return type(value) == "number" and value == value and math.abs(value) < math.huge
end
local function finiteVector(value)
	return typeof(value) == "Vector3" and finite(value.X) and finite(value.Y) and finite(value.Z)
end
local function position(part) return part.CFrame.Position end
local function flat(vector) return Vector3.new(vector.X, 0, vector.Z) end
local function moveModel(model, destination)
	local previous = model.PrimaryPart.CFrame
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then part.CFrame = destination * previous:ToObjectSpace(part.CFrame) end
	end
end
local function buildModel(home)
	local model = Instance.new("Model")
	model.Name = "Briarwarden"
	local wood, dark, leaves = Color3.fromRGB(111, 77, 43), Color3.fromRGB(68, 49, 32), Color3.fromRGB(95, 143, 76)
	local function part(name, size, offset, tint, shape, material, rotation)
		local object = Instance.new("Part")
		object.Name, object.Size = name, size
		object.CFrame = CFrame.new(home + offset) * (rotation or CFrame.identity)
		object.Color, object.Shape = tint, shape or Enum.PartType.Block
		object.Material = material or Enum.Material.Wood
		object.Anchored, object.CanCollide, object.CanTouch = true, false, false
		object.CanQuery = name == "Hitbox"
		object.TopSurface, object.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
		object.Parent = model
		return object
	end
	local body = part("Hitbox", Vector3.new(5.5, 7.4, 4.5), Vector3.zero, wood)
	model.PrimaryPart = body
	part("AncientCrown", Vector3.new(4.6, 3.1, 4.1), Vector3.new(0, 4.8, 0), dark, Enum.PartType.Ball)
	part("LivingCore", Vector3.new(1.8, 2.3, 0.35), Vector3.new(0, 0.9, -2.35), Color3.fromRGB(173, 213, 126), Enum.PartType.Ball, Enum.Material.Neon)
	for _, side in { -1, 1 } do
		part("BranchArm", Vector3.new(2, 5.3, 1.8), Vector3.new(side * 4.0, 0.6, 0), wood, nil, nil, CFrame.Angles(0, 0, side * 0.65))
		part("BranchFingers", Vector3.new(2.7, 0.8, 2.5), Vector3.new(side * 5.6, -1.1, -0.2), dark)
		part("RootFoot", Vector3.new(3.6, 1.2, 4.3), Vector3.new(side * 2.0, -3.4, -0.3), dark, nil, nil, CFrame.Angles(0, side * 0.25, 0))
		part("LeafCrown", Vector3.new(5.0, 2.3, 4.1), Vector3.new(side * 2.5, 6.6, 0.5), leaves, Enum.PartType.Ball, Enum.Material.Grass)
		part("Eye", Vector3.new(0.4, 0.55, 0.25), Vector3.new(side * 1.1, 5, -1.9), Color3.fromRGB(230, 215, 141), Enum.PartType.Ball, Enum.Material.Neon)
	end
	local billboard = Instance.new("BillboardGui")
	billboard.Name, billboard.Adornee = "BossBillboard", body
	billboard.Size, billboard.StudsOffset, billboard.MaxDistance = UDim2.fromOffset(260, 64), Vector3.new(0, 10, 0), 150
	billboard.Parent = body
	for index, name in { "BossName", "HealthText" } do
		local label = Instance.new("TextLabel")
		label.Name, label.Text = name, if index == 1 then "BRIARWARDEN · DORMANT" else "650 / 650"
		label.Size, label.Position = UDim2.new(1, 0, 0.5, 0), UDim2.fromScale(0, (index - 1) / 2)
		label.BackgroundColor3, label.BackgroundTransparency = dark, 0.15
		label.TextColor3, label.TextSize, label.Font = Color3.fromRGB(244, 229, 184), 15, Enum.Font.GothamMedium
		label.Parent = billboard
	end
	return model
end

function BossService.new(profiles, combat, grove, options)
	options = options or {}
	local center, radius = grove:GetAttribute("ArenaCenter"), grove:GetAttribute("ArenaRadius")
	local entry = grove:GetAttribute("EntryPosition")
	assert(finiteVector(center) and finite(radius) and radius >= 24 and radius <= 40 and finiteVector(entry), "Valid grove arena required")
	local prompt = assert(grove:FindFirstChild("ChallengeBriarwarden", true), "Boss challenge prompt required")
	local parent = options.worldParent or workspace
	assert(not parent:FindFirstChild("AetherfallBoss"), "Boss world name already in use")
	local world = Instance.new("Folder")
	world.Name = "AetherfallBoss"
	local targets = Instance.new("Folder")
	targets.Name, targets.Parent = "Targets", world
	local home = center + Vector3.new(0, 4, 0)
	local model = buildModel(home)
	model:SetAttribute("TargetId", ID)
	model:SetAttribute("Enemy", true)
	model:SetAttribute("Boss", true)
	model:SetAttribute("SpawnHome", home)
	model:SetAttribute("LeashDistance", radius + 6)
	model:SetAttribute("Health", 650)
	model:SetAttribute("MaxHealth", 650)
	model:SetAttribute("Defence", 25)
	model:SetAttribute("AliveGeneration", 1)
	model:SetAttribute("DownUntil", 0)
	model.Parent, world.Parent = targets, parent
	local event = Instance.new("RemoteEvent")
	event.Name, event.Parent = "BossState", assert(options.remotes, "Boss remotes folder required")
	local marker = Instance.new("Part")
	marker.Name, marker.Size = "BossDangerMarker", Vector3.new(1, 0.12, 1)
	marker.Anchored, marker.CanCollide, marker.CanTouch, marker.CanQuery = true, false, false, false
	marker.Color, marker.Material, marker.Transparency = Color3.fromRGB(236, 169, 82), Enum.Material.Neon, 1
	marker.Parent = world
	local self = setmetatable({ profiles = profiles, combat = combat, grove = grove, options = options,
		center = center, radius = radius, home = home, entryPosition = entry, prompt = prompt,
		world = world, model = model, marker = marker, stateEvent = event,
		now = options.now or os.clock, physics = options.physics or workspace,
		participants = {}, joinedUsers = {}, audience = {}, contributors = {}, lastChallenge = {}, joined = 0, generation = 1,
		active = false, phase = "Dormant", warning = "Inspect the grove rune, then challenge the guardian.",
		untilTime = 0, nextChallenge = 0, attackCount = 0, elapsed = 0, destroyed = false,
	}, BossService)
	self:_phase("Dormant", self.warning, 0)
	combat:registerTarget(model)
	self.connection = prompt.Triggered:Connect(function(player) self:challenge(player) end)
	if options.autoStep ~= false then
		self.heartbeat = (options.heartbeat or RunService.Heartbeat):Connect(function(delta)
			self.elapsed += delta
			if self.elapsed >= 0.2 then
				local elapsed = math.min(self.elapsed, 0.5)
				self.elapsed = 0
				self:step(self.now(), elapsed)
			end
		end)
	end
	return self
end

function BossService:_player(player, allowDead)
	if not self.profiles[player] or (self.options.canAct and not self.options.canAct(player)) then return nil end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not humanoid or not root or not root:IsA("BasePart") or not finiteVector(position(root))
		or (not allowDead and humanoid.Health <= 0) then return nil end
	return character, humanoid, root
end
function BossService:_inside(root, allowance)
	return flat(position(root) - self.center).Magnitude <= self.radius + (allowance or 0)
		and math.abs(position(root).Y - self.center.Y) <= 18
end
function BossService:_phase(phase, warning, untilTime)
	self.phase, self.warning, self.untilTime = phase, warning, untilTime or 0
	self.model:SetAttribute("Phase", phase)
	self.model:SetAttribute("Warning", warning)
	self.model:SetAttribute("BossActive", self.active)
	self.model:SetAttribute("Defence", if phase == "Exposed" then 0 else 25)
	self.model.PrimaryPart.CanQuery = self.active and phase ~= "Defeated"
	local title = self.model:FindFirstChild("BossName", true)
	if title then title.Text = "BRIARWARDEN · " .. string.upper(phase) end
	local core = self.model:FindFirstChild("LivingCore")
	if core then core.Color = if phase == "Exposed" then Color3.fromRGB(235, 237, 155) else Color3.fromRGB(173, 213, 126) end
end
function BossService:_send(message)
	if not self.stateEvent:IsDescendantOf(ReplicatedStorage) then return end
	local hp, maximum = self.model:GetAttribute("Health"), self.model:GetAttribute("MaxHealth")
	local label = self.model:FindFirstChild("HealthText", true)
	if label then label.Text = string.format("%d / %d", math.ceil(hp), maximum) end
	for player in self.profiles do
		local _, _, root = self:_player(player, true)
		local nearby = root and flat(position(root) - self.center).Magnitude <= 75
		if self.participants[player] or nearby or self.audience[player] then
			self.stateEvent:FireClient(player, { active = self.active, health = hp, maxHealth = maximum,
				phase = self.phase, warning = self.warning, encounterId = self.generation, eligible = self.participants[player] == true and root ~= nil and self:_inside(root, 6),
				participants = self.joined, count = self.joined, message = message })
			self.audience[player] = if self.participants[player] or nearby then true else nil
		end
	end
end
function BossService:_sendTo(player, message)
	if not self.stateEvent:IsDescendantOf(ReplicatedStorage) then return end
	local _, _, root = self:_player(player, true)
	self.stateEvent:FireClient(player, { active = self.active,
		health = self.model:GetAttribute("Health"), maxHealth = self.model:GetAttribute("MaxHealth"),
		phase = self.phase, warning = self.warning, encounterId = self.generation,
		eligible = self.participants[player] == true and root ~= nil and self:_inside(root, 6),
		participants = self.joined, count = self.joined, message = message })
end
function BossService:canTarget(player, target)
	if self.destroyed or target ~= self.model or not self.active or self.phase == "Defeated"
		or self.model:GetAttribute("Health") <= 0 or not self.participants[player] then return false, "Join the grove challenge before attacking Briarwarden." end
	local _, _, root = self:_player(player)
	if not root or not self:_inside(root) then return false, "Return to the grove arena before attacking." end
	return true
end
function BossService:challenge(player)
	if self.destroyed then return false end
	local character, _, root = self:_player(player)
	if not root or not self.prompt.Parent or not self.prompt.Parent:IsA("BasePart")
		or (position(root) - position(self.prompt.Parent)).Magnitude > 10 then return false end
	local now = self.now()
	if not finite(now) or now - (self.lastChallenge[player] or -math.huge) < 1 then return false end
	self.lastChallenge[player] = now
	if self.phase == "Defeated" or now < self.nextChallenge then
		self:_sendTo(player, "The grove is recovering. Wait a moment before challenging again.")
		return false
	end
	if self.options.canChallenge then
		local allowed, reason = self.options.canChallenge(player)
		if allowed ~= true then
			self:_sendTo(player, if type(reason) == "string" then string.sub(reason, 1, 300)
				else "Reach level 3 and inspect the grove rune during Rowan's quest first.")
			return false
		end
	end
	if not self.participants[player] then
		local identity = player.UserId
		if not self.joinedUsers[identity] and self.joined >= 12 then
			self:_sendTo(player, "This encounter already has twelve adventurers. Wait for the next challenge.")
			return false
		end
		local previousMaximum = self.model:GetAttribute("MaxHealth")
		local ratio = self.model:GetAttribute("Health") / previousMaximum
		if not self.joinedUsers[identity] then
			self.joined += 1
			self.joinedUsers[identity] = true
		end
		self.participants[player] = true
		local maximum = math.floor(650 * (1 + 0.45 * (self.joined - 1)))
		self.model:SetAttribute("MaxHealth", maximum)
		self.model:SetAttribute("Health", maximum * ratio)
	end
	-- A late arrival must receive time to read a warning already in progress.
	-- The same character cannot renew this grace period by reusing the gate.
	if character:GetAttribute("AetherfallBossEntryEncounter") ~= self.generation then
		character:SetAttribute("AetherfallBossEntryEncounter", self.generation)
		local previous = character:GetAttribute("AetherfallSpawnProtectedUntil")
		character:SetAttribute("AetherfallSpawnProtectedUntil", math.max(if finite(previous) then previous else 0, now + 1.5))
	end
	local destination = CFrame.new(self.entryPosition) * (root.CFrame - root.CFrame.Position)
	character:PivotTo(destination)
	root.AssemblyLinearVelocity = Vector3.zero
	if not self.active then
		self.active, self.attackCount, self.wipeSince = true, 0, nil
		self:_phase("Ready", "Guardian awakened. Watch its branch and root warnings.", now + 1.5)
	end
	self:_send("Grove challenge joined.")
	return true
end
function BossService:_reset(now, message)
	self.active, self.joined, self.attackCount, self.wipeSince = false, 0, 0, nil
	table.clear(self.participants)
	table.clear(self.joinedUsers)
	table.clear(self.contributors)
	self.generation += 1
	self.model:SetAttribute("AliveGeneration", self.generation)
	self.model:SetAttribute("MaxHealth", 650)
	self.model:SetAttribute("Health", 650)
	self.model:SetAttribute("StunnedUntil", 0)
	self.marker.Transparency = 1
	moveModel(self.model, CFrame.new(self.home))
	self.nextChallenge = now + 5
	self:_phase("Dormant", "The grove is quiet. Challenge again when ready.", 0)
	self:_send(message)
end
function BossService:_lineOfSight(character, origin, destination)
	local delta = destination - origin
	if delta.Magnitude < 0.01 then return true end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { self.model, self.marker }
	local hit = self.physics:Raycast(origin, delta, params)
	return hit == nil or hit.Instance:IsDescendantOf(character)
end
function BossService:_aliveParticipants()
	local alive = {}
	for player in self.participants do
		local character, humanoid, root = self:_player(player)
		if root and self:_inside(root) then table.insert(alive, { player = player, character = character, humanoid = humanoid, root = root }) end
	end
	return alive
end
function BossService:_startAttack(now, participants)
	local nearest
	for _, participant in participants do
		local distance = flat(position(participant.root) - self.home).Magnitude
		if not nearest or distance < nearest.distance then nearest = { data = participant, distance = distance } end
	end
	if not nearest then return end
	if self.attackCount % 2 == 0 then
		local delta = flat(position(nearest.data.root) - self.home)
		if delta.Magnitude < 0.01 then delta = Vector3.new(0, 0, -1) end
		self.sweepDirection = delta.Unit
		moveModel(self.model, CFrame.lookAt(self.home, self.home + self.sweepDirection))
		self.marker.Shape = Enum.PartType.Block
		self.marker.Size = Vector3.new(22, 0.12, 11)
		self.marker.CFrame = CFrame.lookAt(self.center + self.sweepDirection * 5.5 + Vector3.new(0, 0.16, 0), self.center + self.sweepDirection * 6.5 + Vector3.new(0, 0.16, 0))
		self.marker.Transparency = 0.7
		self:_phase("SweepWindup", "BRANCH SWEEP: move behind the guardian or beyond 11 studs.", now + 1.2)
	else
		self.rootPosition = position(nearest.data.root)
		self.marker.Shape = Enum.PartType.Cylinder
		self.marker.Size = Vector3.new(0.12, 10, 10)
		self.marker.CFrame = CFrame.new(self.rootPosition.X, self.center.Y + 0.16, self.rootPosition.Z) * CFrame.Angles(0, 0, math.pi / 2)
		self.marker.Transparency = 0.55
		self:_phase("RootWindup", "ROOT BURST: leave the marked circle before the roots erupt.", now + 1.4)
	end
end
function BossService:_impact(now)
	for _, participant in self:_aliveParticipants() do
		local delta = flat(position(participant.root) - self.home)
		local inside = if self.phase == "SweepWindup"
			then delta.Magnitude <= 11 and (delta.Magnitude < 0.01 or delta.Unit:Dot(self.sweepDirection) >= 0)
			else flat(position(participant.root) - self.rootPosition).Magnitude <= 5
		if inside and (participant.character:GetAttribute("AetherfallSpawnProtectedUntil") or 0) <= now
			and self:_lineOfSight(participant.character, self.home, position(participant.root)) then
			local defence = math.max(0, Progression.stats(self.profiles[participant.player]).Defence)
			local damage = math.max(1, 16 * 100 / (100 + defence))
			local source = if self.phase == "SweepWindup" then self.home else self.rootPosition
			if self.options.applyDamage then self.options.applyDamage(participant.player, damage, source)
			else participant.humanoid:TakeDamage(damage) end
		end
	end
	self.marker.Transparency = 1
	self.attackCount += 1
	if self.attackCount % 2 == 0 then
		self:_phase("Exposed", "CORE EXPOSED: attack now. The guardian cannot strike for four seconds.", now + 4)
	else self:_phase("Recover", "The guardian is recovering. Prepare for its next warning.", now + 0.8) end
end
function BossService:onDamaged(player, target, damage, defeated)
	if target ~= self.model or not finite(damage) or damage <= 0 or not self:canTarget(player, target) then
		-- A lethal hit has already set Health=0; its contributor still needs validation.
		if target ~= self.model or not defeated or not self.active or not self.participants[player] then return end
		local _, _, root = self:_player(player)
		if not root or not self:_inside(root) or not finite(damage) or damage <= 0 then return end
	end
	self.contributors[player] = self.now()
	if not defeated or self.model:GetAttribute("Health") > 0 or self.phase == "Defeated" then return end
	local now = self.now()
	self.active = false
	self.marker.Transparency = 1
	self.model:SetAttribute("DownUntil", now + 20)
	self:_phase("Defeated", "Briarwarden has fallen. Return to Elder Rowan with the first shard.", now + 20)
	for contributor, lastHit in self.contributors do
		local _, _, root = self:_player(contributor, true)
		if root and self.participants[contributor] and self:_inside(root, 6) and now - lastHit <= 60
			and self.options.onDefeat then self.options.onDefeat(contributor) end
	end
	table.clear(self.contributors)
	self:_send("Briarwarden defeated.")
end
function BossService:step(now, dt)
	if self.destroyed or not finite(now) or not finite(dt) or dt <= 0 then return end
	if self.phase == "Defeated" then
		if now >= self.untilTime then self:_reset(now) end
		self:_send()
		return
	end
	if not self.active then self:_send(); return end
	local participants = self:_aliveParticipants()
	if #participants == 0 then
		self.wipeSince = self.wipeSince or now
		if now - self.wipeSince >= 3 then self:_reset(now, "The encounter reset. Rest, then challenge again.") end
		self:_send()
		return
	end
	self.wipeSince = nil
	if now >= self.untilTime then
		if self.phase == "SweepWindup" or self.phase == "RootWindup" then self:_impact(now)
		else self:_startAttack(now, participants) end
	end
	self:_send()
end
function BossService:removePlayer(player)
	self.participants[player], self.contributors[player], self.lastChallenge[player], self.audience[player] = nil, nil, nil, nil
end
function BossService:destroy()
	if self.destroyed then return end
	self.destroyed = true
	self.connection:Disconnect()
	if self.heartbeat then self.heartbeat:Disconnect() end
	self.combat:unregisterTarget(ID)
	self.stateEvent:Destroy()
	self.world:Destroy()
	table.clear(self.participants)
	table.clear(self.contributors)
end
return BossService
