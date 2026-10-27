--!strict
-- Hearthglen equipment, shared by presentation and server rules.
-- CriticalChance is a fraction: 0.03 means three percentage points.
-- Stat bonuses are implemented now; names/descriptions do not grant combat abilities.

export type Stats = { [string]: number }
export type Item = {
	id: string,
	name: string,
	description: string,
	rarity: string,
	family: string,
	slot: string,
	level: number,
	classes: { string },
	stats: Stats,
	sellValue: number,
	twoHanded: boolean,
	model: { shape: string, primary: { number }, accent: { number } },
}

local Items: { [string]: Item } = {}
local Order: { string } = {}
local all = { "Sentinel", "Spellweaver", "Ranger" }
local sentinel = { "Sentinel" }
local spellweaver = { "Spellweaver" }
local ranger = { "Ranger" }
local wood = { 112, 75, 46 }
local iron = { 141, 155, 168 }
local bronze = { 190, 130, 64 }
local blue = { 92, 181, 216 }
local green = { 98, 151, 91 }
local violet = { 161, 116, 220 }

local function add(
	id: string,
	name: string,
	description: string,
	rarity: string,
	family: string,
	slot: string,
	level: number,
	classes: { string },
	stats: Stats,
	sellValue: number,
	primary: { number },
	accent: { number },
	twoHanded: boolean?
)
	assert(Items[id] == nil, "Duplicate equipment id: " .. id)
	Items[id] = {
		id = id,
		name = name,
		description = description,
		rarity = rarity,
		family = family,
		slot = slot,
		level = level,
		classes = classes,
		stats = stats,
		sellValue = sellValue,
		twoHanded = twoHanded == true,
		model = { shape = family, primary = primary, accent = accent },
	}
	table.insert(Order, id)
end

-- Fourteen weapons provide different stat tradeoffs without random affixes.
add("training_sword", "Training Sword", "A broad wooden practice blade bound with bronze. A dependable first sword.",
	"Common", "Sword", "MainHand", 1, sentinel, { Attack = 10, Defence = 1 }, 3, wood, bronze, false)
add("iron_longsword", "Iron Longsword", "A balanced village-forged blade with a protective crossguard.",
	"Uncommon", "Sword", "MainHand", 3, sentinel, { Attack = 17, Defence = 3 }, 26, iron, bronze, false)
add("woodcutters_axe", "Woodcutter's Axe", "A heavy crescent head trades a little movement for a stronger strike.",
	"Uncommon", "Axe", "MainHand", 3, sentinel, { Attack = 21, MoveSpeed = -0.5 }, 25, iron, wood, false)
add("forge_mace", "Forgekeeper's Mace", "A square-flanged hammer carried by Hearthglen's forge wardens.",
	"Uncommon", "Mace", "MainHand", 4, sentinel, { Attack = 16, MaxHealth = 16 }, 30, iron, bronze, false)
add("boar_spear", "Boarwatch Spear", "A leaf-shaped head and ashwood shaft favour a sturdy, mobile loadout.",
	"Rare", "Spear", "MainHand", 5, sentinel, { Attack = 25, MoveSpeed = 0.5 }, 48, wood, iron, true)
add("grove_greatsword", "Grovewarden Greatsword", "A broad two-handed blade with a green-wrapped hilt; powerful but heavy.",
	"Rare", "Greatsword", "MainHand", 8, sentinel, { Attack = 34, MoveSpeed = -2 }, 83, iron, green, true)
add("hunting_knife", "Hunting Knife", "A compact hooked blade that leaves the other hand free for field gear.",
	"Common", "Dagger", "MainHand", 1, ranger, { Attack = 8, CriticalChance = 0.03, MoveSpeed = 0.5 }, 4, iron, wood, false)
add("longbow", "Longbow", "An unadorned ash bow for a new ranger. Both hands are required.",
	"Common", "Bow", "MainHand", 1, ranger, { Attack = 16 }, 6, wood, bronze, true)
add("hunters_bow", "Hunter's Bow", "A recurved greenwood bow with a finely balanced grip.",
	"Uncommon", "Bow", "MainHand", 4, ranger, { Attack = 22, CriticalChance = 0.03 }, 32, green, bronze, true)
add("watchtower_crossbow", "Watchtower Crossbow", "A braced iron bow offers high attack at the cost of movement speed.",
	"Rare", "Crossbow", "MainHand", 7, ranger, { Attack = 31, MoveSpeed = -1 }, 65, wood, iron, true)
add("apprentice_staff", "Apprentice Staff", "A tall forked staff cradling a blue aether stone. Requires both hands.",
	"Common", "Staff", "MainHand", 1, spellweaver, { MagicPower = 18 }, 6, wood, blue, true)
add("runic_staff", "Runic Staff", "A ring-crowned staff cut with old village runes and protective fittings.",
	"Rare", "Staff", "MainHand", 6, spellweaver, { MagicPower = 29, MagicResistance = 4 }, 55, wood, violet, true)
