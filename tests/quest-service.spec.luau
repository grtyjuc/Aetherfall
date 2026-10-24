-- Actual QuestService and quest rules; networking, prompt signals and time are mocked.
-- Character instances use Lune's data model. This does not run Studio networking.
local fs = require("@lune/fs")
local roblox = require("@lune/roblox")
local Progression = require("../src/shared/ProgressionRules")
local QuestRules = require("../src/shared/QuestRules")

local function signal()
	local event = { listeners = {} }
	function event:Connect(callback)
		local connection = { Connected = true }
		function connection:Disconnect() self.Connected = false end
		table.insert(self.listeners, { callback = callback, connection = connection })
		return connection
	end
	function event:Fire(...)
		for _, record in self.listeners do
			if record.connection.Connected then record.callback(...) end
		end
	end
	return event
end

local function fixture()
	local f = { now = 10, changed = 0, canPlay = true, profiles = {}, prompts = {}, npcModels = {} }
	local storage = {}
	function storage:WaitForChild(name) assert(name == "Shared"); return { QuestRules = QuestRules } end
	f.remotes = { Parent = storage }
	local function newRemote()
		local object = { OnServerEvent = signal(), messages = {} }
		function object:FireClient(player, payload) table.insert(self.messages, { player = player, payload = payload }) end
		function object:IsDescendantOf(parent) return self.Parent and self.Parent.Parent == parent end
		function object:Destroy() self.destroyed = true end
		return object
	end
	local game = {}
	function game:GetService(name) assert(name == "ReplicatedStorage"); return storage end
	local environment = setmetatable({
		game = game, require = function(module) return module end,
		Instance = { new = function(name) assert(name == "RemoteEvent"); return newRemote() end },
	}, { __index = getfenv() })
	local factory = assert(loadstring(fs.readFile("src/server/QuestService.luau"), "QuestService"))
	setfenv(factory, environment)
	local Service = factory()
	for id, position in { Rowan = roblox.Vector3.new(0, 3, -65), Blacksmith = roblox.Vector3.new(-22, 3, -60) } do
		local body = roblox.Instance.new("Part")
		body.CFrame, body.Position = roblox.CFrame.new(position), position
		local prompt = { Triggered = signal() }
		function prompt:IsA(name) return name == "ProximityPrompt" end
		local npc = { PrimaryPart = body }
		function npc:IsA(name) return name == "Model" end
		function npc:FindFirstChild(name) assert(name == "Talk" .. id); return prompt end
		f.npcModels[id], f.prompts[id] = npc, prompt
	end
	local npcs = {}
	function npcs:FindFirstChild(id) return f.npcModels[id] end
	local village = {}
	function village:FindFirstChild(name) assert(name == "NPCs"); return npcs end
	f.service = Service.new(f.profiles, f.remotes, village, {
		now = function() return f.now end,
		canAct = function() return f.canPlay end,
		onChanged = function() f.changed += 1 end,
	})
	function f:add(id, profile)
		local player = { UserId = id }
		local character = roblox.Instance.new("Model")
		local humanoid = roblox.Instance.new("Humanoid")
		humanoid.MaxHealth, humanoid.Health = 100, 100
		humanoid.Parent = character
		local root = roblox.Instance.new("Part")
		root.Name = "HumanoidRootPart"
		root.Parent = character
		player.Character, player.humanoid, player.root = character, humanoid, root
		self.profiles[player] = profile or Progression.newProfile("Sentinel")
		self.service:addPlayer(player)
		return player
	end
	function f:last()
		return self.service.state.messages[#self.service.state.messages].payload
	end
	function f:talk(player, id)
		self.now += 1
		local position = self.npcModels[id].PrimaryPart.Position + roblox.Vector3.new(0, 0, 2)
		player.root.CFrame, player.root.Position = roblox.CFrame.new(position), position
		self.prompts[id].Triggered:Fire(player)
	end
	function f:completeIntroduction(player)
		self:talk(player, "Rowan")
		self:talk(player, "Blacksmith")
		self:talk(player, "Rowan")
	end
	return f
end

local passed = 0
local function test(name, callback)
	local ok, reason = pcall(callback)
	if not ok then error("FAIL " .. name .. ": " .. tostring(reason), 0) end
	passed += 1
	print("PASS " .. name)
end

test("new players receive a default quest objective without rewards", function()
	local f = fixture(); local player = f:add(1)
	assert(f.profiles[player].quests.strangerStage == 0)
	assert(f:last().canPlay and f:last().strangerStage == 0)
	assert(f:last().objective:find("Elder Rowan", 1, true))
	assert(f.changed == 0 and f.profiles[player].gold == 0)
	f.service:destroy()
end)

test("validated NPC sequence completes the introduction and delivers dialogue", function()
	local f = fixture(); local player = f:add(1)
	f:talk(player, "Blacksmith")
	assert(f.profiles[player].quests.strangerStage == 0 and f.changed == 0)
	f:talk(player, "Rowan")
	assert(f:last().strangerStage == 1 and f:last().dialogue.speaker == "Elder Rowan")
	f:talk(player, "Blacksmith")
	assert(f:last().strangerStage == 2 and f:last().dialogue.speaker == "Smith Tessa")
	f:talk(player, "Rowan")
	assert(f:last().strangerDone and f.profiles[player].claimedRewards.quest_stranger)
	assert(f.profiles[player].gold == 20 and f.profiles[player].level == 2)
	assert(f.changed == 3 and QuestRules.validateProfile(f.profiles[player]))
	f.service:destroy()
end)

test("replayed introductions never repeat the reward", function()
	local f = fixture(); local player = f:add(1)
	f:completeIntroduction(player)
	local profile = f.profiles[player]
	local nextId, gold, level, xp = profile.nextId, profile.gold, profile.level, profile.xp
	for _ = 1, 4 do f:talk(player, "Blacksmith"); f:talk(player, "Rowan") end
	assert(profile.gold == gold and profile.level == level and profile.xp == xp and profile.nextId == nextId)
	assert(profile.quests.strangerStage == 3)
	f.service:destroy()
end)

test("field defeats count only after accepting the quest and only for supported enemies", function()
	local f = fixture(); local player = f:add(1)
	f.service:recordDefeat(player, "MeadowSlime")
	assert(f.profiles[player].quests.fieldsKills == 0)
	f:completeIntroduction(player)
	f.service:recordDefeat(player, "WildBoar")
	assert(f.profiles[player].quests.fieldsKills == 0)
	f:talk(player, "Rowan")
	local changed = f.changed
	for _, kind in { "TrainingDummy", "Unknown", "", 4, {} } do f.service:recordDefeat(player, kind) end
	assert(f.changed == changed and f.profiles[player].quests.fieldsKills == 0)
	for _, kind in { "MeadowSlime", "WildBoar", "Thornling", "MeadowSlime", "WildBoar" } do
		f.service:recordDefeat(player, kind)
	end
	assert(f.profiles[player].quests.fieldsKills == 4 and f.changed == changed + 4)
	assert(not f.profiles[player].claimedRewards.quest_fields)
	f.service:destroy()
end)

test("field turn-in rewards once and leaves both quests completed", function()
	local f = fixture(); local player = f:add(1)
	f:completeIntroduction(player); f:talk(player, "Rowan")
	for _ = 1, 4 do f.service:recordDefeat(player, "Thornling") end
	f:talk(player, "Rowan")
	local profile = f.profiles[player]
	assert(profile.gold == 80 and f:last().fieldsDone and f:last().strangerDone)
	local nextId, gold, xp, changed = profile.nextId, profile.gold, profile.xp, f.changed
	for _ = 1, 5 do f.service:recordDefeat(player, "WildBoar"); f:talk(player, "Rowan") end
	assert(profile.gold == gold and profile.xp == xp and profile.nextId == nextId and f.changed == changed)
	assert(QuestRules.validateProfile(profile))
	f.service:destroy()
end)

test("remote clients can synchronize but cannot accept, progress or claim quests", function()
	local f = fixture(); local player = f:add(1)
	for _, args in { { "Accept" }, { "Claim", "quest_stranger" }, { "Defeat", "WildBoar" }, { "Sync", "Rowan" } } do
		f.service.request.OnServerEvent:Fire(player, table.unpack(args))
	end
	assert(f.profiles[player].quests.strangerStage == 0 and f.profiles[player].gold == 0)
	f.now += 5
	local sent = #f.service.state.messages
	f.service.request.OnServerEvent:Fire(player, "Sync")
	assert(#f.service.state.messages == sent + 1)
	f.service:destroy()
end)

test("Sync rejects malformed arguments and limits request bursts per player", function()
	local f = fixture(); local player = f:add(1)
	local sent = #f.service.state.messages
	for _, value in { {}, 3, false, string.rep("x", 500) } do
		f.service.request.OnServerEvent:Fire(player, value)
	end
	assert(#f.service.state.messages == sent)
	f.now += 4
	for _ = 1, 10 do f.service.request.OnServerEvent:Fire(player, "Sync") end
	assert(#f.service.state.messages == sent + 4)
	assert(f.changed == 0)
	f.service:destroy()
end)

test("prompt events still enforce server-observed distance", function()
	local f = fixture(); local player = f:add(1)
	player.root.CFrame, player.root.Position = roblox.CFrame.new(100, 3, 100), roblox.Vector3.new(100, 3, 100)
	f.prompts.Rowan.Triggered:Fire(player)
	assert(f.changed == 0 and f.profiles[player].quests.strangerStage == 0)
	f.service:destroy()
end)

test("dead or missing characters cannot trigger quest transitions", function()
	local f = fixture(); local player = f:add(1)
	player.humanoid.Health = 0
	f:talk(player, "Rowan")
	assert(f.changed == 0)
	player.Character = nil
	f.prompts.Rowan.Triggered:Fire(player)
	assert(f.profiles[player].quests.strangerStage == 0)
	f.service:destroy()
end)

test("quest conversations share a one-second per-player cooldown", function()
	local f = fixture(); local player = f:add(1)
	f:talk(player, "Rowan")
	assert(f.profiles[player].quests.strangerStage == 1)
	local position = f.npcModels.Blacksmith.PrimaryPart.Position
	player.root.CFrame, player.root.Position = roblox.CFrame.new(position), position
	f.prompts.Blacksmith.Triggered:Fire(player)
	assert(f.profiles[player].quests.strangerStage == 1)
	f.now += 1
	f.prompts.Blacksmith.Triggered:Fire(player)
	assert(f.profiles[player].quests.strangerStage == 2)
	f.service:destroy()
end)

test("missing profiles transmit loading state without granting rewards", function()
	local f = fixture(); local player = { UserId = 1 }
	f.service:addPlayer(player)
	assert(not f:last().canPlay and f:last().objective:find("Loading", 1, true))
	f.prompts.Rowan.Triggered:Fire(player)
	assert(f.changed == 0 and f.profiles[player] == nil)
	f.service:destroy()
end)

test("lost save authority freezes NPC and defeat progress", function()
	local f = fixture(); local player = f:add(1)
	f.canPlay = false
	f:talk(player, "Rowan")
	assert(f.changed == 0 and f.profiles[player].quests.strangerStage == 0)
	f.canPlay = true
	f:completeIntroduction(player); f:talk(player, "Rowan")
	f.canPlay = false
	f.service:recordDefeat(player, "MeadowSlime")
	f.service:changed(player)
	assert(f.profiles[player].quests.fieldsKills == 0 and not f:last().canPlay)
	f.service:destroy()
end)

test("saved quest state resumes without regranting introduction rewards", function()
	local f = fixture(); local player = f:add(1)
	f:completeIntroduction(player); f:talk(player, "Rowan")
	f.service:recordDefeat(player, "WildBoar")
	local profile = f.profiles[player]
	f.service:removePlayer(player)
	local rejoined = f:add(2, profile)
	assert(f:last().strangerDone and f:last().fieldsAccepted and f:last().fieldsKills == 1)
	f:talk(rejoined, "Rowan")
	assert(profile.gold == 20 and profile.quests.fieldsKills == 1)
	f.service:destroy()
end)

test("each player's quest transitions and network state are isolated", function()
	local f = fixture(); local first, second = f:add(1), f:add(2)
	f:completeIntroduction(first)
	assert(f.profiles[first].gold == 20 and f.profiles[second].gold == 0)
	assert(f.profiles[second].quests.strangerStage == 0)
	local last = f.service.state.messages[#f.service.state.messages]
	assert(last.player == first and last.payload.strangerDone)
	f.service:destroy()
end)

test("removed players and destroyed services cannot mutate quest state", function()
	local f = fixture(); local player = f:add(1)
	f.service:removePlayer(player)
	f:talk(player, "Rowan")
	f.service.request.OnServerEvent:Fire(player, "Sync")
	assert(f.changed == 0)
	f.service:destroy()
	for _, connection in f.service.connections do assert(not connection.Connected) end
	assert(f.service.state.destroyed and f.service.request.destroyed)
	f.service:addPlayer(player)
	f:talk(player, "Rowan")
	assert(f.profiles[player].quests.strangerStage == 0)
	f.service:destroy()
end)

print(passed .. " QuestService tests passed with mocked network and prompt signals.")
