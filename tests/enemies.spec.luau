-- Actual AI and construction code with mocked physics/player life state, not live Studio.
local fs = require("@lune/fs")
local roblox = require("@lune/roblox")
local Definitions = require("../src/shared/EnemyDefinitions")
local Progression = require("../src/shared/ProgressionRules")
local Vector3, CFrame = roblox.Vector3, roblox.CFrame
local function fixture()
	local f = { now = 100, blocked = false, grounded = true, protectedUntil = 0, awards = {}, profiles = {}, registered = {} }
	local worldParent = roblox.Instance.new("Workspace")
	local village = roblox.Instance.new("Model")
	local spawns = roblox.Instance.new("Folder")
	spawns.Name = "EnemySpawns"
	spawns.Parent = village
	for index, kind in { "MeadowSlime", "WildBoar", "Thornling" } do
		local marker = roblox.Instance.new("Part")
		marker.CFrame = CFrame.new(70 + index * 15, 1, -50 - index * 24)
		marker:SetAttribute("EnemyKind", kind)
		marker:SetAttribute("SpawnId", "spawn_" .. index)
		marker.Parent = spawns
	end
	local shared = { EnemyDefinitions = Definitions, ProgressionRules = Progression }
	local storage = {}
	function storage:WaitForChild(name) assert(name == "Shared"); return shared end
	local game = {}
	function game:GetService(name)
		return if name == "ReplicatedStorage" then storage else {}
	end
	local physics = {}
	function physics:Raycast(_, delta)
		if delta.Y == -7 then return if f.grounded then { Normal = Vector3.yAxis } else nil end
		return if f.blocked then { Instance = { IsDescendantOf = function() return false end } } else nil
	end
	local combat = {}
	function combat:registerTarget(model) f.registered[model:GetAttribute("TargetId")] = model end
	function combat:unregisterTarget(id) f.registered[id] = nil end
	local environment = setmetatable({
		game = game, workspace = worldParent, Instance = roblox.Instance, Enum = roblox.Enum,
		Vector3 = Vector3, CFrame = CFrame, Color3 = roblox.Color3, UDim2 = roblox.UDim2,
		RaycastParams = { new = function() return {} end }, require = function(module) return module end,
	}, { __index = getfenv() })
	local factory = assert(loadstring(fs.readFile("src/server/EnemyService.luau"), "EnemyService"))
	setfenv(factory, environment)
	local Service = factory()
	f.service = Service.new(f.profiles, combat, village, {
		autoStep = false, worldParent = worldParent, physics = physics, now = function() return f.now end,
		canAct = function(player) return not player.paused end,
		onDefeat = function(player, kind, killId) table.insert(f.awards, { player = player, kind = kind, killId = killId }) end,
	})
	f.parent, f.village, f.Service, f.combat = worldParent, village, Service, combat
	function f:entry(index) return self.service.entries["enemy_spawn_" .. (index or 1)] end
	function f:addPlayer(offset, index)
		local humanoid = { Health = 100, taken = 0 }
		function humanoid:TakeDamage(damage) self.taken += damage; self.Health = math.max(0, self.Health - damage) end
		local root = roblox.Instance.new("Part")
		root.CFrame = CFrame.new(self:entry(index).home + (offset or Vector3.new(2, 0, 0)))
		local character = {}
		function character:FindFirstChildOfClass(name) return if name == "Humanoid" then humanoid else nil end
		function character:FindFirstChild(name) return if name == "HumanoidRootPart" then root else nil end
		function character:GetAttribute(name) return if name == "AetherfallSpawnProtectedUntil" then f.protectedUntil else nil end
		local player = { Character = character, root = root, humanoid = humanoid }
		self.profiles[player] = Progression.newProfile("Sentinel")
		return player
	end
	function f:step(seconds)
		self.now += seconds
		self.service:step(self.now, math.min(seconds, 0.4))
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

test("all three frozen definitions provide bounded early-game statistics", function()
	local count = 0
	for _, definition in Definitions do
		assert(table.isfrozen(definition))
		assert(definition.health > 0 and definition.damage >= 1 and definition.damage <= 12)
		assert(definition.windup >= 0.8 and definition.cooldown >= 2 and definition.respawn >= 10)
		assert(definition.xp > 0 and definition.gold > 0)
		count += 1
	end
	assert(count == 3 and table.isfrozen(Definitions))
end)

test("three recognizable models register stable target IDs and safe geometry", function()
	local f = fixture()
	local count = 0
	for id, entry in f.service.entries do
		assert(f.registered[id] == entry.model and entry.model.PrimaryPart.Name == "Hitbox")
		assert(entry.model:GetAttribute("Enemy") and entry.model:GetAttribute("AliveGeneration") == 1)
		assert(entry.model:GetAttribute("SpawnHome") == entry.home and entry.model:GetAttribute("LeashDistance") == entry.definition.leash)
		local parts = 0
		for _, object in entry.model:GetDescendants() do
			assert(not object:IsA("LuaSourceContainer") and not object:IsA("MeshPart") and not object:IsA("Sound"))
			if object:IsA("BasePart") then
				parts += 1
				assert(object.Anchored and not object.CanTouch and not object.CanCollide)
				assert(object.CanQuery == (object == entry.model.PrimaryPart))
				for _, component in { object.CFrame:GetComponents() } do assert(component == component and math.abs(component) < math.huge) end
			end
		end
		assert(parts >= 7 and parts <= 18)
		count += 1
	end
	assert(count == 3)
	f.service:destroy()
end)

