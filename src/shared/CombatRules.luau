-- Pure combat transactions. The server supplies geometry, ownership, life state and time.
local Config = if script then require(script.Parent.CombatConfig) else require("./CombatConfig")
local Rules = {}

local function finite(value)
	return type(value) == "number" and value == value and math.abs(value) < math.huge
end

local function validTime(now)
	return finite(now) and now >= 0
end

local function validState(state)
	return type(state) == "table"
		and finite(state.mana) and state.mana >= 0 and state.mana <= Config.maxMana
		and finite(state.stamina) and state.stamina >= 0 and state.stamina <= Config.maxStamina
		and validTime(state.nextBasic) and validTime(state.nextSkill)
		and validTime(state.comboUntil) and validTime(state.lastTick)
		and finite(state.combo) and state.combo % 1 == 0 and state.combo >= 0 and state.combo <= 3
end

function Rules.newState(now)
	assert(validTime(now), "Combat state requires a finite, nonnegative server time")
	return {
		mana = Config.maxMana,
		stamina = Config.maxStamina,
		nextBasic = 0,
		nextSkill = 0,
		combo = 0,
		comboUntil = 0,
		lastTick = now,
	}
end

function Rules.refresh(state, now, staminaScale)
	staminaScale = if staminaScale == nil then 1 else staminaScale
	if not validState(state) or not validTime(now) or now < state.lastTick then
		return false, "Invalid or non-monotonic combat time/state."
	end
	if not finite(staminaScale) or staminaScale < 0 or staminaScale > 1 then
		return false, "Invalid stamina regeneration scale."
	end
	local elapsed = now - state.lastTick
	state.mana = math.min(Config.maxMana, state.mana + elapsed * Config.regenMana)
	state.stamina = math.min(Config.maxStamina, state.stamina + elapsed * Config.regenStamina * staminaScale)
	state.lastTick = now
	return true, "Combat resources refreshed."
end

function Rules.tryAction(state, className, action, now, context)
	if not validState(state) or not validTime(now) or now < state.lastTick then
		return false, "Invalid or non-monotonic combat time/state."
	end
	if type(className) ~= "string" or not Config.Classes[className] then
		return false, "Unknown combat class."
	end
	if action ~= "Basic" and action ~= "Skill" then
		return false, "Unknown combat action."
	end
	if type(context) ~= "table" then
		return false, "Missing server combat context."
	end
	if context.weaponFamily ~= nil and type(context.weaponFamily) ~= "string" then
		return false, "Invalid server weapon family."
	end
	if context.alive ~= true then return false, "You must be alive to act." end
	if context.hasWeapon ~= true then return false, "Equip a compatible main-hand weapon first." end
	local definition = Config.getAction(className, action, context.weaponFamily)
	if definition.requiresShield and context.hasShield ~= true then
		return false, "Shield Bash requires an equipped shield."
	end
	local timer = if action == "Basic" then "nextBasic" else "nextSkill"
	if now < state[timer] then return false, "That action is still on cooldown." end
	if definition.kind ~= "Dash" then
		if context.targetValid ~= true then return false, "Choose an active training target." end
		if not finite(context.distance) or context.distance < 0 or context.distance > definition.range then
			return false, "The target is out of range."
		end
		if not finite(context.aimDot) or context.aimDot < -1 or context.aimDot > 1 then
			return false, "Invalid server aim direction."
		end
		if context.aimDot < definition.coneDot then return false, "Face the target before attacking." end
		if context.lineOfSight ~= true then return false, "The target is blocked." end
	end
	local resource = if definition.resource == "Mana" then "mana" else "stamina"
	if state[resource] < definition.cost then
		return false, "Not enough " .. string.lower(definition.resource) .. "."
	end

	-- Reject paths above are read-only. Commit an accepted action once, without yielding.
	local combo = 1
	local multiplier = definition.multiplier
	if className == "Sentinel" and action == "Basic" then
		combo = if state.combo > 0 and now <= state.comboUntil then state.combo % 3 + 1 else 1
		multiplier *= ({ 1, 1.1, 1.35 })[combo]
		state.combo = combo
		state.comboUntil = now + Config.comboWindow
	end
	state[resource] -= definition.cost
	state[timer] = now + definition.cooldown
	-- Advance the clock so a rejected backwards request cannot rewind resource time.
	state.lastTick = now
	local result = table.clone(definition)
	result.combo = combo
	result.multiplier = multiplier
	return true, definition.name .. " activated.", result
end

function Rules.damage(stats, result, defence, criticalRoll)
	assert(type(stats) == "table" and type(result) == "table", "Trusted combat statistics/result required")
	assert(result.stat == "Attack" or result.stat == "MagicPower", "Damage requires a supported attack statistic")
	local power = stats[result.stat]
	assert(finite(power) and power >= 0 and power <= 1e6, "Attack power must be finite and nonnegative")
	assert(finite(result.multiplier) and result.multiplier > 0 and result.multiplier <= 10, "Invalid attack multiplier")
	assert(finite(defence) and defence >= 0 and defence <= 1e6, "Defence must be finite and nonnegative")
	assert(finite(criticalRoll) and criticalRoll >= 0 and criticalRoll < 1, "Critical roll must be in [0, 1)")
	assert(finite(stats.CriticalChance) and stats.CriticalChance >= 0 and stats.CriticalChance <= 1, "Invalid critical chance")
	local critical = criticalRoll < math.clamp(stats.CriticalChance, 0, 0.6)
	local amount = power * result.multiplier * (100 / (100 + defence))
	if critical then amount *= Config.criticalMultiplier end
	return math.max(1, amount), critical
end

return table.freeze(Rules)
