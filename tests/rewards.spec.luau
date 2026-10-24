-- Real training reward service/rules; network, proximity signals and time are mocked.
-- NPC construction uses Lune's data model, not live Studio rendering/physics.
local fs = require("@lune/fs")
local roblox = require("@lune/roblox")
local Progression = require("../src/shared/ProgressionRules")
local Catalog = require("../src/shared/EquipmentCatalog")
local function signal()
	local object = { listeners = {} }
	function object:Connect(callback)
		local connection = { Connected = true }
		function connection:Disconnect() self.Connected = false end
		table.insert(self.listeners, { callback = callback, connection = connection })
		return connection
	end
	function object:Fire(...)
		for _, record in self.listeners do
			if record.connection.Connected then record.callback(...) end
		end
	end
	return object
end
local function fixture(realWorld)
	local f = { now = 0, changed = 0, canPlay = true, mode = "SessionOnly" }
	local storage = {}
	function storage:WaitForChild(name) assert(name == "Shared"); return { ProgressionRules = Progression } end
	local services = { ReplicatedStorage = storage }
	local game = {}
	function game:GetService(name) return assert(services[name]) end
	f.workspace = roblox.Instance.new("Workspace")
	f.remotes = { Parent = storage }
	local function remote()
		local object = { OnServerEvent = signal(), messages = {} }
		function object:FireClient(player, payload) table.insert(self.messages, { player = player, payload = payload }) end
		function object:IsDescendantOf(parent) return self.Parent.Parent == parent end
		function object:Destroy() self.destroyed = true end
		return object
	end
	local environment = setmetatable({
		game = game, workspace = f.workspace,
		Instance = { new = function(className) return if className == "RemoteEvent" then remote() else roblox.Instance.new(className) end },
		Vector3 = roblox.Vector3, CFrame = roblox.CFrame, Color3 = roblox.Color3, UDim2 = roblox.UDim2, Enum = roblox.Enum,
		require = function(module) return module end,
	}, { __index = getfenv() })
	local factory = assert(loadstring(fs.readFile("src/server/TrainingRewards.luau"), "TrainingRewards"))
	setfenv(factory, environment)
	f.module = factory()
	if realWorld then return f end
	f.world = roblox.Instance.new("Model")
	local body = roblox.Instance.new("Part")
	body.Position = roblox.Vector3.new(0, 3, 0)
	body.CFrame = roblox.CFrame.new(0, 3, 0)
	body.Parent = f.world
	f.world.PrimaryPart = body
	f.prompt = { Triggered = signal() }
	f.profiles = {}
	f.service = f.module.new(f.profiles, f.remotes, {
		worldFactory = function() return f.world, f.prompt end,
		now = function() return f.now end,
		onChanged = function() f.changed += 1 end,
		getSaveStatus = function() return { mode = f.mode, message = "Test save status", canPlay = f.canPlay } end,
	})
	function f:add(id, className, saved)
		local player = { UserId = id }
		local character = roblox.Instance.new("Model")
		local humanoid = roblox.Instance.new("Humanoid")
		humanoid.Health = 100
		humanoid.MaxHealth = 100
		humanoid.Parent = character
		local root = roblox.Instance.new("Part")
		root.Name = "HumanoidRootPart"
		root.CFrame = roblox.CFrame.new(0, 3, 2)
		root.Position = roblox.Vector3.new(0, 3, 2)
		root.Parent = character
		player.Character, player.humanoid, player.root = character, humanoid, root
		self.profiles[player] = saved or Progression.newProfile(className or "Sentinel")
		self.service:addPlayer(player)
		return player
	end
	function f:last()
		return self.service.state.messages[#self.service.state.messages].payload
	end
	function f:action(player, action, kind)
		self.service:recordAction(player, action, { kind = kind })
	end
	function f:complete(player)
		for _ = 1, 3 do self:action(player, "Basic", "Melee") end
		self:action(player, "Skill", "Dash")
	end
	return f
end
local passed = 0
local function test(name, callback)
	local ok, problem = pcall(callback)
	if not ok then error("FAIL " .. name .. ": " .. tostring(problem), 0) end
	passed += 1
	print("PASS " .. name)
end
local function inventoryCount(profile)
	local count = 0
	for _ in profile.inventory do count += 1 end
	return count
end
local function owns(profile, id)
	for _, item in profile.inventory do if item.itemId == id then return true end end
	return false
end

test("three accepted basic actions grant once; damaged target count is not a reward input", function()
	local f = fixture(); local player = f:add(1)
	f:action(player, "Basic", "Projectile")
	f:action(player, "Basic", "Melee")
	assert(f:last().basicHits == 2 and f.profiles[player].gold == 0)
	f:action(player, "Basic", "Melee")
	assert(f.profiles[player].gold == 10 and f.profiles[player].level == 2)
	for _ = 1, 10 do f:action(player, "Basic", "Melee") end
	assert(f.profiles[player].gold == 10 and f.changed == 1 and f:last().basicDone)
	f.service:destroy()
end)

test("each class skill kind qualifies once including targetless Quickstep", function()
	for _, kind in { "Melee", "Area", "Dash" } do
		local f = fixture(); local player = f:add(1)
		f:action(player, "Skill", kind)
		f:action(player, "Skill", kind)
		assert(f.profiles[player].gold == 20 and f.changed == 1)
		assert(f:last().skillDone and not f:last().basicDone)
		f.service:destroy()
	end
end)

test("unsupported action/result shapes do not advance training", function()
	local f = fixture(); local player = f:add(1)
	for _, args in { { "Damage", "Melee" }, { "Basic", "Area" }, { "Basic", "Dash" }, { "Skill", "Projectile" }, { {}, "Melee" } } do
		f:action(player, args[1], args[2])
	end
	f.service:recordAction(player, "Basic", 500)
	assert(f:last().basicHits == 0 and f.profiles[player].gold == 0 and f.changed == 0)
	f.service:destroy()
end)

test("early mentor talk guides the player without granting rewards", function()
	local f = fixture(); local player = f:add(1)
	f.prompt.Triggered:Fire(player)
	assert(f.changed == 0 and f.profiles[player].gold == 0)
	assert(string.find(f:last().message, "Land three basic attacks", 1, true))
	f.service:destroy()
end)

test("mentor grants class-specific final gear once and preserves earned profile progression", function()
	local expected = { Sentinel = "iron_longsword", Spellweaver = "apprentice_staff", Ranger = "hunting_knife" }
	for className, itemId in expected do
		local f = fixture(); local player = f:add(1, className)
		local initial = inventoryCount(f.profiles[player])
		f:complete(player)
		f.prompt.Triggered:Fire(player)
		local profile = f.profiles[player]
		assert(profile.gold == 90 and profile.level == 3 and profile.xp == 127)
		assert(profile.claimedRewards.curriculum_final and owns(profile, itemId))
		assert(inventoryCount(profile) == initial + 1 and f.changed == 3)
		f.now += 1
		f.prompt.Triggered:Fire(player)
		assert(profile.gold == 90 and inventoryCount(profile) == initial + 1 and f.changed == 3)
		assert(f:last().finalDone)
		f.service:destroy()
	end
end)

test("prompt triggers still validate server distance and living character", function()
	local f = fixture(); local player = f:add(1)
	f:complete(player)
	player.root.Position = roblox.Vector3.new(50, 3, 0)
	f.prompt.Triggered:Fire(player)
	assert(not f.profiles[player].claimedRewards.curriculum_final)
	player.root.Position = roblox.Vector3.new(0, 3, 2)
	player.humanoid.Health = 0
	f.prompt.Triggered:Fire(player)
	assert(not f.profiles[player].claimedRewards.curriculum_final)
	player.humanoid.Health = 100
	f.prompt.Triggered:Fire(player)
	assert(f.profiles[player].claimedRewards.curriculum_final)
	f.service:destroy()
end)

test("mentor talk has a one-second per-player cooldown", function()
	local f = fixture(); local player = f:add(1)
	f.prompt.Triggered:Fire(player)
	f:complete(player)
	f.prompt.Triggered:Fire(player)
	assert(not f.profiles[player].claimedRewards.curriculum_final)
	f.now = 1
	f.prompt.Triggered:Fire(player)
	assert(f.profiles[player].claimedRewards.curriculum_final)
	f.service:destroy()
end)

test("loading players receive safe status before profile availability", function()
	local f = fixture(); local player = { UserId = 9 }
	f.mode = "Loading"; f.canPlay = false
	f.service:addPlayer(player)
	assert(f:last().level == 1 and f:last().gold == 0 and f:last().xp == 0)
	assert(not f:last().canPlay and f:last().saveMode == "Loading")
	f.service:recordAction(player, "Skill", { kind = "Dash" })
	assert(f.changed == 0 and f.profiles[player] == nil)
	f.service:destroy()
end)

test("save loading/loss blocks action rewards and final claims", function()
	local f = fixture(); local player = f:add(1)
	f.canPlay = false; f.mode = "Lost"
	f:complete(player)
	f.prompt.Triggered:Fire(player)
	assert(f.changed == 0 and f.profiles[player].gold == 0)
	f.service:changed(player)
	assert(f:last().canPlay == false and f:last().saveMode == "Lost")
	f.service:destroy()
end)

test("persisted claims survive rejoin while partial basic progress is session-only", function()
	local f = fixture(); local first = f:add(1)
	f:action(first, "Basic", "Melee")
	f:action(first, "Skill", "Dash")
	local profile = f.profiles[first]
	f.service:removePlayer(first)
	local rejoined = f:add(1, nil, profile)
	assert(f:last().basicHits == 0 and f:last().skillDone)
	f.service:removePlayer(rejoined)
	profile.claimedRewards.curriculum_basic = true
	f:add(1, nil, profile)
	assert(f:last().basicHits == 3 and f:last().basicDone)
	f.service:destroy()
end)

test("one player completing training never changes another player's state", function()
	local f = fixture(); local first, second = f:add(1), f:add(2)
	f:complete(first)
	f.prompt.Triggered:Fire(first)
	assert(f.profiles[second].gold == 0 and f.profiles[second].level == 1)
	assert(next(f.profiles[second].claimedRewards) == nil)
	f.service:destroy()
end)

test("Sync is rate-limited and cannot carry arbitrary reward requests", function()
	local f = fixture(); local player = f:add(1)
	local count = #f.service.state.messages
	f.service.request.OnServerEvent:Fire(player, "Claim", "curriculum_final")
	f.service.request.OnServerEvent:Fire(player, "Sync", "injected")
	assert(#f.service.state.messages == count)
	for _ = 1, 20 do f.service.request.OnServerEvent:Fire(player, "Sync") end
	assert(#f.service.state.messages == count + 2)
	assert(f.profiles[player].gold == 0)
	f.now += 1
	f.service.request.OnServerEvent:Fire(player, "Sync")
	assert(#f.service.state.messages == count + 3)
	f.service:destroy()
end)

test("remove and destroy stop all reward actions and signal callbacks", function()
	local f = fixture(); local player = f:add(1)
	f.service:removePlayer(player)
	f:complete(player)
	f.prompt.Triggered:Fire(player)
	assert(f.changed == 0)
	f.service:destroy()
	assert(not f.service.requestConnection.Connected and not f.service.promptConnection.Connected)
	assert(f.service.state.destroyed and f.service.request.destroyed)
	f.service:destroy()
end)

test("original mentor constructs safely with no external assets or scripts", function()
	local f = fixture(true)
	local existing = roblox.Instance.new("Part")
	existing.Parent = f.workspace
	local world, prompt = f.module.buildWorld()
	assert(world.Name == "AetherfallTrainingRewards" and world.PrimaryPart.Name == "Uniform")
	assert(world.PrimaryPart.CFrame.Position == roblox.Vector3.new(-21, 3, 16))
	assert(prompt:IsA("ProximityPrompt") and prompt.ActionText == "Talk" and prompt.ObjectText == "Warden Mira")
	assert(prompt.MaxActivationDistance == 10 and not prompt.RequiresLineOfSight)
	local parts = 0
	local allowed = { Model = true, Part = true, ProximityPrompt = true, BillboardGui = true, TextLabel = true }
	for _, object in world:GetDescendants() do
		assert(allowed[object.ClassName], "Unexpected asset/script")
		if object:IsA("BasePart") then
			parts += 1
			assert(object.Anchored and not object.CanCollide and not object.CanTouch and not object.CanQuery)
		end
	end
	assert(parts == 15)
	local again, samePrompt = f.module.buildWorld()
	assert(again == world and samePrompt == prompt and existing.Parent == f.workspace)
	world.Name = "RetainedWorld"
	local collision = roblox.Instance.new("Model")
	collision.Name = "AetherfallTrainingRewards"
	collision.Parent = f.workspace
	assert(not pcall(f.module.buildWorld))
	assert(collision.Parent == f.workspace)
end)

print(passed .. " training reward tests passed with mocked networking/proximity and original NPC data-model construction.")
