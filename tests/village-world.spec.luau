-- Construction checks only. Studio rendering, collisions and navigation remain manual.
local fs = require("@lune/fs")
local roblox = require("@lune/roblox")
local workspace = roblox.Instance.new("Workspace")
local environment = setmetatable({
	Instance = roblox.Instance, Enum = roblox.Enum, Vector3 = roblox.Vector3,
	CFrame = roblox.CFrame, Color3 = roblox.Color3, UDim2 = roblox.UDim2,
	workspace = workspace,
}, { __index = getfenv() })
local factory = assert(loadstring(fs.readFile("src/server/VillageWorld.luau"), "VillageWorld"))
setfenv(factory, environment)
local VillageWorld = factory()
local existing = roblox.Instance.new("Model")
existing.Name = "ExistingWorkshop"
existing.Parent = workspace
local world = VillageWorld.build()
assert(world.Name == "AetherfallVillage" and world:IsA("Model") and world.Parent == workspace)
assert(world.PrimaryPart and world.PrimaryPart:IsDescendantOf(world), "Village requires a root")
assert(existing.Parent == workspace, "Existing workshop was altered")
local count = 0
local allowed = { Model = true, Folder = true, Part = true, WedgePart = true,
	SurfaceGui = true, TextLabel = true, BillboardGui = true, ProximityPrompt = true, PointLight = true }
for _, object in world:GetDescendants() do
	assert(allowed[object.ClassName], "Unexpected asset or script " .. object.ClassName)
	if object:IsA("BasePart") then
		count += 1
		assert(object.Anchored and not object.CanTouch, "Village part is simulated/touch-active")
		for _, axis in { object.Size.X, object.Size.Y, object.Size.Z } do
			assert(axis == axis and axis > 0 and axis <= 200, "Invalid village scale")
		end
		for _, component in { object.CFrame:GetComponents() } do
			assert(component == component and math.abs(component) < math.huge, "Nonfinite village geometry")
		end
		assert(object.CFrame.Position.Y >= -1 and object.CFrame.Position.Y < 20, "Unexpected terrain height")
	end
end
assert(count > 250 and count <= 500, "Incomplete village or exceeded part budget: " .. count)
local meadow = world.Scenery.VillageAndFieldMeadow
assert(meadow.CanCollide and meadow.CanQuery, "Ground must support characters/physics queries")
assert(math.abs(meadow.CFrame.Position.Y + meadow.Size.Y / 2) < 0.001, "Ground must align with existing Y=0 meadow")
assert(meadow.CFrame.Position.X - meadow.Size.X / 2 <= -55 and meadow.CFrame.Position.X + meadow.Size.X / 2 >= 135)
assert(meadow.CFrame.Position.Z - meadow.Size.Z / 2 <= -150 and meadow.CFrame.Position.Z + meadow.Size.Z / 2 >= -25)
local bypass = {}
for _, part in world.Scenery:GetChildren() do
	if part.Name == "WorkshopBypassPath" then
		table.insert(bypass, part)
		assert(part.CFrame.Position.X == 23 and part.CanCollide, "Approach must bypass the forge")
	end
end
assert(#bypass >= 14, "Missing connected approach path")
assert(#world.Buildings:GetChildren() == 5, "Need cottages and named inn")
for _, building in world.Buildings:GetChildren() do
	assert(building:IsA("Model") and building.PrimaryPart, "Building missing usable pivot")
	assert(building:FindFirstChild("DoorStep") and building:FindFirstChild("DoorLintel"), "Missing entrance")
	local frameCount, roofCount = 0, 0
	for _, part in building:GetChildren() do
		if part.Name == "DoorFrame" then frameCount += 1 end
		if part.Name == "SlopedRoof" then roofCount += 1 end
	end
	assert(frameCount == 2 and roofCount == 2, "Incomplete doorway/roof")
end
local expected = {
	Rowan = { prompt = "TalkRowan", display = "Elder Rowan", position = roblox.Vector3.new(0, 3.1, -65) },
	Blacksmith = { prompt = "TalkBlacksmith", display = "Smith Tessa", position = roblox.Vector3.new(-22, 3.1, -60) },
}
for name, data in expected do
	local npc = world.NPCs[name]
	assert(npc and npc:IsA("Model") and npc.PrimaryPart.Name == "Torso", "Missing NPC " .. name)
	assert((npc.PrimaryPart.CFrame.Position - data.position).Magnitude < 0.01, "Wrong NPC placement")
	local talk = npc.PrimaryPart:FindFirstChild(data.prompt)
	assert(talk and talk:IsA("ProximityPrompt") and talk.ActionText == "Talk" and talk.ObjectText == data.display)
	assert(talk.MaxActivationDistance == 10 and not talk.RequiresLineOfSight, "NPC prompt contract changed")
end
local rest = world:FindFirstChild("RestAtWell", true)
assert(rest and rest:IsA("ProximityPrompt") and rest.Parent.Name == "WellBasin", "Missing rest interaction")
assert(rest.MaxActivationDistance == 10 and rest.ActionText == "Rest")
local expectedSpawns = { slime_1 = "MeadowSlime", slime_2 = "MeadowSlime", boar_1 = "WildBoar", thorn_1 = "Thornling" }
local kinds = {}
local spawnCount = 0
for _, marker in world.EnemySpawns:GetChildren() do
	local id, kind = marker:GetAttribute("SpawnId"), marker:GetAttribute("EnemyKind")
	assert(expectedSpawns[id] == kind, "Unrecognized or changed spawn")
	expectedSpawns[id] = nil
	kinds[kind] = true
	spawnCount += 1
	assert(marker.Transparency == 1 and not marker.CanCollide and not marker.CanQuery and not marker.CanTouch)
	assert(marker.CFrame.Position.X >= 65 and marker.CFrame.Position.X <= 120, "Spawn enters village safe area")
	assert(marker.CFrame.Position.Z >= -130 and marker.CFrame.Position.Z <= -45)
end
assert(spawnCount == 4 and next(expectedSpawns) == nil, "Missing spawn markers")
assert(kinds.MeadowSlime and kinds.WildBoar and kinds.Thornling, "Missing enemy family")
local descendantCount = #world:GetDescendants()
assert(VillageWorld.build() == world and #world:GetDescendants() == descendantCount, "Village duplicated on repeated build")
assert(#workspace:GetChildren() == 2 and existing.Parent == workspace, "Build changed unrelated workspace content")
world.Name = "PreservedVillage"
local conflict = roblox.Instance.new("Folder")
conflict.Name = "AetherfallVillage"
conflict.Parent = workspace
assert(not pcall(VillageWorld.build), "Reserved-name conflict must fail")
assert(conflict.Parent == workspace and world.Parent == workspace and existing.Parent == workspace)
print("PASS Hearthglen village: " .. count .. " anchored parts, five enterable buildings, two NPCs, rest well, four enemy spawns and safe repeated construction.")
