local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ContextActionService = game:GetService("ContextActionService")
local RunService = game:GetService("RunService")
if not RunService:IsStudio() then return end

local shared = ReplicatedStorage:WaitForChild("Shared")
local Catalog = require(shared.EquipmentCatalog)
local Models = require(shared.EquipmentModels)
local remotes = ReplicatedStorage:WaitForChild("WorkshopRemotes", 30)
if not remotes then
	warn("Equipment workshop did not start. Check Server Output.")
	return
end
local request = remotes:WaitForChild("EquipmentRequest")
local colors = {
	background = Color3.fromRGB(16, 24, 33), panel = Color3.fromRGB(25, 36, 47),
	card = Color3.fromRGB(35, 49, 60), text = Color3.fromRGB(238, 233, 218),
	muted = Color3.fromRGB(174, 191, 196), gold = Color3.fromRGB(220, 180, 103),
	blue = Color3.fromRGB(66, 119, 139), error = Color3.fromRGB(255, 170, 155),
}
local function make(className, parent, properties)
	local object = Instance.new(className)
	for key, value in properties do object[key] = value end
	object.Parent = parent
	return object
end
local function label(parent, text, position, size, fontSize, color)
	return make("TextLabel", parent, {
		Text = text, Position = position, Size = size, TextSize = fontSize or 14,
		Font = Enum.Font.Gotham, TextColor3 = color or colors.text,
		BackgroundTransparency = 1, TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Center,
	})
end
local function button(parent, text, position, size, callback)
	local object = make("TextButton", parent, {
		Text = text, Position = position, Size = size, TextSize = 13,
		Font = Enum.Font.GothamMedium, TextColor3 = colors.text, BackgroundColor3 = colors.card,
		BorderSizePixel = 0, AutoButtonColor = true, TextWrapped = true,
	})
	make("UICorner", object, { CornerRadius = UDim.new(0, 6) })
	object.Activated:Connect(callback)
	return object
end

local screen = make("ScreenGui", Players.LocalPlayer:WaitForChild("PlayerGui"), {
	Name = "AetherfallEquipment", ResetOnSpawn = false, ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
})
local root = make("Frame", screen, {
	Name = "Workshop", Position = UDim2.fromScale(0.025, 0.025), Size = UDim2.fromScale(0.95, 0.95),
	BackgroundColor3 = colors.background, BorderSizePixel = 0,
})
make("UICorner", root, { CornerRadius = UDim.new(0, 12) })
make("UIStroke", root, { Color = colors.gold, Thickness = 1, Transparency = 0.4 })
label(root, "AETHERFALL  /  THE HEARTHGLEN ARMOURY", UDim2.fromOffset(14, 5), UDim2.new(1, -70, 0, 34), 16, colors.gold)
button(root, "×", UDim2.new(1, -48, 0, 8), UDim2.fromOffset(36, 32), function() root.Visible = false end)
local saveNotice = label(root, "Loading your character…", UDim2.fromOffset(14, 40), UDim2.new(1, -28, 0, 32), 12, colors.muted)

local state, selectedUid, selectedSlot, category = nil, nil, nil, "All"
local accessoryTarget = "Accessory1"
local busy = false
local render
local status = label(root, "Connecting to workshop…", UDim2.new(0, 14, 1, -40), UDim2.new(1, -28, 0, 36), 13, colors.gold)
local function transact(action, first, second)
	if busy then return end
	busy = true
	local success, response = pcall(function() return request:InvokeServer(action, first, second) end)
	busy = false
	if not success or type(response) ~= "table" then
		status.Text = "Connection interrupted. Reopen the armoury to retry."
		status.TextColor3 = colors.error
		return
	end
	if response.state then state = response.state end
	status.Text = response.message or "No response."
	status.TextColor3 = if response.ok then colors.gold else colors.error
	if state and render then render() end
end

local classButtons = {}
for index, className in Catalog.Classes do
	classButtons[className] = button(root, className, UDim2.new((index - 1) / 3, 10, 0, 76), UDim2.new(1 / 3, -16, 0, 36), function()
		transact("Class", className)
	end)
