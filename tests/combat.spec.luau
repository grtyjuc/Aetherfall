-- Pure authoritative rules, not a Roblox engine or network test.
local Config = require("../src/shared/CombatConfig")
local Rules = require("../src/shared/CombatRules")
local passed, failed = 0, 0
local function test(name, run)
	local ok, message = pcall(run)
	if ok then passed += 1; print("PASS " .. name)
	else failed += 1; warn("FAIL " .. name .. ": " .. tostring(message)) end
end
local function near(actual, expected)
	assert(math.abs(actual - expected) < 1e-6, "expected " .. expected .. ", got " .. tostring(actual))
end
local function context(changes)
	local result = { alive = true, hasWeapon = true, hasShield = true, targetValid = true, distance = 5, aimDot = 1, lineOfSight = true }
	for key, value in changes or {} do result[key] = value end
	return result
end
local function unchanged(state, className, action, now, ctx)
	local before = table.clone(state)
	local ok = Rules.tryAction(state, className, action, now, ctx)
	assert(not ok, "Expected rejection")
	for key, value in before do assert(state[key] == value, "Rejected request changed " .. key) end
	for key in state do assert(before[key] ~= nil, "Rejected request introduced field " .. key) end
end
local function accepted(state, className, action, now, ctx)
	local ok, message, result = Rules.tryAction(state, className, action, now, ctx or context())
	assert(ok, message)
	return result
end

test("all three classes have frozen basic and skill definitions", function()
	assert(table.isfrozen(Config) and table.isfrozen(Config.Classes))
	for _, name in { "Sentinel", "Spellweaver", "Ranger" } do
		local c = Config.Classes[name]
		assert(c and table.isfrozen(c.basic) and table.isfrozen(c.skill))
		assert(c.basic.cost > 0 and c.skill.cost > 0 and c.basic.cooldown > 0 and c.skill.cooldown > 0)
	end
end)

test("fresh states are independent and reset resources, combo and cooldowns", function()
	local first, second = Rules.newState(10), Rules.newState(10)
	accepted(first, "Sentinel", "Basic", 10)
	assert(first.stamina == 94 and second.stamina == 100 and second.combo == 0)
	assert(second.mana == 100 and second.nextBasic == 0 and second.nextSkill == 0)
end)

for _, className in { "Sentinel", "Spellweaver", "Ranger" } do
	for _, action in { "Basic", "Skill" } do
		test(className .. " " .. action .. " spends correct resource and starts correct cooldown", function()
			local state = Rules.newState(20)
			local result = accepted(state, className, action, 20)
			local definition = Config.Classes[className][if action == "Basic" then "basic" else "skill"]
			local key = if definition.resource == "Mana" then "mana" else "stamina"
			near(state[key], 100 - definition.cost)
			near(state[if action == "Basic" then "nextBasic" else "nextSkill"], 20 + definition.cooldown)
			assert(result.kind == definition.kind and result.name == definition.name)
			result.name = "Changed copy"
			assert(definition.name ~= result.name, "Result aliases shared config")
		end)
	end
end

test("same-tick spam cannot bypass either action cooldown", function()
	for _, className in { "Sentinel", "Spellweaver", "Ranger" } do
		for _, action in { "Basic", "Skill" } do
			local state = Rules.newState(1)
			accepted(state, className, action, 1)
			for _ = 1, 100 do unchanged(state, className, action, 1, context()) end
		end
	end
end)

test("Ranger dagger uses Knife Cut melee damage, stamina cost and cooldown", function()
	local state = Rules.newState(0)
	local result = accepted(state, "Ranger", "Basic", 0, context({ weaponFamily = "Dagger", distance = 6 }))
	assert(result.name == "Knife Cut" and result.kind == "Melee" and result.range == 6)
	near(result.multiplier, 0.85)
	near(state.stamina, 96)
	near(state.nextBasic, 0.4)
	assert(Config.getAction("Ranger", "Basic", "Dagger") == Config.Classes.Ranger.daggerBasic)
	assert(Config.getAction("Ranger", "Basic", "Bow") == Config.Classes.Ranger.basic)
	assert(Config.getAction("Ranger", "Skill", "Dagger") == Config.Classes.Ranger.skill)
end)

test("Ranger dagger cannot fire at distant or behind targets and preserves Quickstep", function()
	unchanged(Rules.newState(0), "Ranger", "Basic", 0, context({ weaponFamily = "Dagger", distance = 6.01 }))
	unchanged(Rules.newState(0), "Ranger", "Basic", 0, context({ weaponFamily = "Dagger", aimDot = 0.19 }))
	local result = accepted(Rules.newState(0), "Ranger", "Skill", 0, context({ weaponFamily = "Dagger", targetValid = false }))
	assert(result.name == "Quickstep" and result.kind == "Dash")
	unchanged(Rules.newState(0), "Ranger", "Basic", 0, context({ weaponFamily = {} }))
end)

