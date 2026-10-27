-- Input and presentation only. Movement, stamina and damage protection are server-owned.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ContextActionService = game:GetService("ContextActionService")
local UserInputService = game:GetService("UserInputService")
if not RunService:IsStudio() then return end

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local remotes = ReplicatedStorage:WaitForChild("WorkshopRemotes", 30)
if not remotes then return end
local request = remotes:WaitForChild("DefenceRequest", 30)
local stateRemote = remotes:WaitForChild("DefenceState", 30)
local feedbackRemote = remotes:WaitForChild("DefenceFeedback", 30)
if not request or not stateRemote or not feedbackRemote then
	warn("Defence controls did not start; check Server Output.")
	return
end

local connections = {}
local running = true
local state = nil
local blockRequested, sprintRequested = false, false
local shiftHeld, sprintPendingStart = false, false
local shiftResumeAllowed = false
local sprintRetryAt = 0
local messageUntil, lastDodge = 0, -math.huge
local actions = { "AetherfallDodge", "AetherfallGuard", "AetherfallSprint" }
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
	Name = "AetherfallDefence", ResetOnSpawn = false, DisplayOrder = 0,
	ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets, ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
})
local panel = create("Frame", screen, {
	Name = "DefenceHUD", AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -115), Size = UDim2.new(0.88, 0, 0, 30),
	BackgroundColor3 = Color3.fromRGB(17, 27, 36), BackgroundTransparency = 0.1, BorderSizePixel = 0,
})
create("UISizeConstraint", panel, { MaxSize = Vector2.new(640, 30), MinSize = Vector2.new(230, 30) })
create("UICorner", panel, { CornerRadius = UDim.new(0, 6) })
local caption = create("TextLabel", panel, {
	Name = "DefenceStatus", Size = UDim2.new(1, -12, 1, 0), Position = UDim2.fromOffset(6, 0),
	Text = "Dodge Q / B · Guard RMB / LT · Sprint Shift / L3",
	BackgroundTransparency = 1, Font = Enum.Font.GothamMedium, TextSize = 11,
	TextColor3 = Color3.fromRGB(228, 229, 211), TextWrapped = true,
})
local notice = create("TextLabel", screen, {
	Name = "DefenceFeedback", AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -150), Size = UDim2.new(0.8, 0, 0, 32),
	Text = "", BackgroundTransparency = 1, Font = Enum.Font.GothamBold, TextSize = 16,
	TextColor3 = Color3.fromRGB(230, 217, 170), TextStrokeTransparency = 0.45, TextWrapped = true,
})

local function overlayOpen()
	local equipment = playerGui:FindFirstChild("AetherfallEquipment")
	local workshop = equipment and equipment:FindFirstChild("Workshop")
	local quests = playerGui:FindFirstChild("AetherfallQuests")
	local dialogue = quests and quests:FindFirstChild("Dialogue")
	return (workshop ~= nil and workshop.Visible) or (dialogue ~= nil and dialogue.Visible)
end
local function suppressed()
	return overlayOpen() or UserInputService:GetFocusedTextBox() ~= nil
end
local function fire(action, argument)
	if request.Parent then request:FireServer(action, argument) end
end
local function block(wanted, force)
	if not force and blockRequested == wanted then return end
	if wanted then shiftResumeAllowed, sprintPendingStart = false, false end
	blockRequested = wanted
	fire("Block", wanted)
end
local function sprint(wanted, force)
	if not force and sprintRequested == wanted then return end
	sprintRequested = wanted
	fire("Sprint", wanted)
end
local function releaseHolds()
	-- Release commands are sent even while a menu or text box has focus.
	shiftHeld, sprintPendingStart, shiftResumeAllowed = false, false, false
	block(false)
	sprint(false)
end
local function notify(message, color)
	if type(message) ~= "string" or #message == 0 then return end
	notice.Text = string.sub(message, 1, 180)
	notice.TextColor3 = color or Color3.fromRGB(230, 217, 170)
	messageUntil = os.clock() + 1.8
