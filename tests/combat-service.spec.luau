-- Actual CombatService handlers with mocked clocks/network/physics/signals.
-- Instances and geometry use Lune's data model; this does NOT run live Studio physics.
local fs = require("@lune/fs")
local roblox = require("@lune/roblox")
local Catalog = require("../src/shared/EquipmentCatalog")
local EquipmentRules = require("../src/shared/EquipmentRules")
local Config = require("../src/shared/CombatConfig")
local CombatRules = require("../src/shared/CombatRules")
local Vector3, CFrame = roblox.Vector3, roblox.CFrame

local function signal()
	local event = { listeners = {} }
	function event:Connect(callback)
		local connection = { Connected = true }
		function connection:Disconnect() self.Connected = false end
		table.insert(self.listeners, { callback, connection })
		return connection
	end
	function event:Fire(...)
		for _, listener in self.listeners do
			if listener[2].Connected then listener[1](...) end
		end
	end
	return event
end

local function makeCharacter()
	local humanoid = { Health = 100, MaxHealth = 100, WalkSpeed = 16, HealthChanged = signal() }
	function humanoid:IsA(name) return name == "Humanoid" end
	local root = roblox.Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.CFrame = CFrame.new(0, 3, 0)
	root.Position = Vector3.new(0, 3, 0)
	local character = {}
	function character:FindFirstChildOfClass(name) return if name == "Humanoid" then humanoid else nil end
	function character:FindFirstChild(name) return if name == "HumanoidRootPart" then root else nil end
	function character:WaitForChild(name) return if name == "Humanoid" then humanoid else root end
	function character:GetPivot() return root.CFrame end
	function character:PivotTo(cf) root.CFrame = cf; root.Position = cf.Position end
	return character, humanoid, root
end