add("apprentice_wand", "Apprentice Wand", "A short hazel wand with a simple crystal tip; leaves room for a focus.",
	"Common", "Wand", "MainHand", 1, spellweaver, { MagicPower = 12 }, 4, wood, blue, false)
add("dewglass_wand", "Dewglass Wand", "A slender wand set with polished pond glass, favouring precise magic.",
	"Rare", "Wand", "MainHand", 8, spellweaver, { MagicPower = 25, CriticalChance = 0.04 }, 72, iron, blue, false)

-- A quiver can accompany a two-handed bow/crossbow. Other off-hands need a free hand.
add("wooden_shield", "Wooden Shield", "An iron-rimmed round shield from the village militia.",
	"Common", "Shield", "OffHand", 1, sentinel, { Defence = 6, MaxHealth = 10 }, 5, wood, iron)
add("novice_focus", "Novice Focus", "A floating crystal held in a bronze ring. Complements a one-handed wand.",
	"Common", "Focus", "OffHand", 1, spellweaver, { MagicPower = 5, MagicResistance = 3 }, 5, bronze, blue)
add("trail_quiver", "Trailrunner's Quiver", "Feathered shafts in a light leather quiver. Complements bows, crossbows, or a hunting knife.",
	"Uncommon", "Quiver", "OffHand", 3, ranger, { Attack = 4, CriticalChance = 0.02, MoveSpeed = 0.5 }, 20, wood, green)
add("wayfarer_lantern", "Wayfarer's Lantern", "A brass-caged aether lantern with a steady glow and defensive fittings.",
	"Uncommon", "Lantern", "OffHand", 2, all, { MaxHealth = 10, MagicResistance = 4 }, 15, bronze, blue)

-- Twelve starter armour pieces: steel militia, supple scout leather, woven acolyte cloth.
-- Individual pieces can be mixed with later gear; no hidden set-bonus code is implied.
add("militia_helmet", "Militia Helm", "A rounded steel cap with a bronze brow band.",
	"Common", "Helmet", "Helmet", 1, sentinel, { Defence = 3, MaxHealth = 5 }, 4, iron, bronze)
add("militia_chest", "Militia Cuirass", "Overlapping steel panels and a padded green undershirt.",
	"Common", "Chest", "Chest", 1, sentinel, { Defence = 6, MaxHealth = 12, MoveSpeed = -0.5 }, 8, iron, green)
add("militia_gloves", "Militia Gauntlets", "Reinforced gloves with compact steel knuckle guards.",
	"Common", "Gloves", "Gloves", 1, sentinel, { Defence = 2, Attack = 1 }, 3, iron, bronze)
add("militia_boots", "Militia Sabatons", "Sturdy leather boots capped with worn steel plates.",
	"Common", "Boots", "Boots", 1, sentinel, { Defence = 3, MaxHealth = 5 }, 4, wood, iron)
add("scout_helmet", "Scout Hood", "A moss-green hood pinned with a small brass leaf.",
	"Common", "Helmet", "Helmet", 1, ranger, { Defence = 1, CriticalChance = 0.01 }, 4, green, bronze)
add("scout_chest", "Scout Jerkin", "A fitted leather vest with a short green shoulder cape.",
	"Common", "Chest", "Chest", 1, ranger, { Defence = 4, MaxHealth = 8 }, 8, wood, green)
add("scout_gloves", "Scout Bracers", "Light leather bracers leave the fingers free.",
	"Common", "Gloves", "Gloves", 1, ranger, { Attack = 2, CriticalChance = 0.01 }, 3, wood, bronze)
add("scout_boots", "Scout Trailboots", "Soft-soled trail boots made for moving over root and stone.",
	"Common", "Boots", "Boots", 1, ranger, { Defence = 1, MoveSpeed = 1 }, 4, wood, green)
add("acolyte_helmet", "Acolyte Circlet", "A bronze circlet holding one pale blue crystal.",
	"Common", "Helmet", "Helmet", 1, spellweaver, { MagicPower = 2, MagicResistance = 2 }, 4, bronze, blue)
add("acolyte_chest", "Acolyte Robe", "Layered blue cloth with an embroidered aether sigil.",
	"Common", "Chest", "Chest", 1, spellweaver, { MagicResistance = 5, MaxHealth = 6 }, 8, { 58, 83, 133 }, blue)
add("acolyte_gloves", "Acolyte Wraps", "Cloth hand wraps sewn with small focusing beads.",
	"Common", "Gloves", "Gloves", 1, spellweaver, { MagicPower = 3 }, 3, { 58, 83, 133 }, bronze)
add("acolyte_boots", "Acolyte Slippers", "Quiet blue boots with protective rune-stitched cuffs.",
	"Common", "Boots", "Boots", 1, spellweaver, { Defence = 1, MagicResistance = 2, MoveSpeed = 0.5 }, 4, { 58, 83, 133 }, blue)