test("basic and skill have independent authoritative timers", function()
	local state = Rules.newState(5)
	accepted(state, "Sentinel", "Basic", 5)
	accepted(state, "Sentinel", "Skill", 5)
	near(state.stamina, 72)
	near(state.nextBasic, 5.5)
	near(state.nextSkill, 11)
end)

test("exact cooldown boundary accepts without a grace-period exploit", function()
	local state = Rules.newState(0)
	accepted(state, "Sentinel", "Basic", 0)
	unchanged(state, "Sentinel", "Basic", 0.499, context())
	accepted(state, "Sentinel", "Basic", 0.5)
end)

test("Sentinel three-hit combo cycles multipliers then starts over", function()
	local state = Rules.newState(0)
	for index, expected in { 1, 1.1, 1.35, 1 } do
		local result = accepted(state, "Sentinel", "Basic", (index - 1) * 0.5)
		near(result.multiplier, expected)
		assert(result.combo == (index - 1) % 3 + 1)
	end
end)

test("expired Sentinel combo restarts at hit one", function()
	local state = Rules.newState(0)
	accepted(state, "Sentinel", "Basic", 0)
	accepted(state, "Sentinel", "Basic", 0.5)
	local result = accepted(state, "Sentinel", "Basic", 2)
	assert(result.combo == 1)
	near(result.multiplier, 1)
end)

test("shield bash requires shield and rejects without consuming anything", function()
	unchanged(Rules.newState(0), "Sentinel", "Skill", 0, context({ hasShield = false }))
end)

test("dead players and missing weapons cannot act including Quickstep", function()
	for _, className in { "Sentinel", "Spellweaver", "Ranger" } do
		for _, action in { "Basic", "Skill" } do
			unchanged(Rules.newState(0), className, action, 0, context({ alive = false }))
			unchanged(Rules.newState(0), className, action, 0, context({ hasWeapon = false }))
		end
	end
end)

test("non-boolean truthy ownership and life fields are rejected", function()
	unchanged(Rules.newState(0), "Sentinel", "Basic", 0, context({ alive = 1 }))
	unchanged(Rules.newState(0), "Sentinel", "Basic", 0, context({ hasWeapon = "yes" }))
	unchanged(Rules.newState(0), "Sentinel", "Skill", 0, context({ hasShield = 1 }))
end)

test("malformed classes, action names and contexts are rejected atomically", function()
	for _, className in { "Fake", false, {} } do
		unchanged(Rules.newState(0), className, "Basic", 0, context())
	end
	for _, action in { "Damage", false, {}, 1 } do
		unchanged(Rules.newState(0), "Sentinel", action, 0, context())
	end
	unchanged(Rules.newState(0), "Sentinel", "Basic", 0, nil)
	unchanged(Rules.newState(0), "Sentinel", "Basic", 0, false)
end)

test("nonfinite or backwards times cannot mutate state", function()
	for _, now in { -1, 0, math.huge, -math.huge, 0 / 0, "1" } do
		local state = Rules.newState(1)
		unchanged(state, "Sentinel", "Basic", now, context())
		local before = table.clone(state)
		assert(not Rules.refresh(state, now))
		for key, value in before do assert(state[key] == value) end
	end
	assert(not pcall(Rules.newState, math.huge))
	assert(not pcall(Rules.newState, -1))
end)

test("target attacks reject missing or inactive targets without spending", function()
	for _, pair in { { "Sentinel", "Basic" }, { "Sentinel", "Skill" }, { "Spellweaver", "Basic" }, { "Spellweaver", "Skill" }, { "Ranger", "Basic" } } do
		unchanged(Rules.newState(0), pair[1], pair[2], 0, context({ targetValid = false }))
	end
end)

test("target attacks enforce range and reject malformed distance", function()
	for _, pair in { { "Sentinel", "Basic" }, { "Spellweaver", "Basic" }, { "Spellweaver", "Skill" }, { "Ranger", "Basic" } } do
		local definition = Config.Classes[pair[1]][if pair[2] == "Basic" then "basic" else "skill"]
		for _, distance in { definition.range + 0.01, -1, math.huge, 0 / 0, "5" } do
			unchanged(Rules.newState(0), pair[1], pair[2], 0, context({ distance = distance }))
		end
		accepted(Rules.newState(0), pair[1], pair[2], 0, context({ distance = definition.range }))
	end
end)

test("melee cone and all damaging-action line of sight are enforced", function()
	unchanged(Rules.newState(0), "Sentinel", "Basic", 0, context({ aimDot = 0.19 }))
	unchanged(Rules.newState(0), "Sentinel", "Skill", 0, context({ aimDot = -0.01 }))
	for _, pair in { { "Sentinel", "Basic" }, { "Spellweaver", "Basic" }, { "Spellweaver", "Skill" }, { "Ranger", "Basic" } } do
		unchanged(Rules.newState(0), pair[1], pair[2], 0, context({ lineOfSight = false }))
		for _, dot in { 1.01, -1.01, math.huge, 0 / 0 } do
			unchanged(Rules.newState(0), pair[1], pair[2], 0, context({ aimDot = dot }))
		end
	end
end)

