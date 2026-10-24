-- Data-model construction checks, not Roblox engine rendering or physics tests.
-- Run from repository root: .tools/lune run tests/models.spec.luau
local fs = require("@lune/fs")
local roblox = require("@lune/roblox")
local Catalog = require("../src/shared/EquipmentCatalog")

local environment = setmetatable({
	Instance = roblox.Instance,
	Enum = roblox.Enum,
	Vector3 = roblox.Vector3,
	CFrame = roblox.CFrame,
	Color3 = roblox.Color3,
}, { __index = getfenv() })
local factory = assert(loadstring(fs.readFile("src/shared/EquipmentModels.luau"), "EquipmentModels"))
setfenv(factory, environment)
local Models = factory()

local passed = 0
local seenShapes = {}
local function finite(value)
	return value == value and math.abs(value) < math.huge
end

for _, id in Catalog.Order do
	local item = Catalog.Items[id]
	local model = Models.create(item)
	assert(model.ClassName == "Model" and model.Name == id, "Incorrect preview identity: " .. id)
	assert(model.PrimaryPart ~= nil, "Missing PrimaryPart: " .. id)
	assert(model.PrimaryPart.Name == "Handle", "PrimaryPart must be the Handle: " .. id)
	assert(model.PrimaryPart:IsDescendantOf(model), "Detached PrimaryPart: " .. id)
	local partCount = 0
	for _, object in model:GetDescendants() do
		-- The whitelist also excludes scripts, asset-backed meshes/textures, sounds, and emitters.
		assert(object.ClassName == "Part" or object.ClassName == "WedgePart",
			"Unexpected preview content: " .. id .. " / " .. object.ClassName)
		partCount += 1
		assert(object.Anchored, "Unanchored preview part: " .. id)
		assert(not object.CanCollide and not object.CanTouch and not object.CanQuery,
			"Interactive preview geometry: " .. id)
		for _, axis in {object.Size.X, object.Size.Y, object.Size.Z} do
			assert(finite(axis) and axis > 0 and axis <= 6, "Invalid preview scale: " .. id)
		end
		for _, component in {object.CFrame:GetComponents()} do
			assert(finite(component), "Non-finite preview transform: " .. id)
		end
		for _, channel in {object.Color.R, object.Color.G, object.Color.B} do
			assert(finite(channel) and channel >= 0 and channel <= 1, "Invalid preview color: " .. id)
		end
	end
	assert(partCount > 0 and partCount <= 30, "Part budget exceeded: " .. id .. " (" .. partCount .. ")")
	seenShapes[item.model.shape] = true
	model:Destroy()
	passed += 1
	print("PASS " .. id .. " (" .. partCount .. " parts)")
end

assert(passed == 36, "Expected all 36 catalog items to be constructed")
local expectedShapes = {
	"Sword", "Axe", "Mace", "Spear", "Greatsword", "Dagger", "Bow", "Crossbow", "Staff", "Wand",
	"Shield", "Focus", "Quiver", "Lantern", "Helmet", "Chest", "Gloves", "Boots", "Accessory",
}
for _, shape in expectedShapes do
	assert(seenShapes[shape], "Untested silhouette: " .. shape)
end

local invalid = table.clone(Catalog.Items[Catalog.Order[1]])
invalid.model = table.clone(invalid.model)
invalid.model.shape = "Unknown"
assert(not pcall(Models.create, invalid), "Unsupported silhouette must fail explicitly")
assert(not pcall(Models.create, nil), "Missing definition must fail explicitly")
print("36 equipment models constructed; 19 silhouettes covered; invalid definitions rejected.")
