-- Pure quest transitions. NPC identity and defeat events must be validated by the server.
local Progression = if script then require(script.Parent.ProgressionRules) else require("./ProgressionRules")
local Rules = {}
local allowedKinds = { MeadowSlime = true, WildBoar = true, Thornling = true }
local questFields = { strangerStage = true, fieldsAccepted = true, fieldsKills = true }

local function defaults()
	return { strangerStage = 0, fieldsAccepted = false, fieldsKills = 0 }
end
local function integer(value, minimum, maximum)
	return type(value) == "number" and value == value and value % 1 == 0 and value >= minimum and value <= maximum
end

function Rules.ensure(profile)
	assert(type(profile) == "table", "Player profile required")
	if profile.quests == nil then profile.quests = defaults() end
	return profile.quests
end

function Rules.validate(quests)
	if type(quests) ~= "table" or getmetatable(quests) ~= nil then return false, "Missing or malformed quest state." end
	for key in quests do
		if not questFields[key] then return false, "Unknown quest state field." end
	end
	if not integer(quests.strangerStage, 0, 3) or type(quests.fieldsAccepted) ~= "boolean"
		or not integer(quests.fieldsKills, 0, 4) then return false, "Invalid quest progress." end
	if quests.fieldsAccepted and quests.strangerStage ~= 3 then return false, "Field quest requires the village introduction." end
	if not quests.fieldsAccepted and quests.fieldsKills ~= 0 then return false, "An unaccepted quest cannot have defeat progress." end
	return true, "Quest state valid."
end

function Rules.validateProfile(profile)
	local ok, reason = Progression.validate(profile)
	if not ok then return false, reason end
	ok, reason = Rules.validate(profile.quests)
	if not ok then return false, reason end
	local quests, claims = profile.quests, profile.claimedRewards
	if (claims.quest_stranger == true) ~= (quests.strangerStage == 3) then
		return false, "Village introduction reward and quest stage disagree."
	end
	if claims.quest_fields and (not quests.fieldsAccepted or quests.fieldsKills ~= 4) then
		return false, "Field reward requires completed field objectives."
	end
	return true, "Quest profile valid."
end

local function readState(profile)
	local ok, reason = Progression.validate(profile)
	if not ok then return nil, reason end
	if profile.quests == nil then
		if profile.claimedRewards.quest_stranger or profile.claimedRewards.quest_fields then
			return nil, "Quest reward claims have no matching quest state."
		end
		return defaults()
	end
	ok, reason = Rules.validateProfile(profile)
	return if ok then profile.quests else nil, reason
end

-- true means progress/reward changed; guided dialogue and rejected transitions return false.
function Rules.interact(profile, npcId)
	if npcId ~= "Rowan" and npcId ~= "Blacksmith" then return false, "Unknown quest character." end
	local quests, reason = readState(profile)
	if not quests then return false, reason end
	if npcId == "Blacksmith" then
		if quests.strangerStage == 1 then
			quests.strangerStage = 2
			profile.quests = quests
			return true, "Tessa: Welcome to my forge. Your gear will serve you well. Tell Elder Rowan you found me."
		end
		return false, "Tessa: Keep your equipment ready. Elder Rowan is by the village square if you need directions."
	end
	if quests.strangerStage == 0 then
		quests.strangerStage = 1
		profile.quests = quests
		return true, "Rowan: Welcome to Hearthglen. Meet Smith Tessa at the south forge, then return to me."
	elseif quests.strangerStage == 1 then
		return false, "Rowan: Smith Tessa is beside the south forge. Introduce yourself before we discuss the fields."
	elseif quests.strangerStage == 2 then
		local ok, message, summary = Progression.grantReward(profile, "quest_stranger", {
			xp = 100, gold = 20, items = { "wayfarer_lantern" },
		})
		if not ok then return false, message end
		quests.strangerStage = 3
		profile.quests = quests
		return true, "Rowan: You have found your footing here. Take this lantern, and speak to me again about the troubled fields.", summary
	elseif not quests.fieldsAccepted then
		quests.fieldsAccepted = true
		profile.quests = quests
		return true, "Rowan: Creatures have overrun our eastern fields. Defeat four slimes, boars or thornlings, then return."
	elseif profile.claimedRewards.quest_fields then
		return false, "Rowan: The farmers are safer thanks to you. Hearthglen will remember your help."
	elseif quests.fieldsKills < 4 then
		return false, string.format("Rowan: The eastern fields still need you. You have defeated %d of four creatures.", quests.fieldsKills)
	end
	local ok, message, summary = Progression.grantReward(profile, "quest_fields", {
		xp = 150, gold = 60, items = { "scouts_charm" },
	})
	if not ok then return false, message end
	return true, "Rowan: Well done. Take this charm and payment from the farmers. Rest at the village well before your next journey.", summary
end

function Rules.recordDefeat(profile, kind)
	if type(kind) ~= "string" or not allowedKinds[kind] then return false, "That creature does not count toward this quest." end
	local quests, reason = readState(profile)
	if not quests then return false, reason end
	if not quests.fieldsAccepted or quests.fieldsKills >= 4 or profile.claimedRewards.quest_fields then
		return false, "No active field objective needs this defeat."
	end
	quests.fieldsKills += 1
	profile.quests = quests
	return true, string.format("Trouble at the Fields: %d / 4 creatures defeated.", quests.fieldsKills)
end

function Rules.snapshot(profile)
	local quests = if type(profile) == "table" and type(profile.quests) == "table" then profile.quests else defaults()
	local claims = if type(profile) == "table" and type(profile.claimedRewards) == "table" then profile.claimedRewards else {}
	local title, objective
	if quests.strangerStage == 0 then title, objective = "A Stranger in Hearthglen", "Speak to Elder Rowan in the village square."
	elseif quests.strangerStage == 1 then title, objective = "A Stranger in Hearthglen", "Meet Smith Tessa beside the south forge."
	elseif quests.strangerStage == 2 then title, objective = "A Stranger in Hearthglen", "Return to Elder Rowan."
	elseif not quests.fieldsAccepted then title, objective = "Trouble at the Fields", "Speak to Elder Rowan about the eastern fields."
	elseif claims.quest_fields then title, objective = "Hearthglen Defender", "Both village quests complete. Rest at the well or explore."
	elseif quests.fieldsKills >= 4 then title, objective = "Trouble at the Fields", "Return to Elder Rowan for your reward."
	else title, objective = "Trouble at the Fields", string.format("Defeat creatures in the eastern fields: %d / 4.", quests.fieldsKills) end
	return { strangerStage = quests.strangerStage, fieldsAccepted = quests.fieldsAccepted, fieldsKills = quests.fieldsKills,
		strangerDone = claims.quest_stranger == true, fieldsDone = claims.quest_fields == true,
		title = title, objective = objective }
end

return table.freeze(Rules)
