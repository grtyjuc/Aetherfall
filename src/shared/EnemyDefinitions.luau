-- Early Hearthglen balance. These definitions never accept client-supplied statistics.
local definitions = {
	MeadowSlime = {
		name = "Meadow Slime", health = 65, defence = 0, damage = 8, speed = 5,
		xp = 20, gold = 3, detectRange = 22, attackRange = 5, impactRange = 6,
		windup = 0.8, cooldown = 2.2, leash = 35, respawn = 10,
		color = { 113, 187, 101 }, accent = { 200, 235, 143 },
	},
	WildBoar = {
		name = "Wild Boar", health = 95, defence = 5, damage = 12, speed = 7,
		xp = 35, gold = 5, detectRange = 22, attackRange = 5, impactRange = 6,
		windup = 0.8, cooldown = 2.4, leash = 35, respawn = 10,
		color = { 125, 88, 62 }, accent = { 224, 201, 151 },
	},
	Thornling = {
		name = "Thornling", health = 80, defence = 3, damage = 10, speed = 6,
		xp = 45, gold = 7, detectRange = 22, attackRange = 5, impactRange = 6,
		windup = 0.8, cooldown = 2.3, leash = 35, respawn = 10,
		color = { 109, 91, 53 }, accent = { 91, 151, 81 },
	},
}
for _, definition in definitions do
	table.freeze(definition.color)
	table.freeze(definition.accent)
	table.freeze(definition)
end
return table.freeze(definitions)
