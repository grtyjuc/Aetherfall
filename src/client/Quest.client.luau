-- Quest presentation only. NPC interactions, progress and rewards are server-owned.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ContextActionService = game:GetService("ContextActionService")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
if not RunService:IsStudio() then return end

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local remotes = ReplicatedStorage:WaitForChild("WorkshopRemotes", 30)
if not remotes then return end
local stateRemote = remotes:WaitForChild("QuestState", 30)
local request = remotes:WaitForChild("QuestRequest", 30)
if not stateRemote or not request then
	warn("Village quests did not start; check Server Output.")
	return
end
local connections, running, state = {}, true, nil
local dialogueRequested, previousSelection = false, nil
local compact, expanded = false, false
local lastViewport = Vector2.zero
local colors = {
	background = Color3.fromRGB(17, 27, 36), border = Color3.fromRGB(220, 180, 103),
	text = Color3.fromRGB(238, 233, 218), muted = Color3.fromRGB(174, 191, 196),
	button = Color3.fromRGB(48, 75, 87),
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
local function safeText(value, fallback, limit)
	return if type(value) == "string" and #value > 0 then string.sub(value, 1, limit or 400) else fallback
end
local screen = create("ScreenGui", playerGui, {
	Name = "AetherfallQuests", ResetOnSpawn = false, DisplayOrder = 5,
	ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets, ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
})
local tracker = create("Frame", screen, {
	Name = "QuestTracker", Position = UDim2.fromOffset(12, 190), Size = UDim2.fromOffset(280, 100),
	BackgroundColor3 = colors.background, BackgroundTransparency = 0.08, BorderSizePixel = 0,
})
create("UICorner", tracker, { CornerRadius = UDim.new(0, 9) })
create("UIStroke", tracker, { Color = colors.border, Transparency = 0.45 })
local title = create("TextButton", tracker, {
	Name = "QuestTitle", Text = "HEARTHGLEN QUESTS", Position = UDim2.fromOffset(10, 4),
	Size = UDim2.new(1, -20, 0, 28), BackgroundTransparency = 1, Font = Enum.Font.GothamMedium,
	TextSize = 13, TextColor3 = colors.border, TextXAlignment = Enum.TextXAlignment.Left,
	TextWrapped = true, AutoButtonColor = false,
})
local objective = create("TextLabel", tracker, {
	Name = "QuestObjective", Text = "Loading village quests…", Position = UDim2.fromOffset(10, 35),
	Size = UDim2.new(1, -20, 1, -40), BackgroundTransparency = 1, Font = Enum.Font.Gotham,
	TextSize = 13, TextColor3 = colors.text, TextWrapped = true,
	TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
})
-- Root input controllers inspect this exact frame to suppress attacks during dialogue.
local dialogue = create("Frame", screen, {
	Name = "Dialogue", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0),
	BackgroundTransparency = 0.45, BorderSizePixel = 0, Active = true, Visible = false,
})
local card = create("Frame", dialogue, {
	Name = "DialogueCard", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.new(0.9, 0, 0, 225), BackgroundColor3 = colors.background, BorderSizePixel = 0,
})
create("UISizeConstraint", card, { MaxSize = Vector2.new(420, 225), MinSize = Vector2.new(200, 200) })
create("UICorner", card, { CornerRadius = UDim.new(0, 12) })
create("UIStroke", card, { Color = colors.border, Transparency = 0.2 })
local speaker = create("TextLabel", card, {
	Name = "Speaker", Text = "Elder Rowan", Position = UDim2.fromOffset(14, 10),
	Size = UDim2.new(1, -28, 0, 30), BackgroundTransparency = 1, Font = Enum.Font.GothamBold,
	TextSize = 18, TextColor3 = colors.border, TextXAlignment = Enum.TextXAlignment.Left,
})
local bodyScroll = create("ScrollingFrame", card, {
	Name = "DialogueText", Position = UDim2.fromOffset(14, 47), Size = UDim2.new(1, -28, 1, -102),
	BackgroundTransparency = 1, BorderSizePixel = 0, CanvasSize = UDim2.new(),
	AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 4,
})
local body = create("TextLabel", bodyScroll, {
	Text = "", Size = UDim2.new(1, -8, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
	BackgroundTransparency = 1, Font = Enum.Font.Gotham, TextSize = 15, TextColor3 = colors.text,
	TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
})
local continueButton = create("TextButton", card, {
	Name = "Continue", Text = "Continue", Position = UDim2.new(0, 14, 1, -45),
	Size = UDim2.new(1, -28, 0, 32), BackgroundColor3 = colors.button, BorderSizePixel = 0,
	Font = Enum.Font.GothamMedium, TextSize = 14, TextColor3 = colors.text,
})
create("UICorner", continueButton, { CornerRadius = UDim.new(0, 6) })
local function inventoryOpen()
	local inventory = playerGui:FindFirstChild("AetherfallEquipment")
	local workshop = inventory and inventory:FindFirstChild("Workshop")
	return workshop ~= nil and workshop.Visible
end
local function closeDialogue()
	dialogueRequested = false
	dialogue.Visible = false
	if GuiService.SelectedObject == continueButton then
		GuiService.SelectedObject = if previousSelection and previousSelection.Parent then previousSelection else nil
	end
	previousSelection = nil
end
connect(continueButton.Activated, closeDialogue)
ContextActionService:BindAction("AetherfallCloseDialogue", function(_, inputState)
	if inputState == Enum.UserInputState.Begin and dialogue.Visible then
		closeDialogue()
		return Enum.ContextActionResult.Sink
	end
	return Enum.ContextActionResult.Pass
end, false, Enum.KeyCode.Escape, Enum.KeyCode.ButtonB)

local function applyLayout()
	local camera = workspace.CurrentCamera
	local viewport = if camera then camera.ViewportSize else Vector2.new(800, 600)
	if viewport == lastViewport then return end
	lastViewport = viewport
	compact = viewport.Y < 450
	if viewport.X < 560 then
		tracker.Position = UDim2.fromOffset(12, 375)
		tracker.Size = UDim2.new(1, -24, 0, if compact and not expanded then 32 else 84)
	elseif viewport.X < 700 then
		tracker.Position = UDim2.fromOffset(12, if compact then 180 else 190)
		tracker.Size = UDim2.fromOffset(math.min(280, viewport.X * 0.45), if compact and not expanded then 32 else 100)
	else
		tracker.Position = UDim2.fromOffset(12, if compact then 180 else 190)
		tracker.Size = UDim2.fromOffset(280, if compact and not expanded then 32 else 100)
	end
	objective.Visible = not compact or expanded
end
connect(title.Activated, function()
	if not compact then return end
	expanded = not expanded
	lastViewport = Vector2.zero
	applyLayout()
end)
local function render()
	if not state then return end
	if state.canPlay == false then
		title.Text = "VILLAGE QUESTS"
		objective.Text = "Waiting for your character. Check the save status."
	else
		title.Text = safeText(state.title, "HEARTHGLEN QUESTS", 90)
		objective.Text = safeText(state.objective, "Talk to Elder Rowan in the village.")
	end
	if compact and not expanded then title.Text ..= "  [+]" end
	if type(state.dialogue) == "table" then
		speaker.Text = safeText(state.dialogue.speaker, "Hearthglen", 70)
		body.Text = safeText(state.dialogue.text, "Welcome to Hearthglen.", 700)
		bodyScroll.CanvasPosition = Vector2.zero
		if not dialogueRequested then previousSelection = GuiService.SelectedObject end
		dialogueRequested = true
		if UserInputService.GamepadEnabled then GuiService.SelectedObject = continueButton end
	end
end
connect(stateRemote.OnClientEvent, function(data)
	if type(data) ~= "table" then return end
	state = data
	render()
end)
connect(script.Destroying, function()
	running = false
	for _, connection in connections do connection:Disconnect() end
	ContextActionService:UnbindAction("AetherfallCloseDialogue")
	screen:Destroy()
end)
applyLayout()
request:FireServer("Sync")
task.spawn(function()
	local retries, retryAt = 0, os.clock() + 2
	while running do
		local inventory = inventoryOpen()
		local progression = playerGui:FindFirstChild("AetherfallProgression")
		local notice = progression and progression:FindFirstChild("RewardNotification")
		local portraitNotice = lastViewport.X < 560 and notice and notice.Visible
		tracker.Visible = not inventory and not dialogueRequested and not portraitNotice and player:GetAttribute("AetherfallBossActive") ~= true
		dialogue.Visible = dialogueRequested and not inventory
		applyLayout()
		if (not state or state.canPlay == false) and retries < 10 and os.clock() >= retryAt then
			retries += 1
			retryAt = os.clock() + 2
			request:FireServer("Sync")
		end
		task.wait(0.2)
	end
end)