end
local content = make("Frame", root, {
	Position = UDim2.fromOffset(10, 122), Size = UDim2.new(1, -20, 1, -166), BackgroundTransparency = 1,
})
local inventoryPanel = make("Frame", content, { Size = UDim2.fromScale(0.39, 1), BackgroundColor3 = colors.panel, BorderSizePixel = 0 })
local filters = make("ScrollingFrame", inventoryPanel, {
	Size = UDim2.new(1, 0, 0, 42), BackgroundTransparency = 1, BorderSizePixel = 0,
	AutomaticCanvasSize = Enum.AutomaticSize.X, CanvasSize = UDim2.new(), ScrollBarThickness = 3,
	ScrollingDirection = Enum.ScrollingDirection.X,
})
make("UIListLayout", filters, { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder })
local filterButtons = {}
for index, name in { "All", "Weapons", "Armour", "Off hand", "Accessories" } do
	local b = button(filters, name, UDim2.new(), UDim2.fromOffset(if name == "Accessories" then 100 else 76, 36), function()
		category = name
		if state then render() end
	end)
	b.LayoutOrder = index
	filterButtons[name] = b
end
local list = make("ScrollingFrame", inventoryPanel, {
	Position = UDim2.fromOffset(6, 48), Size = UDim2.new(1, -12, 1, -54), BackgroundTransparency = 1,
	BorderSizePixel = 0, AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(), ScrollBarThickness = 5,
	ScrollingDirection = Enum.ScrollingDirection.Y,
})
make("UIListLayout", list, { Padding = UDim.new(0, 5), SortOrder = Enum.SortOrder.LayoutOrder })
local detail = make("Frame", content, {
	Position = UDim2.fromScale(0.405, 0), Size = UDim2.fromScale(0.595, 1), BackgroundColor3 = colors.panel, BorderSizePixel = 0,
})
local detailScroll = make("ScrollingFrame", detail, {
	Size = UDim2.new(1, 0, 1, -54), CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
	BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 4,
	ScrollingDirection = Enum.ScrollingDirection.Y,
})
local detailContent = make("Frame", detailScroll, { Size = UDim2.new(1, -8, 0, 850), BackgroundTransparency = 1 })
local itemTitle = label(detailContent, "Choose your equipment", UDim2.fromOffset(12, 6), UDim2.new(1, -24, 0, 42), 18, colors.gold)
local itemMeta = label(detailContent, "", UDim2.fromOffset(12, 48), UDim2.new(1, -24, 0, 38), 12, colors.muted)
local viewport = make("ViewportFrame", detailContent, {
	Position = UDim2.fromOffset(12, 90), Size = UDim2.new(1, -24, 0, 180), BackgroundColor3 = colors.background,
	Ambient = Color3.fromRGB(170, 182, 195), LightColor = Color3.fromRGB(255, 235, 210),
	LightDirection = Vector3.new(-1, -1, -1), BorderSizePixel = 0,
})
local camera = make("Camera", viewport, { FieldOfView = 40 })
viewport.CurrentCamera = camera
local previewWorld = make("WorldModel", viewport, { Name = "Preview" })
local itemDescription = label(detailContent, "", UDim2.fromOffset(12, 278), UDim2.new(1, -24, 0, 64), 13)
local itemStats = label(detailContent, "", UDim2.fromOffset(12, 346), UDim2.new(1, -24, 0, 80), 13, colors.gold)
itemStats.TextYAlignment = Enum.TextYAlignment.Top
local accessoryTargets = {}
for index, slot in { "Accessory1", "Accessory2" } do
	accessoryTargets[slot] = button(detailContent, "Target: Acc. " .. index, UDim2.new((index - 1) / 2, 12, 0, 430), UDim2.new(0.5, -18, 0, 36), function()
		accessoryTarget = slot
		selectedSlot = slot
		if state then render() end
	end)
end
local derived = label(detailContent, "", UDim2.fromOffset(12, 476), UDim2.new(1, -24, 0, 72), 12, colors.muted)
label(detailContent, "EQUIPPED · Select a slot to inspect or remove", UDim2.fromOffset(12, 552), UDim2.new(1, -24, 0, 36), 12, colors.gold)
local slotButtons = {}
for index, slot in Catalog.Slots do
	local b = button(detailContent, slot, UDim2.fromOffset(12, 594 + (index - 1) * 31), UDim2.new(1, -24, 0, 29), function()
		if not state then return end
		selectedSlot = slot
		if state.equipped[slot] then selectedUid = state.equipped[slot] end
		render()
	end)
	b.TextSize = 12
	slotButtons[slot] = b
end

