-- Actual boss logic with Lune models and mocked network, time and physics.
local fs = require("@lune/fs")
local roblox = require("@lune/roblox")
local Progression = require("../src/shared/ProgressionRules")
local Vector3, CFrame = roblox.Vector3, roblox.CFrame
local function signal()
	local event = { listeners = {} }
	function event:Connect(callback)
		local link = { Connected = true }
		function link:Disconnect() self.Connected = false end
		table.insert(self.listeners, { callback, link })
		return link
	end
	function event:Fire(...)
		for _, listener in self.listeners do if listener[2].Connected then listener[1](...) end end
	end
	return event
end
local function fixture()
	local f = { now = 100, blocked = false, profiles = {}, registered = {}, awards = {} }
	local parent = roblox.Instance.new("Workspace")
	local grove = roblox.Instance.new("Model")
	grove:SetAttribute("ArenaCenter", Vector3.new(100, 0, -200))
	grove:SetAttribute("ArenaRadius", 30)
	grove:SetAttribute("EntryPosition", Vector3.new(100, 3, -178))
	local stone = roblox.Instance.new("Part")
	stone.CFrame = CFrame.new(82, 3, -172)
	local prompt = { Parent = stone, Triggered = signal() }
	local groveProxy = {
		GetAttribute = function(_, name) return grove:GetAttribute(name) end,
		FindFirstChild = function(_, name) assert(name == "ChallengeBriarwarden"); return prompt end,
	}
	local remotes = {}
	local state = { messages = {} }
	function state:IsDescendantOf() return true end
	function state:FireClient(player, data) table.insert(self.messages, { player = player, data = data }) end
	function state:Destroy() self.destroyed = true end
	local storage = { WaitForChild = function() return { ProgressionRules = Progression } end }
	local game = { GetService = function(_, name) return if name == "ReplicatedStorage" then storage else {} end }
	local physics = { Raycast = function()
		return if f.blocked then { Instance = { IsDescendantOf = function() return false end } } else nil
	end }
	local combat = {}
	function combat:registerTarget(model) f.registered[model:GetAttribute("TargetId")] = model end
	function combat:unregisterTarget(id) f.registered[id] = nil end
	local env = setmetatable({ game = game, workspace = parent, Vector3 = Vector3, CFrame = CFrame,
		Enum = roblox.Enum, Color3 = roblox.Color3, UDim2 = roblox.UDim2,
		RaycastParams = { new = function() return {} end }, require = function(value) return value end,
		Instance = { new = function(class) return if class == "RemoteEvent" then state else roblox.Instance.new(class) end },
	}, { __index = getfenv() })
	local factory = assert(loadstring(fs.readFile("src/server/BossService.luau"), "BossService"))
	setfenv(factory, env)
	f.Service = factory()
	f.service = f.Service.new(f.profiles, combat, groveProxy, { autoStep = false, worldParent = parent,
		remotes = remotes, now = function() return f.now end, physics = physics,
		canAct = function(player) return not player.paused end,
		canChallenge = function(player) return player.unlocked end,
		onDefeat = function(player) f.awards[player] = (f.awards[player] or 0) + 1 end,
	})
	f.parent, f.state, f.prompt, f.stone = parent, state, prompt, stone
	function f:addPlayer(id)
		local root = roblox.Instance.new("Part")
		root.CFrame = stone.CFrame
		local humanoid = { Health = 100, damage = 0 }
		function humanoid:TakeDamage(amount) self.damage += amount; self.Health = math.max(0, self.Health - amount) end
		local attributes = {}
		local character = {}
		function character:FindFirstChild(name) return if name == "HumanoidRootPart" then root else nil end
		function character:FindFirstChildOfClass(name) return if name == "Humanoid" then humanoid else nil end
		function character:GetAttribute(name) return attributes[name] end
		function character:SetAttribute(name, value) attributes[name] = value end
		function character:PivotTo(cf) root.CFrame = cf end
		local player = { UserId = id or 1, Character = character, root = root, humanoid = humanoid, unlocked = true }
		self.profiles[player] = Progression.newProfile("Sentinel")
		return player
	end
	function f:step(seconds)
		self.now += seconds
		self.service:step(self.now, math.min(seconds, 0.5))
	end
	function f:move(player, offset) player.root.CFrame = CFrame.new(self.service.home + offset) end
	function f:hit(player, damage)
		local hp = math.max(0, self.service.model:GetAttribute("Health") - damage)
		self.service.model:SetAttribute("Health", hp)
		self.service:onDamaged(player, self.service.model, damage, hp == 0)
	end
	return f
