-- Client presentation only. The server owns resources, targeting checks, and damage.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ContextActionService = game:GetService("ContextActionService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
if not RunService:IsStudio() then return end

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local remotes = ReplicatedStorage:WaitForChild("WorkshopRemotes", 30)
if not remotes then return end
local request = remotes:WaitForChild("CombatRequest", 30)
local stateRemote = remotes:WaitForChild("CombatState", 30)
local feedbackRemote = remotes:WaitForChild("CombatFeedback", 30)
if not request or not stateRemote or not feedbackRemote then
	warn("Combat training did not start; check Server Output.")
	return
end

local connections = {}
local running = true
local reducedMotion = false
local selectedTarget = nil
local manualTargetUntil = 0
local lastRequest = 0
local state = nil
local statusUntil = 0
local classColors = {
	Sentinel = Color3.fromRGB(232, 192, 117),
	Spellweaver = Color3.fromRGB(128, 189, 247),
	Ranger = Color3.fromRGB(142, 214, 152),
}
local function connect(signal, callback)
	local connection = signal:Connect(callback)
	table.insert(connections, connection)
	return connection
end
local function create(className, parent, properties)
	local object = Instance.new(className)
	for key, value in properties do object[key] = value end
	object.Parent = parent
	return object
end
local screen = create("ScreenGui", playerGui, {
	Name = "AetherfallCombat", ResetOnSpawn = false, DisplayOrder = 0,
	ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets, ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
})
local panel = create("Frame", screen, {
	Name = "CombatHUD", Position = UDim2.fromOffset(12, 10), Size = UDim2.new(0.46, 0, 0, 170),
	BackgroundColor3 = Color3.fromRGB(17, 27, 36), BackgroundTransparency = 0.08, BorderSizePixel = 0,
})
create("UISizeConstraint", panel, { MinSize = Vector2.new(230, 170), MaxSize = Vector2.new(370, 170) })
create("UICorner", panel, { CornerRadius = UDim.new(0, 10) })
create("UIStroke", panel, { Color = classColors.Sentinel, Transparency = 0.45 })
local function text(parent, value, y, height, size, color)
	return create("TextLabel", parent, {
		Text = value, Position = UDim2.fromOffset(10, y), Size = UDim2.new(1, -20, 0, height),
		BackgroundTransparency = 1, Font = Enum.Font.GothamMedium, TextSize = size,
		TextColor3 = color or Color3.fromRGB(236, 233, 220), TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
	})
end
local title = text(panel, "AETHERFALL · TRAINING", 5, 26, 14, classColors.Sentinel)
local function bar(name, y, tint)
	local back = create("Frame", panel, {
		Name = name, Position = UDim2.fromOffset(10, y), Size = UDim2.new(1, -20, 0, 18),
		BackgroundColor3 = Color3.fromRGB(40, 49, 58), BorderSizePixel = 0, ClipsDescendants = true,
	})
	create("UICorner", back, { CornerRadius = UDim.new(0, 4) })
	local fill = create("Frame", back, { Size = UDim2.fromScale(1, 1), BackgroundColor3 = tint, BorderSizePixel = 0 })
	local caption = create("TextLabel", back, {
		Size = UDim2.fromScale(1, 1), Text = name, BackgroundTransparency = 1,
		Font = Enum.Font.GothamMedium, TextSize = 12, TextColor3 = Color3.new(1, 1, 1),
		TextStrokeTransparency = 0.45,
	})
	return { fill = fill, caption = caption }
end
local health = bar("Health", 35, Color3.fromRGB(154, 65, 67))
local mana = bar("Mana", 58, Color3.fromRGB(58, 104, 165))
local stamina = bar("Stamina", 81, Color3.fromRGB(75, 125, 83))
local skills = text(panel, "Connecting to combat training…", 106, 42, 12)
text(panel, "Studio sandbox · progress is not saved", 147, 18, 11, Color3.fromRGB(174, 190, 194))

local help = create("Frame", screen, {
	Name = "TrainingHelp", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -12),
	Size = UDim2.new(0.78, 0, 0, 96), BackgroundColor3 = Color3.fromRGB(17, 27, 36),
	BackgroundTransparency = 0.12, BorderSizePixel = 0,
})
create("UISizeConstraint", help, { MaxSize = Vector2.new(640, 96), MinSize = Vector2.new(250, 96) })
create("UICorner", help, { CornerRadius = UDim.new(0, 8) })
local targetText = text(help, "Look toward a training dummy to select it.", 4, 24, 13, classColors.Sentinel)
local status = text(help, "Face the selected dummy. Attack: click / RT · Skill: 1 / X", 28, 32, 12)
local motion = create("TextButton", help, {
	Text = "Reduced motion: OFF", Position = UDim2.new(0, 10, 1, -29), Size = UDim2.new(1, -20, 0, 24),
	BackgroundColor3 = Color3.fromRGB(40, 54, 63), BorderSizePixel = 0,
	Font = Enum.Font.GothamMedium, TextSize = 11, TextColor3 = Color3.fromRGB(225, 231, 226),
})
create("UICorner", motion, { CornerRadius = UDim.new(0, 4) })
local highlight = create("Highlight", workspace, {
	Name = "SelectedTrainingTarget", FillTransparency = 1, OutlineTransparency = 0.15,
	OutlineColor = classColors.Sentinel, DepthMode = Enum.HighlightDepthMode.Occluded, Enabled = false,
})
local effects = create("Folder", workspace, { Name = "AetherfallLocalCombatEffects_" .. player.UserId })
local activeTweens = {}
local swingStates = {}
local function inventoryOpen()
	local inventory = playerGui:FindFirstChild("AetherfallEquipment")
	local workshop = inventory and inventory:FindFirstChild("Workshop")
	return workshop ~= nil and workshop.Visible
