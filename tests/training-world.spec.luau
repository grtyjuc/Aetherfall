-- Construction/data-model checks, not live Roblox rendering or combat checks.
local fs = require("@lune/fs")
local roblox = require("@lune/roblox")
local workspace = roblox.Instance.new("Workspace")
local environment = setmetatable({
	Instance = roblox.Instance, Enum = roblox.Enum, Vector3 = roblox.Vector3,
	CFrame = roblox.CFrame, Color3 = roblox.Color3, UDim2 = roblox.UDim2,
	workspace = workspace,
}, { __index = getfenv() })
local factory = assert(loadstring(fs.readFile("src/server/TrainingWorld.luau"), "TrainingWorld"))
setfenv(factory, environment)
local TrainingWorld = factory()
local preserved = roblox.Instance.new("Part")
preserved.Name = "ExistingWorkshopContent"
preserved.Parent = workspace
local world = TrainingWorld.build()
assert(world:IsA("Model") and world.Name == "AetherfallTrainingGrounds", "Incorrect world identity")
assert(world.Parent == workspace and world.PrimaryPart:IsDescendantOf(world), "Missing world root")
assert(preserved.Parent == workspace, "Existing content was altered")
local targets = world:FindFirstChild("Targets")
assert(targets and targets:IsA("Folder") and #targets:GetChildren() == 3, "Need exactly three target models")
local identities, targetParts = {}, 0
for index, target in targets:GetChildren() do
	assert(target:IsA("Model"), "Target is not a Model")
	local id = target:GetAttribute("TargetId")
	assert(type(id) == "string" and not identities[id], "Duplicate or missing target identity")
	identities[id] = true
	assert(id == "dummy_" .. index, "Unstable target identity")
	assert(target:GetAttribute("Health") == 300 and target:GetAttribute("MaxHealth") == 300, "Unexpected health")
	assert(target:GetAttribute("Defence") == 10 and target:GetAttribute("DownUntil") == 0, "Unexpected target combat stats")
	assert(target.PrimaryPart and target.PrimaryPart.Name == "Hitbox", "PrimaryPart must be Hitbox")
	assert(target.PrimaryPart.CanQuery and target.PrimaryPart.CanCollide, "Hitbox must remain targetable and solid")
	local label = target.PrimaryPart:FindFirstChild("HealthText", true)
	assert(label and label:IsA("TextLabel") and label.Text == "300 / 300", "Missing health text")
	local count = 0
	for _, object in target:GetDescendants() do
		if object:IsA("BasePart") then
			count += 1
			if object ~= target.PrimaryPart then assert(not object.CanQuery, "Only torso should answer combat raycasts") end
		end
	end
	assert(count <= 30, "Dummy exceeds its part budget")
	targetParts += count
end
assert(identities.dummy_1 and identities.dummy_2 and identities.dummy_3, "Missing expected target IDs")
local closePair = false
local targetList = targets:GetChildren()
for first = 1, #targetList do
	for second = first + 1, #targetList do
		local spacing = (targetList[first].PrimaryPart.CFrame.Position - targetList[second].PrimaryPart.CFrame.Position).Magnitude
		assert(spacing >= 6, "Target pedestals must remain separate")
		if spacing <= 10 then closePair = true end
	end
end
assert(closePair, "At least one target pair must fit Flame Burst's radius")
local allowed = { Model = true, Folder = true, Part = true, BillboardGui = true, SurfaceGui = true, TextLabel = true }
local count = 0
for _, object in world:GetDescendants() do
	assert(allowed[object.ClassName], "Unexpected script or asset: " .. object.ClassName)
	if object:IsA("BasePart") then
		count += 1
		assert(object.Anchored and not object.CanTouch, "Training part is simulated or touch-active")
		for _, axis in { object.Size.X, object.Size.Y, object.Size.Z } do
			assert(axis == axis and axis > 0 and axis < 20, "Invalid scale")
		end
		for _, component in { object.CFrame:GetComponents() } do
			assert(component == component and math.abs(component) < math.huge, "Non-finite transform")
		end
		assert(object.CFrame.Position.Magnitude < 51, "Training geometry outside supported island bounds")
	end
end
assert(count > 60 and count <= 180, "Incomplete grounds or part budget exceeded")
local descendants = #world:GetDescendants()
assert(TrainingWorld.build() == world and #world:GetDescendants() == descendants, "Build is not idempotent")
assert(#workspace:GetChildren() == 2, "Repeated build duplicated world")
world.Name = "PreservedTrainingGrounds"
local conflict = roblox.Instance.new("Folder")
conflict.Name = "AetherfallTrainingGrounds"
conflict.Parent = workspace
assert(not pcall(TrainingWorld.build), "Reserved-name conflict must fail")
assert(conflict.Parent == workspace and world.Parent == workspace and preserved.Parent == workspace, "Conflict deleted existing content")
print("PASS training grounds: " .. count .. " anchored parts, 3 unique targets, " .. targetParts .. " dummy parts, health UI, finite geometry and safe repeatability.")
