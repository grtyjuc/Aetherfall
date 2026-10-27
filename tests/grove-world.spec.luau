-- Construction/data-model checks only; live Studio navigation and rendering are separate.
local fs = require("@lune/fs")
local roblox = require("@lune/roblox")
local workspace = roblox.Instance.new("Workspace")
local environment = setmetatable({
	Instance = roblox.Instance, Enum = roblox.Enum, Vector3 = roblox.Vector3,
	CFrame = roblox.CFrame, Color3 = roblox.Color3, UDim2 = roblox.UDim2, workspace = workspace,
}, { __index = getfenv() })
local factory = assert(loadstring(fs.readFile("src/server/GroveWorld.luau"), "GroveWorld"))
setfenv(factory, environment)
local Grove = factory()
local existing = roblox.Instance.new("Model")
existing.Name = "PreviousVillage"
existing.Parent = workspace
local world = Grove.build()
assert(world:IsA("Model") and world.Name == "AetherfallGrove" and world.Parent == workspace)
assert(world:GetAttribute("GroveOwned") == true and world.PrimaryPart and world.PrimaryPart:IsDescendantOf(world))
assert(existing.Parent == workspace, "Existing content must be preserved")
local center = world:GetAttribute("ArenaCenter")
local radius = world:GetAttribute("ArenaRadius")
local entry = world:GetAttribute("EntryPosition")
assert(center == roblox.Vector3.new(100, 0, -200) and radius == 30)
assert(entry == roblox.Vector3.new(100, 3, -178) and (entry - center).Magnitude < radius)
local meadow = world.Scenery.GroveMeadow
assert(meadow.CanCollide and meadow.CanQuery, "Grove requires walkable, queryable ground")
assert(meadow.CFrame.Position.X - meadow.Size.X / 2 <= 55 and meadow.CFrame.Position.X + meadow.Size.X / 2 >= 145)
assert(meadow.CFrame.Position.Z - meadow.Size.Z / 2 <= -250 and meadow.CFrame.Position.Z + meadow.Size.Z / 2 >= -140)
assert(math.abs(meadow.CFrame.Position.Y + meadow.Size.Y / 2) < 0.001, "Ground must join the Y=0 field")
assert(entry.X > meadow.CFrame.Position.X - meadow.Size.X / 2 and entry.X < meadow.CFrame.Position.X + meadow.Size.X / 2)
assert(entry.Z > meadow.CFrame.Position.Z - meadow.Size.Z / 2 and entry.Z < meadow.CFrame.Position.Z + meadow.Size.Z / 2)
local expected = {
	InspectGroveRune = {parent="RuneStone", action="Inspect", position=roblox.Vector3.new(80, 3, -156)},
	ChallengeBriarwarden = {parent="ChallengeStone", action="Challenge", position=roblox.Vector3.new(82, 3, -172)},
}
for name, definition in expected do
	local prompt = world:FindFirstChild(name, true)
	assert(prompt and prompt:IsA("ProximityPrompt") and prompt.Parent.Name == definition.parent)
	assert(prompt.ActionText == definition.action and prompt.MaxActivationDistance == 10 and not prompt.RequiresLineOfSight)
	assert(prompt.Parent.CFrame.Position == definition.position)
	assert(not prompt.Parent.CanCollide, "Interactive stones should not block the entry route")
end
local count, trunks, roots, ringStones, approach = 0, 0, 0, 0, 0
local allowed = { Model=true, Folder=true, Part=true, WedgePart=true, ProximityPrompt=true, SurfaceGui=true, TextLabel=true }
for _, object in world:GetDescendants() do
	assert(allowed[object.ClassName], "Unexpected asset/script in grove: " .. object.ClassName)
	if object:IsA("BasePart") then
		count += 1
		assert(object.Anchored and not object.CanTouch, "Scenery must be static and touch-inactive")
		for _, value in {object.Size.X, object.Size.Y, object.Size.Z} do
			assert(value == value and value > 0 and value <= 120, "Invalid grove scale")
		end
		for _, component in {object.CFrame:GetComponents()} do
			assert(component == component and math.abs(component) < math.huge, "Nonfinite grove transform")
		end
		local cf, size = object.CFrame, object.Size
		local extentY = (math.abs(cf.RightVector.Y) * size.X + math.abs(cf.UpVector.Y) * size.Y
			+ math.abs(cf.LookVector.Y) * size.Z) / 2
		local offset = cf.Position - center
		local horizontal = roblox.Vector3.new(offset.X, 0, offset.Z).Magnitude
		assert(not object.CanCollide or cf.Position.Y + extentY <= 0.5 or horizontal >= radius,
			"Tall collision geometry blocks the arena interior: " .. object.Name)
		if object.Name == "AncientTrunk" then
			trunks += 1
			local delta = object.CFrame.Position - center
			assert(roblox.Vector3.new(delta.X, 0, delta.Z).Magnitude > radius + 5, "Trees must stand outside the arena")
		elseif object.Name == "AncientRoot" then
			roots += 1
			assert(not object.CanCollide and not object.CanQuery, "Decorative roots must not block attacks or dodges")
		elseif object.Name == "BrokenCircleStone" then
			ringStones += 1
			assert(not object.CanCollide)
		elseif object.Name == "FieldApproachStone" then approach += 1 end
	end
end
assert(count >= 100 and count <= 220, "Incomplete grove or part budget exceeded: " .. count)
assert(trunks == 6 and roots == 12 and ringStones == 12 and approach >= 7, "Missing original grove landmarks")
local descendants = #world:GetDescendants()
assert(Grove.build() == world and #world:GetDescendants() == descendants, "Repeated build must be idempotent")
assert(#workspace:GetChildren() == 2 and existing.Parent == workspace)
world.Name = "PreservedGrove"
local conflict = roblox.Instance.new("Folder")
conflict.Name = "AetherfallGrove"
conflict.Parent = workspace
assert(not pcall(Grove.build), "Name conflict must reject without deleting unrelated content")
assert(conflict.Parent == workspace and existing.Parent == workspace)
print("PASS grove world: " .. count .. " static parts, clear arena, six trees, root circle, two prompts, connected ground and repeatable construction.")