end
local function finite(value)
	return type(value) == "number" and value == value and math.abs(value) < math.huge
end
local function dodgeDirection()
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not humanoid or not root or not root:IsA("BasePart") or humanoid.Health <= 0 then return nil end
	local direction = Vector3.new(humanoid.MoveDirection.X, 0, humanoid.MoveDirection.Z)
	if direction.Magnitude < 0.05 then
		direction = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
	end
	if not finite(direction.X) or not finite(direction.Z) or direction.Magnitude < 0.01 then return nil end
	return direction.Unit
end
local function moving()
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	return humanoid ~= nil and humanoid.Health > 0 and humanoid.MoveDirection.Magnitude > 0.05
end
local function dodge()
	if suppressed() or os.clock() - lastDodge < 0.1 then return false end
	local direction = dodgeDirection()
	if not direction then return false end
	shiftResumeAllowed, sprintPendingStart = false, false
	lastDodge = os.clock()
	fire("Dodge", direction)
	return true
end

ContextActionService:BindAction("AetherfallDodge", function(_, inputState)
	if inputState ~= Enum.UserInputState.Begin or suppressed() then return Enum.ContextActionResult.Pass end
	dodge()
	return Enum.ContextActionResult.Sink
end, true, Enum.KeyCode.Q, Enum.KeyCode.ButtonB)
ContextActionService:BindAction("AetherfallGuard", function(_, inputState, input)
	if inputState == Enum.UserInputState.End or inputState == Enum.UserInputState.Cancel then
		if input.UserInputType ~= Enum.UserInputType.Touch then block(false) end
		return Enum.ContextActionResult.Pass
	end
	if inputState ~= Enum.UserInputState.Begin or suppressed() then return Enum.ContextActionResult.Pass end
	if input.UserInputType == Enum.UserInputType.Touch then
		-- Touch uses a toggle; the latest server state determines its next request.
		local active = if state then state.blocking == true else blockRequested
		block(not active, true)
	else block(true) end
	return Enum.ContextActionResult.Sink
end, true, Enum.KeyCode.ButtonL2)
ContextActionService:BindAction("AetherfallSprint", function(_, inputState, input)
	local toggled = input.UserInputType == Enum.UserInputType.Touch or input.KeyCode == Enum.KeyCode.ButtonL3
	if inputState == Enum.UserInputState.End or inputState == Enum.UserInputState.Cancel then
		if not toggled then
			shiftHeld, sprintPendingStart, shiftResumeAllowed = false, false, false
			sprint(false)
		end
		return Enum.ContextActionResult.Pass
	end
	if inputState ~= Enum.UserInputState.Begin or suppressed() then return Enum.ContextActionResult.Pass end
	if toggled then
		local active = if state then state.sprinting == true else sprintRequested
		sprint(not active, true)
	else
		shiftHeld, sprintPendingStart, shiftResumeAllowed = true, true, true
		if moving() then sprint(true); sprintRetryAt = os.clock() + 0.5 end
	end
	return Enum.ContextActionResult.Sink
end, true, Enum.KeyCode.LeftShift, Enum.KeyCode.ButtonL3)
ContextActionService:SetTitle("AetherfallDodge", "Dodge")
ContextActionService:SetTitle("AetherfallGuard", "Guard")
ContextActionService:SetTitle("AetherfallSprint", "Sprint")
ContextActionService:SetPosition("AetherfallDodge", UDim2.fromScale(0.88, 0.75))
ContextActionService:SetPosition("AetherfallGuard", UDim2.fromScale(0.69, 0.75))
ContextActionService:SetPosition("AetherfallSprint", UDim2.fromScale(0.50, 0.75))
connect(UserInputService.InputBegan, function(input, processed)
	if not processed and input.UserInputType == Enum.UserInputType.MouseButton2 and not suppressed() then block(true) end
	-- An attack cancels a still-pending Shift start as well as the server's active sprint.
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.KeyCode == Enum.KeyCode.ButtonR2
		or input.KeyCode == Enum.KeyCode.One or input.KeyCode == Enum.KeyCode.ButtonX then
		sprintPendingStart, shiftResumeAllowed = false, false
	end
end)
connect(UserInputService.InputEnded, function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton2 then block(false) end
end)
connect(UserInputService.WindowFocusReleased, releaseHolds)
connect(UserInputService.TextBoxFocused, releaseHolds)
connect(player.CharacterAdded, function()
	releaseHolds()
	fire("Sync")
end)