test("idle enemies patrol without leaving their home field", function()
	local f = fixture(); local entry = f:entry()
	f:step(1)
	assert(entry.state == "Patrol")
	assert((entry.model.PrimaryPart.CFrame.Position - entry.home).Magnitude <= 4)
	assert(entry.model.PrimaryPart.CFrame.Position.X >= 48)
	f.service:destroy()
end)

test("nearby living players trigger readable windup before any damage", function()
	local f = fixture(); local player = f:addPlayer(); local entry = f:entry()
	f:step(0.2)
	assert(entry.state == "Windup" and player.humanoid.taken == 0)
	assert(entry.model:FindFirstChild("EnemyName", true).Text:find("DODGE!", 1, true))
	f:step(0.79)
	assert(player.humanoid.taken == 0)
	f:step(0.02)
	assert(player.humanoid.taken > 0 and player.humanoid.taken <= entry.definition.damage)
	assert(entry.state == "Recover")
	local damage = player.humanoid.taken
	f:step(0.4)
	assert(player.humanoid.taken == damage)
	f.service:destroy()
end)

test("moving out of range during windup avoids the impact", function()
	local f = fixture(); local player = f:addPlayer(); local entry = f:entry()
	f:step(0.2)
	player.root.CFrame = CFrame.new(entry.home + Vector3.new(12, 0, 0))
	f:step(0.81)
	assert(player.humanoid.taken == 0 and entry.state == "Recover")
	f.service:destroy()
end)

test("blocked impacts and spawn protection prevent damage", function()
	for _, mode in { "blocked", "protected" } do
		local f = fixture(); local player = f:addPlayer()
		f:step(0.2)
		if mode == "blocked" then f.blocked = true else f.protectedUntil = f.now + 3 end
		f:step(0.81)
		assert(player.humanoid.taken == 0)
		f.service:destroy()
	end
end)

test("paused, dead and safe-village players are never pursued", function()
	for _, mode in { "paused", "dead", "safe" } do
		local f = fixture(); local player = f:addPlayer(); local entry = f:entry()
		if mode == "paused" then player.paused = true
		elseif mode == "dead" then player.humanoid.Health = 0
		else player.root.CFrame = CFrame.new(47, 2, -74) end
		f:step(1)
		assert(entry.target == nil and player.humanoid.taken == 0)
		f.service:destroy()
	end
end)

test("distant targets beyond the home leash are abandoned", function()
	local f = fixture(); local player = f:addPlayer(Vector3.new(12, 0, 0)); local entry = f:entry()
	f:step(0.2)
	assert(entry.target == player and entry.state == "Chase")
	player.root.CFrame = CFrame.new(entry.home + Vector3.new(40, 0, 0))
	f:step(0.2)
	assert(entry.target == nil)
	f.service:destroy()
end)

test("obstacles and missing ground stop movement and return stuck enemies home", function()
	for _, mode in { "blocked", "gap" } do
		local f = fixture(); local player = f:addPlayer(Vector3.new(12, 0, 0)); local entry = f:entry()
		if mode == "blocked" then f.blocked = true else f.grounded = false end
		entry.target = player
		local before = entry.model.PrimaryPart.CFrame.Position
		f:step(0.2)
		assert(entry.model.PrimaryPart.CFrame.Position == before)
		f:step(4.1)
		assert(entry.state == "Return")
		f:step(0.2)
		assert(entry.model.PrimaryPart.CFrame.Position == entry.home and entry.target == nil)
		f.service:destroy()
	end
end)