test("Quickstep needs no target and returns only bounded server dash distance", function()
	local result = accepted(Rules.newState(0), "Ranger", "Skill", 0, context({ targetValid = false, lineOfSight = false, distance = math.huge }))
	assert(result.kind == "Dash" and result.dashDistance == 10 and result.stat == nil)
end)

test("insufficient mana or stamina rejects without starting a timer", function()
	for _, pair in { { "Sentinel", "Basic" }, { "Sentinel", "Skill" }, { "Spellweaver", "Basic" }, { "Spellweaver", "Skill" }, { "Ranger", "Basic" }, { "Ranger", "Skill" } } do
		local state = Rules.newState(0)
		state.mana, state.stamina = 0, 0
		unchanged(state, pair[1], pair[2], 0, context())
	end
end)

test("exact resource cost can be spent down to zero but never below", function()
	local state = Rules.newState(0)
	state.mana = 25
	accepted(state, "Spellweaver", "Skill", 0)
	near(state.mana, 0)
	unchanged(state, "Spellweaver", "Basic", 0, context())
end)

test("resources regenerate by elapsed server time and cap at maximum", function()
	local state = Rules.newState(5)
	state.mana, state.stamina = 10, 20
	assert(Rules.refresh(state, 7))
	near(state.mana, 26)
	near(state.stamina, 50)
	assert(Rules.refresh(state, 7))
	near(state.mana, 26)
	near(state.stamina, 50)
	assert(Rules.refresh(state, 100))
	near(state.mana, Config.maxMana)
	near(state.stamina, Config.maxStamina)
end)

test("malformed server state fails safely instead of propagating NaN", function()
	for _, key in { "mana", "stamina", "nextBasic", "nextSkill", "combo", "comboUntil", "lastTick" } do
		local state = Rules.newState(0)
		state[key] = math.huge
		assert(not Rules.tryAction(state, "Sentinel", "Basic", 0, context()))
		assert(not Rules.refresh(state, 0))
	end
	assert(not Rules.tryAction(nil, "Sentinel", "Basic", 0, context()))
	assert(not Rules.refresh({}, 0))
end)

test("damage follows stat, multiplier, defence and deterministic critical roll", function()
	local stats = { Attack = 40, MagicPower = 80, CriticalChance = 0.1 }
	local physical = { stat = "Attack", multiplier = 1.5 }
	local magic = { stat = "MagicPower", multiplier = 1.5 }
	local amount, critical = Rules.damage(stats, physical, 100, 0.9)
	near(amount, 30)
	assert(not critical)
	amount, critical = Rules.damage(stats, physical, 100, 0.05)
	near(amount, 45)
	assert(critical)
	near(Rules.damage(stats, magic, 100, 0.9), 60)
	near(Rules.damage({ Attack = 0, CriticalChance = 0 }, physical, 100, 0), 1)
end)

test("critical boundary and maximum chance cannot guarantee critical damage", function()
	local attack = { stat = "Attack", multiplier = 1 }
	local amount, critical = Rules.damage({ Attack = 10, CriticalChance = 1 }, attack, 0, 0.6)
	near(amount, 10)
	assert(not critical)
	amount, critical = Rules.damage({ Attack = 10, CriticalChance = 0.1 }, attack, 0, 0.1)
	near(amount, 10)
	assert(not critical)
end)

test("negative, nonfinite or unsupported damage inputs cannot amplify damage", function()
	local stats = { Attack = 10, CriticalChance = 0.1 }
	local result = { stat = "Attack", multiplier = 1 }
	for _, defence in { -1, -100, math.huge, 0 / 0, "0" } do
		assert(not pcall(Rules.damage, stats, result, defence, 0.5))
	end
	for _, power in { -1, math.huge, 0 / 0, "10" } do
		assert(not pcall(Rules.damage, { Attack = power, CriticalChance = 0.1 }, result, 0, 0.5))
	end
	for _, multiplier in { 0, -1, 11, math.huge, 0 / 0 } do
		assert(not pcall(Rules.damage, stats, { stat = "Attack", multiplier = multiplier }, 0, 0.5))
	end
	for _, roll in { -0.1, 1, math.huge, 0 / 0 } do
		assert(not pcall(Rules.damage, stats, result, 0, roll))
	end
	assert(not pcall(Rules.damage, stats, { stat = "MaxHealth", multiplier = 1 }, 0, 0.5))
	assert(not pcall(Rules.damage, { Attack = 1, CriticalChance = -1 }, result, 0, 0.5))
end)

print("Combat rules: " .. passed .. " passed, " .. failed .. " failed")
assert(failed == 0, "Combat rule checks failed")