connect(stateRemote.OnClientEvent, function(data)
	if type(data) ~= "table" then return end
	state = data
	if data.sprinting == true then sprintPendingStart = false end
	if data.sprinting == false and shiftHeld and shiftResumeAllowed and not moving()
		and data.blocking ~= true and not blockRequested then sprintPendingStart = true end
	if data.canPlay == false then releaseHolds() end
	if type(data.message) == "string" then notify(data.message) end
end)
connect(feedbackRemote.OnClientEvent, function(data)
	if type(data) ~= "table" then return end
	if type(data.message) == "string" and #data.message > 0 then notify(data.message); return end
	local damage = if finite(data.damage) then math.max(0, data.damage) else 0
	if data.kind == "Dodged" then notify("DODGED", Color3.fromRGB(169, 218, 229))
	elseif data.kind == "Blocked" then notify(string.format("BLOCKED · %.0f damage", damage), Color3.fromRGB(185, 218, 162))
	elseif data.kind == "GuardBroken" then notify("GUARD BROKEN", Color3.fromRGB(246, 168, 143))
	elseif data.kind == "Hit" and damage > 0 then notify(string.format("HIT · -%.0f health", damage), Color3.fromRGB(246, 168, 143)) end
	-- Feedback is static text, including when reduced motion is enabled.
end)

connect(script.Destroying, function()
	running = false
	releaseHolds()
	for _, connection in connections do connection:Disconnect() end
	for _, name in actions do ContextActionService:UnbindAction(name) end
	screen:Destroy()
end)
fire("Sync")
task.spawn(function()
	local retries, retryAt = 0, os.clock() + 2
	while running do
		local hidden = suppressed()
		if hidden then releaseHolds() end
		if shiftHeld and sprintPendingStart and not hidden and moving() and os.clock() >= sprintRetryAt
			and state and state.canPlay == true and finite(state.stamina) and state.stamina >= 1 then
			sprint(true, true)
			sprintRetryAt = os.clock() + 0.5
		end
		local camera = workspace.CurrentCamera
		local viewport = if camera then camera.ViewportSize else Vector2.new(800, 600)
		local compactBoss = player:GetAttribute("AetherfallBossActive") == true
			and viewport.X < 700 and viewport.Y < 450
		panel.Visible = not hidden and not compactBoss
		notice.Visible = not hidden and not compactBoss and os.clock() < messageUntil
		for _, name in actions do
			local button = ContextActionService:GetButton(name)
			if button then button.Visible = not hidden end
		end
		if state then
			local remaining = if finite(state.dodgeRemaining) then math.max(0, state.dodgeRemaining) else 0
			local dodgeText = if state.dodging == true then "DODGING" elseif remaining > 0 then string.format("Dodge %.1fs", remaining) else "Dodge Q/B ready"
			local guardTime = if finite(state.guardRemaining) then math.max(0, state.guardRemaining) else 0
			local guardText = if state.blocking == true then "GUARDING" elseif guardTime > 0 then string.format("Guard %.1fs", guardTime) elseif state.hasShield == true then "Guard RMB/LT" else "Guard needs shield"
			local sprintText = if state.sprinting == true then "SPRINTING" else "Sprint Shift/L3"
			caption.Text = if state.canPlay == false then "Defence paused · check player/save status" else dodgeText .. "  /  " .. guardText .. "  /  " .. sprintText
		elseif retries < 8 and os.clock() >= retryAt then
			retries += 1
			retryAt = os.clock() + 2
			fire("Sync")
		end
		task.wait(0.2)
	end
end)
