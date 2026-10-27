-- Deterministic defensive actions. The server supplies life, ownership and geometry.
-- These rules share only CombatRules' stamina balance; they never regenerate resources.
local Rules = {}
local Config = table.freeze({
	dodgeCost = 18, dodgeCooldown = 1.2, dodgeInvulnerability = 0.25, dodgeDistance = 8,
	sprintDrain = 22, blockDrain = 4, blockHitCost = 10, blockDamageMultiplier = 0.3,
	blockConeDot = 0.15, sprintMultiplier = 1.35, blockSpeed = 6, guardBreakDuration = 1,
})
Rules.Config = Config

local function finite(value)
	return type(value) == "number" and value == value and math.abs(value) < math.huge
end
local function time(value)
	return finite(value) and value >= 0
end
local function validState(state)
	return type(state) == "table" and time(state.dodgeUntil) and time(state.nextDodge)
		and time(state.nextBlock) and time(state.lastTick)
		and type(state.blocking) == "boolean" and type(state.sprinting) == "boolean"
		and not (state.blocking and state.sprinting)
end
local function validResources(combat)
	return type(combat) == "table" and finite(combat.stamina) and combat.stamina >= 0 and combat.stamina <= 100
end
local function validInputs(state, combat, now, context)
	return validState(state) and validResources(combat) and time(now) and now >= state.lastTick
		and type(context) == "table"
end
local function stop(state)
	state.blocking, state.sprinting = false, false
end
local function exhausted(state, now)
	stop(state)
	state.nextBlock = math.max(state.nextBlock, now + Config.guardBreakDuration)
end

function Rules.newState(now)
	assert(time(now), "Defence state requires a finite, nonnegative server time")
	return { dodgeUntil = 0, nextDodge = 0, nextBlock = 0, blocking = false, sprinting = false, lastTick = now }
end

-- Call tick before actions so switching or releasing a stance cannot skip its drain.
-- Rejected requests do not modify timers, resources, or stance.
function Rules.act(state, combat, action, argument, now, context)
	if not validInputs(state, combat, now, context) then return false, "Invalid defence state or server time." end
	if action ~= "Dodge" and action ~= "Block" and action ~= "Sprint" then return false, "Unknown defensive action." end
	if action == "Dodge" then
		if argument ~= nil then return false, "Dodge direction must be validated by the server." end
	elseif type(argument) ~= "boolean" then
		return false, "Stance requests require a boolean."
	end
	-- A release is always safe, including after death, menu opening or session loss.
	if action ~= "Dodge" and argument == false then
		state[if action == "Block" then "blocking" else "sprinting"] = false
		state.lastTick = now
		return true, "Stance released."
	end
	if context.canAct ~= true then return false, "Your character is loading or saving is unavailable." end
	if context.alive ~= true then return false, "You must be alive to act." end
	if now < state.dodgeUntil then return false, "Finish your dodge before another defensive action." end
	if action == "Dodge" then
		if now < state.nextDodge then return false, "Dodge is still on cooldown." end
		if context.pathClear ~= true then return false, "Dodge needs a clear, grounded path." end
		if combat.stamina < Config.dodgeCost then return false, "Not enough stamina to dodge." end
		combat.stamina -= Config.dodgeCost
		state.dodgeUntil = now + Config.dodgeInvulnerability
		state.nextDodge = now + Config.dodgeCooldown
		stop(state)
	elseif action == "Block" then
		if context.hasShield ~= true then return false, "Equip a shield before blocking." end
		if now < state.nextBlock then return false, "Your guard is recovering." end
		if combat.stamina < Config.blockHitCost then return false, "Not enough stamina to raise your shield." end
		state.blocking, state.sprinting = true, false
	else
		if context.moving ~= true then return false, "Start moving before sprinting." end
		if combat.stamina < 1 then return false, "Not enough stamina to sprint." end
		state.sprinting, state.blocking = true, false
	end
	state.lastTick = now
	return true, if action == "Dodge" then "Dodged." elseif action == "Block" then "Shield raised." else "Sprinting."
end

function Rules.tick(state, combat, now, context)
	if not validInputs(state, combat, now, context) then return false, "Invalid defence state or server time." end
	local elapsed = now - state.lastTick
	if context.canAct ~= true or context.alive ~= true then
		stop(state)
	else
		-- The stance was active during the preceding interval. Charge that interval
		-- before applying a newly observed stop or equipment change.
		local rate = if state.blocking then Config.blockDrain elseif state.sprinting then Config.sprintDrain else 0
		if rate > 0 then
			combat.stamina = math.max(0, combat.stamina - rate * elapsed)
			if combat.stamina == 0 then exhausted(state, now) end
		end
		if state.blocking and context.hasShield ~= true then state.blocking = false end
		if state.sprinting and context.moving ~= true then state.sprinting = false end
	end
	state.lastTick = now
	return true, "Defence state updated."
end

-- Call tick first. Source position/facing and damage are trusted server calculations.
function Rules.resolveDamage(state, combat, damage, now, context)
	assert(validInputs(state, combat, now, context), "Valid trusted defence state, resources and time required")
	assert(finite(damage) and damage >= 1 and damage <= 10000, "Damage must be finite and in [1, 10000]")
	assert(finite(context.facingDot) and context.facingDot >= -1 and context.facingDot <= 1, "Valid server facing dot required")
	state.lastTick = now
	if context.canAct ~= true or context.alive ~= true then stop(state); return 0, "Paused" end
	if now < state.dodgeUntil then return 0, "Dodged" end
	if state.blocking and context.hasShield ~= true then state.blocking = false end
	if state.blocking and context.facingDot >= Config.blockConeDot then
		if combat.stamina < Config.blockHitCost then
			exhausted(state, now)
			return damage, "GuardBroken"
		end
		combat.stamina -= Config.blockHitCost
		if combat.stamina == 0 then exhausted(state, now) end
		return damage * Config.blockDamageMultiplier, "Blocked"
	end
	return damage, "Hit"
end

function Rules.staminaRegenScale(state)
	assert(validState(state), "Valid defence state required")
	return if state.blocking or state.sprinting then 0 else 1
end

return table.freeze(Rules)
