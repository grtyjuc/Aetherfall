-- Pure, immutable first-pass training balance. All timing is server-owned.
local Config = {
	maxMana = 100,
	maxStamina = 100,
	regenMana = 8,
	regenStamina = 15,
	criticalMultiplier = 1.5,
	comboWindow = 1.4,
	Classes = {
		Sentinel = {
			basic = {
				name = "Steel Slash", kind = "Melee", stat = "Attack", multiplier = 1,
				range = 8, cooldown = 0.5, resource = "Stamina", cost = 6, coneDot = 0.2,
			},
			skill = {
				name = "Shield Bash", kind = "Melee", stat = "Attack", multiplier = 1.8,
				range = 8, cooldown = 6, resource = "Stamina", cost = 22, coneDot = 0,
				requiresShield = true,
			},
		},
		Spellweaver = {
			basic = {
				name = "Arcane Bolt", kind = "Projectile", stat = "MagicPower", multiplier = 1,
				range = 65, cooldown = 0.65, resource = "Mana", cost = 5, coneDot = -1,
			},
			skill = {
				name = "Flame Burst", kind = "Area", stat = "MagicPower", multiplier = 1.6,
				range = 45, radius = 10, cooldown = 7, resource = "Mana", cost = 25, coneDot = -1,
			},
		},
		Ranger = {
			daggerBasic = {
				name = "Knife Cut", kind = "Melee", stat = "Attack", multiplier = 0.85,
				range = 6, cooldown = 0.4, resource = "Stamina", cost = 4, coneDot = 0.2,
			},
			basic = {
				name = "Piercing Shot", kind = "Projectile", stat = "Attack", multiplier = 1,
				range = 75, cooldown = 0.65, resource = "Stamina", cost = 7, coneDot = -1,
			},
			skill = {
				name = "Quickstep", kind = "Dash", cooldown = 5, resource = "Stamina", cost = 20,
				dashDistance = 10,
			},
		},
	},
}

-- Keep range checks, presentation and transaction logic on the same definition.
function Config.getAction(className, action, weaponFamily)
	if type(className) ~= "string" then return nil end
	local class = Config.Classes[className]
	if not class then return nil end
	if action == "Skill" then return class.skill end
	if action ~= "Basic" then return nil end
	if className == "Ranger" and weaponFamily == "Dagger" then return class.daggerBasic end
	return class.basic
end

local function freeze(value)
	for _, child in value do
		if type(child) == "table" then freeze(child) end
	end
	return table.freeze(value)
end

return freeze(Config)
