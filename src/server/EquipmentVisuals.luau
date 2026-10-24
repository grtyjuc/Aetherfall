-- Server-created visual attachments. Inventory authority stays with EquipmentRules.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Catalog = require(Shared.EquipmentCatalog)
local Models = require(Shared.EquipmentModels)

local EquipmentVisuals = {}
local FOLDER_NAME = "AetherfallEquipment"
local OWNER_ATTRIBUTE = "AetherfallOwnedVisuals"

local function ownedFolder(character)
	local folder = character:FindFirstChild(FOLDER_NAME)
	return if folder and folder:GetAttribute(OWNER_ATTRIBUTE) == true then folder else nil
end

function EquipmentVisuals.clear(character)
	if not character or not character:IsA("Model") then return end
	local folder = ownedFolder(character)
	if folder then folder:Destroy() end
end

local function definition(profile, slot)
	if type(profile) ~= "table" or type(profile.inventory) ~= "table" or type(profile.equipped) ~= "table" then
		return nil
	end
	local uid = profile.equipped[slot]
	local instance = if uid then profile.inventory[uid] else nil
	local item = if instance then Catalog.Items[instance.itemId] else nil
	if not item or item.slot ~= slot or type(profile.level) ~= "number" or profile.level < item.level
		or not table.find(item.classes, profile.className) then return nil end
	return item
end

local function limb(character, first, fallback)
	local result = character:FindFirstChild(first) or character:FindFirstChild(fallback)
	return if result and result:IsA("BasePart") then result else nil
end

local function mount(folder, bodyPart, item, slot, c0, motorName)
	local model = Models.create(item)
	model.Name = slot
	model:SetAttribute("ItemId", item.id)
	local handle = model.PrimaryPart
	local initialHandle = handle.CFrame
	local desiredHandle = bodyPart.CFrame * c0
	-- Transform each piece relative to the real grip, which is not always the model origin.
	for _, object in model:GetDescendants() do
		if object:IsA("BasePart") then
			object.CFrame = desiredHandle * initialHandle:ToObjectSpace(object.CFrame)
			object.Anchored = false
			object.Massless = true
			object.CanCollide = false
			object.CanTouch = false
			object.CanQuery = false
			if object ~= handle then
				local weld = Instance.new("WeldConstraint")
				weld.Name = "VisualWeld"
				weld.Part0 = handle
				weld.Part1 = object
				weld.Parent = object
			end
		end
	end
	local motor = Instance.new("Motor6D")
	motor.Name = motorName
	motor.Part0 = bodyPart
	motor.Part1 = handle
	motor.C0 = c0
	motor.C1 = CFrame.identity
	motor:SetAttribute("DefaultC0", c0)
	motor.Parent = handle
	model.Parent = folder
end

local function mainGrip(item)
	if item.family == "Bow" then
		return CFrame.new(0, -0.1, -0.35) * CFrame.Angles(0, math.pi / 2, 0)
	elseif item.family == "Crossbow" then
		return CFrame.new(0, -0.1, -0.3)
	elseif item.family == "Staff" then
		return CFrame.new(0, -0.15, -0.25) * CFrame.Angles(math.rad(-40), 0, 0)
	end
	return CFrame.new(0, -0.1, -0.25) * CFrame.Angles(math.rad(-65), 0, 0)
end

local function handOffset(bodyPart, grip)
	-- R6 arms contain the whole forearm/hand; R15 hand parts already have a hand-centred pivot.
	if bodyPart.Name == "Right Arm" or bodyPart.Name == "Left Arm" then
		return CFrame.new(0, -math.max(0, bodyPart.Size.Y / 2 - 0.1), 0) * grip
	end
	return grip
end

function EquipmentVisuals.apply(character, profile)
	if not character or not character:IsA("Model") then return false, "Missing character." end
	local collision = character:FindFirstChild(FOLDER_NAME)
	if collision and collision:GetAttribute(OWNER_ATTRIBUTE) ~= true then
		return false, "Equipment visual folder name is already in use."
	end
	EquipmentVisuals.clear(character)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid and humanoid.Health <= 0 then return false, "Character is defeated." end
	local folder = Instance.new("Folder")
	folder.Name = FOLDER_NAME
	folder:SetAttribute(OWNER_ATTRIBUTE, true)
	local main = definition(profile, "MainHand")
	local off = definition(profile, "OffHand")
	local right = limb(character, "RightHand", "Right Arm")
	local left = limb(character, "LeftHand", "Left Arm")
	if main and right then mount(folder, right, main, "MainHand", handOffset(right, mainGrip(main)), "WeaponGrip") end
	if off then
		if off.family == "Quiver" then
			local torso = limb(character, "UpperTorso", "Torso")
			if torso then
				mount(folder, torso, off, "OffHand", CFrame.new(0.6, 0.2, 0.85) * CFrame.Angles(0, 0, math.rad(-12)), "QuiverGrip")
			end
		elseif left then
			local offset = if off.family == "Shield" then CFrame.new(-0.1, 0, -0.55)
				elseif off.family == "Lantern" then CFrame.new(0, -0.6, -0.2)
				else CFrame.new(0, 0, -0.35)
			-- Shields strap to the forearm; carried foci and lanterns belong at the hand.
			if off.family ~= "Shield" then offset = handOffset(left, offset) end
			mount(folder, left, off, "OffHand", offset, "OffHandGrip")
		end
	end
	folder.Parent = character
	return true, "Equipment visuals updated."
end

return table.freeze(EquipmentVisuals)
