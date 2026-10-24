-- Studio development build with isolated save data and server-owned gameplay.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
if not RunService:IsStudio() then
	warn("Aetherfall development build is Studio-only. Production launch is not configured.")
	return
end

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Catalog = require(Shared.EquipmentCatalog)
local Equipment = require(Shared.EquipmentRules)
local Progression = require(Shared.ProgressionRules)
local Models = require(Shared.EquipmentModels)
local World = require(script.Parent.WorkshopWorld)
local TrainingWorld = require(script.Parent.TrainingWorld)
local CombatService = require(script.Parent.CombatService)
local Visuals = require(script.Parent.EquipmentVisuals)
local PlayerDataService = require(script.Parent.PlayerDataService)
local TrainingRewards = require(script.Parent.TrainingRewards)
local remotes = Instance.new("Folder")
remotes.Name = "WorkshopRemotes"
local request = Instance.new("RemoteFunction")
request.Name = "EquipmentRequest"
request.Parent = remotes
local open = Instance.new("RemoteEvent")
open.Name = "OpenEquipment"
open.Parent = remotes
local profiles, buckets, visualConnections = {}, {}, {}
local shuttingDown = false
local world = World.build(Catalog, Models)
local trainingWorld = TrainingWorld.build()
local data, rewards, combat

data = PlayerDataService.new(profiles, { onStatus = function(player)
	if rewards then rewards:changed(player) end
end })
local function changed(player, classChanged)
	data:markDirty(player)
	combat:equipmentChanged(player, classChanged == true)
	if player.Character then Visuals.apply(player.Character, profiles[player]) end
	rewards:changed(player)
end
rewards = TrainingRewards.new(profiles, remotes, {
	getSaveStatus = function(player) return data:getStatus(player) end,
	onChanged = function(player) changed(player, false) end,
})
combat = CombatService.new(profiles, remotes, trainingWorld, {
	canAct = function(player) return not shuttingDown and data:getStatus(player).canPlay end,
	onAction = function(player, action, result) rewards:recordAction(player, action, result) end,
})

local function attachCharacter(player, character)
	task.spawn(function()
		if shuttingDown then return end
		local humanoid = character:WaitForChild("Humanoid", 10)
		if not humanoid or not humanoid:IsA("Humanoid") then return end
		local r15 = humanoid.RigType == Enum.HumanoidRigType.R15
		character:WaitForChild(if r15 then "RightHand" else "Right Arm", 10)
		character:WaitForChild(if r15 then "LeftHand" else "Left Arm", 10)
		if shuttingDown or player.Character ~= character or not profiles[player] then return end
		Visuals.apply(character, profiles[player])
	end)
end
local function addPlayer(player)
	if shuttingDown or buckets[player] then return end
	buckets[player] = { tokens = 8, time = os.clock() }
	rewards:addPlayer(player)
	visualConnections[player] = player.CharacterAdded:Connect(function(character)
		attachCharacter(player, character)
	end)
	task.spawn(function()
		local profile = data:load(player)
		if not profile then return end
		if shuttingDown or player.Parent ~= Players then data:removePlayer(player); return end
		combat:addPlayer(player)
		if player.Character then attachCharacter(player, player.Character) end
		rewards:changed(player)
	end)
end
local addedConnection = Players.PlayerAdded:Connect(addPlayer)
local removingConnection = Players.PlayerRemoving:Connect(function(player)
	combat:removePlayer(player)
	rewards:removePlayer(player)
	if visualConnections[player] then visualConnections[player]:Disconnect() end
	visualConnections[player] = nil
	buckets[player] = nil
	data:removePlayer(player)
end)

request.OnServerInvoke = function(player, action, first, second)
	if shuttingDown then return { ok = false, message = "Workshop is shutting down." } end
	local bucket, profile = buckets[player], profiles[player]
	if not bucket then return { ok = false, message = "Your character is not ready." } end
	local now = os.clock()
	bucket.tokens = math.min(8, bucket.tokens + (now - bucket.time) * 4)
	bucket.time = now
	if bucket.tokens < 1 then return { ok = false, message = "Please wait before another equipment action." } end
	bucket.tokens -= 1
	if type(action) ~= "string" or #action > 16
		or (first ~= nil and (type(first) ~= "string" or #first > 64))
		or (second ~= nil and (type(second) ~= "string" or #second > 32)) then
		return { ok = false, message = "Invalid equipment request." }
	end
	local status = data:getStatus(player)
	if not profile or not status.canPlay then
		return { ok = false, message = status.message, loading = status.mode == "Loading" }
	end
	local ok, message = false, "Unknown equipment action."
	if action == "Snapshot" then ok, message = true, "Inventory loaded."
	elseif action == "Equip" then ok, message = Equipment.equip(profile, first, second)
	elseif action == "Unequip" then ok, message = Equipment.unequip(profile, first)
	elseif action == "Class" then ok, message = Progression.selectClass(profile, first)
	end
	if ok and action ~= "Snapshot" then changed(player, action == "Class") end
	return { ok = ok, message = message, state = Progression.snapshot(profile) }
end
local prompt = world:FindFirstChild("OpenEquipment", true)
local promptConnection
if prompt then
	promptConnection = prompt.Triggered:Connect(function(player)
		if not shuttingDown then open:FireClient(player) end
	end)
end
remotes.Parent = ReplicatedStorage
for _, player in Players:GetPlayers() do addPlayer(player) end

local function shutdown()
	if shuttingDown then return end
	shuttingDown = true
	addedConnection:Disconnect()
	removingConnection:Disconnect()
	if promptConnection then promptConnection:Disconnect() end
	data:close()
	combat:destroy()
	rewards:destroy()
	for _, connection in visualConnections do connection:Disconnect() end
	for player in profiles do if player.Character then Visuals.clear(player.Character) end end
	table.clear(visualConnections)
	remotes:Destroy()
end
game:BindToClose(shutdown)
script.Destroying:Connect(shutdown)
print("Aetherfall: training progression ready; save mode is shown per player.")