end
local function notify(message, duration)
	status.Text = message
	statusUntil = os.clock() + (duration or 2)
end
local function setBar(record, name, value, maximum)
	value, maximum = tonumber(value) or 0, math.max(1, tonumber(maximum) or 1)
	record.fill.Size = UDim2.fromScale(math.clamp(value / maximum, 0, 1), 1)
	record.caption.Text = string.format("%s  %.0f / %.0f", name, value, maximum)
end
local function renderState()
	if not state then return end
	title.Text = "AETHERFALL · " .. string.upper(state.className or "TRAINING")
	title.TextColor3 = classColors[state.className] or classColors.Sentinel
	setBar(health, "Health", state.health, state.maxHealth)
	setBar(mana, "Mana", state.mana, state.maxMana)
	setBar(stamina, "Stamina", state.stamina, state.maxStamina)
	local basicTime = tonumber(state.basicRemaining) or 0
	local skillTime = tonumber(state.skillRemaining) or 0
	skills.Text = (state.basicName or "Attack") .. (if basicTime > 0 then string.format(" · %.1fs", basicTime) else " · Ready")
		.. "\n" .. (state.skillName or "Skill") .. (if skillTime > 0 then string.format(" · %.1fs", skillTime) else " · Ready")
	if state.hasWeapon == false and os.clock() > statusUntil then
		notify("Equip a compatible main-hand weapon in the armoury (I / Y).", 0.4)
	end
end
local function targetList()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local world = workspace:FindFirstChild("AetherfallTrainingGrounds")
	local targets = world and world:FindFirstChild("Targets")
	local result = {}
	if not root or not targets then return result end
	local camera = workspace.CurrentCamera
	for _, model in targets:GetChildren() do
		local hitbox = model:FindFirstChild("Hitbox")
		local id = model:GetAttribute("TargetId")
		local hp = model:GetAttribute("Health")
		if model:IsA("Model") and hitbox and hitbox:IsA("BasePart") and type(id) == "string" and type(hp) == "number" and hp > 0 then
			local distance = (hitbox.Position - root.Position).Magnitude
			if distance <= 100 and camera then
				local position, onScreen = camera:WorldToViewportPoint(hitbox.Position)
				local size = camera.ViewportSize
				local screenDistance = (Vector2.new(position.X, position.Y) - size / 2).Magnitude / math.max(1, size.Magnitude)
				table.insert(result, { model = model, id = id, distance = distance, score = screenDistance + distance / 2000 + (if onScreen then 0 else 2) })
			end
		end
	end
	table.sort(result, function(a, b) return a.score < b.score end)
	return result
end
local function updateTarget()
	local candidates = targetList()
	local chosen = candidates[1]
	if selectedTarget and os.clock() < manualTargetUntil then
		for _, candidate in candidates do
			if candidate.model == selectedTarget then chosen = candidate; break end
		end
	end
	selectedTarget = if chosen then chosen.model else nil
	highlight.Adornee = selectedTarget
	highlight.Enabled = selectedTarget ~= nil and not inventoryOpen()
	if chosen then
		local hp = chosen.model:GetAttribute("Health") or 0
		local maximum = chosen.model:GetAttribute("MaxHealth") or 300
		targetText.Text = string.format("Target: %s · %.0f/%.0f HP · %.0f studs", chosen.model.Name, hp, maximum, chosen.distance)
	else
		targetText.Text = "Look toward a training dummy to select it."
	end
