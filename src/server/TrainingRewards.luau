-- Server-owned training milestones. Clients can request state, never rewards.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Progression = require(ReplicatedStorage:WaitForChild("Shared").ProgressionRules)
local TrainingRewards = {}
TrainingRewards.__index = TrainingRewards

local BASIC = "curriculum_basic"
local SKILL = "curriculum_skill"
local FINAL = "curriculum_final"
local finalItems = { Sentinel = "iron_longsword", Spellweaver = "apprentice_staff", Ranger = "hunting_knife" }

function TrainingRewards.buildWorld()
	local existing = workspace:FindFirstChild("AetherfallTrainingRewards")
	if existing then
		assert(existing:IsA("Model") and existing:GetAttribute("TrainingRewardsOwned") == true,
			"Training rewards world name is already in use")
		local prompt = existing:FindFirstChild("TalkToMira", true)
		assert(prompt and prompt:IsA("ProximityPrompt"), "Missing training mentor prompt")
		return existing, prompt
	end
	local world = Instance.new("Model")
	world.Name = "AetherfallTrainingRewards"
	world:SetAttribute("TrainingRewardsOwned", true)
	local npc = Instance.new("Model")
	npc.Name = "WardenMira"
	npc.Parent = world
	local origin = Vector3.new(-21, 0, 16)
	local cloth = Color3.fromRGB(65, 103, 119)
	local leather = Color3.fromRGB(97, 65, 45)
	local bronze = Color3.fromRGB(202, 160, 85)
	local skin = Color3.fromRGB(181, 131, 91)
	local function part(name, size, offset, color, material, rotate)
		local object = Instance.new("Part")
		object.Name = name
		object.Size = size
		object.CFrame = CFrame.new(origin + offset) * (rotate or CFrame.identity)
		object.Color = color
		object.Material = material or Enum.Material.Fabric
		object.Anchored = true
		object.CanCollide = false
		object.CanTouch = false
		object.CanQuery = false
		object.TopSurface = Enum.SurfaceType.Smooth
		object.BottomSurface = Enum.SurfaceType.Smooth
		object.Parent = npc
		return object
	end
	local body = part("Uniform", Vector3.new(1.7, 1.9, 0.9), Vector3.new(0, 3, 0), cloth)
	npc.PrimaryPart = body
	world.PrimaryPart = body
	local head = part("Head", Vector3.new(1.05, 1.05, 1.05), Vector3.new(0, 4.5, 0), skin, Enum.Material.SmoothPlastic)
	head.Shape = Enum.PartType.Ball
	part("Hair", Vector3.new(1.1, 0.35, 1.1), Vector3.new(0, 4.91, 0.03), leather)
	part("Cape", Vector3.new(1.9, 2.3, 0.16), Vector3.new(0, 2.95, 0.56), cloth)
	part("Belt", Vector3.new(1.8, 0.22, 1), Vector3.new(0, 2.32, 0), leather)
	part("Buckle", Vector3.new(0.35, 0.3, 0.12), Vector3.new(0, 2.32, -0.55), bronze, Enum.Material.Metal)
	part("Medallion", Vector3.new(0.3, 0.4, 0.1), Vector3.new(0, 3.65, -0.5), bronze, Enum.Material.Metal)
	for _, side in { -1, 1 } do
		part("Sleeve", Vector3.new(0.65, 1.5, 0.7), Vector3.new(side * 1.12, 3.15, 0), cloth,
			nil, CFrame.Angles(0, 0, side * 0.12))
		part("Glove", Vector3.new(0.6, 0.65, 0.65), Vector3.new(side * 1.2, 2.25, 0), leather)
		part("Leg", Vector3.new(0.65, 1.4, 0.7), Vector3.new(side * 0.45, 1.55, 0), cloth)
		part("Boot", Vector3.new(0.8, 0.65, 1.05), Vector3.new(side * 0.45, 0.55, -0.15), leather)
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "TalkToMira"
	prompt.ActionText = "Talk"
	prompt.ObjectText = "Warden Mira"
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = body
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "MentorName"
	billboard.Adornee = body
	billboard.Size = UDim2.fromOffset(210, 60)
	billboard.StudsOffset = Vector3.new(0, 3.6, 0)
	billboard.MaxDistance = 75
	billboard.Parent = body
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundColor3 = Color3.fromRGB(24, 37, 44)
	label.BackgroundTransparency = 0.2
	label.Text = "WARDEN MIRA\nTraining mentor · Talk for rewards"
	label.TextColor3 = Color3.fromRGB(240, 222, 180)
	label.Font = Enum.Font.GothamMedium
	label.TextSize = 14
	label.Parent = billboard
	world.Parent = workspace
	return world, prompt
end