local equipButton = button(detail, "Equip", UDim2.new(0, 8, 1, -46), UDim2.new(0.5, -12, 0, 38), function()
	if not state or not selectedUid then return end
	local item = Catalog.Items[state.inventory[selectedUid].itemId]
	local slot = item.slot
	if slot == "Accessory" then
		slot = accessoryTarget
	end
	transact("Equip", selectedUid, slot)
end)
local unequipButton = button(detail, "Remove slot", UDim2.new(0.5, 4, 1, -46), UDim2.new(0.5, -12, 0, 38), function()
	if selectedSlot then transact("Unequip", selectedSlot) end
end)

local statOrder = { "MaxHealth", "Attack", "MagicPower", "Defence", "MagicResistance", "CriticalChance", "MoveSpeed" }
local statNames = { MaxHealth = "Health", Attack = "Attack", MagicPower = "Magic", Defence = "Defence", MagicResistance = "Resistance", CriticalChance = "Crit", MoveSpeed = "Speed" }
local function formatStat(name, value)
	return if name == "CriticalChance" then string.format("%.0f%%", value * 100) else string.format("%g", value)
end
local function matches(item)
	return category == "All"
		or (category == "Weapons" and item.slot == "MainHand")
		or (category == "Off hand" and item.slot == "OffHand")
		or (category == "Accessories" and item.slot == "Accessory")
		or (category == "Armour" and table.find({ "Helmet", "Chest", "Gloves", "Boots" }, item.slot) ~= nil)
end
local previewId
local function showPreview(item)
	if previewId == item.id then return end
	previewId = item.id
	previewWorld:ClearAllChildren()
	local model = Models.create(item)
	model.Parent = previewWorld
	model:PivotTo(CFrame.Angles(0, math.rad(-22), 0))
	local cf, size = model:GetBoundingBox()
	local radius = size.Magnitude / 2
	local distance = radius / math.sin(math.rad(camera.FieldOfView / 2))
	-- Account for narrow mobile ViewportFrames as well as vertical field of view.
	local aspect = math.max(0.2, viewport.AbsoluteSize.X / math.max(1, viewport.AbsoluteSize.Y))
	distance *= math.max(1, 1 / aspect) * 1.12
	camera.CFrame = CFrame.lookAt(cf.Position + Vector3.new(0, 0.12, -1).Unit * distance, cf.Position)
