-- Original compact Hearthglen village and adjoining fields. Built once on server startup.
local VillageWorld = {}

function VillageWorld.build()
	local existing = workspace:FindFirstChild("AetherfallVillage")
	if existing then
		assert(existing:IsA("Model") and existing:GetAttribute("VillageOwned") == true,
			"AetherfallVillage is already used by another instance")
		return existing
	end
	local world = Instance.new("Model")
	world.Name = "AetherfallVillage"
	world:SetAttribute("VillageOwned", true)
	local buildings = Instance.new("Folder")
	buildings.Name = "Buildings"
	buildings.Parent = world
	local npcs = Instance.new("Folder")
	npcs.Name = "NPCs"
	npcs.Parent = world
	local spawns = Instance.new("Folder")
	spawns.Name = "EnemySpawns"
	spawns.Parent = world
	local scenery = Instance.new("Folder")
	scenery.Name = "Scenery"
	scenery.Parent = world

	local wood = Color3.fromRGB(98, 62, 38)
	local timber = Color3.fromRGB(151, 107, 64)
	local plaster = Color3.fromRGB(222, 208, 173)
	local stone = Color3.fromRGB(125, 132, 126)
	local brass = Color3.fromRGB(199, 155, 82)
	local slate = Color3.fromRGB(52, 81, 91)
	local grass = Color3.fromRGB(92, 131, 77)
	local cream = Color3.fromRGB(242, 230, 198)

	local function part(parent, name, size, position, tint, material, rotation, kind, collide, query)
		local object = Instance.new(kind or "Part")
		object.Name = name
		object.Size = size
		object.CFrame = CFrame.new(position) * (rotation or CFrame.identity)
		object.Color = tint
		object.Material = material or Enum.Material.SmoothPlastic
		object.Anchored = true
		object.CanCollide = collide ~= false
		object.CanTouch = false
		object.CanQuery = query ~= false
		object.TopSurface = Enum.SurfaceType.Smooth
		object.BottomSurface = Enum.SurfaceType.Smooth
		object.Parent = parent
		return object
	end
	local function ball(parent, name, size, position, tint, material)
		local object = part(parent, name, size, position, tint, material, nil, nil, false, false)
		object.Shape = Enum.PartType.Ball
		return object
	end
	local function sign(board, text, face, textSize)
		local surface = Instance.new("SurfaceGui")
		surface.Name = "VillageSign"
		surface.Face = face or Enum.NormalId.Back
		surface.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		surface.PixelsPerStud = 40
		surface.LightInfluence = 0
		surface.Parent = board
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.GothamMedium
		label.Text = text
		label.TextColor3 = cream
		label.TextSize = textSize or 21
		label.TextWrapped = true
		label.Parent = surface
	end
	local function prompt(parent, name, action, objectText)
		local object = Instance.new("ProximityPrompt")
		object.Name = name
		object.ActionText = action
		object.ObjectText = objectText
		object.MaxActivationDistance = 10
		object.RequiresLineOfSight = false
		object.Parent = parent
		return object
	end

	local ground = part(scenery, "VillageAndFieldMeadow", Vector3.new(190, 2, 125), Vector3.new(40, -1, -87.5),
		grass, Enum.Material.Grass)
	world.PrimaryPart = ground
	-- The eastern bypass keeps the original workshop forge and entrances unobstructed.
	for z = -5, -61, -4 do
		part(scenery, "WorkshopBypassPath", Vector3.new(7, 0.16, 3.7), Vector3.new(23, 0.1, z),
			stone, Enum.Material.Cobblestone)
	end
	for x = 1, 21, 4 do
		part(scenery, "VillageApproachPath", Vector3.new(3.7, 0.16, 7), Vector3.new(x, 0.1, -63),
			stone, Enum.Material.Cobblestone)
	end
	part(scenery, "VillageSquare", Vector3.new(23, 0.18, 24), Vector3.new(0, 0.1, -79),
		Color3.fromRGB(164, 162, 145), Enum.Material.Cobblestone)
	part(scenery, "VillageMainRoad", Vector3.new(7, 0.16, 57), Vector3.new(0, 0.1, -101), stone, Enum.Material.Cobblestone)
	part(scenery, "FieldRoad", Vector3.new(104, 0.16, 7), Vector3.new(51, 0.1, -74), stone, Enum.Material.Ground)
	for _, z in {-88, -113} do
		part(scenery, "CottageLane", Vector3.new(53, 0.14, 4), Vector3.new(0, 0.1, z + 10), stone,
			Enum.Material.Cobblestone)
	end

	local function cottage(name, base, roofTint)
		local model = Instance.new("Model")
		model.Name = name
		model.Parent = buildings
		local floor = part(model, "Foundation", Vector3.new(17, 0.35, 13), base + Vector3.new(0, 0.18, 0), stone,
			Enum.Material.Cobblestone)
		model.PrimaryPart = floor
		part(model, "RearWall", Vector3.new(16, 6.7, 0.6), base + Vector3.new(0, 3.6, -6), plaster, Enum.Material.Plaster)
		for _, side in {-1, 1} do
			part(model, "SideWall", Vector3.new(0.6, 6.7, 12), base + Vector3.new(side * 8, 3.6, 0), plaster, Enum.Material.Plaster)
			part(model, "DoorSideWall", Vector3.new(6.1, 6.7, 0.6), base + Vector3.new(side * 4.95, 3.6, 6), plaster, Enum.Material.Plaster)
			part(model, "CornerTimber", Vector3.new(0.55, 7.1, 0.8), base + Vector3.new(side * 7.8, 3.7, 6.1), wood, Enum.Material.Wood)
			part(model, "DoorFrame", Vector3.new(0.35, 6, 0.85), base + Vector3.new(side * 1.8, 3.15, 6.15), wood, Enum.Material.Wood)
			part(model, "WindowShutter", Vector3.new(2.35, 2.5, 0.2), base + Vector3.new(side * 5, 4.1, 6.4), roofTint, Enum.Material.Wood, nil, nil, false)
			part(model, "WindowCrossbar", Vector3.new(2.5, 0.18, 0.25), base + Vector3.new(side * 5, 4.1, 6.55), timber, Enum.Material.Wood, nil, nil, false)
			part(model, "WindowSill", Vector3.new(2.8, 0.22, 0.75), base + Vector3.new(side * 5, 2.75, 6.5), timber, Enum.Material.Wood)
			part(model, "SlopedRoof", Vector3.new(18, 4, 7.2), base + Vector3.new(0, 8.85, side * 3.5), roofTint,
				Enum.Material.Slate, CFrame.Angles(0, if side == 1 then 0 else math.pi, 0), "WedgePart")
		end
		part(model, "DoorLintel", Vector3.new(4, 0.6, 0.9), base + Vector3.new(0, 6.4, 6.15), wood, Enum.Material.Wood)
		part(model, "DoorStep", Vector3.new(4.2, 0.3, 2.3), base + Vector3.new(0, 0.16, 7.3), stone, Enum.Material.Cobblestone)
		part(model, "FrontRoofBeam", Vector3.new(17, 0.5, 0.7), base + Vector3.new(0, 7.15, 6), wood, Enum.Material.Wood)
		part(model, "RoofRidge", Vector3.new(18.4, 0.35, 0.6), base + Vector3.new(0, 10.95, 0), timber, Enum.Material.Wood)
		part(model, "BrickChimney", Vector3.new(1.6, 5.5, 1.7), base + Vector3.new(-5, 9, -2), stone, Enum.Material.Brick)
		part(model, "InteriorTable", Vector3.new(4, 0.4, 2.2), base + Vector3.new(-3, 2.2, -1.5), timber, Enum.Material.Wood)
		for _, side in {-1, 1} do
			part(model, "TableLeg", Vector3.new(0.4, 2, 1.6), base + Vector3.new(-3 + side * 1.5, 1.05, -1.5), wood, Enum.Material.Wood)
		end
		return model
	end
	cottage("WillowCottage", Vector3.new(-25, 0, -88), Color3.fromRGB(59, 101, 109))
	cottage("SmithsCottage", Vector3.new(25, 0, -88), Color3.fromRGB(122, 76, 55))
	cottage("CartographersCottage", Vector3.new(-25, 0, -116), Color3.fromRGB(76, 105, 78))
	cottage("Farmhouse", Vector3.new(25, 0, -116), Color3.fromRGB(113, 89, 115))
	local inn = cottage("TheCopperLeafInn", Vector3.new(0, 0, -137), slate)
	local innBoard = part(inn, "InnNameboard", Vector3.new(8.6, 1.5, 0.3), Vector3.new(0, 6.3, -130.1), wood, Enum.Material.Wood, nil, nil, false)
	sign(innBoard, "THE COPPER LEAF\nVillage inn", Enum.NormalId.Back, 20)
	-- Open porch, with no pretend closed doorway or hidden required interior.
	part(inn, "PorchRoof", Vector3.new(11, 0.4, 6), Vector3.new(0, 6.1, -126.8), timber, Enum.Material.Wood)
	for _, x in {-4.8, 4.8} do
		part(inn, "PorchPost", Vector3.new(0.45, 5.9, 0.45), Vector3.new(x, 3, -124.5), wood, Enum.Material.Wood)
		part(inn, "PorchBench", Vector3.new(3.4, 0.6, 1.2), Vector3.new(x, 1.2, -127), timber, Enum.Material.Wood)
	end

	local well = Instance.new("Model")
	well.Name = "HearthglenWell"
	well.Parent = scenery
	local basin = part(well, "WellBasin", Vector3.new(5.5, 1.3, 5.5), Vector3.new(0, 0.75, -81), stone, Enum.Material.Cobblestone)
	well.PrimaryPart = basin
	part(well, "Water", Vector3.new(4.8, 0.12, 4.8), Vector3.new(0, 1.43, -81), Color3.fromRGB(78, 150, 166),
		Enum.Material.Glass, nil, nil, false, false)
	for _, side in {-1, 1} do
		part(well, "RoofSupport", Vector3.new(0.5, 5.9, 0.5), Vector3.new(side * 2.7, 3, -81), wood, Enum.Material.Wood)
		part(well, "WellRoof", Vector3.new(7.3, 1.8, 3.5), Vector3.new(0, 6.25, -81 + side * 1.6), slate,
			Enum.Material.Slate, CFrame.Angles(0, if side == 1 then 0 else math.pi, 0), "WedgePart")
	end
	part(well, "Windlass", Vector3.new(5.9, 0.3, 0.3), Vector3.new(0, 4.5, -81), timber, Enum.Material.Wood)
	part(well, "Rope", Vector3.new(0.08, 3, 0.08), Vector3.new(0, 3, -81), cream, Enum.Material.Fabric, nil, nil, false, false)
	prompt(basin, "RestAtWell", "Rest", "Hearthglen Well")
	local wellSign = part(well, "WellNotice", Vector3.new(5.6, 1.1, 0.15), Vector3.new(0, 2.2, -77.8), slate, Enum.Material.Wood, nil, nil, false)
	sign(wellSign, "REST AT THE WELL\nA safe place to recover", Enum.NormalId.Back, 17)

	local function npc(name, displayName, position, tint, promptName)
		local model = Instance.new("Model")
		model.Name = name
		model.Parent = npcs
		local torso = part(model, "Torso", Vector3.new(1.65, 1.8, 0.9), position + Vector3.new(0, 3.1, 0), tint,
			Enum.Material.Fabric, nil, nil, false, false)
		model.PrimaryPart = torso
		ball(model, "Head", Vector3.new(1.1, 1.1, 1.1), position + Vector3.new(0, 4.6, 0), Color3.fromRGB(179, 133, 98), Enum.Material.SmoothPlastic)
		part(model, "Hair", Vector3.new(1.15, 0.35, 1.1), position + Vector3.new(0, 5.02, 0.04), wood, Enum.Material.Fabric, nil, nil, false, false)
		part(model, "Belt", Vector3.new(1.75, 0.2, 1), position + Vector3.new(0, 2.3, 0), timber, Enum.Material.Wood, nil, nil, false, false)
		for _, side in {-1, 1} do
			part(model, "Sleeve", Vector3.new(0.6, 1.5, 0.65), position + Vector3.new(side * 1.1, 3, 0), tint,
				Enum.Material.Fabric, CFrame.Angles(0, 0, side * 0.08), nil, false, false)
			part(model, "Hand", Vector3.new(0.55, 0.6, 0.55), position + Vector3.new(side * 1.15, 2.1, 0),
				Color3.fromRGB(179, 133, 98), Enum.Material.SmoothPlastic, nil, nil, false, false)
			part(model, "TrouserLeg", Vector3.new(0.65, 1.3, 0.7), position + Vector3.new(side * 0.45, 1.55, 0), wood,
				Enum.Material.Fabric, nil, nil, false, false)
			part(model, "Boot", Vector3.new(0.8, 0.6, 1.05), position + Vector3.new(side * 0.45, 0.6, -0.12), wood,
				Enum.Material.Wood, nil, nil, false, false)
		end
		prompt(torso, promptName, "Talk", displayName)
		local bill = Instance.new("BillboardGui")
		bill.Name = "NPCName"
		bill.Adornee = torso
		bill.Size = UDim2.fromOffset(180, 28)
		bill.StudsOffset = Vector3.new(0, 3, 0)
		bill.MaxDistance = 65
		bill.Parent = torso
		local title = Instance.new("TextLabel")
		title.Size = UDim2.fromScale(1, 1)
		title.BackgroundColor3 = slate
		title.BackgroundTransparency = 0.15
		title.Text = displayName
		title.TextColor3 = cream
		title.Font = Enum.Font.GothamMedium
		title.TextSize = 13
		title.Parent = bill
		return model
	end
	local rowan = npc("Rowan", "Elder Rowan", Vector3.new(0, 0, -65), Color3.fromRGB(91, 119, 105), "TalkRowan")
	part(rowan, "WalkingStaff", Vector3.new(0.18, 4.9, 0.18), Vector3.new(1.55, 2.5, -65), timber, Enum.Material.Wood, nil, nil, false, false)
	local smith = npc("Blacksmith", "Smith Tessa", Vector3.new(-22, 0, -60), Color3.fromRGB(128, 79, 55), "TalkBlacksmith")
	part(smith, "Apron", Vector3.new(1.3, 1.45, 0.15), Vector3.new(-22, 2.8, -60.55), wood, Enum.Material.Fabric, nil, nil, false, false)

	for _, x in {-13, 13, 42} do
		for _, z in {-61, -99} do
			part(scenery, "VillageLampPost", Vector3.new(0.45, 5.8, 0.45), Vector3.new(x, 2.9, z), wood, Enum.Material.Wood)
			part(scenery, "LanternCap", Vector3.new(1.2, 0.18, 1.2), Vector3.new(x, 5.9, z), slate, Enum.Material.Metal, nil, nil, false)
			local glow = part(scenery, "WarmLantern", Vector3.new(0.7, 1, 0.7), Vector3.new(x, 5.2, z), brass,
				Enum.Material.Neon, nil, nil, false, false)
			local light = Instance.new("PointLight")
			light.Color = Color3.fromRGB(255, 211, 146)
			light.Brightness = 0.8
			light.Range = 13
			light.Shadows = false
			light.Parent = glow
		end
	end
	for _, x in {-44, 43, 121} do
		for _, z in {-41, -107, -143} do
			part(scenery, "OakTrunk", Vector3.new(1.4, 6.5, 1.4), Vector3.new(x, 3.25, z), wood, Enum.Material.Wood)
			ball(scenery, "OakCrown", Vector3.new(9, 7.5, 8), Vector3.new(x, 8.6, z), Color3.fromRGB(69, 116, 68), Enum.Material.Grass)
			ball(scenery, "OakLobe", Vector3.new(6, 6, 6), Vector3.new(x + 3, 7.5, z + 1), Color3.fromRGB(94, 137, 73), Enum.Material.Grass)
		end
	end
	for _, x in {-38, 36} do
		for flower = 1, 5 do
			ball(scenery, "FlowerBedShrub", Vector3.new(1.8, 1, 2.2), Vector3.new(x, 0.7, -56 - flower * 2),
				Color3.fromRGB(73, 120, 74), Enum.Material.Grass)
			ball(scenery, "FlowerCluster", Vector3.new(0.55, 0.55, 0.55), Vector3.new(x + 0.2, 1.3, -56 - flower * 2),
				if flower % 2 == 0 then Color3.fromRGB(193, 145, 197) else Color3.fromRGB(235, 192, 106), Enum.Material.SmoothPlastic)
		end
	end
	-- Field boundary has a wide road opening. Enemy patrol space stays clear to its east.
	for _, z in {-47, -56, -92, -101, -110, -119, -128} do
		part(scenery, "FieldFencePost", Vector3.new(0.5, 2.8, 0.5), Vector3.new(48, 1.4, z), timber, Enum.Material.Wood)
		if z ~= -56 then
			part(scenery, "FieldFenceRail", Vector3.new(0.25, 0.25, 7.8), Vector3.new(48, 1.9, z - 4), wood, Enum.Material.Wood)
		end
	end
	for row = 1, 3 do
		part(scenery, "CultivatedSoil", Vector3.new(19, 0.15, 1.6), Vector3.new(108, 0.15, -110 - row * 4),
			Color3.fromRGB(104, 76, 45), Enum.Material.Ground)
		for stalk = 1, 4 do
			part(scenery, "WheatStalk", Vector3.new(0.15, 1.35, 0.15), Vector3.new(100 + stalk * 3, 0.85, -110 - row * 4),
				Color3.fromRGB(181, 157, 75), Enum.Material.Grass, nil, nil, false, false)
		end
	end
	local directions = part(scenery, "WorkshopVillageSign", Vector3.new(8.2, 2.1, 0.25), Vector3.new(17, 3, -33), slate, Enum.Material.Wood)
	sign(directions, "HEARTHGLEN VILLAGE\nFollow the east path · Talk to Elder Rowan", Enum.NormalId.Back, 21)
	part(scenery, "VillageSignPost", Vector3.new(0.4, 2.3, 0.4), Vector3.new(17, 1.15, -33), wood, Enum.Material.Wood)
	local fieldsSign = part(scenery, "FieldsWarning", Vector3.new(9, 2.4, 0.25), Vector3.new(51, 3, -68), slate,
		Enum.Material.Wood, CFrame.Angles(0, math.pi / 2, 0))
	sign(fieldsSign, "MEADOW FIELDS\nCreatures beyond this point", Enum.NormalId.Front, 22)
	part(scenery, "FieldsSignPost", Vector3.new(0.4, 2.4, 0.4), Vector3.new(51, 1.2, -68), wood, Enum.Material.Wood)
	local villageName = part(scenery, "VillageNameboard", Vector3.new(11, 2.2, 0.3), Vector3.new(0, 6.5, -53), wood, Enum.Material.Wood, nil, nil, false)
	sign(villageName, "HEARTHGLEN\nVillage of the First Light", Enum.NormalId.Back, 24)
	for _, x in {-6, 6} do
		part(scenery, "VillageGatePost", Vector3.new(0.65, 7, 0.65), Vector3.new(x, 3.5, -53), timber, Enum.Material.Wood)
	end

	local definitions = {
		{ id = "slime_1", kind = "MeadowSlime", position = Vector3.new(72, 1, -65) },
		{ id = "slime_2", kind = "MeadowSlime", position = Vector3.new(105, 1, -56) },
		{ id = "boar_1", kind = "WildBoar", position = Vector3.new(92, 1, -85) },
		{ id = "thorn_1", kind = "Thornling", position = Vector3.new(77, 1, -111) },
	}
	for _, definition in definitions do
		local marker = part(spawns, definition.id, Vector3.new(1, 1, 1), definition.position, grass,
			Enum.Material.SmoothPlastic, nil, nil, false, false)
		marker.Transparency = 1
		marker:SetAttribute("SpawnId", definition.id)
		marker:SetAttribute("EnemyKind", definition.kind)
	end
	world.Parent = workspace
	return world
end

return VillageWorld
