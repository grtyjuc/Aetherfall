-- Manifest validation only. No uploaded audio or live Roblox sound playback is claimed.
local Manifest = require("../src/shared/AudioManifest")
local groups = {}
for _, name in Manifest.Groups do groups[name] = true end
assert(table.isfrozen(Manifest) and table.isfrozen(Manifest.Events), "Manifest must be immutable")
local count = 0
for name, entry in Manifest.Events do
	assert(type(name) == "string" and table.isfrozen(entry), "Invalid event definition")
	assert(groups[entry.group], "Unknown audio group: " .. name)
	assert(type(entry.soundId) == "string", "Sound IDs must be strings")
	assert(entry.soundId == "", "No licensed assets have been uploaded for this build")
	assert(not Manifest.validSoundId(entry.soundId), "Empty IDs must never create sounds")
	assert(type(entry.looped) == "boolean" and type(entry.spatial) == "boolean", "Missing playback flags")
	assert(entry.volume > 0 and entry.volume <= 0.5, "Unsafe default event volume")
	assert(entry.rolloffMin > 0 and entry.rolloffMax > entry.rolloffMin and entry.rolloffMax <= 120, "Invalid spatial limits")
	assert(type(entry.trigger) == "string" and #entry.trigger > 10, "Missing integration trigger")
	count += 1
end
assert(count == 6, "Expected all six integration events")
for _, name in { "MusicVillage", "AmbienceFields", "CombatHit", "QuestAccepted", "QuestCompleted", "EnemyWindup" } do
	assert(Manifest.Events[name], "Missing audio hook: " .. name)
end
assert(Manifest.Events.MusicVillage.looped and Manifest.Events.AmbienceFields.looped, "Region tracks must loop")
assert(Manifest.Events.CombatHit.spatial and Manifest.Events.EnemyWindup.spatial, "Combat cues should use spatial anchors")
assert(not Manifest.Events.QuestAccepted.spatial and not Manifest.Events.QuestCompleted.spatial, "Quest cues must stay nonspatial")
for _, value in { "", "1234", "http://example.com", "rbxassetid://0", "rbxassetid://-1", "rbxassetid://abc", "rbxassetid://12.3", string.rep("x", 100), false, 1234, {} } do
	assert(not Manifest.validSoundId(value), "Malformed asset reference accepted")
end
assert(not Manifest.validSoundId(nil), "Missing ID accepted")
assert(Manifest.validSoundId("rbxassetid://123456"), "A configured numeric Roblox audio ID should be accepted")
print("PASS six immutable silent audio hooks, group/volume/spatial settings, and sound ID validation; playback is untested.")
