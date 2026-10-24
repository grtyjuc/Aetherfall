-- Empty IDs are intentional: configure only audio assets the experience may use.
-- This module registers integration points; it does not contain uploaded audio.
local Manifest = {
	Groups = { "Music", "Ambience", "Combat", "UI" },
	Events = {
		MusicVillage = { soundId = "", group = "Music", volume = 0.3, looped = true,
			spatial = false, rolloffMin = 10, rolloffMax = 80, trigger = "Inside Hearthglen village" },
		AmbienceFields = { soundId = "", group = "Ambience", volume = 0.25, looped = true,
			spatial = false, rolloffMin = 10, rolloffMax = 100, trigger = "Meadow Fields east of the village" },
		CombatHit = { soundId = "", group = "Combat", volume = 0.35, looped = false,
			spatial = true, rolloffMin = 6, rolloffMax = 65, trigger = "Server-approved damaging hit" },
		QuestAccepted = { soundId = "", group = "UI", volume = 0.35, looped = false,
			spatial = false, rolloffMin = 10, rolloffMax = 80, trigger = "Quest accepted after initial state synchronization" },
		QuestCompleted = { soundId = "", group = "UI", volume = 0.4, looped = false,
			spatial = false, rolloffMin = 10, rolloffMax = 80, trigger = "Quest completion confirmed by server" },
		EnemyWindup = { soundId = "", group = "Combat", volume = 0.3, looped = false,
			spatial = true, rolloffMin = 5, rolloffMax = 35, trigger = "Nearby enemy enters a telegraphed windup" },
	},
}

function Manifest.validSoundId(value)
	return type(value) == "string" and value:match("^rbxassetid://[1-9]%d*$") ~= nil and #value <= 40
end
local function freeze(value)
	for _, child in value do if type(child) == "table" then freeze(child) end end
	return table.freeze(value)
end
return freeze(Manifest)