end
local function send(action)
	if inventoryOpen() or UserInputService:GetFocusedTextBox() then return false end
	-- This throttle is presentation only. Server cooldowns and rate limits are authoritative.
	if os.clock() - lastRequest < 0.12 then return true end
	lastRequest = os.clock()
	local id = selectedTarget and selectedTarget:GetAttribute("TargetId")
	request:FireServer(action, id)
	return true
end
local function action(actionName, inputState, input)
	if inputState ~= Enum.UserInputState.Begin then return Enum.ContextActionResult.Pass end
	if inventoryOpen() or UserInputService:GetFocusedTextBox() then return Enum.ContextActionResult.Pass end
	local kind = if input.KeyCode == Enum.KeyCode.One or input.KeyCode == Enum.KeyCode.ButtonX then "Skill" else "Basic"
	if input.UserInputType == Enum.UserInputType.Touch then
		kind = if actionName == "AetherfallSkill" then "Skill" else "Basic"
	end
	send(kind)
	return Enum.ContextActionResult.Sink
end
ContextActionService:BindAction("AetherfallAttack", action, true, Enum.KeyCode.ButtonR2)
ContextActionService:BindAction("AetherfallSkill", action, true, Enum.KeyCode.One, Enum.KeyCode.ButtonX)
ContextActionService:SetTitle("AetherfallAttack", "Attack")
ContextActionService:SetTitle("AetherfallSkill", "Skill")
ContextActionService:SetPosition("AetherfallAttack", UDim2.fromScale(0.88, 0.58))
ContextActionService:SetPosition("AetherfallSkill", UDim2.fromScale(0.70, 0.58))
connect(UserInputService.InputBegan, function(input, gameProcessed)
	if not gameProcessed and input.UserInputType == Enum.UserInputType.MouseButton1 then send("Basic") end
end)
ContextActionService:BindAction("AetherfallCycleTarget", function(_, inputState)
	if inputState ~= Enum.UserInputState.Begin or inventoryOpen() or UserInputService:GetFocusedTextBox() then
		return Enum.ContextActionResult.Pass
	end
	local candidates = targetList()
	if #candidates > 0 then
		local index = 0
		for i, candidate in candidates do if candidate.model == selectedTarget then index = i; break end end
		selectedTarget = candidates[index % #candidates + 1].model
		manualTargetUntil = os.clock() + 4
		updateTarget()
	end
	return Enum.ContextActionResult.Sink
end, false, Enum.KeyCode.T, Enum.KeyCode.ButtonR3)

local function effectPart(name, position, size, tint)
	if #effects:GetChildren() >= 32 then return nil end
	local part = create("Part", effects, {
		Name = name, Position = position, Size = size, Color = tint,
		Material = Enum.Material.Neon, Anchored = true, CanCollide = false, CanTouch = false,
		CanQuery = false, CastShadow = false, Transparency = 0.2,
	})
	Debris:AddItem(part, 0.8)
	return part
end
local function tween(object, duration, properties)
	local animation = TweenService:Create(object, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), properties)
	activeTweens[animation] = true
	animation.Completed:Once(function() activeTweens[animation] = nil end)
	animation:Play()
	-- Explicitly release tween signals/references even if its target is destroyed early.
	task.delay(duration + 0.1, function()
		activeTweens[animation] = nil
		animation:Destroy()
	end)
	return animation
end
local function swing(actor, combo, abilityName)
	if reducedMotion then return end
	local character = actor and actor.Character
	local equipment = character and character:FindFirstChild("AetherfallEquipment")
	local gripName = if abilityName == "Shield Bash" then "OffHandGrip" else "WeaponGrip"
	local joint = equipment and equipment:FindFirstChild(gripName, true)
	if not joint or not (joint:IsA("Motor6D") or joint:IsA("Weld")) then return end
	local previous = swingStates[joint]
	local default = joint:GetAttribute("DefaultC0")
	local base = if previous then previous.base elseif typeof(default) == "CFrame" then default else joint.C0
	if previous then previous.tween:Cancel(); joint.C0 = base end
	local sign = if combo == 2 then -1 else 1
	joint.C0 = if abilityName == "Shield Bash" then base * CFrame.new(0, 0, -0.7)
		else base * CFrame.Angles(math.rad(-35), 0, math.rad(65 * sign))
	local animation = tween(joint, 0.24, { C0 = base })
	swingStates[joint] = { base = base, tween = animation }
	animation.Completed:Once(function()
		if swingStates[joint] and swingStates[joint].tween == animation then swingStates[joint] = nil end
	end)
