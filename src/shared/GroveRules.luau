-- Pure grove quest transitions. Rune proximity and boss defeat credit are server-validated.
local Progression = if script then require(script.Parent.ProgressionRules) else require("./ProgressionRules")
local Grove = {}
local gear = { Sentinel = "briarwarden_shield", Spellweaver = "briarwarden_staff", Ranger = "briarwarden_bow" }

local function stage(value)
	return type(value) == "number" and value == value and value % 1 == 0 and value >= 0 and value <= 4
end

function Grove.ensure(profile)
	assert(type(profile) == "table" and type(profile.quests) == "table", "Quest profile required")
	if profile.quests.groveStage == nil then profile.quests.groveStage = 0 end
	return profile.quests
end

function Grove.validateProfile(profile)
	local ok, reason = Progression.validate(profile)
	if not ok then return false, reason end
	local quests, claims = profile.quests, profile.claimedRewards
	if type(quests) ~= "table" or getmetatable(quests) ~= nil or not stage(quests.groveStage) then return false, "Invalid grove quest stage." end
	if quests.groveStage > 0 and (claims.quest_fields ~= true or claims.quest_stranger ~= true
		or quests.strangerStage ~= 3 or quests.fieldsAccepted ~= true or quests.fieldsKills ~= 4) then
		return false, "The grove requires completed village quests."
	end
	if (claims.boss_briarwarden == true) ~= (quests.groveStage >= 3) then
		return false, "Briarwarden reward and grove progress disagree."
	end
	if (claims.quest_grove == true) ~= (quests.groveStage == 4) then
		return false, "Grove completion reward and quest progress disagree."
	end
	return true, "Grove progress valid."
end

local function read(profile)
	local ok, reason = Grove.validateProfile(profile)
	return if ok then profile.quests else nil, reason
end

function Grove.interact(profile)
	local quests, reason = read(profile)
	if not quests then return false, reason end
	if profile.claimedRewards.quest_fields ~= true then return false, "Rowan: Help the farmers before venturing into the grove." end
	if quests.groveStage == 0 then
		quests.groveStage = 1
		return true, "Rowan: An ancient guardian stirs beyond the eastern fields. Follow the northern trail and inspect the glowing runestone before entering its grove."
	elseif quests.groveStage == 1 then
		return false, "Rowan: The runestone stands beyond the northern edge of the fields. Read it before challenging Briarwarden."
	elseif quests.groveStage == 2 then
		return false, "Rowan: Challenge Briarwarden at the grove entrance when you are ready. Watch its branches and roots, then strike its exposed core."
	elseif quests.groveStage == 3 then
		local ok, message, summary = Progression.grantReward(profile, "quest_grove", { xp = 400, gold = 120, items = {} })
		if not ok then return false, message end
		quests.groveStage = 4
		return true, "Rowan: The guardian has yielded the first Aether Shard. Hearthglen is safer, and our journey toward the Hollow Star has begun.", summary
	end
	return false, "Rowan: The first Aether Shard is secure. You may return to the grove to help other adventurers."
end

function Grove.inspectRune(profile)
	local quests, reason = read(profile)
	if not quests then return false, reason end
	if quests.groveStage == 0 then return false, "Speak to Elder Rowan about the grove first." end
	if quests.groveStage ~= 1 then return false, "The runestone's warning is already known: avoid roots and strike the exposed core." end
	quests.groveStage = 2
	return true, "The runes warn of sweeping branches and rising roots. The guardian's core opens between attacks. Challenge Briarwarden at the grove entrance; level 3 is required."
end

function Grove.canChallenge(profile)
	local quests, reason = read(profile)
	if not quests then return false, reason end
	if quests.groveStage < 2 or profile.claimedRewards.quest_fields ~= true then return false, "Inspect the grove runestone after helping Elder Rowan." end
	if profile.level < 3 then return false, "Reach level 3 before challenging Briarwarden." end
	return true, "The grove challenge is available."
end

function Grove.recordBossDefeat(profile)
	local ready, reason = Grove.canChallenge(profile)
	if not ready then return false, reason end
	local quests = profile.quests
	if quests.groveStage ~= 2 then return false, "Briarwarden's first-defeat reward has already been earned." end
	local ok, message, summary = Progression.grantReward(profile, "boss_briarwarden", {
		xp = 1300, gold = 180, items = { gear[profile.className] },
	})
	if not ok then return false, message end
	quests.groveStage = 3
	return true, "Briarwarden has yielded. You earned grove equipment; return to Elder Rowan with the first Aether Shard.", summary
end

function Grove.snapshot(profile)
	local quests = if type(profile) == "table" and type(profile.quests) == "table" then profile.quests else {}
	local value = if stage(quests.groveStage) then quests.groveStage else 0
	local objectives = {
		"Speak to Elder Rowan about the ancient grove.",
		"Inspect the glowing runestone beyond the northern fields.",
		"Challenge Briarwarden at the grove entrance (level 3 required).",
		"Return to Elder Rowan with the first Aether Shard.",
		"First Aether Shard secured. Return to the grove to help others.",
	}
	return { groveStage = value, title = "Guardian of the Roots", objective = objectives[value + 1],
		groveDone = value == 4, bossDefeated = value >= 3 }
end

return table.freeze(Grove)