end
local passed = 0
local function test(name, callback)
	local ok, errorMessage = pcall(callback)
	if not ok then error("FAIL " .. name .. ": " .. tostring(errorMessage), 0) end
	passed += 1
	print("PASS " .. name)
end

test("original dormant guardian registers bounded noninteractive geometry", function()
	local f = fixture(); local service = f.service
	assert(f.registered.boss_briarwarden == service.model)
	assert(service.model:GetAttribute("Boss") and service.model:GetAttribute("Enemy"))
	assert(not service.model.PrimaryPart.CanQuery and not service.active)
	local count = 0
	for _, object in service.model:GetDescendants() do
		if object:IsA("BasePart") then
			count += 1
			assert(object.Anchored and not object.CanCollide and not object.CanTouch)
			for _, component in { object.CFrame:GetComponents() } do assert(component == component and math.abs(component) < math.huge) end
		else assert(not object:IsA("LuaSourceContainer") and not object:IsA("MeshPart") and not object:IsA("Sound")) end
	end
	assert(count >= 12 and count <= 30)
	service:destroy()
end)

test("challenge prompt validates quest gate, save ownership, life and distance", function()
	for _, reason in { "locked", "paused", "dead", "distance" } do
		local f = fixture(); local player = f:addPlayer()
		if reason == "locked" then player.unlocked = false elseif reason == "paused" then player.paused = true
		elseif reason == "dead" then player.humanoid.Health = 0 else player.root.CFrame = CFrame.new(0, 3, 0) end
		assert(not f.service:challenge(player) and not f.service.active and f.service.joined == 0)
		f.service:destroy()
	end
end)

test("challenge enrolls, teleports safely and rejects nonparticipant attacks", function()
	local f = fixture(); local player, outsider = f:addPlayer(1), f:addPlayer(2)
	assert(f.service:challenge(player))
	assert(player.root.CFrame.Position == f.service.entryPosition)
	assert(f.service:canTarget(player, f.service.model))
	assert(not f.service:canTarget(outsider, f.service.model))
	assert(f.service.model.PrimaryPart.CanQuery)
	f.service:destroy()
end)

test("party joining preserves health ratio and repeat joins never heal or inflate scaling", function()
	local f = fixture(); local first, second = f:addPlayer(1), f:addPlayer(2)
	assert(f.service:challenge(first)); f:hit(first, 325)
	assert(f.service:challenge(second))
	assert(f.service.model:GetAttribute("MaxHealth") == 942)
	assert(f.service.model:GetAttribute("Health") == 471)
	f.now += 2; first.root.CFrame = f.stone.CFrame
	assert(f.service:challenge(first) and f.service.joined == 2)
	assert(f.service.model:GetAttribute("Health") == 471)
	f.service:removePlayer(first); f.profiles[first] = nil
	local returned = f:addPlayer(1)
	assert(f.service:challenge(returned) and f.service.joined == 2)
	f.service:destroy()
end)

test("branch sweep telegraphs before damage and moving behind avoids it", function()
	local f = fixture(); local player = f:addPlayer()
	assert(f.service:challenge(player)); f:move(player, Vector3.new(0, 0, 7))
	f:step(1.5)
	assert(f.service.phase == "SweepWindup" and player.humanoid.damage == 0)
	assert(f.service.model:GetAttribute("Warning"):find("BRANCH SWEEP", 1, true))
	f:step(1.19); assert(player.humanoid.damage == 0)
	f:move(player, Vector3.new(0, 0, -7)); f:step(0.02)
	assert(player.humanoid.damage == 0 and f.service.phase == "Recover")
	f.service:destroy()
end)

test("remaining in sweep cone damages only enrolled living participants", function()
	local f = fixture(); local player, outsider = f:addPlayer(1), f:addPlayer(2)
	assert(f.service:challenge(player)); f:move(player, Vector3.new(0, 0, 7)); f:move(outsider, Vector3.new(0, 0, 7))
	f:step(1.5); f:step(1.21)
	assert(player.humanoid.damage > 0 and player.humanoid.damage <= 16)
	assert(outsider.humanoid.damage == 0)
	f.service:destroy()
end)

test("LOS obstruction and spawn protection each prevent sweep damage", function()
	for _, reason in { "wall", "spawn" } do
		local f = fixture(); local player = f:addPlayer()
		assert(f.service:challenge(player)); f:move(player, Vector3.new(0, 0, 7))
		f:step(1.5)
		if reason == "wall" then f.blocked = true else player.Character:SetAttribute("AetherfallSpawnProtectedUntil", f.now + 3) end
		f:step(1.21); assert(player.humanoid.damage == 0)
		f.service:destroy()
	end
end)