function TrainingRewards.new(profiles, remotes, options)
	options = options or {}
	local self = setmetatable({ profiles = profiles, options = options, players = {}, now = options.now or os.clock,
		destroyed = false }, TrainingRewards)
	self.state = Instance.new("RemoteEvent")
	self.state.Name = "ProgressionState"
	self.state.Parent = remotes
	self.request = Instance.new("RemoteEvent")
	self.request.Name = "ProgressionRequest"
	self.request.Parent = remotes
	self.world, self.prompt = (options.worldFactory or TrainingRewards.buildWorld)()
	self.requestConnection = self.request.OnServerEvent:Connect(function(player, action, ...)
		local entry = self.players[player]
		if self.destroyed or not entry then return end
		local now = self.now()
		entry.tokens = math.min(4, entry.tokens + math.max(0, now - entry.tokenTime))
		entry.tokenTime = now
		if entry.tokens < 1 then return end
		entry.tokens -= 1
		if action ~= "Sync" or select("#", ...) ~= 0 then return end
		self:changed(player)
	end)
	self.promptConnection = self.prompt.Triggered:Connect(function(player) self:_talk(player) end)
	return self
end

function TrainingRewards:addPlayer(player)
	if self.destroyed or self.players[player] then return end
	self.players[player] = { basicHits = 0, tokens = 4, tokenTime = self.now(), lastTalk = -math.huge }
	self:changed(player)
end

function TrainingRewards:removePlayer(player)
	self.players[player] = nil
end

function TrainingRewards:_canPlay(player)
	if not self.options.getSaveStatus then return true end
	local status = self.options.getSaveStatus(player)
	return status ~= nil and status.canPlay == true
end

function TrainingRewards:changed(player, message)
	if self.destroyed or not self.players[player] then return end
	-- Initial players can load before the remote folder is exposed.
	if not self.state:IsDescendantOf(ReplicatedStorage) then return end
	local loadedProfile, entry = self.profiles[player], self.players[player]
	local profile = loadedProfile or { level = 1, xp = 0, gold = 0, claimedRewards = {} }
	local status = if self.options.getSaveStatus then self.options.getSaveStatus(player)
		else { mode = "SessionOnly", message = "Progress is session-only.", canPlay = true }
	status = status or { mode = "Loading", message = "Loading player data…", canPlay = false }
	local claims = profile.claimedRewards
	local basicDone = claims[BASIC] == true
	self.state:FireClient(player, {
		level = profile.level, xp = profile.xp, requiredXp = Progression.requiredXp(profile.level), gold = profile.gold,
		basicHits = if basicDone then 3 else entry.basicHits, basicGoal = 3,
		basicDone = basicDone, skillDone = claims[SKILL] == true, finalDone = claims[FINAL] == true,
		saveMode = status.mode, saveMessage = status.message, canPlay = loadedProfile ~= nil and status.canPlay == true, message = message,
	})
end

function TrainingRewards:_grant(player, id, specification)
	local profile = self.profiles[player]
	local ok, message, summary = Progression.grantReward(profile, id, specification)
	if not ok then return false, message end
	if self.options.onChanged then self.options.onChanged(player) end
	local text = string.format("Training reward: +%d XP, +%d gold", summary.xp, summary.gold)
	if #summary.items > 0 then text ..= " · New equipment added" end
	self:changed(player, text)
	return true, text
end

function TrainingRewards:recordAction(player, action, result)
	local entry, profile = self.players[player], self.profiles[player]
	if self.destroyed or not entry or not profile or not self:_canPlay(player) or type(result) ~= "table" then return end
	if action == "Basic" and (result.kind == "Melee" or result.kind == "Projectile") then
		if profile.claimedRewards[BASIC] then return end
		entry.basicHits = math.min(3, entry.basicHits + 1)
		if entry.basicHits == 3 then
			self:_grant(player, BASIC, { xp = 100, gold = 10, items = {} })
		else self:changed(player) end
	elseif action == "Skill" and (result.kind == "Melee" or result.kind == "Area" or result.kind == "Dash") then
		if not profile.claimedRewards[SKILL] then
			self:_grant(player, SKILL, { xp = 150, gold = 20, items = {} })
		end
	end
end

function TrainingRewards:_talk(player)
	local entry, profile = self.players[player], self.profiles[player]
	if self.destroyed or not entry or not profile or not self:_canPlay(player) then return end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not humanoid or not (humanoid.Health > 0) or not root or not root:IsA("BasePart") then return end
	if not self.world.PrimaryPart then return end
	local distance = (root.Position - self.world.PrimaryPart.Position).Magnitude
	if distance ~= distance or distance > 10 then return end
	local now = self.now()
	if now - entry.lastTalk < 1 then return end
	entry.lastTalk = now
	local claims = profile.claimedRewards
	if claims[FINAL] then self:changed(player, "Mira: Your training is complete. Keep practising!")
	elseif claims[BASIC] and claims[SKILL] then
		self:_grant(player, FINAL, { xp = 250, gold = 60, items = { finalItems[profile.className] } })
	else
		self:changed(player, "Mira: Land three basic attacks and use your class skill, then return to me.")
	end
end

function TrainingRewards:destroy()
	if self.destroyed then return end
	self.destroyed = true
	self.requestConnection:Disconnect()
	self.promptConnection:Disconnect()
	self.state:Destroy()
	self.request:Destroy()
	table.clear(self.players)
end

return TrainingRewards
