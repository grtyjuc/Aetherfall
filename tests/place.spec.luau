-- Check the generated Studio artifact, not a live Roblox session.
local fs = require("@lune/fs")
local roblox = require("@lune/roblox")
local place = roblox.deserializePlace(fs.readFile("build/Aetherfall-Step-4.rbxl"))
local shared = place.ReplicatedStorage.Shared
for _, name in { "EquipmentCatalog", "EquipmentRules", "EquipmentModels", "CombatConfig", "CombatRules", "ProgressionRules", "QuestRules", "EnemyDefinitions", "AudioManifest" } do
	assert(shared[name]:IsA("ModuleScript") and #shared[name].Source > 100, "Missing shared source: " .. name)
end
local server = place.ServerScriptService.Workshop
assert(server.Workshop:IsA("Script"), "Missing server entry point")
assert(server.WorkshopWorld:IsA("ModuleScript"), "Missing world generator")
for _, name in { "TrainingWorld", "EquipmentVisuals", "CombatService", "PlayerSchema", "SessionStore", "PlayerDataService", "TrainingRewards", "VillageWorld", "QuestService", "EnemyService", "EnemyRewards", "RestService" } do
	assert(server[name]:IsA("ModuleScript") and #server[name].Source > 100, "Missing server module: " .. name)
end
local client = place.StarterPlayer.StarterPlayerScripts.EquipmentWorkshop.Workshop
assert(client:IsA("LocalScript") and #client.Source > 100, "Missing client entry point")
local combat = place.StarterPlayer.StarterPlayerScripts.EquipmentWorkshop.Combat
assert(combat:IsA("LocalScript") and #combat.Source > 100, "Missing combat controller")
assert(place.StarterPlayer.StarterPlayerScripts.EquipmentWorkshop.Progression:IsA("LocalScript"), "Missing progression HUD")
assert(place.StarterPlayer.StarterPlayerScripts.EquipmentWorkshop.Quest:IsA("LocalScript"), "Missing quest UI")
assert(place.StarterPlayer.StarterPlayerScripts.EquipmentWorkshop.Audio:IsA("LocalScript"), "Missing audio controller")
assert(place.Workspace.StreamingEnabled, "Streaming must be enabled")
local count = 0
for _, object in place:GetDescendants() do
	if object:IsA("LuaSourceContainer") then count += 1 end
end
assert(count == 28, "Unexpected runtime source count: " .. count)
print("PASS Step 4 Studio place contains all 28 runtime sources in the intended services.")