test("root marker stays at cast position and leaving it avoids impact", function()
	local f = fixture(); local player = f:addPlayer()
	assert(f.service:challenge(player)); f:move(player, Vector3.new(0, 0, 16))
	f:step(1.5); f:step(1.21); f:step(0.81)
	assert(f.service.phase == "RootWindup")
	local mark = f.service.rootPosition
	f:move(player, Vector3.new(12, 0, 16)); f:step(1.41)
	assert(f.service.rootPosition == mark and player.humanoid.damage == 0)
	assert(f.service.phase == "Exposed" and f.service.model:GetAttribute("Defence") == 0)
	f.service:destroy()
end)

test("remaining in marked roots takes damage and then gets a four-second core window", function()
	local f = fixture(); local player = f:addPlayer()
	assert(f.service:challenge(player)); f:move(player, Vector3.new(0, 0, 16))
	f:step(1.5); f:step(1.21); f:step(0.81); f:step(1.41)
	assert(player.humanoid.damage > 0 and f.service.phase == "Exposed")
	f:step(3.99); assert(f.service.phase == "Exposed")
	f:step(0.02); assert(f.service.phase == "SweepWindup" and f.service.model:GetAttribute("Defence") == 25)
	f.service:destroy()
end)

test("boss windups ignore normal-enemy Shield Bash stun", function()
	local f = fixture(); local player = f:addPlayer()
	assert(f.service:challenge(player)); f:move(player, Vector3.new(0, 0, 7)); f:step(1.5)
	f.service.model:SetAttribute("StunnedUntil", f.now + 20)
	f:step(1.21)
	assert(player.humanoid.damage > 0 and f.service.phase == "Recover")
	f.service:destroy()
end)

test("victory credits recent enrolled contributors once including nearby defeated allies", function()
	local f = fixture(); local first, second, outsider = f:addPlayer(1), f:addPlayer(2), f:addPlayer(3)
	assert(f.service:challenge(first)); assert(f.service:challenge(second))
	f:hit(first, 10); second.humanoid.Health = 0
	f.service.contributors[second] = f.now
	f.service.contributors[outsider] = f.now
	f:hit(first, 2000)
	assert(f.awards[first] == 1 and f.awards[second] == 1 and f.awards[outsider] == nil)
	assert(f.service.phase == "Defeated" and not f.service.model.PrimaryPart.CanQuery)
	f.service:onDamaged(first, f.service.model, 2000, true)
	assert(f.awards[first] == 1)
	f:step(20); assert(f.service.phase == "Dormant" and f.service.model:GetAttribute("Health") == 650)
	f.service:destroy()
end)

test("stale, distant, removed and paused contributors receive no victory rewards", function()
	local f = fixture(); local first, second = f:addPlayer(1), f:addPlayer(2)
	assert(f.service:challenge(first)); assert(f.service:challenge(second)); f:hit(second, 10)
	f.service.contributors[second] = f.now - 61
	f:hit(first, 2000)
	assert(f.awards[first] == 1 and f.awards[second] == nil)
	f.service:destroy()
	for _, reason in { "distant", "removed", "paused" } do
		f = fixture(); first, second = f:addPlayer(1), f:addPlayer(2)
		assert(f.service:challenge(first)); assert(f.service:challenge(second)); f:hit(second, 10)
		if reason == "distant" then second.root.CFrame = CFrame.new(0, 3, 0)
		elseif reason == "removed" then f.service:removePlayer(second) else second.paused = true end
		f:hit(first, 2000); assert(f.awards[second] == nil)
		f.service:destroy()
	end
end)

test("complete wipe resets after three seconds without awarding or duplicating participants", function()
	local f = fixture(); local player = f:addPlayer()
	assert(f.service:challenge(player)); f:hit(player, 30)
	player.humanoid.Health = 0
	f:step(0.2); f:step(2.99); assert(f.service.active)
	f:step(0.02)
	assert(not f.service.active and f.service.phase == "Dormant" and f.service.joined == 0)
	assert(next(f.awards) == nil and f.service.model:GetAttribute("Health") == 650)
	assert(not f.service:challenge(player))
	f.service:destroy()
end)

test("lost authority and leaving arena reject damage even after enrollment", function()
	local f = fixture(); local player = f:addPlayer()
	assert(f.service:challenge(player)); player.paused = true
	assert(not f.service:canTarget(player, f.service.model))
	player.paused = false; f:move(player, Vector3.new(40, 0, 0))
	assert(not f.service:canTarget(player, f.service.model))
	f.service:destroy()
end)

