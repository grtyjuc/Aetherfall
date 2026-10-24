-- Installment 2: session-only equipment and training combat, not a production save service.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

-- The catalogue is intentionally granted for testing. Never grant it in a published game.
if not RunService:IsStudio() then
	warn("Aetherfall equipment workshop is Studio-only; production gameplay is not implemented.")
	return
end

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Catalog = require(Shared.EquipmentCatalog)
local Rules = require(Shared.EquipmentRules)
local Models = require(Shared.EquipmentModels)
local World = require(script.Parent.WorkshopWorld)
local TrainingWorld = require(script.Parent.TrainingWorld)
local CombatService = require(script.Parent.CombatService)
local Visuals = require(script.Parent.EquipmentVisuals)

local remotes = Instance.new("Folder")
remotes.Name = "WorkshopRemotes"
local request = Instance.new("RemoteFunction")
request.Name = "EquipmentRequest"
request.Parent = remotes
local open = Instance.new("RemoteEvent")
open.Name = "OpenEquipment"
open.Parent = remotes

local profiles = {}
local buckets = {}
local visualConnections = {}
local shuttingDown = false
local world = World.build(Catalog, Models)
local trainingWorld = TrainingWorld.build()
local combat = CombatService.new(profiles, remotes, trainingWorld)

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
	if shuttingDown or profiles[player] then return end
	profiles[player] = Rules.newProfile("Sentinel", 10, true)
	buckets[player] = { tokens = 8, time = os.clock() }
	combat:addPlayer(player)
	visualConnections[player] = player.CharacterAdded:Connect(function(character)
		attachCharacter(player, character)
	end)
	if player.Character then attachCharacter(player, player.Character) end
end
local addedConnection = Players.PlayerAdded:Connect(addPlayer)
local removingConnection = Players.PlayerRemoving:Connect(function(player)
	combat:removePlayer(player)
	if visualConnections[player] then visualConnections[player]:Disconnect() end
	visualConnections[player] = nil
	profiles[player] = nil
	buckets[player] = nil
end)
for _, player in Players:GetPlayers() do
	addPlayer(player)
end

request.OnServerInvoke = function(player, action, first, second)
	if shuttingDown then return { ok = false, message = "Workshop is shutting down." } end
	local bucket = buckets[player]
	local profile = profiles[player]
	if not bucket or not profile then
		return { ok = false, message = "Your workshop session is not ready." }
	end
	local now = os.clock()
	bucket.tokens = math.min(8, bucket.tokens + (now - bucket.time) * 4)
	bucket.time = now
	if bucket.tokens < 1 then
		return { ok = false, message = "Please wait a moment before another equipment action." }
	end
	bucket.tokens -= 1
	if type(action) ~= "string" or #action > 16
		or (first ~= nil and (type(first) ~= "string" or #first > 64))
		or (second ~= nil and (type(second) ~= "string" or #second > 32)) then
		return { ok = false, message = "Invalid equipment request." }
	end
	local ok, message = false, "Unknown equipment action."
	if action == "Snapshot" then
		ok, message = true, "Workshop inventory loaded."
	elseif action == "Equip" then
		ok, message = Rules.equip(profile, first, second)
	elseif action == "Unequip" then
		ok, message = Rules.unequip(profile, first)
	elseif action == "Class" then
		ok, message = Rules.setClass(profile, first)
	end
	if ok and action ~= "Snapshot" then
		combat:equipmentChanged(player, action == "Class")
		if player.Character then Visuals.apply(player.Character, profile) end
	end
	return { ok = ok, message = message, state = Rules.snapshot(profile) }
end

local prompt = world:FindFirstChild("OpenEquipment", true)
local promptConnection
if prompt then
	promptConnection = prompt.Triggered:Connect(function(player)
		open:FireClient(player)
	end)
end
-- Expose networking only after handlers, profiles, and the world exist.
remotes.Parent = ReplicatedStorage
script.Destroying:Connect(function()
	shuttingDown = true
	addedConnection:Disconnect()
	removingConnection:Disconnect()
	if promptConnection then promptConnection:Disconnect() end
	combat:destroy()
	for _, connection in visualConnections do connection:Disconnect() end
	for player in profiles do
		if player.Character then Visuals.clear(player.Character) end
	end
	table.clear(visualConnections)
	table.clear(profiles)
	table.clear(buckets)
	remotes:Destroy()
end)
print("Aetherfall installment 2: equipment and combat training ready (Studio, session only).")
