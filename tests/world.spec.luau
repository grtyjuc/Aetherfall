-- Data-model construction checks only; Studio rendering, collisions and input are manual checks.
-- Run from repository root: .tools/lune run tests/world.spec.luau
local fs = require("@lune/fs")
local roblox = require("@lune/roblox")
local Catalog = require("../src/shared/EquipmentCatalog")

local workspace = roblox.Instance.new("Workspace")
local environment = setmetatable({
	Instance = roblox.Instance,
	Enum = roblox.Enum,
	Vector3 = roblox.Vector3,
	CFrame = roblox.CFrame,
	Color3 = roblox.Color3,
	UDim2 = roblox.UDim2,
	workspace = workspace,
}, { __index = getfenv() })

local function loadModule(path)
	local factory = assert(loadstring(fs.readFile(path), path))
	setfenv(factory, environment)
	return factory()
end

local Models = loadModule("src/shared/EquipmentModels.luau")
local World = loadModule("src/server/WorkshopWorld.luau")
local existingContent = roblox.Instance.new("Part")
existingContent.Name = "PreservedContent"
existingContent.Parent = workspace

local world = World.build(Catalog, Models)
assert(world.ClassName == "Model" and world.Name == "AetherfallWorkshop", "Incorrect world identity")
assert(world.Parent == workspace and world.PrimaryPart:IsDescendantOf(world), "Detached world or PrimaryPart")
assert(existingContent.Parent == workspace, "World construction altered existing content")

local function finite(value)
	return value == value and math.abs(value) < math.huge
end

-- This whitelist excludes scripts, external meshes/textures, audio and particle assets.
local allowedClasses = {
	Model = true, Part = true, WedgePart = true, SpawnLocation = true,
	PointLight = true, SurfaceGui = true, TextLabel = true, ProximityPrompt = true,
}
local parts, displays = 0, 0
for _, object in world:GetDescendants() do
	assert(allowedClasses[object.ClassName], "Unexpected world content: " .. object.ClassName)
	if object:IsA("BasePart") then
		parts += 1
		assert(object.Anchored, "Unanchored workshop part: " .. object.Name)
		for _, axis in { object.Size.X, object.Size.Y, object.Size.Z } do
			assert(finite(axis) and axis > 0 and axis <= 106, "Invalid part scale: " .. object.Name)
		end
		for _, component in { object.CFrame:GetComponents() } do
			assert(finite(component), "Non-finite world transform: " .. object.Name)
		end
		assert(object.CFrame.Position.Magnitude < 60, "Geometry center exceeds courtyard bounds: " .. object.Name)
	end
end
assert(parts >= 150 and parts < 400, "Incomplete world or excessive part count: " .. parts)

for _, object in world:GetChildren() do
	if object:IsA("Model") and string.sub(object.Name, 1, 8) == "Display_" then
		displays += 1
		local id = string.sub(object.Name, 9)
		assert(Catalog.Items[id] and object.PrimaryPart, "Display has no catalog item or handle")
		for _, part in object:GetDescendants() do
			assert(part:IsA("BasePart") and not part.CanCollide, "Display must remain cosmetic")
		end
	end
end
assert(displays == 6, "Expected six distinct equipment displays")

local prompt = assert(world:FindFirstChild("OpenEquipment", true), "Missing equipment interaction")
assert(prompt.ClassName == "ProximityPrompt", "Wrong equipment interaction type")
assert(prompt.ActionText == "Inspect equipment" and prompt.ObjectText == "Hearthglen Workshop", "Incorrect interaction text")
assert(prompt.MaxActivationDistance == 12 and not prompt.RequiresLineOfSight, "Incorrect interaction reach")
local spawn = assert(world:FindFirstChild("WorkshopSpawn"), "Missing player spawn")
assert(spawn:IsA("SpawnLocation") and spawn.Neutral, "Spawn must accept all classes")
assert(spawn.Position == roblox.Vector3.new(0, 1, 15), "Incorrect spawn position")
assert(spawn.Duration == 0, "Workshop spawn should not add a force field")

local descendantCount = #world:GetDescendants()
assert(World.build(Catalog, Models) == world, "Repeated build replaced the workshop")
assert(#world:GetDescendants() == descendantCount and #workspace:GetChildren() == 2, "Repeated build duplicated content")

-- Refuse to replace an unrelated object using the reserved world name.
world.Name = "PreservedWorkshop"
local conflictingObject = roblox.Instance.new("Folder")
conflictingObject.Name = "AetherfallWorkshop"
conflictingObject.Parent = workspace
assert(not pcall(World.build, Catalog, Models), "Conflicting content must fail explicitly")
assert(conflictingObject.Parent == workspace and world.Parent == workspace, "Conflict handling destroyed content")

print("Workshop constructed: " .. parts .. " anchored parts; six catalog displays; finite transforms; no external assets.")
print("PASS equipment prompt, neutral spawn, preserved content, repeatable build and reserved-name conflict handling.")
