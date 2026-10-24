-- A compact, original equipment test courtyard. This is not the finished village.
local WorkshopWorld = {}

function WorkshopWorld.build(Catalog, EquipmentModels)
	local existing = workspace:FindFirstChild("AetherfallWorkshop")
	if existing then
		assert(existing:IsA("Model"), "AetherfallWorkshop is already used by another instance")
		return existing
	end

	local world = Instance.new("Model")
	world.Name = "AetherfallWorkshop"
	local wood = Color3.fromRGB(88, 54, 34)
	local lightWood = Color3.fromRGB(156, 111, 63)
	local stone = Color3.fromRGB(104, 115, 111)
	local cream = Color3.fromRGB(222, 204, 158)
	local slate = Color3.fromRGB(45, 69, 79)
	local grass = Color3.fromRGB(84, 126, 74)
	local brass = Color3.fromRGB(201, 154, 73)

	local function part(name, size, position, tint, material, rotation, kind, collide)
		local object = Instance.new(kind or "Part")
		object.Name = name
		object.Size = size
		object.CFrame = CFrame.new(position) * (rotation or CFrame.identity)
		object.Color = tint
		object.Material = material or Enum.Material.SmoothPlastic
		object.Anchored = true
		object.CanCollide = collide ~= false
		object.CanTouch = false
		object.TopSurface = Enum.SurfaceType.Smooth
		object.BottomSurface = Enum.SurfaceType.Smooth
		object.Parent = world
		return object
	end

	local function ball(name, size, position, tint)
		local object = part(name, size, position, tint, Enum.Material.Grass, nil, nil, false)
		object.Shape = Enum.PartType.Ball
		return object
	end

	local function sign(onPart, text, size)
		local surface = Instance.new("SurfaceGui")
		surface.Name = "WorkshopSign"
		surface.Face = Enum.NormalId.Back
		surface.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		surface.PixelsPerStud = 45
		surface.LightInfluence = 0
		surface.Parent = onPart
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.Text = text
		label.TextColor3 = cream
		label.TextSize = size or 22
		label.Font = Enum.Font.GothamMedium
		label.TextWrapped = true
		label.Parent = surface
	end

	-- A grassy island with a rock rim; its top is at y = 0.
	local rim = part("StoneIslandRim", Vector3.new(3, 105, 105), Vector3.new(0, -2, 0), stone,
		Enum.Material.Slate, CFrame.Angles(0, 0, math.pi / 2))
	rim.Shape = Enum.PartType.Cylinder
	local ground = part("Meadow", Vector3.new(1.1, 102, 102), Vector3.new(0, -0.55, 0), grass,
		Enum.Material.Grass, CFrame.Angles(0, 0, math.pi / 2))
	ground.Shape = Enum.PartType.Cylinder
	world.PrimaryPart = ground
	part("WorkshopFoundation", Vector3.new(29, 0.5, 19), Vector3.new(0, 0.15, -15), stone, Enum.Material.Cobblestone)
	for z = -5, 22, 3 do
		part("VillagePaving", Vector3.new(6.7, 0.18, 2.7), Vector3.new(0, 0.12, z),
			Color3.fromRGB(163 + (z % 3) * 5, 163, 144), Enum.Material.Cobblestone)
	end
	for x = -18, 18, 6 do
		part("DisplayPaving", Vector3.new(5.7, 0.18, 4.5), Vector3.new(x, 0.1, 1), stone, Enum.Material.Cobblestone)
	end

	-- Open-front blacksmith workshop, with a timber frame and layered slate roof.
	for _, x in { -12, 12 } do
		for _, z in { -22, -8 } do
			part("TimberPost", Vector3.new(0.85, 8.8, 0.85), Vector3.new(x, 4.7, z), wood, Enum.Material.Wood)
			part("PostFooting", Vector3.new(1.35, 0.9, 1.35), Vector3.new(x, 0.7, z), stone, Enum.Material.Slate)
		end
		part("SideBeam", Vector3.new(1, 1, 16), Vector3.new(x, 8.8, -15), lightWood, Enum.Material.Wood)
	end
	part("FrontLintel", Vector3.new(26, 1, 1), Vector3.new(0, 8.8, -8), wood, Enum.Material.Wood)
	part("BackWall", Vector3.new(25, 5.5, 0.8), Vector3.new(0, 3.1, -22), cream, Enum.Material.Plaster)
	for _, x in { -8, 0, 8 } do
		part("WallStud", Vector3.new(0.5, 6.5, 1), Vector3.new(x, 3.7, -21.8), wood, Enum.Material.Wood)
	end
	for _, side in { -1, 1 } do
		local roof = part("SlopingSlateRoof", Vector3.new(27.5, 4.1, 8.3), Vector3.new(0, 10.5, -15 + side * 4),
			slate, Enum.Material.Slate, CFrame.Angles(0, side == 1 and 0 or math.pi, 0), "WedgePart")
		roof.CanCollide = false
		for row = 0, 2 do
			part("RoofTileTrim", Vector3.new(28, 0.16, 0.35), Vector3.new(0, 12.45 - row * 1.25, -15 + side * (0.3 + row * 2.45)),
				Color3.fromRGB(67, 91, 96), Enum.Material.Slate, nil, nil, false)
		end
	end
	part("RoofRidge", Vector3.new(28, 0.45, 0.6), Vector3.new(0, 12.6, -15), brass, Enum.Material.Metal, nil, nil, false)
	local title = part("HearthglenNameboard", Vector3.new(17, 2.2, 0.3), Vector3.new(0, 7.1, -7.6), slate, Enum.Material.Wood)
	sign(title, "AETHERFALL\nHearthglen equipment workshop", 25)

	-- The forge is architectural geometry, with a contained cosmetic ember glow.
	part("ForgeHearth", Vector3.new(6, 1.2, 4), Vector3.new(-7, 1, -18), stone, Enum.Material.Brick)
	for _, x in { -9.2, -4.8 } do
		part("ForgePillar", Vector3.new(1.5, 3.5, 3.6), Vector3.new(x, 3, -18), stone, Enum.Material.Brick)
	end
	part("ForgeHood", Vector3.new(6.5, 1.2, 4.3), Vector3.new(-7, 5.3, -18), stone, Enum.Material.Brick)
	part("ForgeChimney", Vector3.new(2.6, 8.5, 2.6), Vector3.new(-7, 9.2, -18.5), stone, Enum.Material.Brick)
	part("ChimneyCap", Vector3.new(3.2, 0.5, 3.2), Vector3.new(-7, 13.65, -18.5), slate, Enum.Material.Slate)
	local embers = part("ContainedEmbers", Vector3.new(2.8, 0.2, 2), Vector3.new(-7, 1.75, -17.9),
		Color3.fromRGB(255, 135, 54), Enum.Material.Neon, nil, nil, false)
	local glow = Instance.new("PointLight")
	glow.Name = "ForgeGlow"
	glow.Color = Color3.fromRGB(255, 177, 94)
	glow.Range = 13
	glow.Brightness = 1.4
	glow.Shadows = false
	glow.Parent = embers
	part("AnvilStump", Vector3.new(3, 2.3, 3), Vector3.new(-1.5, 1.55, -11), wood, Enum.Material.Wood)
	part("AnvilFoot", Vector3.new(2.5, 0.35, 1.7), Vector3.new(-1.5, 2.85, -11), slate, Enum.Material.Metal)
	part("AnvilWaist", Vector3.new(1.25, 0.8, 1.1), Vector3.new(-1.5, 3.4, -11), slate, Enum.Material.Metal)
	local anvil = part("AnvilFace", Vector3.new(3.4, 0.5, 1.5), Vector3.new(-1.5, 4, -11), Color3.fromRGB(137, 151, 152), Enum.Material.Metal)
	part("AnvilHorn", Vector3.new(1.7, 0.5, 1.25), Vector3.new(0.9, 4, -11), slate,
		Enum.Material.Metal, CFrame.Angles(0, 0, math.pi / 2), "WedgePart")
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "OpenEquipment"
	prompt.ActionText = "Inspect equipment"
	prompt.ObjectText = "Hearthglen Workshop"
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = anvil
	part("Workbench", Vector3.new(6.2, 0.6, 3), Vector3.new(7, 3.1, -18), lightWood, Enum.Material.Wood)
	for _, x in { 4.5, 9.5 } do
		part("WorkbenchLeg", Vector3.new(0.5, 2.8, 2.5), Vector3.new(x, 1.6, -18), wood, Enum.Material.Wood)
	end
	for i = 0, 3 do
		part("StackedIronBillet", Vector3.new(1.2, 0.32, 0.7), Vector3.new(5.2 + i * 1.2, 3.6, -18.5),
			Color3.fromRGB(143, 158, 157), Enum.Material.Metal, nil, nil, false)
	end

	-- Six distinct silhouettes stand beside the central path.
	local wanted = { "Sword", "Axe", "Bow", "Staff", "Shield", "Helmet" }
	for index, shape in wanted do
		local definition
		for _, id in Catalog.Order do
			local item = Catalog.Items[id]
			if item.model.shape == shape then
				definition = item
				break
			end
		end
		if definition then
			local side = index <= 3 and -1 or 1
			local row = (index - 1) % 3
			local position = Vector3.new(side * 18, 0, -9 + row * 9)
			part("EquipmentPlinth", Vector3.new(4.5, 1.3, 4.5), position + Vector3.new(0, 0.65, 0), stone, Enum.Material.Slate)
			part("PlinthBrassTrim", Vector3.new(4.7, 0.15, 4.7), position + Vector3.new(0, 1.35, 0), brass, Enum.Material.Metal)
			local display = EquipmentModels.create(definition)
			display.Name = "Display_" .. definition.id
			-- Include rotated part extents, then translate the static preview onto its plinth.
			local bottom = math.huge
			for _, piece in display:GetDescendants() do
				if piece:IsA("BasePart") then
					local frame, size = piece.CFrame, piece.Size
					local halfHeight = (math.abs(frame.RightVector.Y) * size.X
						+ math.abs(frame.UpVector.Y) * size.Y + math.abs(frame.LookVector.Y) * size.Z) / 2
					bottom = math.min(bottom, frame.Position.Y - halfHeight)
				end
			end
			local offset = CFrame.new(position + Vector3.new(0, 1.65 - bottom, 0))
			for _, piece in display:GetDescendants() do
				if piece:IsA("BasePart") then
					piece.CFrame = offset * piece.CFrame
				end
			end
			display.Parent = world
			local plaque = part("EquipmentPlaque", Vector3.new(4.3, 0.85, 0.15), position + Vector3.new(0, 0.8, 2.34), slate, Enum.Material.Metal, nil, nil, false)
			sign(plaque, definition.name, 18)
		end
	end

	-- Low-cost foliage and a partial picket fence frame the courtyard.
	for i = 0, 6 do
		local angle = math.rad(30 + i * 43)
		local x, z = math.cos(angle) * 38, math.sin(angle) * 37
		part("OakTrunk", Vector3.new(1.5, 6, 1.5), Vector3.new(x, 3, z), wood, Enum.Material.Wood)
		ball("OakCrown", Vector3.new(9, 8, 8), Vector3.new(x, 8, z), Color3.fromRGB(65, 111 + i * 3, 69))
		ball("OakCrownLobe", Vector3.new(6, 6, 6), Vector3.new(x + 3, 7.2, z + 1), Color3.fromRGB(83, 133, 69))
		ball("OakCrownLobe", Vector3.new(6, 6, 6), Vector3.new(x - 2.5, 7.6, z - 1), Color3.fromRGB(98, 144, 74))
	end
	for _, side in { -1, 1 } do
		for segment = 0, 3 do
			local z = -25 + segment * 9
			part("FencePost", Vector3.new(0.55, 3.5, 0.55), Vector3.new(side * 29, 1.75, z), lightWood, Enum.Material.Wood)
			if segment < 3 then
				for _, y in { 1.2, 2.5 } do
					part("FenceRail", Vector3.new(0.25, 0.32, 9), Vector3.new(side * 29, y, z + 4.5), wood, Enum.Material.Wood)
				end
			end
		end
		part("RaisedGarden", Vector3.new(7, 0.6, 4), Vector3.new(side * 11, 0.3, 20), wood, Enum.Material.Wood)
		for flower = 0, 3 do
			local center = Vector3.new(side * 11 - 2.2 + flower * 1.45, 0.8, 20)
			ball("GardenShrub", Vector3.new(1.9, 1.5, 2.3), center, Color3.fromRGB(65, 117, 72))
			ball("GardenFlower", Vector3.new(0.5, 0.5, 0.5), center + Vector3.new(0.2, 0.9, 0), Color3.fromRGB(230, 177, 109))
		end
	end
	local sessionSign = part("SessionNotice", Vector3.new(10, 1.3, 0.25), Vector3.new(0, 2.7, 25), slate, Enum.Material.Wood)
	sign(sessionSign, "Session-only test inventory\nEquipment workshop • not saved", 20)
	for _, x in { -4.3, 4.3 } do
		part("NoticePost", Vector3.new(0.35, 2.4, 0.35), Vector3.new(x, 1.2, 25), wood, Enum.Material.Wood)
	end
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "WorkshopSpawn"
	spawn.Size = Vector3.new(6, 1, 6)
	spawn.Position = Vector3.new(0, 1, 15)
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Transparency = 1
	spawn.CanCollide = false
	spawn.Parent = world
	world.Parent = workspace
	return world
end

return WorkshopWorld
