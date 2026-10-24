-- Quest progress is driven by validated NPC prompts and server-confirmed defeats.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local QuestRules = require(ReplicatedStorage:WaitForChild("Shared").QuestRules)

local QuestService = {}
QuestService.__index = QuestService
local npcDefinitions = {
	Rowan = { prompt = "TalkRowan", speaker = "Elder Rowan" },
	Blacksmith = { prompt = "TalkBlacksmith", speaker = "Smith Tessa" },
}

local function finite(value)
	return type(value) == "number" and value == value and math.abs(value) < math.huge
end

local function remote(parent, name)
	local event = Instance.new("RemoteEvent")
	event.Name = name
	event.Parent = parent
	return event
end

function QuestService.new(profiles, remotes, villageWorld, options)
	options = options or {}
	local self = setmetatable({
		profiles = profiles, options = options, players = {}, npcs = {}, connections = {},
		now = options.now or os.clock, destroyed = false,
	}, QuestService)
	self.state = remote(remotes, "QuestState")
	self.request = remote(remotes, "QuestRequest")
	local npcs = assert(villageWorld:FindFirstChild("NPCs"), "Village NPC folder required")
	for id, definition in npcDefinitions do
		local npc = assert(npcs:FindFirstChild(id), "Missing quest NPC: " .. id)
		assert(npc:IsA("Model") and npc.PrimaryPart, "Quest NPC requires a model and PrimaryPart")
		local prompt = assert(npc:FindFirstChild(definition.prompt, true), "Missing quest prompt: " .. id)
		assert(prompt:IsA("ProximityPrompt"), "Quest interaction must be a ProximityPrompt")
		self.npcs[id] = npc
		table.insert(self.connections, prompt.Triggered:Connect(function(player)
			self:_interact(player, id)
		end))
	end
	table.insert(self.connections, self.request.OnServerEvent:Connect(function(player, action, ...)
		local entry = self.players[player]
		if self.destroyed or not entry then return end
		local now = self.now()
		if not finite(now) then return end
		entry.tokens = math.min(4, entry.tokens + math.max(0, now - entry.tokenTime))
		entry.tokenTime = now
		if entry.tokens < 1 then return end
		entry.tokens -= 1
		if action ~= "Sync" or select("#", ...) ~= 0 then return end
		self:changed(player)
	end))
	return self
end

function QuestService:_canAct(player)
	return not self.options.canAct or self.options.canAct(player) == true
end

function QuestService:addPlayer(player)
	if self.destroyed or self.players[player] then return end
	self.players[player] = { tokens = 4, tokenTime = self.now(), lastTalk = -math.huge }
	local profile = self.profiles[player]
	if profile then QuestRules.ensure(profile) end
	self:changed(player)
end

function QuestService:removePlayer(player)
	self.players[player] = nil
end

function QuestService:changed(player, message, dialogue)
	if self.destroyed or not self.players[player] then return end
	if not self.state:IsDescendantOf(ReplicatedStorage) then return end
	local profile = self.profiles[player]
	local payload = QuestRules.snapshot(profile)
	payload.canPlay = profile ~= nil and self:_canAct(player)
	if not profile then payload.objective = "Loading your character and quest progress…" end
	if not payload.canPlay and profile then payload.objective = "Quest actions paused while player data is unavailable." end
	payload.message = message
	payload.dialogue = dialogue
	self.state:FireClient(player, payload)
end

function QuestService:_interact(player, npcId)
	local entry, profile, npc = self.players[player], self.profiles[player], self.npcs[npcId]
	if self.destroyed or not entry or not profile or not npc or not self:_canAct(player) then return end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local body = npc.PrimaryPart
	if not humanoid or humanoid.Health <= 0 or not root or not root:IsA("BasePart") or not body then return end
	local distance = (root.Position - body.Position).Magnitude
	if not finite(distance) or distance > 10 then return end
	local now = self.now()
	if not finite(now) or now - entry.lastTalk < 1 then return end
	entry.lastTalk = now
	local changed, message = QuestRules.interact(profile, npcId)
	if changed and self.options.onChanged then self.options.onChanged(player) end
	self:changed(player, message, { speaker = npcDefinitions[npcId].speaker, text = message })
end

function QuestService:recordDefeat(player, kind)
	if self.destroyed or not self.players[player] or not self.profiles[player] or not self:_canAct(player) then return end
	local changed, message = QuestRules.recordDefeat(self.profiles[player], kind)
	if not changed then return end
	if self.options.onChanged then self.options.onChanged(player) end
	self:changed(player, message)
end

function QuestService:destroy()
	if self.destroyed then return end
	self.destroyed = true
	for _, connection in self.connections do connection:Disconnect() end
	self.state:Destroy()
	self.request:Destroy()
	table.clear(self.players)
	table.clear(self.npcs)
end

return QuestService
