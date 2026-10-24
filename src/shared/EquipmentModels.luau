-- Original low-part-count preview geometry. These are display models, not combat Tools.
local EquipmentModels = {}

local WOOD = Enum.Material.Wood
local METAL = Enum.Material.Metal
local CLOTH = Enum.Material.Fabric

local function color(rgb)
	return Color3.fromRGB(rgb[1], rgb[2], rgb[3])
end

function EquipmentModels.create(item)
	assert(type(item) == "table" and type(item.model) == "table", "Equipment model definition required")
	local model = Instance.new("Model")
	model.Name = item.id
	local primary = color(item.model.primary)
	local accent = color(item.model.accent)
	local dark = Color3.fromRGB(55, 39, 33)
	local silver = Color3.fromRGB(191, 201, 212)
	local shape = item.model.shape
	local armorMaterial = if string.find(item.id, "acolyte_") then CLOTH
		elseif string.find(item.id, "scout_") then Enum.Material.SmoothPlastic else METAL

	local function part(name, size, position, tint, material, rotation, kind)
		local object = Instance.new(kind or "Part")
		object.Name = name
		object.Size = size
		object.CFrame = CFrame.new(position) * (rotation or CFrame.identity)
		object.Color = tint or primary
		object.Material = material or METAL
		object.Anchored = true
		object.CanCollide = false
		object.CanTouch = false
		object.CanQuery = false
		object.CastShadow = false
		object.TopSurface = Enum.SurfaceType.Smooth
		object.BottomSurface = Enum.SurfaceType.Smooth
		object.Parent = model
		return object
	end

	local function ball(name, diameter, position, tint, material)
		local object = part(name, Vector3.new(diameter, diameter, diameter), position, tint, material)
		object.Shape = Enum.PartType.Ball
		return object
	end

	local function cylinder(name, diameter, height, position, tint, material)
		local object = part(name, Vector3.new(height, diameter, diameter), position, tint, material,
			CFrame.Angles(0, 0, math.pi / 2))
		object.Shape = Enum.PartType.Cylinder
		return object
	end

	local function line(name, startPoint, endPoint, width, tint, material)
		local delta = endPoint - startPoint
		-- A vertical segment needs a perpendicular up vector to avoid a degenerate lookAt.
		local up = if math.abs(delta.Unit.Y) > 0.98 then Vector3.xAxis else Vector3.yAxis
		return part(name, Vector3.new(width, width, delta.Magnitude), (startPoint + endPoint) / 2,
			tint, material, CFrame.lookAt(Vector3.zero, delta, up))
	end

	local function grip(length)
		return cylinder("Handle", 0.2, length or 0.8, Vector3.zero, dark, WOOD)
	end

	local handle
	if shape == "Sword" or shape == "Greatsword" or shape == "Dagger" then
		local scale = if shape == "Greatsword" then 1.35 elseif shape == "Dagger" then 0.6 else 1
		handle = grip(0.8 * scale)
		part("Crossguard", Vector3.new(1.0 * scale, 0.14, 0.25), Vector3.new(0, 0.42 * scale, 0), accent)
		part("Blade", Vector3.new(0.34 * scale, 1.7 * scale, 0.12), Vector3.new(0, 1.31 * scale, 0), primary)
		part("BladePoint", Vector3.new(0.34 * scale, 0.45 * scale, 0.12), Vector3.new(0, 2.38 * scale, 0),
			primary, METAL, CFrame.Angles(0, math.pi / 2, 0), "WedgePart")
		part("Fuller", Vector3.new(0.06, 1.35 * scale, 0.13), Vector3.new(0, 1.27 * scale, 0), accent)
		ball("Pommel", 0.28 * scale, Vector3.new(0, -0.45 * scale, 0), accent)
	elseif shape == "Axe" then
		handle = cylinder("Handle", 0.18, 2.8, Vector3.new(0, 0.8, 0), dark, WOOD)
		part("HeadSocket", Vector3.new(0.34, 0.65, 0.3), Vector3.new(0, 1.85, 0), accent)
		part("AxeBlade", Vector3.new(0.95, 0.85, 0.17), Vector3.new(0.55, 1.85, 0), primary, METAL,
			CFrame.Angles(0, 0, -0.12))
		part("CuttingEdge", Vector3.new(0.15, 1.05, 0.2), Vector3.new(1.0, 1.85, 0), silver)
		part("BackSpike", Vector3.new(0.45, 0.25, 0.2), Vector3.new(-0.33, 1.85, 0), primary)
	elseif shape == "Mace" then
		handle = grip(1.5)
		cylinder("Collar", 0.35, 0.18, Vector3.new(0, 0.82, 0), accent)
		ball("Head", 0.85, Vector3.new(0, 1.2, 0), primary)
		for index = 0, 3 do
			local angle = index * math.pi / 2
			part("Flange" .. index, Vector3.new(0.17, 0.7, 0.45),
				Vector3.new(math.sin(angle) * 0.36, 1.2, math.cos(angle) * 0.36), accent, METAL,
				CFrame.Angles(0, angle, 0))
		end
	elseif shape == "Spear" then
		handle = cylinder("Handle", 0.16, 3.7, Vector3.new(0, 0.8, 0), dark, WOOD)
		cylinder("Binding", 0.22, 0.4, Vector3.new(0, 2.5, 0), accent)
		part("Spearhead", Vector3.new(0.38, 0.85, 0.12), Vector3.new(0, 3.06, 0), primary, METAL,
			CFrame.Angles(0, math.pi / 2, 0), "WedgePart")
	elseif shape == "Bow" then
		handle = grip(0.65)
		local points = {
			Vector3.new(0.08, -1.65, 0), Vector3.new(0.52, -1.05, 0), Vector3.new(0.62, -0.5, 0),
			Vector3.new(0, 0, 0), Vector3.new(0.62, 0.5, 0), Vector3.new(0.52, 1.05, 0),
			Vector3.new(0.08, 1.65, 0),
		}
		for index = 1, #points - 1 do
			line("BowLimb" .. index, points[index], points[index + 1], 0.15, primary, WOOD)
		end
		line("Bowstring", points[1], points[#points], 0.035, accent, CLOTH)
	elseif shape == "Crossbow" then
		handle = part("Handle", Vector3.new(0.24, 0.55, 0.35), Vector3.new(0, -0.25, 0.25), dark, WOOD)
		part("Stock", Vector3.new(0.3, 0.3, 1.8), Vector3.new(0, 0, 0.3), primary, WOOD)
		line("LeftLimb", Vector3.new(-1, 0, -0.3), Vector3.new(0, 0, -0.6), 0.15, accent)
		line("RightLimb", Vector3.new(0, 0, -0.6), Vector3.new(1, 0, -0.3), 0.15, accent)
		line("LeftString", Vector3.new(-1, 0.04, -0.3), Vector3.new(0, 0.04, 0.1), 0.035, dark, CLOTH)
		line("RightString", Vector3.new(1, 0.04, -0.3), Vector3.new(0, 0.04, 0.1), 0.035, dark, CLOTH)
		line("Bolt", Vector3.new(0, 0.2, -0.8), Vector3.new(0, 0.2, 0.4), 0.065, silver)
	elseif shape == "Staff" or shape == "Wand" then
		local length = if shape == "Staff" then 3.2 else 1.2
		handle = cylinder("Handle", if shape == "Staff" then 0.19 else 0.12, length,
			Vector3.new(0, length / 2 - 0.4, 0), primary, WOOD)
		cylinder("CrystalSetting", 0.35, 0.2, Vector3.new(0, length - 0.4, 0), accent)
		ball("AetherCrystal", if shape == "Staff" then 0.58 else 0.32,
			Vector3.new(0, length - 0.13, 0), accent, Enum.Material.Neon)
	elseif shape == "Shield" then
		handle = part("Handle", Vector3.new(0.15, 0.6, 0.15), Vector3.new(0, 0, 0.2), dark, WOOD)
		part("ShieldFace", Vector3.new(1.5, 1.8, 0.2), Vector3.zero, primary)
		part("TopRim", Vector3.new(1.6, 0.12, 0.28), Vector3.new(0, 0.9, 0), accent)
		for _, side in {-1, 1} do
			part("SideRim" .. side, Vector3.new(0.12, 1.85, 0.28), Vector3.new(side * 0.75, 0, 0), accent)
		end
		part("ShieldTip", Vector3.new(1.5, 0.5, 0.2), Vector3.new(0, -1.1, 0), primary, METAL,
			CFrame.Angles(0, math.pi / 2, math.pi), "WedgePart")
		ball("Boss", 0.4, Vector3.new(0, 0, -0.17), accent)
	elseif shape == "Focus" then
		handle = part("Handle", Vector3.new(0.55, 0.12, 0.55), Vector3.new(0, -0.4, 0), primary)
		ball("FocusOrb", 0.72, Vector3.new(0, 0.1, 0), accent, Enum.Material.Neon)
		for _, side in {-1, 1} do
			part("OrbProng" .. side, Vector3.new(0.12, 0.8, 0.12), Vector3.new(side * 0.4, 0, 0), primary,
				METAL, CFrame.Angles(0, 0, -side * 0.3))
		end
	elseif shape == "Quiver" then
		handle = cylinder("Handle", 0.6, 1.5, Vector3.zero, primary, WOOD)
		cylinder("MouthRim", 0.7, 0.12, Vector3.new(0, 0.76, 0), accent)
		for index = 1, 3 do
			local x = (index - 2) * 0.16
			cylinder("ArrowShaft" .. index, 0.05, 0.9, Vector3.new(x, 1.0, 0), dark, WOOD)
			part("Fletching" .. index, Vector3.new(0.2, 0.25, 0.045), Vector3.new(x, 1.35, 0), accent, CLOTH)
		end
	elseif shape == "Lantern" then
		handle = part("Handle", Vector3.new(0.55, 0.1, 0.12), Vector3.new(0, 0.75, 0), accent)
		part("Base", Vector3.new(0.75, 0.12, 0.75), Vector3.new(0, -0.5, 0), primary)
		part("Cap", Vector3.new(0.8, 0.16, 0.8), Vector3.new(0, 0.5, 0), primary)
		ball("Glow", 0.45, Vector3.zero, accent, Enum.Material.Neon)
		for _, x in {-0.3, 0.3} do
			for _, z in {-0.3, 0.3} do
				part("CagePost", Vector3.new(0.07, 1, 0.07), Vector3.new(x, 0, z), primary)
			end
		end
		for _, side in {-1, 1} do
			part("HandleUpright" .. side, Vector3.new(0.07, 0.3, 0.1), Vector3.new(side * 0.25, 0.65, 0), accent)
		end
	elseif shape == "Helmet" then
		if item.id == "acolyte_helmet" then
			for index = 0, 7 do
				local angle = index * math.pi / 4
				local piece = part(if index == 0 then "Handle" else "CircletBand" .. index,
					Vector3.new(0.42, 0.16, 0.1), Vector3.new(math.sin(angle) * 0.5, 0, math.cos(angle) * 0.5),
					primary, METAL, CFrame.Angles(0, angle, 0))
				if index == 0 then handle = piece end
			end
			ball("BrowCrystal", 0.25, Vector3.new(0, 0.08, -0.55), accent)
		else
			local material = if item.id == "scout_helmet" then CLOTH else METAL
			handle = part("Handle", Vector3.new(1.1, 0.25, 0.95), Vector3.new(0, 0.5, 0), primary, material)
			part("BackPlate", Vector3.new(1.1, 0.7, 0.15), Vector3.new(0, 0.05, 0.4), primary, material)
			for _, side in {-1, 1} do
				part("CheekGuard" .. side, Vector3.new(0.18, 0.8, 0.85), Vector3.new(side * 0.5, -0.05, 0), primary, material)
			end
			part("Brow", Vector3.new(1.1, 0.14, 0.15), Vector3.new(0, 0.25, -0.42), accent)
			if item.id ~= "scout_helmet" then
				part("Crest", Vector3.new(0.12, 0.2, 0.65), Vector3.new(0, 0.7, 0), accent)
			end
		end
	elseif shape == "Chest" then
		handle = part("Handle", Vector3.new(1.4, 1.65, 0.65), Vector3.zero, primary, armorMaterial)
		for _, side in {-1, 1} do
			part("Shoulder" .. side, Vector3.new(0.5, 0.45, 0.8), Vector3.new(side * 0.85, 0.6, 0), primary,
				armorMaterial, CFrame.Angles(0, 0, side * -0.15))
		end
		if item.id == "acolyte_chest" then
			part("RobeHem", Vector3.new(1.6, 0.9, 0.8), Vector3.new(0, -1.05, 0), primary, CLOTH)
		end
		part("Belt", Vector3.new(1.45, 0.18, 0.7), Vector3.new(0, -0.55, 0), dark, WOOD)
		part("Buckle", Vector3.new(0.25, 0.25, 0.08), Vector3.new(0, -0.55, -0.39), accent)
		part("ChestEmblem", Vector3.new(0.25, 0.45, 0.08), Vector3.new(0, 0.25, -0.37), accent)
	elseif shape == "Gloves" or shape == "Boots" then
		for _, side in {-1, 1} do
			local x = side * 0.43
			local piece = part(if side == -1 then "Handle" else "PairedPiece", Vector3.new(0.55, 0.8, 0.55),
				Vector3.new(x, 0, 0), primary, armorMaterial)
			if side == -1 then handle = piece end
			part("Cuff" .. side, Vector3.new(0.65, 0.15, 0.65), Vector3.new(x, 0.42, 0), accent)
			if shape == "Boots" then
				part("Toe" .. side, Vector3.new(0.57, 0.3, 0.85), Vector3.new(x, -0.3, -0.2), primary, armorMaterial)
				part("Sole" .. side, Vector3.new(0.6, 0.1, 0.9), Vector3.new(x, -0.48, -0.17), dark, WOOD)
			else
				part("Thumb" .. side, Vector3.new(0.2, 0.35, 0.3), Vector3.new(x - side * 0.32, -0.1, -0.05), primary,
					armorMaterial, CFrame.Angles(0, 0, side * 0.25))
			end
		end
	elseif shape == "Accessory" then
		local identity = string.lower(item.id .. " " .. item.family)
		if string.find(identity, "band") or string.find(identity, "ring") or string.find(identity, "signet") then
			for index = 0, 7 do
				local angle = index * math.pi / 4
				local piece = part(if index == 0 then "Handle" else "BandSegment" .. index,
					Vector3.new(0.28, 0.13, 0.13), Vector3.new(math.sin(angle) * 0.35, math.cos(angle) * 0.35, 0),
					primary, METAL, CFrame.Angles(0, 0, -angle))
				if index == 0 then handle = piece end
			end
			ball("Setting", 0.2, Vector3.new(0, 0.48, 0), accent)
		else
			handle = part("Handle", Vector3.new(0.45, 0.6, 0.15), Vector3.new(0, -0.3, 0), primary, METAL,
				CFrame.Angles(0, 0, math.pi / 4))
			ball("Inlay", 0.22, Vector3.new(0, -0.3, -0.12), accent)
			line("LeftChain", Vector3.new(-0.45, 0.65, 0), Vector3.new(0, 0, 0), 0.045, accent)
			line("RightChain", Vector3.new(0.45, 0.65, 0), Vector3.new(0, 0, 0), 0.045, accent)
			line("ChainTop", Vector3.new(-0.45, 0.65, 0), Vector3.new(0.45, 0.65, 0), 0.045, accent)
		end
	else
		model:Destroy()
		error("Unsupported equipment silhouette: " .. tostring(shape))
	end

	model.PrimaryPart = handle
	return model
end

return table.freeze(EquipmentModels)
