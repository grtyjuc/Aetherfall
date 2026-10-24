-- Optional licensed audio hooks. Empty manifest IDs create no Sound objects or requests.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
if not RunService:IsStudio() then return end
local player = Players.LocalPlayer
local Manifest = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("AudioManifest"))
local remotes = ReplicatedStorage:WaitForChild("WorkshopRemotes", 30)
if not remotes then return end
local feedback = remotes:WaitForChild("CombatFeedback", 30)
local quests = remotes:WaitForChild("QuestState", 30)
if not feedback or not quests then return end
local running, connections = true, {}
local groups, loopSounds, loopTweens = {}, {}, {}
local lastQuest, windups = nil, {}
local effects = Instance.new("Folder")
effects.Name = "AetherfallAudioEffects_" .. player.UserId
effects.Parent = workspace
local function connect(signal, callback)
	local connection = signal:Connect(callback)
	table.insert(connections, connection)
end
local function volume(name)
	local value = player:GetAttribute("Aetherfall" .. name .. "Volume")
	return if type(value) == "number" and value == value then math.clamp(value, 0, 1) else 0.6
end
for _, name in Manifest.Groups do
	local group = Instance.new("SoundGroup")
	group.Name = "Aetherfall" .. name
	group.Volume = volume(name)
	group.Parent = SoundService
	groups[name] = group
	connect(player:GetAttributeChangedSignal("Aetherfall" .. name .. "Volume"), function()
		group.Volume = volume(name)
	end)
end
local function createSound(eventName, parent)
	local entry = Manifest.Events[eventName]
	if not entry or not Manifest.validSoundId(entry.soundId) then return nil end
	local sound = Instance.new("Sound")
	sound.Name = eventName
	sound.SoundId = entry.soundId
	sound.SoundGroup = groups[entry.group]
	sound.Volume = entry.volume
	sound.Looped = entry.looped
	sound.RollOffMode = Enum.RollOffMode.InverseTapered
	sound.RollOffMinDistance = entry.rolloffMin
	sound.RollOffMaxDistance = entry.rolloffMax
	sound.Parent = parent
	return sound
end
local function oneShot(eventName, position)
	local entry = Manifest.Events[eventName]
	if not entry or not Manifest.validSoundId(entry.soundId) or #effects:GetChildren() >= 24 then return end
	local parent = effects
	if entry.spatial and typeof(position) == "Vector3" then
		local anchor = Instance.new("Part")
		anchor.Name = "AudioAnchor"
		anchor.Size = Vector3.new(0.1, 0.1, 0.1)
		anchor.Position = position
		anchor.Transparency = 1
		anchor.Anchored = true
		anchor.CanCollide, anchor.CanTouch, anchor.CanQuery = false, false, false
		anchor.Parent = effects
		parent = anchor
		Debris:AddItem(anchor, 8)
	end
	local sound = createSound(eventName, parent)
	if not sound then return end
	sound.Ended:Once(function()
		if parent ~= effects then parent:Destroy() else sound:Destroy() end
	end)
	Debris:AddItem(sound, 8)
	sound:Play()
end
local function setLoop(eventName, active)
	local entry = Manifest.Events[eventName]
	if not Manifest.validSoundId(entry.soundId) then return end
	local sound = loopSounds[eventName]
	if not sound and active then
		sound = createSound(eventName, SoundService)
		sound.Volume = 0
		loopSounds[eventName] = sound
		sound:Play()
	end
	if not sound then return end
	if loopTweens[eventName] then
		local previous = loopTweens[eventName]
		loopTweens[eventName] = nil -- Cancellation must not run the old fade-out cleanup on this sound.
		previous:Cancel()
		previous:Destroy()
	end
	local tween = TweenService:Create(sound, TweenInfo.new(0.7), { Volume = if active then entry.volume else 0 })
	loopTweens[eventName] = tween
	tween.Completed:Once(function(playbackState)
		if playbackState == Enum.PlaybackState.Completed and loopTweens[eventName] == tween then
			loopTweens[eventName] = nil
			if not active then sound:Stop(); sound:Destroy(); loopSounds[eventName] = nil end
		end
		tween:Destroy()
	end)
	tween:Play()
end
connect(feedback.OnClientEvent, function(data)
	if type(data) == "table" and type(data.damage) == "number" and data.damage > 0 then
		oneShot("CombatHit", data.position)
	end
end)
connect(quests.OnClientEvent, function(data)
	if type(data) ~= "table" or data.canPlay ~= true then return end
	if lastQuest then
		if (data.strangerDone == true and lastQuest.strangerDone ~= true)
			or (data.fieldsDone == true and lastQuest.fieldsDone ~= true) then
			oneShot("QuestCompleted")
		elseif (data.strangerStage == 1 and lastQuest.strangerStage == 0)
			or (data.fieldsAccepted == true and lastQuest.fieldsAccepted ~= true) then
			oneShot("QuestAccepted")
		end
	end
	lastQuest = { strangerStage = data.strangerStage, fieldsAccepted = data.fieldsAccepted,
		strangerDone = data.strangerDone, fieldsDone = data.fieldsDone }
end)
connect(script.Destroying, function()
	running = false
	for _, connection in connections do connection:Disconnect() end
	for _, tween in loopTweens do tween:Cancel(); tween:Destroy() end
	for _, sound in loopSounds do sound:Destroy() end
	for _, group in groups do group:Destroy() end
	effects:Destroy()
end)
task.spawn(function()
	local region
	while running do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local nextRegion = if root and root.Position.X >= 48 then "Fields" else "Village"
		if not root then nextRegion = nil end
		if nextRegion ~= region then
			region = nextRegion
			setLoop("MusicVillage", region == "Village")
			setLoop("AmbienceFields", region == "Fields")
		end
		local enemies = workspace:FindFirstChild("AetherfallEnemies")
		local targets = enemies and enemies:FindFirstChild("Targets")
		local active = {}
		if root and targets then
			for _, target in targets:GetChildren() do
				local hitbox = target:FindFirstChild("Hitbox")
				if hitbox and hitbox:IsA("BasePart") and (hitbox.Position - root.Position).Magnitude <= 35 then
					local winding = target:GetAttribute("AIState") == "Windup"
					active[target] = winding
					if winding and not windups[target] then oneShot("EnemyWindup", hitbox.Position) end
				end
			end
		end
		windups = active
		task.wait(0.5)
	end
end)
