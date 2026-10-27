-- Boss health and warnings are presentation only; the encounter stays server-owned.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
if not RunService:IsStudio() then return end

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local remotes = ReplicatedStorage:WaitForChild("WorkshopRemotes", 30)
local stateRemote = remotes and remotes:WaitForChild("BossState", 30)
if not stateRemote then
	warn("The grove encounter did not start; check Server Output.")
	return
end
local function create(className, parent, properties)
	local object = Instance.new(className)
	for key, value in properties do object[key] = value end
	object.Parent = parent
	return object
end
local screen = create("ScreenGui", playerGui, {
	Name = "AetherfallBoss", ResetOnSpawn = false, DisplayOrder = 1,
	ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets, ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
})
local panel = create("Frame", screen, {
	Name = "BossHUD", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 10),
	Size = UDim2.new(0.45, 0, 0, 110), BackgroundColor3 = Color3.fromRGB(20, 32, 30),
	BackgroundTransparency = 0.05, BorderSizePixel = 0, Visible = false,
})
create("UICorner", panel, { CornerRadius = UDim.new(0, 10) })
create("UIStroke", panel, { Color = Color3.fromRGB(207, 179, 100), Transparency = 0.25 })
local function text(name, y, height, size, tint)
	return create("TextLabel", panel, {
		Name = name, Position = UDim2.fromOffset(10, y), Size = UDim2.new(1, -20, 0, height),
		Text = "", BackgroundTransparency = 1, Font = Enum.Font.GothamMedium, TextSize = size,
		TextColor3 = tint, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left,
	})
end
local title = text("BossName", 4, 25, 15, Color3.fromRGB(237, 218, 163))
title.Text = "BRIARWARDEN · GUARDIAN OF THE GROVE"
local bar = create("Frame", panel, {
	Name = "HealthBar", Position = UDim2.fromOffset(10, 32), Size = UDim2.new(1, -20, 0, 18),
	BackgroundColor3 = Color3.fromRGB(50, 55, 46), BorderSizePixel = 0, ClipsDescendants = true,
})
create("UICorner", bar, { CornerRadius = UDim.new(0, 4) })
local fill = create("Frame", bar, { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(120, 155, 76), BorderSizePixel = 0 })
local healthText = create("TextLabel", bar, {
	Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "",
	TextColor3 = Color3.fromRGB(244, 240, 217), TextStrokeTransparency = 0.35,
	Font = Enum.Font.GothamMedium, TextSize = 12,
})
local phase = text("Phase", 54, 20, 12, Color3.fromRGB(190, 207, 175))
local warning = text("Warning", 76, 30, 13, Color3.fromRGB(246, 215, 153))

local running, state, visibleUntil, lastMessage, notice = true, nil, 0, nil, nil
local function finite(value, fallback)
	return if type(value) == "number" and value == value and math.abs(value) < math.huge then value else fallback
end
local function safeText(value, fallback, limit)
	return if type(value) == "string" and #value > 0 then string.sub(value, 1, limit or 180) else fallback
end
local function overlayOpen()
	local inventory = playerGui:FindFirstChild("AetherfallEquipment")
	local workshop = inventory and inventory:FindFirstChild("Workshop")
	local quests = playerGui:FindFirstChild("AetherfallQuests")
	local dialogue = quests and quests:FindFirstChild("Dialogue")
	return (workshop ~= nil and workshop.Visible) or (dialogue ~= nil and dialogue.Visible)
end
local function layout(engaged)
	local camera = workspace.CurrentCamera
	local viewport = if camera then camera.ViewportSize else Vector2.new(800, 600)
	bar.Visible, phase.Visible = engaged, engaged
	warning.Position = UDim2.fromOffset(10, if engaged then 76 else 31)
	if not engaged then
		-- Result messages stay below the left HUD instead of covering the returned XP panel.
		panel.AnchorPoint = Vector2.new(0, 1)
		panel.Position = UDim2.new(0, 12, 1, -120)
		panel.Size = if viewport.X < 700 then UDim2.new(1, -24, 0, 66)
			else UDim2.fromOffset(math.min(450, viewport.X * 0.45), 66)
	elseif viewport.X < 700 then
		panel.AnchorPoint = Vector2.zero
		panel.Position = UDim2.fromOffset(12, 190)
		panel.Size = UDim2.new(1, -24, 0, 110)
	else
		panel.AnchorPoint = Vector2.new(1, 0)
		panel.Position = UDim2.new(1, -12, 0, 10)
		panel.Size = UDim2.fromOffset(math.min(450, viewport.X * 0.45), 110)
	end
end
local stateConnection = stateRemote.OnClientEvent:Connect(function(data)
	if type(data) ~= "table" then return end
	state = data
	local engaged = data.active == true and data.eligible == true
	player:SetAttribute("AetherfallBossActive", engaged)
	local maximum = math.max(1, finite(data.maxHealth, 650))
	local health = math.clamp(finite(data.health, 0), 0, maximum)
	fill.Size = UDim2.fromScale(health / maximum, 1)
	healthText.Text = string.format("%.0f / %.0f HP", health, maximum)
	local count = math.max(0, math.floor(finite(data.count, finite(data.participants, 0))))
	phase.Text = safeText(data.phase, "Dormant", 50) .. (if engaged then string.format(" · %d adventurers", count) else "")
	local message = safeText(data.message, nil, 200)
	local messageKey = if message then tostring(data.encounterId or "") .. ":" .. tostring(data.phase) .. ":" .. message else nil
	if messageKey and (messageKey ~= lastMessage or os.clock() >= visibleUntil) then
		lastMessage = messageKey
		notice = message
		visibleUntil = os.clock() + 5
	end
	warning.Text = if engaged then safeText(data.warning, "Watch the guardian's attacks and exposed core.", 200)
		elseif os.clock() < visibleUntil then notice or "" else ""
end)
local destroyConnection
destroyConnection = script.Destroying:Connect(function()
	running = false
	stateConnection:Disconnect()
	destroyConnection:Disconnect()
	player:SetAttribute("AetherfallBossActive", false)
	screen:Destroy()
end)
task.spawn(function()
	while running do
		local engaged = state and state.active == true and state.eligible == true
		layout(engaged == true)
		panel.Visible = not overlayOpen() and (engaged or os.clock() < visibleUntil)
		task.wait(0.2)
	end
end)
