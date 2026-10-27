-- Original grove scenery and interaction anchors. BossService owns the encounter.
local GroveWorld = {}

function GroveWorld.build()
	local existing = workspace:FindFirstChild("AetherfallGrove")
	if existing then
		assert(existing:IsA("Model") and existing:GetAttribute("GroveOwned") == true,
			"AetherfallGrove is already used by another instance")
		return existing
	end
	local world = Instance.new("Model")
	world.Name = "AetherfallGrove"
	world:SetAttribute("GroveOwned", true)
	local center = Vector3.new(100, 0, -200)
	world:SetAttribute("ArenaCenter", center)
	world:SetAttribute("ArenaRadius", 30)
	world:SetAttribute("EntryPosition", Vector3.new(100, 3, -178))
	local scenery = Instance.new("Folder")
	scenery.Name = "Scenery"
	scenery.Parent = world
	local markers = Instance.new("Folder")
	markers.Name = "EncounterMarkers"
	markers.Parent = world
	local stone = Color3.fromRGB(113, 132, 121)
	local paleStone = Color3.fromRGB(162, 173, 152)
	local bark = Color3.fromRGB(88, 65, 39)
	local rootTint = Color3.fromRGB(123, 91, 53)
	local grass = Color3.fromRGB(79, 119, 71)
	local gold = Color3.fromRGB(207, 174, 92)
	local aether = Color3.fromRGB(118, 210, 170)
	local cream = Color3.fromRGB(239, 230, 201)

	local function part(parent, name, size, position, tint, material, rotation, kind, collide, query)
		local object = Instance.new(kind or "Part")
		object.Name = name
		object.Size = size
		object.CFrame = CFrame.new(position) * (rotation or CFrame.identity)
		object.Color = tint
		object.Material = material or Enum.Material.Slate
		object.Anchored = true
		object.CanCollide = collide ~= false
		object.CanTouch = false
		object.CanQuery = query ~= false
		object.TopSurface = Enum.SurfaceType.Smooth
		object.BottomSurface = Enum.SurfaceType.Smooth
		object.Parent = parent
		return object
	end
	local function ball(name, size, position, tint)
		local object = part(scenery, name, size, position, tint, Enum.Material.Grass, nil, nil, false, false)
		object.Shape = Enum.PartType.Ball
		return object
	end
	local function cylinder(parent, name, diameter, height, position, tint, material, collide)
		local object = part(parent, name, Vector3.new(height, diameter, diameter), position, tint, material,
			CFrame.Angles(0, 0, math.pi / 2), nil, collide)
		object.Shape = Enum.PartType.Cylinder
		return object
	end
	local function beam(name, first, second, width, tint)
		local delta = second - first
		local up = if math.abs(delta.Unit:Dot(Vector3.yAxis)) > 0.98 then Vector3.xAxis else Vector3.yAxis
		return part(scenery, name, Vector3.new(width, width, delta.Magnitude), (first + second) / 2,
			tint, Enum.Material.Wood, CFrame.lookAt(Vector3.zero, delta, up), nil, false, false)
	end
	local function sign(board, value, fontSize)
		local gui = Instance.new("SurfaceGui")
		gui.Name = "GroveSign"
		gui.Face = Enum.NormalId.Back
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 45
		gui.LightInfluence = 0
		gui.Parent = board
		local text = Instance.new("TextLabel")
		text.Name = "Inscription"
		text.Size = UDim2.fromScale(1, 1)
		text.BackgroundTransparency = 1
		text.TextColor3 = cream
		text.Font = Enum.Font.GothamMedium
		text.TextSize = fontSize or 20
		text.TextWrapped = true
		text.Text = value
		text.Parent = gui
	end
	local function prompt(parent, name, action, objectText)
		local object = Instance.new("ProximityPrompt")
		object.Name = name
		object.ActionText = action
		object.ObjectText = objectText
		object.MaxActivationDistance = 10
		object.RequiresLineOfSight = false
		object.Parent = parent
	end

	local ground = part(scenery, "GroveMeadow", Vector3.new(90, 2, 110), Vector3.new(100, -1, -195), grass,
		Enum.Material.Grass)
	world.PrimaryPart = ground
	cylinder(scenery, "AncientArenaFloor", 60, 0.18, center + Vector3.new(0, 0.1, 0), stone, Enum.Material.Slate)
	cylinder(scenery, "ArenaInnerCircle", 51, 0.04, center + Vector3.new(0, 0.21, 0),
		Color3.fromRGB(136, 148, 124), Enum.Material.Ground)
	-- A low-cost route leaves both interactive stones approachable from every side.
	for z = -144, -172, -4 do
		part(scenery, "FieldApproachStone", Vector3.new(5.6, 0.15, 3.7), Vector3.new(73, 0.12, z), paleStone,
			Enum.Material.Cobblestone)
	end
	for index = 0, 6 do
		part(scenery, "ArenaEntryPath", Vector3.new(3.9, 0.15, 5.6), Vector3.new(75 + index * 4, 0.12, -177),
			paleStone, Enum.Material.Cobblestone)
	end
	part(scenery, "FieldPathJunction", Vector3.new(13, 0.15, 5.5), Vector3.new(78, 0.12, -143), paleStone,
		Enum.Material.Cobblestone)

	for index = 0, 11 do
		local angle = math.rad(index * 30 + 15)
		local radial = Vector3.new(math.cos(angle), 0, math.sin(angle))
		local position = center + radial * 30.4
		-- The broken ring remains cosmetic, so the boss boundary is readable without trapping players.
		part(scenery, "BrokenCircleStone", Vector3.new(5.6, 0.65 + (index % 3) * 0.18, 1.0),
			position + Vector3.new(0, 0.42, 0), if index % 2 == 0 then stone else paleStone,
			Enum.Material.Slate, CFrame.Angles(0, -angle - math.pi / 2, 0), nil, false, false)
		part(scenery, "CircleRune", Vector3.new(0.25, 0.08, 1.1), center + radial * 27.7 + Vector3.new(0, 0.25, 0),
			aether, Enum.Material.Neon, CFrame.Angles(0, -angle, 0), nil, false, false)
	end

	-- Trees stand outside the combat radius. Decorative roots do not obstruct dodge paths.
	for index = 0, 5 do
		local angle = math.rad(index * 60 + 15)
		local radial = Vector3.new(math.cos(angle), 0, math.sin(angle))
		local tangent = Vector3.new(-radial.Z, 0, radial.X)
		local base = center + radial * 38
		cylinder(scenery, "AncientTrunk", 2.7, 11, base + Vector3.new(0, 5.5, 0), bark, Enum.Material.Wood)
		beam("CrookedBranch", base + Vector3.new(0, 7.4, 0), base + tangent * 3 + Vector3.new(0, 11, 0), 1.0, bark)
		ball("AncientCanopy", Vector3.new(11, 8, 10), base + Vector3.new(0, 13, 0), Color3.fromRGB(62, 109 + index * 4, 67))
		ball("CanopyLobe", Vector3.new(7, 6, 7), base + tangent * 3 + Vector3.new(0, 11.7, 0), Color3.fromRGB(87, 135, 72))
		for side = -1, 1, 2 do
			local outer = base + tangent * (side * 2.2) + Vector3.new(0, 0.6, 0)
			local inner = center + radial * 26 + tangent * (side * 3.2) + Vector3.new(0, 0.3, 0)
			beam("AncientRoot", outer, inner, 0.65, rootTint)
		end
		local columnBase = center + radial * 32.5
		part(scenery, "RuinedColumnBase", Vector3.new(2.8, 0.7, 2.8), columnBase + Vector3.new(0, 0.35, 0), stone,
			Enum.Material.Cobblestone)
		part(scenery, "BrokenColumn", Vector3.new(1.8, 3.0 + (index % 3), 1.8),
			columnBase + Vector3.new(0, 1.8 + (index % 3) / 2, 0), paleStone, Enum.Material.Slate,
			CFrame.Angles(0, angle, 0.05 * (index % 2)))
	end

	local rune = cylinder(scenery, "RuneStone", 2.4, 4, Vector3.new(80, 3, -156), stone, Enum.Material.Slate, false)
	part(scenery, "RuneCairnFoot", Vector3.new(3.8, 1, 3.8), Vector3.new(80, 0.5, -156), paleStone,
		Enum.Material.Cobblestone, nil, nil, false, false)
	part(scenery, "RuneCrystal", Vector3.new(1.1, 2.1, 1.1), Vector3.new(80, 5.9, -156), aether,
		Enum.Material.Neon, CFrame.Angles(0, math.pi / 4, 0), "WedgePart", false, false)
	prompt(rune, "InspectGroveRune", "Inspect", "Ancient grove rune")
	local runeBoard = part(scenery, "RuneInscriptionBoard", Vector3.new(5.6, 1.6, 0.25), Vector3.new(80, 2.4, -153.9), bark,
		Enum.Material.Wood, nil, nil, false, false)
	sign(runeBoard, "WHISPERING GROVE\nInspect the ancient rune", 19)

	-- Stone arch faces the field approach. Its clear span is wider than a character.
	for _, x in {77, 87} do
		part(scenery, "GroveArchFoot", Vector3.new(2.7, 0.8, 2.7), Vector3.new(x, 0.4, -171), stone, Enum.Material.Cobblestone)
		part(scenery, "GroveArchPillar", Vector3.new(1.8, 8.4, 1.8), Vector3.new(x, 4.9, -171), paleStone, Enum.Material.Slate)
		part(scenery, "ArchCarving", Vector3.new(0.18, 3.4, 0.2), Vector3.new(x, 5.1, -169.99), gold,
			Enum.Material.Metal, nil, nil, false, false)
	end
	part(scenery, "GroveArchLintel", Vector3.new(12.6, 1.5, 2.5), Vector3.new(82, 9.2, -171), stone, Enum.Material.Slate)
	part(scenery, "ArchKeystone", Vector3.new(2.2, 2.2, 2.6), Vector3.new(82, 9.4, -171), gold,
		Enum.Material.Sandstone, CFrame.Angles(0, 0, math.pi / 4))
	local challenge = part(scenery, "ChallengeStone", Vector3.new(2.3, 2.5, 1.6), Vector3.new(82, 3, -172), stone,
		Enum.Material.Slate, nil, nil, false, false)
	prompt(challenge, "ChallengeBriarwarden", "Challenge", "Briarwarden · Guardian of the Grove")
	local challengeBoard = part(scenery, "ChallengeNotice", Vector3.new(8.2, 2.1, 0.25), Vector3.new(82, 6.8, -169.6), bark,
		Enum.Material.Wood, nil, nil, false, false)
	sign(challengeBoard, "BRIARWARDEN\nRecommended level 5 · Minimum level 3\nComplete Rowan's field quest first", 17)
	local arenaHint = part(scenery, "ArenaTacticsNotice", Vector3.new(8.5, 2.0, 0.25), Vector3.new(111, 2.2, -171), bark,
		Enum.Material.Wood, nil, nil, false, false)
	sign(arenaHint, "Watch the roots and sweeping branches.\nStrike when the guardian's core is exposed.", 19)
	local marker = part(markers, "ArenaCenter", Vector3.new(0.25, 0.25, 0.25), center,
		stone, Enum.Material.SmoothPlastic, nil, nil, false, false)
	marker.Transparency = 1
	world.Parent = workspace
	return world
end

return GroveWorld
