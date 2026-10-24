-- Original, stationary training targets. CombatService owns their health and resets.
local TrainingWorld = {}

function TrainingWorld.build()
	local existing = workspace:FindFirstChild("AetherfallTrainingGrounds")
	if existing then
		assert(existing:IsA("Model"), "AetherfallTrainingGrounds is already used by another instance")
		return existing
	end
	local world = Instance.new("Model")
	world.Name = "AetherfallTrainingGrounds"
	local targets = Instance.new("Folder")
	targets.Name = "Targets"
	targets.Parent = world
	local decoration = Instance.new("Folder")
	decoration.Name = "Decoration"
	decoration.Parent = world
	local straw = Color3.fromRGB(201, 170, 91)
	local wood = Color3.fromRGB(109, 72, 42)
	local stone = Color3.fromRGB(122, 130, 124)
	local bronze = Color3.fromRGB(194, 147, 75)
	local blue = Color3.fromRGB(65, 109, 128)
	local cream = Color3.fromRGB(239, 225, 189)

	local function part(parent, name, size, position, tint, material, rotation, collide, query)
		local object = Instance.new("Part")
		object.Name = name
		object.Size = size
		object.CFrame = CFrame.new(position) * (rotation or CFrame.identity)
		object.Color = tint
		object.Material = material or Enum.Material.Wood
		object.Anchored = true
		object.CanCollide = collide == true
		object.CanTouch = false
		object.CanQuery = query == true
		object.TopSurface = Enum.SurfaceType.Smooth
		object.BottomSurface = Enum.SurfaceType.Smooth
		object.Parent = parent
		return object
	end
	local function cylinder(parent, name, diameter, thickness, position, tint, rotation, material)
		local object = part(parent, name, Vector3.new(thickness, diameter, diameter), position, tint,
			material, rotation or CFrame.Angles(0, 0, math.pi / 2), false, false)
		object.Shape = Enum.PartType.Cylinder
		return object
	end

	-- Small paving stones lead around the existing workshop notice instead of moving it.
	for _, side in { -1, 1 } do
		for index = 0, 4 do
			part(decoration, "ApproachStone", Vector3.new(2.7, 0.12, 2.3), Vector3.new(side * 5.5, 0.08, 23 + index * 2.8),
				stone, Enum.Material.Cobblestone, CFrame.Angles(0, side * 0.08, 0), true, false)
		end
	end
	world.PrimaryPart = decoration:FindFirstChild("ApproachStone")
	-- The left pair is within Flame Burst's radius, but their pedestals do not overlap.
	local positions = { Vector3.new(-8, 0, 34), Vector3.new(0, 0, 37), Vector3.new(10, 0, 32) }
	for index, base in positions do
		local dummy = Instance.new("Model")
		dummy.Name = "TrainingDummy" .. index
		dummy:SetAttribute("TargetId", "dummy_" .. index)
		dummy:SetAttribute("Health", 300)
		dummy:SetAttribute("MaxHealth", 300)
		dummy:SetAttribute("Defence", 10)
		dummy:SetAttribute("DownUntil", 0)
		dummy.Parent = targets
		cylinder(decoration, "TrainingRing", 7.2, 0.08, base + Vector3.new(0, 0.14, 0), bronze, nil, Enum.Material.Slate)
		cylinder(decoration, "TrainingRingInset", 6.65, 0.09, base + Vector3.new(0, 0.15, 0), stone, nil, Enum.Material.Cobblestone)
		part(dummy, "SupportPost", Vector3.new(0.35, 4.8, 0.35), base + Vector3.new(0, 2.4, 0.45), wood)
		local hitbox = part(dummy, "Hitbox", Vector3.new(2.2, 2, 1.4), base + Vector3.new(0, 3, 0), straw,
			Enum.Material.Fabric, nil, true, true)
		dummy.PrimaryPart = hitbox
		part(dummy, "Belt", Vector3.new(2.3, 0.18, 1.5), base + Vector3.new(0, 2.45, 0), wood)
		for _, side in { -1, 1 } do
			part(dummy, "StrawLeg", Vector3.new(0.65, 1.6, 0.75), base + Vector3.new(side * 0.6, 1.1, 0), straw,
				Enum.Material.Fabric, CFrame.Angles(0, 0, side * -0.08))
			part(dummy, "TrainingBoot", Vector3.new(0.85, 0.4, 1.1), base + Vector3.new(side * 0.67, 0.45, -0.12), wood)
			part(dummy, "StrawArm", Vector3.new(1.5, 0.65, 0.65), base + Vector3.new(side * 1.75, 3.5, 0), straw,
				Enum.Material.Fabric, CFrame.Angles(0, 0, side * -0.18))
			part(dummy, "RopeCuff", Vector3.new(0.16, 0.74, 0.74), base + Vector3.new(side * 2.1, 3.44, 0), wood)
			part(dummy, "StrawTuft", Vector3.new(0.12, 0.55, 0.12), base + Vector3.new(side * 2.6, 3.6, 0), cream,
				Enum.Material.Fabric, CFrame.Angles(0, 0, side * -0.5))
		end
		local head = part(dummy, "StrawHead", Vector3.new(1.25, 1.25, 1.25), base + Vector3.new(0, 4.65, 0), straw,
			Enum.Material.Fabric)
		head.Shape = Enum.PartType.Ball
		cylinder(dummy, "HelmetBrim", 1.9, 0.15, base + Vector3.new(0, 5.07, 0), blue, nil, Enum.Material.Metal)
		local helmet = part(dummy, "HelmetCrown", Vector3.new(1.35, 0.7, 1.35), base + Vector3.new(0, 5.3, 0), blue,
			Enum.Material.Metal)
		helmet.Shape = Enum.PartType.Ball
		for _, side in { -1, 1 } do
			part(dummy, "PaintedEye", Vector3.new(0.13, 0.16, 0.08), base + Vector3.new(side * 0.25, 4.7, -0.59), wood)
		end
		-- Separate concentric discs are cosmetic; only the large torso can be raycast.
		local faceRotation = CFrame.Angles(0, math.pi / 2, 0)
		cylinder(dummy, "TargetOuter", 1.65, 0.06, base + Vector3.new(0, 3.1, -0.74), blue, faceRotation)
		cylinder(dummy, "TargetMiddle", 1.12, 0.06, base + Vector3.new(0, 3.1, -0.79), cream, faceRotation)
		cylinder(dummy, "TargetCenter", 0.5, 0.06, base + Vector3.new(0, 3.1, -0.84), bronze, faceRotation)

		local billboard = Instance.new("BillboardGui")
		billboard.Name = "TargetBillboard"
		billboard.Adornee = hitbox
		billboard.Size = UDim2.fromOffset(200, 56)
		billboard.StudsOffset = Vector3.new(0, 3.6, 0)
		billboard.AlwaysOnTop = false
		billboard.MaxDistance = 90
		billboard.Parent = hitbox
		local title = Instance.new("TextLabel")
		title.Name = "TargetName"
		title.Size = UDim2.new(1, 0, 0, 26)
		title.BackgroundColor3 = blue
		title.BackgroundTransparency = 0.15
		title.Text = "TRAINING DUMMY " .. index
		title.TextColor3 = cream
		title.TextSize = 14
		title.Font = Enum.Font.GothamMedium
		title.Parent = billboard
		local health = Instance.new("TextLabel")
		health.Name = "HealthText"
		health.Position = UDim2.fromOffset(0, 26)
		health.Size = UDim2.new(1, 0, 0, 26)
		health.BackgroundColor3 = wood
		health.BackgroundTransparency = 0.15
		health.Text = "300 / 300"
		health.TextColor3 = cream
		health.TextSize = 14
		health.Font = Enum.Font.Gotham
		health.Parent = billboard
	end

	-- A side sign avoids creating cover between the spawn and the targets.
	local sign = part(decoration, "TrainingInstructions", Vector3.new(9, 3.8, 0.3), Vector3.new(-26, 3.3, 20), blue,
		Enum.Material.Wood, CFrame.Angles(0, math.rad(18), 0), true, false)
	for _, side in { -1, 1 } do
		part(decoration, "SignPost", Vector3.new(0.35, 2.8, 0.35), Vector3.new(-26 + side * 3.7, 1.4, 20), wood)
	end
	local surface = Instance.new("SurfaceGui")
	surface.Name = "TrainingGuide"
	surface.Face = Enum.NormalId.Front
	surface.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	surface.PixelsPerStud = 45
	surface.LightInfluence = 0
	surface.Parent = sign
	local instructions = Instance.new("TextLabel")
	instructions.Name = "Instructions"
	instructions.Size = UDim2.fromScale(1, 1)
	instructions.BackgroundTransparency = 1
	instructions.Font = Enum.Font.GothamMedium
	instructions.TextColor3 = cream
	instructions.TextSize = 20
	instructions.TextWrapped = true
	instructions.Text = "HEARTHGLEN TRAINING GROUNDS\nClose the armoury and face a selected dummy.\nAttack: click / R2 / touch Attack\nClass skill: 1 / X / touch Skill\nComplete training, then speak to Warden Mira."
	instructions.Parent = surface
	world.Parent = workspace
	return world
end

return TrainingWorld
