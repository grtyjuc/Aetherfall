-- Actual server handlers, with explicit mocked networking/clock/physics/characters.
-- This exercises resource ownership and transaction flow, not live Roblox movement.
local fs = require("@lune/fs")
local roblox = require("@lune/roblox")
local Catalog = require("../src/shared/EquipmentCatalog")
local Progression = require("../src/shared/ProgressionRules")
local Equipment = require("../src/shared/EquipmentRules")
local Rules = require("../src/shared/DefenceRules")
local Vector3, CFrame = roblox.Vector3, roblox.CFrame

local function signal()
	local object = { listeners = {} }
	function object:Connect(callback)
		local connection = { Connected = true }
		function connection:Disconnect() self.Connected = false end
		table.insert(self.listeners, { connection = connection, callback = callback })
		return connection
	end
	function object:Fire(...)
		for _, listener in self.listeners do
			if listener.connection.Connected then listener.callback(...) end
		end
	end
	return object
end

local function fixture()
	local f = { now = 100, wall = nil, grounded = true, allowed = true, forceField = false }
	local replicated = {}
	local shared = { EquipmentCatalog = Catalog, ProgressionRules = Progression, DefenceRules = Rules }
	function replicated:WaitForChild(name) assert(name == "Shared"); return shared end
	f.remotes = { Parent = replicated }
	local function remote()
		local object = { OnServerEvent = signal(), sent = {} }
		function object:FireClient(player, payload) table.insert(self.sent, { player = player, payload = payload }) end
		function object:IsDescendantOf(parent) return self.Parent and self.Parent.Parent == parent end
		function object:Destroy() self.destroyed = true end
		return object
	end
	local physics = {}
	function physics:Blockcast(_, size, direction)
		assert(size == Vector3.new(2.4, 4, 2.4), "Dodge requires a body-sized sweep")
		assert(direction.Magnitude <= 8.001)
		return if f.wall then { Distance = f.wall } else nil
	end
	function physics:Raycast(_, direction)
		assert(direction == Vector3.new(0, -8, 0))
		return if f.grounded then { Normal = Vector3.yAxis } else nil
	end
	local heartbeat = signal()
	local services = { ReplicatedStorage = replicated, RunService = { Heartbeat = heartbeat } }
	local game = {}
	function game:GetService(name) return assert(services[name]) end
	local factory = assert(loadstring(fs.readFile("src/server/DefenceService.luau"), "DefenceService"))
	setfenv(factory, setmetatable({
		game = game, workspace = physics, Vector3 = Vector3, Enum = roblox.Enum,
		RaycastParams = { new = function() return {} end },
		Instance = { new = function(name) assert(name == "RemoteEvent"); return remote() end },
		require = function(module) return module end,
		task = { spawn = function(callback) callback() end },
	}, { __index = getfenv() }))
	local Service = factory()
	f.profiles, f.resources, f.players = {}, {}, {}
	f.service = Service.new(f.profiles, f.remotes, {
		now = function() return f.now end, physics = physics, autoStep = false,
		canAct = function() return f.allowed end,
		getResources = function(player)
			local state = f.resources[player]
			if not state then return nil end
			-- Same shared-clock/regen contract as CombatService. Stance lookups must not recurse.
			local elapsed = f.now - state.lastTick
			assert(elapsed >= 0)
			state.stamina = math.min(100, state.stamina + elapsed * 15 * f.service:staminaRegenScale(player))
			state.lastTick = f.now
			return state
		end,
	})
	function f:character(player)
		local humanoid = { Health = 100, MaxHealth = 100, WalkSpeed = 16, MoveDirection = Vector3.new(0, 0, -1) }
		function humanoid:IsA(name) return name == "Humanoid" end
		function humanoid:TakeDamage(amount)
			if not f.forceField then self.Health = math.max(0, self.Health - amount) end
		end
		local root = roblox.Instance.new("Part")
		root.CFrame, root.Position = CFrame.new(0, 3, 0), Vector3.new(0, 3, 0)
		root.AssemblyLinearVelocity = Vector3.new(0, 0, -16)
		local character = {}
		function character:FindFirstChildOfClass(name) return if name == "Humanoid" then humanoid else nil end
		function character:FindFirstChild(name) return if name == "HumanoidRootPart" then root else nil end
		function character:WaitForChild(name) assert(name == "Humanoid"); return humanoid end
		function character:GetPivot() return root.CFrame end
		function character:PivotTo(cf) root.CFrame, root.Position = cf, cf.Position end
		player.Character, player.humanoid, player.root = character, humanoid, root
		player.CharacterAdded:Fire(character)
	end
	function f:add(className)
		local player = { UserId = #self.players + 1, CharacterAdded = signal() }
		table.insert(self.players, player)
		self.profiles[player] = Equipment.newProfile(className or "Sentinel", 10, true)
		self.resources[player] = { stamina = 100, lastTick = self.now }
		self:character(player)
		self.service:addPlayer(player)
		return player
	end
	function f:request(player, action, argument, ...)
		self.service.request.OnServerEvent:Fire(player, action, argument, ...)
	end
	function f:advance(seconds)
		self.now += seconds
		self.service:step(self.now)
	end
	function f:last()
		local sent = self.service.stateEvent.sent
		return sent[#sent] and sent[#sent].payload
	end
	return f
end

local passed = 0
local function test(name, callback)
	local ok, failure = pcall(callback)
	if not ok then error("FAIL " .. name .. ": " .. tostring(failure), 0) end
	passed += 1
	print("PASS " .. name)
end
local function close(a, b) assert(math.abs(a - b) < 0.001, tostring(a) .. " differs from " .. tostring(b)) end

test("new players receive per-player defensive state without altering health or resources", function()
	local f = fixture(); local p = f:add()
	assert(f:last().hasShield and not f:last().blocking and f:last().canPlay)
	assert(p.humanoid.Health == 100 and f.resources[p].stamina == 100)
	close(p.humanoid.WalkSpeed, Progression.stats(f.profiles[p]).MoveSpeed)
	f.service:destroy()
end)

test("directional dodge spends shared stamina and moves at most eight server-checked studs", function()
	local f = fixture(); local p = f:add()
	f:request(p, "Dodge", Vector3.xAxis)
	assert(p.root.CFrame.Position == Vector3.new(8, 3, 0))
	assert(f.resources[p].stamina == 82 and f:last().dodging)
	assert(f.service.feedback.sent[1].payload.kind == "Dodge")
	f:request(p, "Dodge", Vector3.zAxis)
	assert(p.root.CFrame.Position == Vector3.new(8, 3, 0) and f.resources[p].stamina == 82)
	f.service:destroy()
end)

test("partial obstacles shorten dodge while close walls and missing ground reject it atomically", function()
	local f = fixture(); local p = f:add()
	f.wall = 3
	f:request(p, "Dodge", Vector3.xAxis)
	assert(p.root.CFrame.Position == Vector3.new(2.5, 3, 0))
	f:advance(2)
	local before = f.resources[p].stamina
	f.wall = 0.5
	f:request(p, "Dodge", Vector3.xAxis)
	assert(f.resources[p].stamina == before)
	f.wall, f.grounded = nil, false
	f:request(p, "Dodge", Vector3.xAxis)
	assert(f.resources[p].stamina == before and p.root.CFrame.Position == Vector3.new(2.5, 3, 0))
	f.service:destroy()
end)

test("malformed protocol and forged directions cannot move, defend or spend stamina", function()
	local f = fixture(); local p = f:add()
	for _, argument in { {}, 100, Vector3.new(2, 0, 0), Vector3.new(0, 1, 0), Vector3.new(0 / 0, 0, 0) } do
		f:request(p, "Dodge", argument)
	end
	f:request(p, "Damage", 1e9)
	f:request(p, "Block", {})
	f:request(p, "Sprint", "true")
	f:request(p, "Sync", true)
	f:request(p, "Dodge", Vector3.xAxis, "injected")
	assert(f.resources[p].stamina == 100 and p.root.CFrame.Position == Vector3.new(0, 3, 0))
	assert(not f.service.entries[p].defence.blocking)
	f.service:destroy()
end)

test("shield guard drains shared stamina without regeneration and reduces a frontal hit", function()
	local f = fixture(); local p = f:add()
	f:request(p, "Block", true)
	assert(p.humanoid.WalkSpeed == 6 and f.service:staminaRegenScale(p) == 0)
	f:advance(1)
	assert(f.resources[p].stamina == 96)
	local actual, outcome = f.service:applyDamage(p, 20, Vector3.new(0, 3, -5))
	close(actual, 6); assert(outcome == "Blocked")
	assert(p.humanoid.Health == 94 and f.resources[p].stamina == 86)
	f.service:destroy()
end)

test("rear hits and directionless root eruptions bypass a raised shield", function()
	local f = fixture(); local p = f:add()
	f:request(p, "Block", true)
	local damage, outcome = f.service:applyDamage(p, 20, Vector3.new(0, 3, 5))
	assert(damage == 20 and outcome == "Hit" and f.resources[p].stamina == 100)
	damage, outcome = f.service:applyDamage(p, 10, p.root.CFrame.Position)
	assert(damage == 10 and outcome == "Hit" and f.resources[p].stamina == 100)
	f.service:destroy()
end)

test("insufficient guard stamina breaks the shield stance and restores base speed", function()
	local f = fixture(); local p = f:add()
	f:request(p, "Block", true)
	f.resources[p].stamina = 9
	local actual, outcome = f.service:applyDamage(p, 20, Vector3.new(0, 3, -5))
	assert(actual == 20 and outcome == "GuardBroken" and not f:last().blocking)
	assert(f:last().guardRemaining == 1)
	close(p.humanoid.WalkSpeed, Progression.stats(f.profiles[p]).MoveSpeed)
	f.service:destroy()
end)

test("dodge invulnerability has an exact server window then incoming damage resumes", function()
	local f = fixture(); local p = f:add()
	f:request(p, "Dodge", Vector3.xAxis)
	local actual, outcome = f.service:applyDamage(p, 20, Vector3.new(8, 3, -5))
	assert(actual == 0 and outcome == "Dodged" and p.humanoid.Health == 100)
	f:advance(0.25)
	actual, outcome = f.service:applyDamage(p, 20, Vector3.new(8, 3, -5))
	assert(actual == 20 and outcome == "Hit" and p.humanoid.Health == 80)
	f.service:destroy()
end)

test("sprinting uses level/equipment speed, drains stamina and stops before attacking", function()
	local f = fixture(); local p = f:add()
	local base = Progression.stats(f.profiles[p]).MoveSpeed
	f:request(p, "Sprint", true)
	close(p.humanoid.WalkSpeed, math.min(32, base * 1.35))
	f:advance(1)
	assert(f.resources[p].stamina == 78 and f:last().sprinting)
	assert(f.service:allowsAttack(p))
	close(p.humanoid.WalkSpeed, base)
	assert(not f:last().sprinting)
	f:advance(1)
	assert(f.resources[p].stamina == 93)
	f.service:destroy()
end)

test("guarding and active dodges prohibit attack requests without altering cooldowns", function()
	local f = fixture(); local p = f:add()
	f:request(p, "Block", true)
	assert(not f.service:allowsAttack(p))
	f:request(p, "Block", false)
	f:request(p, "Dodge", Vector3.xAxis)
	assert(not f.service:allowsAttack(p))
	f:advance(0.25)
	assert(f.service:allowsAttack(p))
	f.service:destroy()
end)

test("request spam is bounded but a valid release always clears a held stance", function()
	local f = fixture(); local p = f:add()
	f:request(p, "Block", true)
	for _ = 1, 20 do f:request(p, "Sync") end
	f:request(p, "Block", false)
	assert(not f.service.entries[p].defence.blocking)
	local sent = #f.service.stateEvent.sent
	for _ = 1, 30 do f:request(p, "Block", false) end
	assert(#f.service.stateEvent.sent == sent, "Idle release spam should not produce replies")
	f:request(p, "Dodge", Vector3.xAxis)
	assert(p.root.CFrame.Position == Vector3.new(0, 3, 0))
	f.service:destroy()
end)

test("dead and paused characters cannot dodge, sprint, guard or take new damage", function()
	local f = fixture(); local p = f:add()
	f:request(p, "Block", true)
	f.allowed = false
	f:advance(0.2)
	assert(not f:last().canPlay and not f:last().blocking)
	f:request(p, "Dodge", Vector3.xAxis)
	assert(p.root.CFrame.Position == Vector3.new(0, 3, 0))
	local actual = f.service:applyDamage(p, 20, Vector3.new(0, 3, -5))
	assert(actual == 0 and p.humanoid.Health == 100)
	f.allowed, p.humanoid.Health = true, 0
	f:request(p, "Block", true)
	f:request(p, "Sprint", true)
	assert(not f:last().blocking and not f:last().sprinting)
	f.service:destroy()
end)

test("removing the shield clears guard without healing or resetting dodge timers", function()
	local f = fixture(); local p = f:add()
	f:request(p, "Dodge", Vector3.xAxis)
	local deadline = f.service.entries[p].defence.nextDodge
	f:advance(0.25)
	f:request(p, "Block", true)
	assert(Equipment.unequip(f.profiles[p], "OffHand"))
	p.humanoid.Health = 40
	f.service:equipmentChanged(p)
	assert(not f:last().blocking and not f:last().hasShield and p.humanoid.Health == 40)
	assert(f.service.entries[p].defence.nextDodge == deadline)
	f.service:destroy()
end)

test("a class with no shield cannot enable guard but can still dodge and sprint", function()
	local f = fixture(); local p = f:add("Ranger")
	f:request(p, "Block", true)
	assert(not f:last().blocking and f.resources[p].stamina == 100)
	f:request(p, "Sprint", true)
	assert(f:last().sprinting)
	f:request(p, "Dodge", Vector3.xAxis)
	assert(f:last().dodging and not f:last().sprinting)
	f.service:destroy()
end)

test("respawn clears held stances but preserves action deadlines and never heals existing characters", function()
	local f = fixture(); local p = f:add()
	f:request(p, "Dodge", Vector3.xAxis)
	local deadline = f.service.entries[p].defence.nextDodge
	f:character(p)
	assert(f.service.entries[p].defence.nextDodge == deadline and not f:last().dodging)
	assert(p.humanoid.Health == 100 and f.resources[p].stamina == 82)
	f.service:destroy()
end)

test("ForceField behavior reports actual health loss rather than claimed damage", function()
	local f = fixture(); local p = f:add()
	f.forceField = true
	local actual, outcome = f.service:applyDamage(p, 20, Vector3.new(0, 3, -5))
	assert(actual == 0 and outcome == "Hit" and p.humanoid.Health == 100)
	assert(f.service.feedback.sent[1].payload.damage == 0)
	f.service:destroy()
end)

test("player states and shared resource balances remain isolated", function()
	local f = fixture(); local first, second = f:add(), f:add()
	f:request(first, "Dodge", Vector3.xAxis)
	f:request(second, "Block", true)
	assert(f.resources[first].stamina == 82 and f.resources[second].stamina == 100)
	assert(not f.service.entries[first].defence.blocking and f.service.entries[second].defence.blocking)
	f.service:destroy()
end)

test("invalid trusted damage and unknown players never reach Humanoid damage", function()
	local f = fixture(); local p = f:add()
	for _, amount in { 0, -1, 0.5, math.huge, 0 / 0, 10001 } do
		local actual, outcome = f.service:applyDamage(p, amount, Vector3.zero)
		assert(actual == 0 and outcome == "Invalid")
	end
	assert(p.humanoid.Health == 100)
	assert(f.service:applyDamage({}, 20, Vector3.zero) == 0)
	f.service:destroy()
end)

test("stopped movement charges the prior sprint interval before ending the stance", function()
	local f = fixture(); local p = f:add()
	f:request(p, "Sprint", true)
	p.humanoid.MoveDirection = Vector3.zero
	p.root.AssemblyLinearVelocity = Vector3.zero
	f:advance(0.2)
	close(f.resources[p].stamina, 95.6)
	assert(not f:last().sprinting)
	close(p.humanoid.WalkSpeed, Progression.stats(f.profiles[p]).MoveSpeed)
	f.service:destroy()
end)

test("sprint observes server assembly motion rather than client-only MoveDirection", function()
	local f = fixture(); local p = f:add()
	p.humanoid.MoveDirection = Vector3.zero
	p.root.AssemblyLinearVelocity = Vector3.new(0, 0, -16)
	f:request(p, "Sprint", true)
	assert(f:last().sprinting, "Client-local zero MoveDirection must not reject observed walking")
	f:request(p, "Sprint", false)
	p.humanoid.MoveDirection = Vector3.new(0, 0, -1)
	p.root.AssemblyLinearVelocity = Vector3.zero
	f:request(p, "Sprint", true)
	assert(not f:last().sprinting, "Movement intent alone must not establish server motion")
	p.root.AssemblyLinearVelocity = Vector3.new(0, 20, 0)
	f:request(p, "Sprint", true)
	assert(not f:last().sprinting, "Vertical motion alone is not horizontal sprinting")
	f.service:destroy()
end)

test("removal and destroy restore speed, disconnect signals and invalidate further requests", function()
	local f = fixture(); local p = f:add()
	f:request(p, "Sprint", true)
	local entry = f.service.entries[p]
	f.service:removePlayer(p)
	assert(not entry.characterConnection.Connected)
	close(p.humanoid.WalkSpeed, Progression.stats(f.profiles[p]).MoveSpeed)
	f:request(p, "Dodge", Vector3.xAxis)
	assert(p.root.CFrame.Position == Vector3.new(0, 3, 0))
	f.service:destroy()
	assert(not f.service.requestConnection.Connected)
	assert(f.service.request.destroyed and f.service.stateEvent.destroyed and f.service.feedback.destroyed)
	f.service:destroy()
end)

print(passed .. " DefenceService handler tests passed with mocked networking, movement and health.")