test("a lethal hit credits eligible contributors once per generation", function()
	local f = fixture(); local first = f:addPlayer(); local second = f:addPlayer(Vector3.new(3, 0, 0)); local entry = f:entry()
	f.service:onDamaged(first, entry.model, 10, false)
	entry.model:SetAttribute("Health", 0)
	f.service:onDamaged(second, entry.model, 55, true)
	assert(#f.awards == 2 and entry.state == "Dead")
	assert(not entry.model.PrimaryPart.CanQuery and not entry.model.PrimaryPart.CanCollide)
	f.service:onDamaged(second, entry.model, 55, true)
	assert(#f.awards == 2)
	assert(f.awards[1].killId == f.awards[2].killId)
	f:step(9.9)
	assert(entry.state == "Dead" and entry.model:GetAttribute("Health") == 0)
	f:step(0.1)
	assert(entry.model:GetAttribute("Health") == entry.definition.health and entry.generation == 2)
	assert(entry.model.PrimaryPart.CanQuery and not entry.model.PrimaryPart.CanCollide)
	entry.model:SetAttribute("Health", 0)
	f.service:onDamaged(first, entry.model, 65, true)
	assert(#f.awards == 3 and f.awards[3].killId ~= f.awards[1].killId)
	f.service:destroy()
end)

test("stale, paused, departed and distant contributors do not receive rewards", function()
	for _, mode in { "stale", "paused", "departed", "distant", "dead" } do
		local f = fixture(); local first = f:addPlayer(); local killer = f:addPlayer(); local entry = f:entry()
		f.service:onDamaged(first, entry.model, 10, false)
		if mode == "stale" then f.now += 21
		elseif mode == "paused" then first.paused = true
		elseif mode == "departed" then f.service:removePlayer(first); f.profiles[first] = nil
		elseif mode == "dead" then first.humanoid.Health = 0
		else first.root.CFrame = CFrame.new(entry.home + Vector3.new(110, 0, 0)) end
		entry.model:SetAttribute("Health", 0)
		f.service:onDamaged(killer, entry.model, 55, true)
		assert(#f.awards == 1 and f.awards[1].player == killer)
		f.service:destroy()
	end
end)

test("ranged damage attracts a field enemy without resetting an active windup", function()
	local f = fixture(); local player = f:addPlayer(Vector3.new(25, 0, 0)); local entry = f:entry()
	f.service:onDamaged(player, entry.model, 10, false)
	assert(entry.target == player and entry.state == "Chase")
	player.root.CFrame = CFrame.new(entry.home + Vector3.new(2, 0, 0))
	f:step(0.2)
	assert(entry.state == "Windup")
	local deadline = entry.untilTime
	f.service:onDamaged(player, entry.model, 10, false)
	assert(entry.state == "Windup" and entry.untilTime == deadline)
	f.service:destroy()
end)

test("damage from a sanctuary or beyond the leash cannot attract or receive credit", function()
	for _, location in { Vector3.new(47, 2, -74), Vector3.new(130, 2, -74) } do
		local f = fixture(); local player = f:addPlayer(); local entry = f:entry()
		player.root.CFrame = CFrame.new(location)
		f.service:onDamaged(player, entry.model, 10, false)
		assert(entry.target == nil and next(entry.contributors) == nil)
		f.service:destroy()
	end
end)

test("stun interrupts a pending attack then permits movement and a new telegraph", function()
	local f = fixture(); local player = f:addPlayer(); local entry = f:entry()
	f:step(0.2)
	assert(entry.state == "Windup")
	entry.model:SetAttribute("StunnedUntil", f.now + 1)
	local before = entry.model.PrimaryPart.CFrame.Position
	f:step(0.9)
	assert(entry.state == "Stunned" and player.humanoid.taken == 0)
	assert(entry.model.PrimaryPart.CFrame.Position == before)
	assert(entry.model:FindFirstChild("EnemyName", true).Text:find("STUNNED", 1, true))
	player.root.CFrame = CFrame.new(entry.home + Vector3.new(9, 0, 0))
	f:step(0.11)
	assert(entry.state == "Chase" and player.humanoid.taken == 0)
	assert(entry.model.PrimaryPart.CFrame.Position ~= before)
	player.root.CFrame = CFrame.new(entry.model.PrimaryPart.CFrame.Position + Vector3.new(2, 0, 0))
	f:step(0.2)
	assert(entry.state == "Windup" and player.humanoid.taken == 0)
	f:step(0.81)
	assert(player.humanoid.taken > 0)
	f.service:destroy()
end)

test("forged targets and nonfinite damage cannot create contribution credit", function()
	local f = fixture(); local player = f:addPlayer(); local entry = f:entry()
	local forged = entry.model:Clone()
	f.service:onDamaged(player, forged, 10, true)
	f.service:onDamaged(player, entry.model, 0/0, true)
	f.service:onDamaged(player, entry.model, -1, true)
	assert(next(entry.contributors) == nil and #f.awards == 0 and entry.state == "Idle")
	f.service:destroy()
end)

test("removal clears aggro and destruction unregisters all owned targets", function()
	local f = fixture(); local player = f:addPlayer(); local entry = f:entry()
	f:step(0.2)
	f.service:removePlayer(player)
	assert(entry.target == nil and entry.state == "Return")
	f.service:destroy()
	assert(next(f.registered) == nil and f.parent:FindFirstChild("AetherfallEnemies") == nil)
	f.service:step(f.now + 10, 0.2)
	f.service:destroy()
end)

test("invalid or duplicate spawn identity fails without replacing existing content", function()
	local f = fixture()
	local marker = f.village.EnemySpawns:GetChildren()[1]
	marker:SetAttribute("EnemyKind", "Unknown")
	assert(not pcall(function() f.Service.new(f.profiles, f.combat, f.village, { worldParent = f.parent, autoStep = false }) end))
	assert(f.parent:FindFirstChild("AetherfallEnemies") == f.service.world)
	f.service:destroy()
end)

print(passed .. " enemy AI/model tests passed with mocked physics and player state; Studio play remains pending.")