end
local slotNames = { MainHand = "Main hand", OffHand = "Off hand", Helmet = "Helmet", Chest = "Chest", Gloves = "Gloves", Boots = "Boots", Accessory1 = "Accessory 1", Accessory2 = "Accessory 2" }
render = function()
	for name, b in classButtons do b.BackgroundColor3 = if state.className == name then colors.blue else colors.card end
	for name, b in filterButtons do b.BackgroundColor3 = if category == name then colors.blue else colors.card end
	for _, child in list:GetChildren() do if child:IsA("TextButton") then child:Destroy() end end
	local sorted = {}
	for uid, instance in state.inventory do table.insert(sorted, { uid = uid, item = Catalog.Items[instance.itemId] }) end
	table.sort(sorted, function(a, b)
		if a.item.level ~= b.item.level then return a.item.level < b.item.level end
		return a.item.name < b.item.name
	end)
	if #sorted == 0 then
		selectedUid = nil
		itemTitle.Text = "No equipment owned"
		itemMeta.Text = "Select a class to receive its starter loadout."
		itemDescription.Text, itemStats.Text, derived.Text = "", "", ""
		previewWorld:ClearAllChildren()
		previewId = nil
		for _, b in accessoryTargets do b.Visible = false end
		for slot, b in slotButtons do b.Text = slotNames[slot] .. ": Empty" end
		return
	end
	if not selectedUid or not state.inventory[selectedUid] then selectedUid = sorted[1].uid end
	for index, entry in sorted do
		local uid, item = entry.uid, entry.item
		if not matches(item) then continue end
		local equipped = false
		for _, equippedUid in state.equipped do if equippedUid == uid then equipped = true end end
		local allowed = table.find(item.classes, state.className) ~= nil
		local row = button(list, (if equipped then "[E] " else "") .. item.name .. "\n" .. item.rarity .. " · Lv " .. item.level .. (if allowed then "" else " · Other class"), UDim2.new(), UDim2.new(1, -6, 0, 60), function()
			selectedUid = uid
			selectedSlot = if item.slot == "Accessory" then accessoryTarget else item.slot
			render()
		end)
		row.LayoutOrder = index
		row.TextSize = 12
		row.BackgroundColor3 = if uid == selectedUid then colors.blue else colors.card
	end
	local item = Catalog.Items[state.inventory[selectedUid].itemId]
	itemTitle.Text = item.name
	itemMeta.Text = item.rarity .. " · " .. item.family .. " · Lv " .. item.level .. "\n" .. table.concat(item.classes, " / ") .. (if item.twoHanded then " · Two hands" else "")
	local tint = Catalog.Rarities[item.rarity].color
	itemTitle.TextColor3 = Color3.fromRGB(tint[1], tint[2], tint[3])
	itemDescription.Text = item.description
	local modifiers = {}
	for _, key in statOrder do
		if item.stats[key] then
			table.insert(modifiers, (if item.stats[key] >= 0 then "+" else "") .. formatStat(key, item.stats[key]) .. " " .. statNames[key])
		end
	end
	itemStats.Text = table.concat(modifiers, "   ") .. "\nSell value: " .. item.sellValue .. " gold (selling arrives later)"
	local totals = {}
	for _, key in statOrder do table.insert(totals, statNames[key] .. " " .. formatStat(key, state.derivedStats[key])) end
	derived.Text = state.className .. " · EQUIPPED TOTALS\n" .. table.concat(totals, "  /  ")
	for slot, b in slotButtons do
		local uid = state.equipped[slot]
		local name = if uid then Catalog.Items[state.inventory[uid].itemId].name else "Empty"
		b.Text = slotNames[slot] .. ": " .. name
		b.BackgroundColor3 = if selectedSlot == slot then colors.blue else colors.card
	end
	for slot, b in accessoryTargets do
		b.Visible = item.slot == "Accessory"
		b.BackgroundColor3 = if slot == accessoryTarget then colors.blue else colors.card
	end
	equipButton.Text = if item.slot == "Accessory" then "Equip → " .. (if accessoryTarget == "Accessory2" then "Acc. 2" else "Acc. 1") else "Equip"
	unequipButton.Text = if selectedSlot then "Remove " .. slotNames[selectedSlot] else "Select a slot"
	showPreview(item)
end
local function toggle(_, inputState)
	if inputState ~= Enum.UserInputState.Begin then return Enum.ContextActionResult.Pass end
	root.Visible = not root.Visible
	if root.Visible then transact("Snapshot") end
	return Enum.ContextActionResult.Sink
end
ContextActionService:BindAction("AetherfallArmoury", toggle, true, Enum.KeyCode.I, Enum.KeyCode.ButtonY)
ContextActionService:SetTitle("AetherfallArmoury", "Gear")
ContextActionService:SetPosition("AetherfallArmoury", UDim2.fromScale(0.8, 0.4))
remotes.OpenEquipment.OnClientEvent:Connect(function()
	root.Visible = true
	transact("Snapshot")
end)
local function showSaveStatus()
	local player = Players.LocalPlayer
	local mode = player:GetAttribute("AetherfallSaveMode") or "Loading"
	local message = player:GetAttribute("AetherfallSaveMessage") or "Loading your character…"
	saveNotice.Text = (if mode == "SessionOnly" then "SESSION ONLY · " else "") .. message
	saveNotice.TextColor3 = if mode == "Lost" or mode == "SessionOnly" then colors.error else colors.muted
	if not state and (mode == "Persistent" or mode == "SessionOnly") then
		task.defer(function() transact("Snapshot") end)
	end
end
local modeConnection = Players.LocalPlayer:GetAttributeChangedSignal("AetherfallSaveMode"):Connect(showSaveStatus)
local messageConnection = Players.LocalPlayer:GetAttributeChangedSignal("AetherfallSaveMessage"):Connect(showSaveStatus)
showSaveStatus()
transact("Snapshot")
-- DataStore reads can outlast the first menu request; readiness attributes also retry later.
task.spawn(function()
	for _ = 1, 30 do
		if state or not screen.Parent then return end
		task.wait(2)
		if screen.Parent and not state then transact("Snapshot") end
	end
end)
script.Destroying:Connect(function()
	modeConnection:Disconnect()
	messageConnection:Disconnect()
	ContextActionService:UnbindAction("AetherfallArmoury")
	screen:Destroy()
end)
