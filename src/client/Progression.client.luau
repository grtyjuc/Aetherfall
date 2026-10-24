-- Progression presentation only. Rewards, saves and account state belong to the server.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
if not RunService:IsStudio() then return end

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local remotes = ReplicatedStorage:WaitForChild("WorkshopRemotes", 30)
if not remotes then return end
local stateRemote = remotes:WaitForChild("ProgressionState", 30)
local request = remotes:WaitForChild("ProgressionRequest", 30)
if not stateRemote or not request then
	warn("Player progression did not start; check Server Output.")
	return
end

local colors = {
	background = Color3.fromRGB(17, 27, 36), border = Color3.fromRGB(220, 180, 103),
	text = Color3.fromRGB(238, 233, 218), muted = Color3.fromRGB(174, 191, 196),
	blue = Color3.fromRGB(66, 119, 139), success = Color3.fromRGB(151, 214, 164),
	warning = Color3.fromRGB(243, 195, 119), error = Color3.fromRGB(255, 170, 155),
}
local connections = {}
local running = true
local state = nil
local noticeUntil = 0
local lastNotice = nil
local lastWidth = 0

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
local function finite(value, fallback)
	return if type(value) == "number" and value == value and math.abs(value) < math.huge then value else fallback
end
local function boundedText(value, fallback)
	return if type(value) == "string" and #value > 0 then string.sub(value, 1, 300) else fallback
end

local screen = create("ScreenGui", playerGui, {
	Name = "AetherfallProgression", ResetOnSpawn = false, DisplayOrder = 0,
	ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets, ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
})
local panel = create("Frame", screen, {
	Name = "ProgressionHUD", AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -12, 0, 10), Size = UDim2.fromOffset(280, 178),
	BackgroundColor3 = colors.background, BackgroundTransparency = 0.08, BorderSizePixel = 0,
})
create("UICorner", panel, { CornerRadius = UDim.new(0, 10) })
create("UIStroke", panel, { Color = colors.border, Transparency = 0.45 })
local function text(parent, name, value, y, height, fontSize, tint)
	return create("TextLabel", parent, {
		Name = name, Text = value, Position = UDim2.fromOffset(10, y),
		Size = UDim2.new(1, -20, 0, height), BackgroundTransparency = 1,
		Font = Enum.Font.GothamMedium, TextSize = fontSize,
		TextColor3 = tint or colors.text, TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Center,
	})
end
local title = text(panel, "LevelAndGold", "LEVEL 1  /  GOLD 0", 5, 24, 14, colors.border)
local xpBack = create("Frame", panel, {
	Name = "ExperienceBar", Position = UDim2.fromOffset(10, 33), Size = UDim2.new(1, -20, 0, 18),
	BackgroundColor3 = Color3.fromRGB(40, 49, 58), BorderSizePixel = 0, ClipsDescendants = true,
})
create("UICorner", xpBack, { CornerRadius = UDim.new(0, 4) })
local xpFill = create("Frame", xpBack, { Size = UDim2.fromScale(0, 1), BackgroundColor3 = colors.blue, BorderSizePixel = 0 })
local xpText = create("TextLabel", xpBack, {
	Size = UDim2.fromScale(1, 1), Text = "XP · loading", BackgroundTransparency = 1,
	Font = Enum.Font.GothamMedium, TextSize = 12, TextColor3 = colors.text, TextStrokeTransparency = 0.45,
})
local objective = text(panel, "CurrentObjective", "Loading player progression…", 56, 34, 13)
local badges = text(panel, "TrainingMilestones", "Basics [ ]   Skill [ ]   Mira [ ]", 93, 20, 11, colors.muted)
local saveStatus = text(panel, "SaveStatus", "Loading · waiting for player data", 119, 50, 11, colors.warning)
saveStatus.TextYAlignment = Enum.TextYAlignment.Top

local notification = create("Frame", screen, {
	Name = "RewardNotification", AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -12, 0, 194), Size = UDim2.fromOffset(280, 58),
	BackgroundColor3 = colors.background, BackgroundTransparency = 0.08, BorderSizePixel = 0, Visible = false,
})
create("UICorner", notification, { CornerRadius = UDim.new(0, 8) })
local notice = text(notification, "RewardMessage", "", 5, 48, 12, colors.success)

local function inventoryOpen()
	local inventory = playerGui:FindFirstChild("AetherfallEquipment")
	local workshop = inventory and inventory:FindFirstChild("Workshop")
	return workshop ~= nil and workshop.Visible
end

