-- Attachment data-model checks. Roblox animation/physics and grip appearance need Studio.
local fs = require("@lune/fs")
local roblox = require("@lune/roblox")
local Catalog = require("../src/shared/EquipmentCatalog")
local Rules = require("../src/shared/EquipmentRules")
local environment = setmetatable({
	Instance = roblox.Instance, Enum = roblox.Enum, Vector3 = roblox.Vector3,
	CFrame = roblox.CFrame, Color3 = roblox.Color3,
}, { __index = getfenv() })
local function loadModule(path, extra)
	local env = setmetatable(extra or {}, { __index = environment })
	local factory = assert(loadstring(fs.readFile(path), path))
	setfenv(factory, env)
	return factory()
end
local Models = loadModule("src/shared/EquipmentModels.luau")
local shared = { EquipmentCatalog = "Catalog", EquipmentModels = "Models" }
local visuals = loadModule("src/server/EquipmentVisuals.luau", {
	game = { GetService = function(_, name)
		assert(name == "ReplicatedStorage")
		return { WaitForChild = function(_, child) assert(child == "Shared"); return shared end }
	end },
	require = function(module)
		if module == "Catalog" then return Catalog end
		if module == "Models" then return Models end
		error("Unexpected module")
	end,
})

local function character(rig)
	local model = roblox.Instance.new("Model")
	model.Name = rig
	for index, name in (if rig == "R15" then { "RightHand", "LeftHand", "UpperTorso" }
		else { "Right Arm", "Left Arm", "Torso" }) do
		local part = roblox.Instance.new("Part")
		part.Name = name
		part.Size = if rig == "R6" then roblox.Vector3.new(1, 2, 1) else roblox.Vector3.new(0.6, 0.6, 0.6)
		part.CFrame = roblox.CFrame.new(index * 2, 5, 3) * roblox.CFrame.Angles(0, 0.4, 0)
		part.Parent = model
	end
	local humanoid = roblox.Instance.new("Humanoid")
	humanoid.Health = 100
	humanoid.Parent = model
	return model