end
local function feedback(data)
	if type(data) ~= "table" then return end
	if data.kind == "Rejected" then
		notify(data.message or "That action is not available.", 1.5)
		return
	end
	local own = data.actorUserId == player.UserId
	if own then notify(data.name or "Attack", 0.8) end
	local tint = classColors[data.className] or classColors.Sentinel
	local position = data.position
	if typeof(position) ~= "Vector3" then return end
	local actor = Players:GetPlayerByUserId(data.actorUserId or 0)
	if data.kind == "Melee" then swing(actor, data.combo or 1, data.name) end
	if not reducedMotion then
		if data.kind == "Projectile" and typeof(data.origin) == "Vector3" then
			local bolt = effectPart("ApprovedProjectile", data.origin, Vector3.new(0.18, 0.18, 0.65), tint)
			if bolt and (position - data.origin).Magnitude > 0.01 then
				bolt.CFrame = CFrame.lookAt(data.origin, position)
				tween(bolt, 0.16, { Position = position, Transparency = 1 })
			end
		elseif data.kind == "Area" then
			local burst = effectPart("ApprovedFlameBurst", position, Vector3.new(1, 1, 1), Color3.fromRGB(235, 162, 88))
			if burst then
				burst.Shape = Enum.PartType.Ball
				burst.Transparency = 0.7
				tween(burst, 0.25, { Size = Vector3.new(8, 8, 8), Transparency = 1 })
			end
		elseif data.kind == "Dash" then
			local mark = effectPart("ApprovedQuickstep", position - Vector3.new(0, 2.5, 0), Vector3.new(2, 0.08, 2), tint)
			if mark then tween(mark, 0.2, { Transparency = 1, Size = Vector3.new(4, 0.08, 4) }) end
		end
	end
	if type(data.damage) == "number" and data.damage > 0 then
		local anchor = effectPart("DamageNotice", position + Vector3.new(0, 2.3, 0), Vector3.new(0.1, 0.1, 0.1), tint)
		if anchor then
			anchor.Transparency = 1
			local bill = create("BillboardGui", anchor, { Size = UDim2.fromOffset(130, 42), AlwaysOnTop = true, Adornee = anchor, MaxDistance = 110 })
			create("TextLabel", bill, {
				Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1,
				Text = string.format("%s%.0f", if data.critical then "CRIT " else "", data.damage),
				Font = Enum.Font.GothamBold, TextSize = 20, TextColor3 = tint, TextStrokeTransparency = 0.3,
			})
			if not reducedMotion then tween(anchor, 0.6, { Position = anchor.Position + Vector3.new(0, 1, 0) }) end
		end
	end
end
connect(motion.Activated, function()
	reducedMotion = not reducedMotion
	motion.Text = "Reduced motion: " .. (if reducedMotion then "ON" else "OFF")
	if reducedMotion then
		effects:ClearAllChildren()
		for joint, record in swingStates do
			record.tween:Cancel()
			if joint.Parent then joint.C0 = record.base end
		end
		table.clear(swingStates)
	end
end)
connect(stateRemote.OnClientEvent, function(data)
	if type(data) == "table" then state = data; renderState() end
end)
connect(feedbackRemote.OnClientEvent, feedback)
connect(player.CharacterAdded, function()
	selectedTarget = nil
	manualTargetUntil = 0
	effects:ClearAllChildren()
	request:FireServer("Sync")
end)
connect(script.Destroying, function()
	running = false
	for _, connection in connections do connection:Disconnect() end
	for animation in activeTweens do animation:Cancel() end
	for joint, record in swingStates do if joint.Parent then joint.C0 = record.base end end
	ContextActionService:UnbindAction("AetherfallAttack")
	ContextActionService:UnbindAction("AetherfallSkill")
	ContextActionService:UnbindAction("AetherfallCycleTarget")
	highlight:Destroy()
	effects:Destroy()
	screen:Destroy()
end)
task.spawn(function()
	while running do
		local visible = not inventoryOpen()
		panel.Visible = visible
		help.Visible = visible
		for _, name in { "AetherfallAttack", "AetherfallSkill" } do
			local touchButton = ContextActionService:GetButton(name)
			if touchButton then touchButton.Visible = visible end
		end
		updateTarget()
		if os.clock() > statusUntil then
			status.Text = "Face the selected dummy. Attack: click / RT · Skill: 1 / X · Target: T / R3"
		end
		task.wait(0.2)
	end
end)
request:FireServer("Sync")