local function applyLayout()
	local camera = workspace.CurrentCamera
	local width = if camera then camera.ViewportSize.X else 800
	if width == lastWidth then return end
	lastWidth = width
	-- On portrait screens, stack beneath the combat panel instead of overlapping it.
	if width < 560 then
		panel.AnchorPoint = Vector2.zero
		panel.Position = UDim2.fromOffset(12, 190)
		panel.Size = UDim2.new(1, -24, 0, 178)
		notification.AnchorPoint = Vector2.zero
		notification.Position = UDim2.fromOffset(12, 374)
		notification.Size = UDim2.new(1, -24, 0, 58)
	else
		local panelWidth = math.min(280, math.max(190, width * 0.40))
		panel.AnchorPoint = Vector2.new(1, 0)
		panel.Position = UDim2.new(1, -12, 0, 10)
		panel.Size = UDim2.fromOffset(panelWidth, 178)
		notification.AnchorPoint = Vector2.new(1, 0)
		notification.Position = UDim2.new(1, -12, 0, 194)
		notification.Size = UDim2.fromOffset(panelWidth, 58)
	end
end

local function render()
	if not state then return end
	local level = math.floor(math.clamp(finite(state.level, 1), 1, 60))
	local xp = math.max(0, math.floor(finite(state.xp, 0)))
	local required = math.max(0, math.floor(finite(state.requiredXp, 0)))
	local gold = math.floor(math.clamp(finite(state.gold, 0), 0, 1e9))
	title.Text = string.format("LEVEL %d  /  GOLD %d", level, gold)
	if level == 60 then
		xpFill.Size = UDim2.fromScale(1, 1)
		xpText.Text = "LEVEL CAP"
	else
		xpFill.Size = UDim2.fromScale(math.clamp(xp / math.max(1, required), 0, 1), 1)
		xpText.Text = string.format("XP  %d / %d", xp, required)
	end
	local basicDone = state.basicDone == true
	local skillDone = state.skillDone == true
	local finalDone = state.finalDone == true
	local goal = math.max(1, math.floor(finite(state.basicGoal, 3)))
	local hits = math.floor(math.clamp(finite(state.basicHits, 0), 0, goal))
	if state.canPlay == false then
		objective.Text = if state.saveMode == "Lost" then "Player data unavailable · actions paused" else "Waiting for player data…"
	elseif finalDone then
		objective.Text = "Training complete · explore your equipment builds"
	elseif not basicDone then
		objective.Text = string.format("Land %d basic attacks on dummies · %d/%d", goal, hits, goal)
	elseif not skillDone then
		objective.Text = "Use your class skill · 1 / X / touch Skill"
	else
		objective.Text = "Talk to Warden Mira to collect your training reward"
	end
	badges.Text = string.format("Basics [%s]   Skill [%s]   Mira [%s]", if basicDone then "✓" else " ", if skillDone then "✓" else " ", if finalDone then "✓" else " ")
	local mode = state.saveMode
	if mode == "Persistent" then
		saveStatus.Text = boundedText(state.saveMessage, "Persistent session · save confirmation pending")
		saveStatus.TextColor3 = colors.muted
	elseif mode == "SessionOnly" then
		saveStatus.Text = "Not saved · " .. boundedText(state.saveMessage, "Publish a test place and enable Studio API access to test saves.")
		saveStatus.TextColor3 = colors.warning
	elseif mode == "Lost" then
		saveStatus.Text = "Saving unavailable · " .. boundedText(state.saveMessage, "Your data session was lost. Rejoin before making more progress.")
		saveStatus.TextColor3 = colors.error
	else
		saveStatus.Text = "Loading · " .. boundedText(state.saveMessage, "Waiting for player data. Actions are paused.")
		saveStatus.TextColor3 = colors.warning
	end
	local message = boundedText(state.message, nil)
	if message and message ~= lastNotice then
		lastNotice = message
		notice.Text = message
		noticeUntil = os.clock() + 5
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
	screen:Destroy()
end)

applyLayout()
request:FireServer("Sync")
task.spawn(function()
	local retries, retryAt = 0, os.clock() + 2
	while running do
		local visible = not inventoryOpen()
		panel.Visible = visible
		notification.Visible = visible and os.clock() < noticeUntil
		applyLayout()
		-- Profile loading may finish after the first request; retries are bounded.
		if not state and retries < 8 and os.clock() >= retryAt then
			retries += 1
			retryAt = os.clock() + 2
			request:FireServer("Sync")
		end
		task.wait(0.2)
	end
end)