local function fixture()
	local f = { now = 100, blocked = false, wallDistance = nil, grounded = true }
	local replicatedStorage = { Name = "ReplicatedStorage" }
	local shared = {
		EquipmentCatalog = Catalog, EquipmentRules = EquipmentRules,
		CombatConfig = Config, CombatRules = CombatRules,
	}
	function replicatedStorage:WaitForChild(name) assert(name == "Shared"); return shared end
	f.remotes = { Parent = replicatedStorage }
	local function newRemote()
		local object = { OnServerEvent = signal(), clients = {}, broadcasts = {}, destroyed = false }
		function object:IsDescendantOf(parent) return self.Parent and self.Parent.Parent == parent end
		function object:FireClient(player, payload) table.insert(self.clients, { player = player, payload = payload }) end
		function object:FireAllClients(payload) table.insert(self.broadcasts, payload) end
		function object:Destroy() self.destroyed = true end
		return object
	end
	local obstacle = roblox.Instance.new("Part")
	local physics = {}
	function physics:Raycast(_, delta)
		if delta.Y == -8 then
			return if f.grounded then { Instance = obstacle, Normal = Vector3.yAxis } else nil
		end
		return if f.blocked then { Instance = obstacle } else nil
	end
	function physics:Blockcast()
		return if f.wallDistance ~= nil then { Distance = f.wallDistance } else nil
	end
	local heartbeat = signal()
	local services = { ReplicatedStorage = replicatedStorage, RunService = { Heartbeat = heartbeat } }
	local game = {}
	function game:GetService(name) return assert(services[name], "Unexpected service " .. name) end
	local environment = setmetatable({
		game = game,
		workspace = physics,
		Enum = roblox.Enum,
		Vector3 = Vector3,
		RaycastParams = { new = function() return {} end },
		Random = { new = function() return { NextNumber = function() return 0.9 end } end },
		Instance = { new = function(className) assert(className == "RemoteEvent"); return newRemote() end },
		require = function(module) return module end,
		os = setmetatable({ clock = function() return f.now end }, { __index = os }),
		task = { spawn = function(callback) callback() end },
	}, { __index = getfenv() })
	local factory = assert(loadstring(fs.readFile("src/server/CombatService.luau"), "CombatService"))
	setfenv(factory, environment)
	local Service = factory()
	local world = roblox.Instance.new("Model")
	local targets = roblox.Instance.new("Folder")
	targets.Name = "Targets"
	targets.Parent = world
	f.targets = {}
	for index, position in { Vector3.new(0, 3, -7), Vector3.new(4, 3, -7) } do
		local target = roblox.Instance.new("Model")
		target.Name = "Target" .. index
		target:SetAttribute("TargetId", "dummy_" .. index)
		target:SetAttribute("MaxHealth", 300)
		target:SetAttribute("Defence", 10)
		local part = roblox.Instance.new("Part")
		part.Name = "Hitbox"
		part.CFrame = CFrame.new(position)
		part.Position = position
		part.Parent = target
		target.PrimaryPart = part
		local text = roblox.Instance.new("TextLabel")
		text.Name = "HealthText"
		text.Parent = part
		target.Parent = targets
		f.targets[index] = target
	end
	f.profiles = {}
	f.service = Service.new(f.profiles, f.remotes, world)
	function f:addPlayer(id, className)
		local player = { UserId = id, CharacterAdded = signal() }
		self.profiles[player] = EquipmentRules.newProfile(className or "Sentinel", 10, true)
		self.service:addPlayer(player)
		player.Character, player.humanoid, player.root = makeCharacter()
		player.CharacterAdded:Fire(player.Character)
		return player
	end
	function f:request(player, action, id, ...)
		self.service.request.OnServerEvent:Fire(player, action, id, ...)
	end
	function f:advance(seconds)
		self.now += seconds
		self.service:_tick(self.now)
	end
	function f:lastMessage()
		local sent = self.service.feedback.clients
		return sent[#sent] and sent[#sent].payload.message
	end
	return f
end

local passed = 0
local function test(name, callback)
	local ok, message = pcall(callback)
	if not ok then error("FAIL " .. name .. ": " .. tostring(message), 0) end
	passed += 1
	print("PASS " .. name)
end
local function uidFor(profile, id)
	for uid, instance in profile.inventory do if instance.itemId == id then return uid end end
	error("Item missing " .. id)
end

test("accepted handler derives damage on server and ignores injected damage arguments", function()
	local f = fixture()
	local player = f:addPlayer(1)
	local expected = EquipmentRules.stats(f.profiles[player]).Attack * 100 / 110
	f:request(player, "Basic", "dummy_1", 1e9)
	assert(math.abs(f.targets[1]:GetAttribute("Health") - (300 - expected)) < 0.001)
	assert(f.service.states[player].combat.stamina == 94)
	assert(#f.service.feedback.broadcasts == 1)
	assert(f.service.feedback.broadcasts[1].actorUserId == 1)
	f.service:destroy()
end)

test("unregistered target ids never become damage destinations", function()
	local f = fixture(); local player = f:addPlayer(1)
	f:request(player, "Basic", "forged_target")
	assert(f.targets[1]:GetAttribute("Health") == 300)
	assert(f.service.states[player].combat.stamina == 100)
	assert(f:lastMessage() == "Choose an active training target.")
	f.service:destroy()
end)

test("real handler rejects out-of-range targets without spending stamina", function()
	local f = fixture(); local player = f:addPlayer(1)
	player.root.CFrame = CFrame.new(0, 3, 20)
	player.root.Position = Vector3.new(0, 3, 20)
	f:request(player, "Basic", "dummy_1")
	assert(f:lastMessage() == "The target is out of range.")
	assert(f.service.states[player].combat.stamina == 100)
	f.service:destroy()
end)

test("LOS and melee facing come from server geometry", function()
	local f = fixture(); local player = f:addPlayer(1)
	f.blocked = true
	f:request(player, "Basic", "dummy_1")
	assert(f:lastMessage() == "The target is blocked.")
	f.blocked = false
	player.root.CFrame = CFrame.new(0, 3, 0) * CFrame.Angles(0, math.pi, 0)
	f:request(player, "Basic", "dummy_1")
	assert(f:lastMessage() == "Face the target before attacking.")
	assert(f.targets[1]:GetAttribute("Health") == 300)
	f.service:destroy()
end)

test("cooldown and per-player request buckets prevent repeated damage under spam", function()
	local f = fixture(); local player = f:addPlayer(1)
	f:request(player, "Basic", "dummy_1")
	local health = f.targets[1]:GetAttribute("Health")
	for _ = 1, 20 do f:request(player, "Basic", "dummy_1") end
	assert(f.targets[1]:GetAttribute("Health") == health)
	assert(f:lastMessage() == "Please slow down your combat requests.")
	f:advance(1)
	f:request(player, "Basic", "dummy_1")
	assert(f.targets[1]:GetAttribute("Health") < health)
	f.service:destroy()
end)

test("class and equipment changes retain resources and action timers", function()
	local f = fixture(); local player = f:addPlayer(1)
	f:request(player, "Skill", "dummy_1")
	local state = f.service.states[player].combat
	local nextSkill, stamina = state.nextSkill, state.stamina
	assert(EquipmentRules.setClass(f.profiles[player], "Ranger"))
	f.service:equipmentChanged(player, true)
	assert(state.nextSkill == nextSkill and state.stamina == stamina)
	f:request(player, "Skill")
	assert(f:lastMessage() == "That action is still on cooldown.")
	assert(state.stamina == stamina)
	f.service:destroy()
end)

test("equipment applies speed/max-health without healing or reviving", function()
	local f = fixture(); local player = f:addPlayer(1)
	local profile = f.profiles[player]
	player.humanoid.Health = 40
	assert(EquipmentRules.equip(profile, uidFor(profile, "briarheart_talisman"), "Accessory1"))
	f.service:equipmentChanged(player, false)
	assert(player.humanoid.Health == 40)
	assert(player.humanoid.MaxHealth == EquipmentRules.stats(profile).MaxHealth)
	assert(player.humanoid.WalkSpeed == EquipmentRules.stats(profile).MoveSpeed)
	player.humanoid.Health = 0
	f.service:equipmentChanged(player, false)
	assert(player.humanoid.Health == 0)
	f:request(player, "Basic", "dummy_1")
	assert(f:lastMessage() == "You must be alive to act.")
	f.service:destroy()
end)

test("unequipped weapons cannot attack and dagger uses melee limits", function()
	local f = fixture(); local player = f:addPlayer(1, "Ranger")
	local profile = f.profiles[player]
	assert(EquipmentRules.unequip(profile, "MainHand"))
	f.service:equipmentChanged(player, false)
	f:request(player, "Basic", "dummy_1")
	assert(f:lastMessage() == "Equip a compatible main-hand weapon first.")
	assert(EquipmentRules.equip(profile, uidFor(profile, "hunting_knife"), "MainHand"))
	f.service:equipmentChanged(player, false)
	f:request(player, "Basic", "dummy_1")
	assert(f:lastMessage() == "The target is out of range.")
	player.root.CFrame = CFrame.new(0, 3, -2)
	player.root.Position = Vector3.new(0, 3, -2)
	f:request(player, "Basic", "dummy_1")
	assert(f.targets[1]:GetAttribute("Health") < 300)
	assert(f.service.feedback.broadcasts[1].kind == "Melee")
	assert(f.service.feedback.broadcasts[1].name == "Knife Cut")
	f.service:destroy()
end)

test("target health is shared but cooldowns/resources remain player-isolated", function()
	local f = fixture(); local first = f:addPlayer(1); local second = f:addPlayer(2)
	f:request(first, "Basic", "dummy_1")
	local health = f.targets[1]:GetAttribute("Health")
	assert(f.service.states[second].combat.stamina == 100)
	f:request(second, "Basic", "dummy_1")
	assert(f.targets[1]:GetAttribute("Health") < health)
	assert(f.service.states[first].combat.stamina == 94)
	f.service:destroy()
end)

test("area ability hits each server-registered nearby target once", function()
	local f = fixture(); local player = f:addPlayer(1, "Spellweaver")
	f:request(player, "Skill", "dummy_1")
	assert(f.targets[1]:GetAttribute("Health") < 300 and f.targets[2]:GetAttribute("Health") < 300)
	assert(#f.service.feedback.broadcasts == 2)
	assert(f.service.states[player].combat.mana == 75)
	f.service:destroy()
end)

test("depleted targets reset only after the four-second recovery period", function()
	local f = fixture(); local player = f:addPlayer(1)
	f.targets[1]:SetAttribute("Health", 1)
	f:request(player, "Basic", "dummy_1")
	assert(f.targets[1]:GetAttribute("Health") == 0)
	assert(f.targets[1].PrimaryPart.HealthText.Text == "Recovering · 4 seconds")
	f:advance(3.99)
	assert(f.targets[1]:GetAttribute("Health") == 0)
	f:advance(0.01)
	assert(f.targets[1]:GetAttribute("Health") == 300)
	assert(f.targets[1].PrimaryPart.HealthText.Text == "300 / 300")
	f.service:destroy()
end)

test("dash travels a bounded server-facing distance and emits feedback", function()
	local f = fixture(); local player = f:addPlayer(1, "Ranger")
	local start = player.root.Position
	f:request(player, "Skill")
	assert(math.abs((player.root.Position - start).Magnitude - 10) < 0.001)
	assert(player.root.Position.Z < start.Z)
	assert(f.service.states[player].combat.stamina == 80)
	assert(f.service.feedback.broadcasts[1].kind == "Dash")
	f.service:destroy()
end)

test("blocked or ungrounded dash cannot spend resources or start its cooldown", function()
	for _, mode in { "wall", "gap" } do
		local f = fixture(); local player = f:addPlayer(1, "Ranger")
		if mode == "wall" then f.wallDistance = 0 else f.grounded = false end
		f:request(player, "Skill")
		assert(f.service.states[player].combat.stamina == 100)
		assert(f.service.states[player].combat.nextSkill == 0)
		assert(player.root.Position == Vector3.new(0, 3, 0))
		assert(f:lastMessage() == "Quickstep needs a clear, grounded path in front of you.")
		f.service:destroy()
	end
end)

test("malformed action/target types never reach damage or consume resources", function()
	local f = fixture(); local player = f:addPlayer(1)
	for _, args in { { {}, "dummy_1" }, { "Damage", "dummy_1" }, { "Basic", {} }, { "Basic", 8 }, { "Basic", string.rep("x", 41) } } do
		f:request(player, args[1], args[2])
		assert(f:lastMessage() == "Invalid combat request.")
	end
	assert(f.targets[1]:GetAttribute("Health") == 300)
	assert(f.service.states[player].combat.stamina == 100)
	f.service:destroy()
end)

test("respawn refreshes health/resources without resetting cooldowns or leaking health connections", function()
	local f = fixture(); local player = f:addPlayer(1)
	f:request(player, "Skill", "dummy_1")
	local entry = f.service.states[player]
	local deadline, previousConnection = entry.combat.nextSkill, entry.healthConnection
	player.Character, player.humanoid, player.root = makeCharacter()
	player.CharacterAdded:Fire(player.Character)
	assert(not previousConnection.Connected and entry.healthConnection.Connected)
	assert(entry.combat.nextSkill == deadline)
	assert(entry.combat.stamina == 100 and player.humanoid.Health == player.humanoid.MaxHealth)
	f.service:destroy()
end)

test("remove/destroy disconnect lifecycle handlers and invalidate further requests", function()
	local f = fixture(); local player = f:addPlayer(1)
	local entry = f.service.states[player]
	f.service:removePlayer(player)
	assert(not entry.characterConnection.Connected and not entry.healthConnection.Connected)
	f:request(player, "Basic", "dummy_1")
	assert(f.targets[1]:GetAttribute("Health") == 300)
	f.service:destroy()
	assert(not f.service.requestConnection.Connected and not f.service.heartbeat.Connected)
	assert(f.service.request.destroyed and f.service.stateEvent.destroyed and f.service.feedback.destroyed)
	f.service:destroy()
end)

print(passed .. " CombatService handler tests passed with mocked network, clocks and physics.")