test("removal, malformed damage and destruction cannot create rewards or orphan targets", function()
	local f = fixture(); local player = f:addPlayer()
	assert(f.service:challenge(player))
	f.service:onDamaged(player, f.service.model, 0/0, true)
	assert(next(f.awards) == nil)
	f.service:removePlayer(player)
	assert(not f.service:canTarget(player, f.service.model))
	f.service:destroy(); f.service:destroy()
	assert(f.registered.boss_briarwarden == nil and f.state.destroyed and f.prompt.Triggered.listeners[1][2].Connected == false)
end)
test("sweep warning conservatively contains every damaging half-disc point", function()
	local f = fixture(); local player = f:addPlayer()
	assert(f.service:challenge(player)); f:move(player, Vector3.new(0, 0, 7)); f:step(1.5)
	local direction = f.service.sweepDirection
	local right = Vector3.new(-direction.Z, 0, direction.X)
	for angle = -90, 90, 10 do
		local offset = direction * math.cos(math.rad(angle)) * 11 + right * math.sin(math.rad(angle)) * 11
		local point = f.service.center + offset + Vector3.new(0, 0.16, 0)
		local localPoint = f.service.marker.CFrame:PointToObjectSpace(point)
		assert(math.abs(localPoint.X) <= f.service.marker.Size.X / 2 + 0.001)
		assert(math.abs(localPoint.Z) <= f.service.marker.Size.Z / 2 + 0.001)
	end
	f.service:destroy()
end)

test("distant wiped participants receive closure state instead of a stuck active HUD", function()
	local f = fixture(); local player = f:addPlayer()
	assert(f.service:challenge(player))
	player.root.CFrame = CFrame.new(0, 3, 15)
	f:step(0.2); f:step(3.01)
	local latest
	for _, sent in f.state.messages do if sent.player == player then latest = sent.data end end
	assert(latest and latest.active == false and latest.eligible == false and latest.phase == "Dormant")
	assert(type(latest.message) == "string" and latest.encounterId == 2)
	f.service:destroy()
end)

test("nearby challenge gate failures report a private actionable message without enrolling", function()
	local f = fixture(); local player, other = f:addPlayer(1), f:addPlayer(2)
	f.service.options.canChallenge = function() return false, "Reach level 3 before challenging Briarwarden." end
	assert(not f.service:challenge(player) and f.service.joined == 0 and not f.service.active)
	assert(#f.state.messages == 1)
	local sent = f.state.messages[1]
	assert(sent.player == player and sent.player ~= other and sent.data.eligible == false)
	assert(sent.data.message == "Reach level 3 before challenging Briarwarden.")
	assert(not f.service:challenge(player) and #f.state.messages == 1, "Gate feedback must be rate-limited")
	f.service:destroy()
end)

test("entry grace applies once per character and encounter without gate renewal", function()
	local f = fixture(); local player = f:addPlayer()
	assert(f.service:challenge(player))
	local deadline = player.Character:GetAttribute("AetherfallSpawnProtectedUntil")
	assert(deadline == f.now + 1.5 and player.Character:GetAttribute("AetherfallBossEntryEncounter") == 1)
	f.now += 1.1; player.root.CFrame = f.stone.CFrame
	assert(f.service:challenge(player))
	assert(player.Character:GetAttribute("AetherfallSpawnProtectedUntil") == deadline)
	f.service:_reset(f.now); f.now += 5.1; player.root.CFrame = f.stone.CFrame
	assert(f.service:challenge(player))
	assert(player.Character:GetAttribute("AetherfallBossEntryEncounter") == 2)
	assert(player.Character:GetAttribute("AetherfallSpawnProtectedUntil") == f.now + 1.5)
	f.service:destroy()
end)

test("late entry onto a nearly resolved root warning is protected only for its grace window", function()
	local f = fixture(); local first, late = f:addPlayer(1), f:addPlayer(2)
	assert(f.service:challenge(first)); f:move(first, Vector3.new(0, 0, 22))
	f:step(1.5); f:step(1.21); f:step(0.81)
	assert(f.service.phase == "RootWindup")
	f:step(1.2); assert(f.service:challenge(late)); f:step(0.21)
	assert(late.humanoid.damage == 0, "A new arrival must not take an almost-finished cast")
	f:step(4.01)
	assert(f.service.phase == "SweepWindup")
	f:move(late, Vector3.new(0, 0, 7)); f:step(1.21)
	assert(late.humanoid.damage > 0, "Entry protection must not persist after its deadline")
	f.service:destroy()
end)

print(passed .. " Briarwarden encounter tests passed with mocked network, time and physics; Studio play remains pending.")