end
local function check(model, expectedModels)
	local folder = assert(model:FindFirstChild("AetherfallEquipment"))
	assert(#folder:GetChildren() == expectedModels, "Incorrect attachment count")
	local motors = 0
	for _, object in folder:GetDescendants() do
		if object:IsA("BasePart") then
			assert(not object.Anchored and object.Massless, "Attachment affects avatar physics")
			assert(not object.CanCollide and not object.CanQuery and not object.CanTouch, "Interactive attachment part")
			for _, component in { object.CFrame:GetComponents() } do
				assert(component == component and math.abs(component) < math.huge, "Invalid transform")
			end
			if object.Name ~= "Handle" then
				local weld = assert(object:FindFirstChild("VisualWeld"), "Unwelded visual part")
				assert(weld.Part0 == object.Parent.PrimaryPart and weld.Part1 == object)
			end
		elseif object:IsA("Motor6D") then
			motors += 1
			assert(object.Part0:IsDescendantOf(model) and object.Part1 == object.Parent, "Detached motor")
			assert(object.C0 == object:GetAttribute("DefaultC0"), "Missing animation reset pose")
		end
	end
	assert(motors == expectedModels, "Incorrect motor count")
end
local count = 0
for _, rig in { "R6", "R15" } do
	for _, className in Catalog.Classes do
		local model = character(rig)
		local profile = Rules.newProfile(className, 10, true)
		local unrelated = roblox.Instance.new("Accessory")
		unrelated.Name = "UserHat"
		unrelated.Parent = model
		assert(visuals.apply(model, profile))
		local expected = if className == "Ranger" then 1 else 2
		check(model, expected)
		local mainGrip = model.AetherfallEquipment.MainHand.Handle.WeaponGrip
		local expectedY = if rig == "R6" then -1 else -0.1
		assert(math.abs(mainGrip.C0.Position.Y - expectedY) < 0.0001, "Main weapon is not at the hand")
		if className == "Spellweaver" then
			local offGrip = model.AetherfallEquipment.OffHand.Handle.OffHandGrip
			assert(math.abs(offGrip.C0.Position.Y - (if rig == "R6" then -0.9 else 0)) < 0.0001,
				"Focus is not carried at the hand")
		elseif className == "Sentinel" then
			assert(model.AetherfallEquipment.OffHand.Handle.OffHandGrip.C0.Position.Y == 0,
				"Shield should remain strapped to forearm")
		end
		assert(visuals.apply(model, profile))
		check(model, expected)
		visuals.clear(model)
		assert(not model:FindFirstChild("AetherfallEquipment"))
		assert(model.UserHat == unrelated, "Unrelated avatar accessory deleted")
		for _, object in model:GetDescendants() do assert(not object:IsA("Motor6D"), "Orphan motor") end
		model:Destroy()
		count += 1
	end
end

-- A larger R6 arm also moves its grip to the hand, rather than using a fixed rig offset.
local tallR6 = character("R6")
tallR6["Right Arm"].Size = roblox.Vector3.new(1, 3, 1)
local lanternProfile = Rules.newProfile("Spellweaver", 10, true)
local lanternUid
for uid, item in lanternProfile.inventory do if item.itemId == "wayfarer_lantern" then lanternUid = uid end end
assert(Rules.equip(lanternProfile, lanternUid, "OffHand"))
assert(visuals.apply(tallR6, lanternProfile))
assert(math.abs(tallR6.AetherfallEquipment.MainHand.Handle.WeaponGrip.C0.Position.Y + 1.5) < 0.0001,
	"Scaled R6 arm grip does not follow limb length")
assert(math.abs(tallR6.AetherfallEquipment.OffHand.Handle.OffHandGrip.C0.Position.Y + 1.5) < 0.0001,
	"R6 lantern grip does not follow hand position")
tallR6:Destroy()

local model = character("R15")
local ranger = Rules.newProfile("Ranger", 10, true)
local quiverUid
for uid, item in ranger.inventory do if item.itemId == "trail_quiver" then quiverUid = uid end end
assert(Rules.equip(ranger, quiverUid, "OffHand"))
assert(visuals.apply(model, ranger))
check(model, 2)
local motor = model.AetherfallEquipment.OffHand.Handle.QuiverGrip
assert(motor.Part0 == model.UpperTorso, "Quiver is not mounted on torso")

-- Every weapon family must construct as a held model, even if not a class starter.
for _, id in Catalog.Order do
	local item = Catalog.Items[id]
	if item.slot == "MainHand" then
		local profile = Rules.newProfile(item.classes[1], 10, true)
		local uid
		for candidate, instance in profile.inventory do if instance.itemId == id then uid = candidate end end
		assert(Rules.equip(profile, uid, "MainHand"))
		assert(visuals.apply(model, profile))
		assert(model.AetherfallEquipment.MainHand:GetAttribute("ItemId") == id)
		check(model, if profile.equipped.OffHand then 2 else 1)
	end
end

-- Missing or dead avatars must not attach physics objects or delete unrelated content.
local empty = roblox.Instance.new("Model")
assert(visuals.apply(empty, ranger))
check(empty, 0)
empty:Destroy()
visuals.clear(model)
local reserved = roblox.Instance.new("Folder")
reserved.Name = "AetherfallEquipment"
reserved.Parent = model
assert(not visuals.apply(model, ranger))
visuals.clear(model)
assert(reserved.Parent == model, "Unowned reserved folder deleted")
reserved:Destroy()
model.Humanoid.Health = 0
assert(not visuals.apply(model, ranger))
assert(not model:FindFirstChild("AetherfallEquipment"))
assert(not visuals.apply(nil, ranger))
model:Destroy()
print("PASS attachment construction for " .. count .. " class/rig combinations, all defined weapons, quiver, idempotence and cleanup.")
