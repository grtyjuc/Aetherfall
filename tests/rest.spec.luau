local fs = require("@lune/fs")
local roblox = require("@lune/roblox")
local signal = { callback = nil }
function signal:Connect(callback)
	self.callback = callback
	return { Disconnect = function() self.callback = nil end }
end
local well = roblox.Instance.new("Part")
well.Position = roblox.Vector3.new(0, 1, -81)
local prompt = { Parent = well, Triggered = signal }
local village = { FindFirstChild = function(_, name) assert(name == "RestAtWell"); return prompt end }
local root = roblox.Instance.new("Part")
root.Position = well.Position + roblox.Vector3.new(0, 2, 0)
local humanoid = { Health = 20, MaxHealth = 120 }
local player = { Character = {
	FindFirstChild = function(_, name) assert(name == "HumanoidRootPart"); return root end,
	FindFirstChildOfClass = function(_, name) assert(name == "Humanoid"); return humanoid end,
} }
local profiles, now, canAct, rests = { [player] = {} }, 100, true, 0
local Module = assert(loadstring(fs.readFile("src/server/RestService.luau")))()
local service = Module.new(profiles, village, {
	now = function() return now end, canAct = function() return canAct end,
	onRest = function(actor) assert(actor == player); rests += 1 end,
})
assert(service:rest(player) and humanoid.Health == 120 and rests == 1)
humanoid.Health = 30
assert(not service:rest(player) and humanoid.Health == 30, "Rest cooldown must be authoritative")
now += 10
root.Position = roblox.Vector3.new(80, 3, -81)
assert(not service:rest(player), "A forged prompt must not heal across the map")
root.Position = well.Position
canAct = false
assert(not service:rest(player), "Lost save sessions cannot heal")
canAct = true
humanoid.Health = 0
assert(not service:rest(player), "Rest cannot revive a defeated character")
humanoid.Health = 15
assert(service:rest(player) and rests == 2)
service:removePlayer(player)
assert(service.lastRest[player] == nil)
service:destroy()
assert(signal.callback == nil and not service:rest(player))
print("PASS village rest: proximity, alive state, save ownership, cooldown, removal and cleanup.")