-- Accessories fit either accessory slot. Each grants a visible, deterministic bonus.
add("hearthstone_pendant", "Hearthstone Pendant", "A river-smoothed hearthstone tied with bronze wire; a keepsake for new arrivals.",
	"Common", "Accessory", "Accessory", 1, all, { MaxHealth = 10 }, 3, bronze, { 218, 127, 77 })
add("copper_band", "Copper Band", "A plain copper ring stamped with Hearthglen's gate mark.",
	"Common", "Accessory", "Accessory", 1, all, { Defence = 1, MagicResistance = 1 }, 3, bronze, iron)
add("scouts_charm", "Scout's Charm", "A carved leaf charm for travellers who favour swift feet.",
	"Uncommon", "Accessory", "Accessory", 3, all, { MoveSpeed = 1, CriticalChance = 0.01 }, 18, green, bronze)
add("forge_signet", "Forge Signet", "A broad iron ring bearing the blacksmith's hammer crest.",
	"Uncommon", "Accessory", "Accessory", 4, all, { Attack = 3, Defence = 2 }, 24, iron, bronze)
add("moonlit_locket", "Moonlit Locket", "A silver locket containing a shard of reflective pond glass.",
	"Rare", "Accessory", "Accessory", 6, all, { MagicPower = 5, MagicResistance = 3 }, 42, iron, blue)
add("briarheart_talisman", "Briarheart Talisman", "A polished amber seed in a branching bronze cage, shaped by grove artisans.",
	"Epic", "Accessory", "Accessory", 10, all, { MaxHealth = 20, Defence = 3, MagicResistance = 3 }, 110, bronze, green)

-- Earned guardian equipment. These deterministic bonuses do not imply hidden passives.
local briarwood = { 92, 76, 44 }
local groveAmber = { 199, 178, 83 }
add("briarwarden_shield", "Briarwarden's Shield", "Woven briarwood frames an amber-green guardian crest. Earned by overcoming Briarwarden.",
	"Epic", "Shield", "OffHand", 5, sentinel, { Defence = 12, MaxHealth = 25, MagicResistance = 4 }, 95, briarwood, groveAmber)
add("briarwarden_staff", "Briarwarden's Staff", "A living-wood staff cradles a polished amber-green stone. A two-handed reward from the grove guardian.",
	"Epic", "Staff", "MainHand", 5, spellweaver, { MagicPower = 36, MagicResistance = 6 }, 110, briarwood, groveAmber, true)
add("briarwarden_bow", "Briarwarden's Bow", "Amber-green bindings reinforce this recurved briarwood bow, earned by defeating the grove guardian.",
	"Epic", "Bow", "MainHand", 5, ranger, { Attack = 34, CriticalChance = 0.04 }, 110, briarwood, groveAmber, true)

local function deepFreeze(value: any)
	if type(value) == "table" and not table.isfrozen(value) then
		for _, child in pairs(value) do
			deepFreeze(child)
		end
		table.freeze(value)
	end
	return value
end

local Catalog = {
	Items = Items,
	Order = Order,
	Classes = all,
	Slots = { "MainHand", "OffHand", "Helmet", "Chest", "Gloves", "Boots", "Accessory1", "Accessory2" },
	Rarities = {
		Common = { color = { 191, 198, 207 }, rank = 1 },
		Uncommon = { color = { 109, 202, 128 }, rank = 2 },
		Rare = { color = { 104, 173, 245 }, rank = 3 },
		Epic = { color = { 195, 141, 245 }, rank = 4 },
		Legendary = { color = { 241, 194, 80 }, rank = 5 },
		Mythic = { color = { 244, 117, 117 }, rank = 6 },
	},
	BaseStats = {
		MaxHealth = 100,
		Attack = 5,
		MagicPower = 5,
		Defence = 0,
		MagicResistance = 0,
		CriticalChance = 0.05,
		MoveSpeed = 16,
	},
	StarterWeapons = {
		Sentinel = "training_sword",
		Spellweaver = "apprentice_wand",
		Ranger = "longbow",
	},
	StarterLoadouts = {
		Sentinel = {
			"training_sword", "wooden_shield", "militia_helmet", "militia_chest",
			"militia_gloves", "militia_boots", "hearthstone_pendant", "copper_band",
		},
		Spellweaver = {
			"apprentice_wand", "novice_focus", "acolyte_helmet", "acolyte_chest",
			"acolyte_gloves", "acolyte_boots", "hearthstone_pendant", "copper_band",
		},
		Ranger = {
			"longbow", "scout_helmet", "scout_chest", "scout_gloves",
			"scout_boots", "hearthstone_pendant", "copper_band",
		},
	},
	get = function(id: string): Item?
		return Items[id]
	end,
}

return deepFreeze(Catalog)
