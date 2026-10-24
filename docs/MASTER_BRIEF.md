# MASTER DEVELOPMENT PROMPT — AETHERFALL: SHARDS OF THE HOLLOW STAR

## ROLE AND OBJECTIVE

You are an expert Roblox game development team consisting of:

- A senior Roblox Luau programmer.
- A professional RPG systems designer.
- A 3D environment and character artist.
- A combat and animation designer.
- A sound designer and music director.
- A UI/UX designer.
- A multiplayer networking engineer.
- A performance optimisation specialist.
- A narrative and quest designer.
- A gameplay quality assurance engineer.

Your objective is to **create a fully functional, polished, original, multiplayer-compatible, open-world fantasy RPG in Roblox Studio**, rather than simply describing a game concept.

The game must contain working gameplay systems, original environments, functional 3D models, enemies, boss encounters, equipment, progression, quests, audio integration, animations, saving systems, multiplayer support, and user interfaces.

Do not produce a collection of disconnected demonstration scripts.

Design every system to function as part of one coherent RPG.

**Game title:** Aetherfall: Shards of the Hollow Star

**Genre:** Open-world fantasy action RPG

**Platform:** Roblox

**Engine:** Roblox Studio

**Programming language:** Luau

**Perspective:** Third-person with adjustable camera

**Players per server:** Target 1–12

**Level cap:** 60

**Art direction:** Stylised, colourful, high-quality fantasy with Roblox-compatible geometry and materials.

**Target audience:** Broad Roblox audience; use stylised fantasy combat without realistic gore.

**Primary gameplay loop:**

Explore → Discover quests → Fight enemies → Earn experience and loot → Upgrade equipment → Unlock abilities → Defeat bosses → Discover new regions → Advance the story → Complete increasingly challenging content.

The game should feel like a polished adventure rather than a repetitive simulator.

---

# 1. CORE GAME VISION

## Setting

The world of Aetherfall was once sustained by a celestial object known as the Hollow Star.

Centuries ago, the Hollow Star fractured into five Aether Shards, scattering magical energy throughout the world.

The fractured energy transformed the surrounding lands, created dangerous creatures, awakened ancient structures, and caused competing factions to seek control of the shards.

Players begin as inexperienced adventurers arriving at Hearthglen Village.

They gradually discover that the Hollow Star was not destroyed by accident. An ancient order deliberately fractured it to imprison a powerful celestial entity.

As players progress, they must decide whether the Hollow Star should be restored, left fragmented, or sealed away forever.

## Design principles

1. Exploration must feel rewarding.
2. Combat must be responsive and skill-based.
3. Progression must feel meaningful at every level.
4. Quests should involve more than repeatedly defeating enemies.
5. Different regions should have distinct visual and musical identities.
6. Boss fights must require learning mechanics.
7. Free players must be able to complete all major gameplay content.
8. Multiplayer cooperation must be encouraged without making solo play impossible.
9. The game must remain understandable to new players.
10. Performance must be prioritised across desktop, mobile, and console.

---

# 2. OPEN WORLD AND MAP GENERATION

Create a connected fantasy world containing five primary regions.

Every region must feature:

- Distinct terrain and materials.
- Buildings and environmental models.
- Enemy spawn locations.
- Named NPCs.
- Quest locations.
- Hidden discoveries.
- Resource gathering nodes.
- Unique ambient audio.
- Appropriate lighting and atmospheric effects.
- A regional boss encounter.
- Unlockable fast-travel locations.
- Safe zones and combat zones.

Use a modular terrain generation system where practical.

## Region 1 — Hearthglen Valley

**Recommended levels:** 1–10

**Theme:** Peaceful forests, green hills, rivers, farmland, and a welcoming medieval village.

**Landmarks:**
- Hearthglen Village
- Old Windmill
- Whispering Woods
- Abandoned Watchtower
- Moonlit Pond
- Forgotten Cellar

**Required 3D models:**
- Timber cottages with layered roofs
- Blacksmith workshop with animated forge
- Village tavern
- Stone paths
- Wooden bridges
- Trees with varied shapes
- Grass and flower clusters
- Market stalls
- Wooden fences
- Crates, barrels, carts, and lanterns
- Training dummies
- Water wells
- Village signposts

**Enemies:**
- Meadow Slime
- Wild Boar
- Forest Wolf
- Thornling
- Corrupted Treant

**Boss:** Briarwarden, Guardian of the Ancient Grove.

**Atmosphere:** Warm lighting, drifting leaves, gentle wind, birdsong, and calm fantasy music.

## Region 2 — Emberwood Expanse

**Recommended levels:** 10–20

**Theme:** Dark enchanted forest with glowing vegetation, ancient trees, ruins, and corrupted wildlife.

**Landmarks:**
- Emberroot Camp
- Ashen Shrine
- Hollow Tree Cathedral
- Forgotten Druid Circle
- Crimson Clearing

**3D models:**
- Large twisted trees
- Glowing mushrooms
- Ancient stone monuments
- Broken statues
- Tree-root bridges
- Moss-covered ruins
- Magical crystal formations
- Abandoned camps
- Hanging lanterns

**Enemies:**
- Ember Sprite
- Corrupted Wolf
- Vine Stalker
- Forest Wraith
- Ancient Root Guardian

**Boss:** Cindermane, the Ashbound Beast.

**Atmosphere:** Red and amber lighting, magical particles, dense forest ambience, distant animal cries.

## Region 3 — Crystal Fen

**Recommended levels:** 20–32

**Theme:** Magical wetlands featuring glowing crystals, shallow water, caves, and mysterious ruins.

**Landmarks:**
- Crystalwatch Outpost
- Shimmering Caverns
- Forgotten Observatory
- Sunken Temple
- Prism Lake

**3D models:**
- Crystal clusters
- Luminescent vegetation
- Wooden walkways
- Stone ruins
- Crystal caves
- Waterfalls
- Arcane devices
- Giant mushrooms
- Ancient bookshelves
- Floating crystal fragments

**Enemies:**
- Crystal Crawler
- Marsh Spirit
- Arcane Wisp
- Stone Sentinel
- Prism Elemental

**Boss:** The Prism Toad, a giant crystalline amphibian.

**Atmosphere:** Blue and purple lighting, shimmering reflections, echoing caves, magical humming.

## Region 4 — Stormreach Highlands

**Recommended levels:** 32–45

**Theme:** Wind-swept mountains, ancient fortresses, thunderstorms, and floating ruins.

**Landmarks:**
- Stormwatch Keep
- Broken Skybridge
- Thunderpeak Summit
- Fallen Citadel
- Observatory of Winds

**3D models:**
- Mountain cliffs
- Fortress walls
- Stone towers
- Battle-damaged banners
- Rope bridges
- Lightning rods
- Ancient machinery
- Floating islands
- Mountain pines
- Broken siege equipment

**Enemies:**
- Storm Harpy
- Ironclad Raider
- Thunder Elemental
- Mountain Golem
- Fallen Knight

**Boss:** Tempest Knight, Keeper of the Fourth Shard.

**Atmosphere:** Strong wind, thunder, lightning flashes, dramatic orchestral music.

## Region 5 — Hollow Spire

**Recommended levels:** 45–60

**Theme:** A ruined celestial kingdom suspended above a massive magical abyss.

**Landmarks:**
- Shattered Gateway
- Astral Gardens
- Hall of Echoes
- Celestial Observatory
- Hollow Star Chamber

**3D models:**
- Floating architecture
- Golden celestial ornaments
- Broken marble pathways
- Magical portals
- Floating debris
- Star-shaped crystal structures
- Astral trees
- Giant celestial statues
- Ancient throne room
- Final boss arena

**Enemies:**
- Astral Sentinel
- Voidbound Knight
- Celestial Spectre
- Starforged Golem
- Hollow Guardian

**Final boss:** The Eclipse Herald.

**Atmosphere:** Celestial ambience, orchestral choir textures, distant echoes, stars, glowing architecture, and restrained magical particle effects.

---

# 3. THREE-DIMENSIONAL MODEL GENERATION

Do not leave the game as an empty baseplate with placeholder cubes.

Create original, recognisable 3D models for the required world objects.

If custom mesh generation is unavailable, construct usable stylised models programmatically from Roblox Parts, Wedges, MeshParts when available, materials, decals, SurfaceAppearance where appropriate, and other supported Studio instances.

Prioritise attractive silhouettes, good proportions, and intentional colour palettes.

## Model categories

### Architecture
Create reusable modular pieces for cottages, inns, castles, towers, bridges, ruins, shops, workshops, and dungeons.

Each building should have:
- A coherent exterior.
- Properly aligned entrances.
- Visible architectural details.
- Correct collisions.
- Appropriate interior space when gameplay requires entry.
- Lighting and props.
- Named components for future editing.

### Characters
Create rigged humanoid characters using Roblox-supported rigs.

Provide:
- Idle animations.
- Walk and run animations.
- Jump and landing animations.
- Basic attack animations.
- Skill animations.
- Hit reaction animations.
- Defeat animations.
- NPC interaction animations.

Use Roblox-compatible Humanoid and Animator systems, with correct rigging and animation ownership.

### Weapons
Create distinctive models for:
- Training Sword
- Iron Longsword
- Emberblade
- Crystal Saber
- Stormbreaker Greatsword
- Astral Edge
- Apprentice Staff
- Runic Staff
- Prism Wand
- Longbow
- Hunter's Bow
- Tempest Bow
- Wooden Shield
- Iron Shield
- Celestial Shield

Each weapon must have:
- Appropriate grip positioning.
- Correct attachment points.
- Distinct silhouettes.
- Appropriate materials.
- Equipment compatibility.
- Optional visual effects for higher rarities.

### Environment
Generate detailed foliage, rocks, mushrooms, fences, lamps, flowers, ore nodes, crystals, water decorations, ruins, and treasure chests.

Use model variations to prevent excessive repetition.

### Enemy models
Every enemy family must have a recognisable silhouette and readable combat animations.

Boss models must be significantly more visually distinctive than ordinary enemies.

Bosses should use separate animated parts or rigged body components as needed.

## Technical model requirements

- Establish consistent scales.
- Use reusable model templates.
- Assign PrimaryParts where useful.
- Use CollectionService tags for interactive objects.
- Avoid unnecessary high-part-count models.
- Configure collisions intentionally.
- Anchor static world geometry.
- Avoid unsupported dependencies.
- Remove scripts from untrusted third-party models.
- Avoid excessive textures and particle emitters.
- Ensure model pivots work correctly.
- Organise assets into clearly named folders.

Any model that cannot be constructed automatically must include an exact, import-ready specification and a functional procedural substitute.

Never falsely claim that an external mesh, animation, or audio asset has been created or uploaded.

---

# 4. CHARACTER CREATION AND CLASSES

Players should enter a character creation menu when beginning a new character.

Provide customisation options for:
- Hair style
- Hair colour
- Skin tone
- Eye appearance
- Outfit colours
- Starting class
- Character name display, following Roblox text filtering and naming rules

Provide three starter classes.

## Class A — Sentinel

A defensive melee fighter specialising in swords, shields, and frontline combat.

**Base characteristics:**
- High health.
- High defence.
- Moderate damage.
- Low mana.
- Strong close-range control.

**Abilities:**
1. Steel Slash — Fast melee attack.
2. Shield Bash — Damages and briefly stuns an enemy.
3. Guardian Stance — Temporarily reduces incoming damage.
4. Ultimate: Titan's Resolve — Creates a protective aura and empowers melee attacks.

## Class B — Spellweaver

A ranged magic user specialising in elemental spells and area damage.

**Base characteristics:**
- Low health.
- Low defence.
- High magical damage.
- High mana.
- Strong crowd control.

**Abilities:**
1. Arcane Bolt — Launches a magical projectile.
2. Flame Burst — Area-of-effect explosion.
3. Frost Bind — Slows enemies.
4. Ultimate: Astral Storm — Summons multiple magical strikes within a designated area.

## Class C — Ranger

A mobile ranged fighter specialising in bows, traps, and precision.

**Base characteristics:**
- Moderate health.
- Moderate defence.
- High mobility.
- Reliable single-target damage.
- Moderate stamina consumption.

**Abilities:**
1. Piercing Shot — Charged arrow attack.
2. Quickstep — Short evasive dash.
3. Snare Trap — Places a temporary slowing trap.
4. Ultimate: Arrow Tempest — Fires a rapid burst of arrows at nearby targets.

## General class requirements

- Classes should have different animations.
- Cooldowns must appear in the UI.
- Skills should visually communicate their area of effect.
- Damage calculations must be server-authoritative.
- Skills must have clearly defined resource costs.
- Players should unlock abilities through progression.
- Respec opportunities should be obtainable through ordinary gameplay.
- Avoid making any class substantially stronger than the others across all content.

---

# 5. COMBAT SYSTEM

Implement a real-time action combat system.

## Required mechanics

- Basic attacks.
- Three-hit melee combo sequences.
- Charged attacks where appropriate.
- Directional dodging.
- Sprinting.
- Blocking.
- Stamina management.
- Mana management.
- Critical hits.
- Damage indicators.
- Enemy hit reactions.
- Knockback where appropriate.
- Ability cooldowns.
- Status effects.
- Boss attack telegraphs.
- Death and respawn.
- Temporary invulnerability where required for dodges or spawning.

## Damage system

Use a configurable formula such as:

Physical Damage = max(1, Weapon Damage × Attack Multiplier × (100 / (100 + Effective Defence)))

Magical Damage = max(1, Spell Power × Ability Multiplier × (100 / (100 + Effective Magic Resistance)))

Critical hits multiply eligible damage by a configurable critical-damage multiplier.

All statistics must be validated and calculated by the server.

Support:
- Physical damage.
- Fire damage.
- Ice damage.
- Lightning damage.
- Arcane damage.
- Damage-over-time effects.
- Defensive buffs.
- Temporary debuffs.

Damage formulas must remain readable and easy to adjust.

## Combat polish

Create:
- Sword trails.
- Magical projectile trails.
- Impact flashes.
- Shield-block visual effects.
- Subtle camera shake.
- Damage number popups.
- Enemy health bars.
- Ability charging effects.
- Critical-hit effects.
- Distinct boss ability warnings.

Support reduced-motion settings, and do not rely solely on colour to communicate danger.

Use animation events when suitable to synchronise hits and effects.

## Enemy AI

Enemies should possess state-based behaviour:

Idle → Patrol → Detect → Pursue → Attack → Recover → Return.

Enemies must:
- Detect players within configurable ranges.
- Respect collision and terrain.
- Avoid becoming permanently stuck.
- Stop chasing after reaching a leash distance.
- Have attack cooldowns.
- Use distinct attack patterns.
- Handle multiple players appropriately.
- Respawn after an appropriate delay.
- Award validated loot and experience.

Use PathfindingService where needed.

Avoid performing expensive pathfinding every frame.

---

# 6. BOSS ENCOUNTERS

Every region requires a mechanically distinct boss.

## Boss 1 — Briarwarden

A giant ancient tree guardian.

**Mechanics:**
- Sweeping branch attacks.
- Root traps.
- Poison-free magical thorn fields.
- Summoned Thornlings.
- A vulnerable core phase.

The player must learn to dodge roots before attacking the exposed core.

## Boss 2 — Cindermane

A giant enchanted beast with burning crystal armour.

**Mechanics:**
- Forward charge.
- Wide claw swipe.
- Flame shockwave.
- Leaping strike.
- Breakable magical armour.

## Boss 3 — Prism Toad

A giant crystal-covered amphibian.

**Mechanics:**
- Crystal projectiles.
- Ground slam.
- Reflective crystal shields.
- Arena crystal formations.
- Weak-point vulnerability windows.

## Boss 4 — Tempest Knight

A fallen warrior wielding lightning.

**Mechanics:**
- Sword combinations.
- Thunder telegraphs.
- Lightning pillars.
- Shield phase.
- Arena-wide attack requiring positioning.

## Final Boss — The Eclipse Herald

A celestial guardian corrupted by fractured Aether.

**Phase 1:**
Sword attacks, magical projectiles, movement challenges.

**Phase 2:**
Floating platforms, celestial beams, summoned sentinels.

**Phase 3:**
Faster attacks, arena changes, and a final interruptible ultimate.

## Boss requirements

- Display boss name and health bar.
- Play distinct boss music.
- Use cinematic but skippable introductions.
- Telegraph dangerous attacks clearly.
- Scale encounters sensibly for parties.
- Prevent exploit-based instant defeats.
- Provide meaningful rewards.
- Allow fair recovery after failure.
- Support solo completion with appropriate balancing.

---

# 7. PLAYER PROGRESSION SYSTEM

Implement a complete level 1–60 progression system.

## Experience

Players gain XP from:
- Story quests.
- Side quests.
- Enemy defeats.
- Boss fights.
- Discovering important locations.
- Completing dungeons.
- Selected achievements.

Use a configurable increasing XP requirement curve, initially:

XP to next level = floor(100 × Level^1.45)

Balance this curve through playtesting.

## Base statistics

Track:
- Level
- Current XP
- Required XP
- Health
- Maximum Health
- Mana
- Maximum Mana
- Stamina
- Maximum Stamina
- Attack
- Defence
- Magic Power
- Magic Resistance
- Critical Chance
- Critical Damage
- Movement Speed

## Level rewards

Every level grants:
- Statistical improvements.
- Recoverable health and mana appropriate to level-up.
- Progress toward new content.

Every five levels grants:
- A skill point or major progression reward.

At selected milestones:
- Unlock additional abilities.
- Access new equipment tiers.
- Gain new regions.
- Unlock advanced crafting recipes.

## Talent trees

Create three skill branches for each class.

Sentinel:
- Vanguard
- Protector
- Warlord

Spellweaver:
- Pyromancer
- Cryomancer
- Arcanist

Ranger:
- Marksman
- Trapper
- Windrunner

Skills should have prerequisites, reasonable caps, and noticeable effects.

Persist allocated skill points and support respecs.

---

# 8. EQUIPMENT AND LOOT

Create an inventory system with item categories.

## Categories

- Weapons
- Armour
- Accessories
- Consumables
- Crafting Materials
- Quest Items
- Cosmetic Items

## Equipment slots

- Main Hand
- Off Hand
- Helmet
- Chest
- Gloves
- Boots
- Accessory 1
- Accessory 2

## Rarity tiers

Common — Grey

Uncommon — Green

Rare — Blue

Epic — Purple

Legendary — Gold

Mythic — Red

Use text labels and icons in addition to colours.

## Item characteristics

Each item should support:
- Unique item identifier where needed.
- Display name.
- Rarity.
- Type.
- Description.
- Level requirement.
- Stat modifiers.
- Equipment slot.
- Sell value.
- Upgrade level.
- Optional special ability.
- Optional cosmetic effects.

## Inventory behaviour

Allow players to:
- Equip.
- Unequip.
- Inspect.
- Sort.
- Filter.
- Sell.
- Craft.
- Upgrade.
- Lock valuable items against accidental selling.
- Discard eligible items after confirmation.

Prevent duplication exploits and invalid inventory transactions.

## Loot distribution

Enemy rewards must be determined by server-controlled tables.

Rare items should feel special but not be mandatory random-grind barriers to finishing the main story.

Show loot notifications and a reward summary after major encounters.

---

# 9. MAIN STORY QUESTLINE

Implement an interconnected main campaign in five acts.

Each quest must have:
- Unique quest ID.
- Quest title.
- Narrative description.
- Prerequisites.
- Objectives.
- NPC or world interaction targets.
- Completion conditions.
- XP rewards.
- Gold rewards.
- Optional item rewards.
- Dialogue.
- Progress tracking.
- Completion persistence.

## Act I — The First Fracture

**Quest 1: A Stranger in Hearthglen**

Talk to Elder Rowan, meet the blacksmith, and learn basic controls.

Reward: Starter weapon, 100 XP.

**Quest 2: Trouble at the Fields**

Protect farmers and defeat four corrupted creatures.

Reward: 150 XP, 60 Gold.

**Quest 3: The Missing Scout**

Follow environmental clues, locate a missing scout, and escort them safely home.

Reward: 250 XP, Scout's Charm.

**Quest 4: The Whispering Grove**

Solve a rune puzzle and investigate the corruption.

Reward: 350 XP, 120 Gold.

**Quest 5: Guardian of the Roots**

Defeat Briarwarden and recover the first shard.

Reward: Major XP, unique class-appropriate equipment, access to Emberwood.

## Act II — Ashes Beneath the Trees

**Quest 6: The Forest's Warning**

Investigate the source of spreading corruption.

**Quest 7: The Broken Circle**

Repair ancient ritual stones by solving environmental challenges.

**Quest 8: Trial of the Druids**

Complete combat, observation, and navigation challenges.

**Quest 9: Heart of the Emberwood**

Defeat Cindermane and claim the second shard.

## Act III — Secrets Beneath the Fen

**Quest 10: The Drowned Archive**

Recover three records from ancient ruins.

**Quest 11: Echoes of the Observatory**

Activate magical devices in the correct sequence.

**Quest 12: The Prism Guardian**

Defeat the Prism Toad and recover the third shard.

The player learns that the shards once sealed something dangerous.

## Act IV — The Skybound War

**Quest 13: The Fallen Banner**

Assist Stormwatch soldiers in defending a fortress.

**Quest 14: The Broken Skybridge**

Recover materials, repair the bridge, and reach the ancient citadel.

**Quest 15: The Knight's Oath**

Investigate the story of the Tempest Knight.

**Quest 16: Eye of the Storm**

Defeat the Tempest Knight and recover the fourth shard.

Reveal the original purpose of the Hollow Star.

## Act V — The Hollow Star

**Quest 17: Beyond the Veil**

Enter the celestial kingdom.

**Quest 18: The Forgotten Truth**

Explore memory fragments and uncover the history of the ancient order.

**Quest 19: The Last Guardian**

Complete the final dungeon.

**Quest 20: Shards of Destiny**

Defeat the Eclipse Herald.

Present three narrative endings:
- Restore the Star.
- Preserve the Seals.
- Bind the Shards into a new protective constellation.

Choices should change dialogue, final cutscenes, and cosmetic world-state details without unfairly locking players out of endgame progression.

---

# 10. SIDE QUESTS AND DYNAMIC EVENTS

Create at least 20 side quests distributed across the world.

Include varied objectives:
- Investigating mysteries.
- Recovering lost belongings.
- Escorting NPCs.
- Solving puzzles.
- Gathering crafting materials.
- Defending settlements.
- Exploring hidden ruins.
- Repairing machinery.
- Defeating optional enemies.
- Recovering ancient artifacts.

Avoid designing every quest around eliminating a fixed number of enemies.

## Example questlines

**The Blacksmith's Legacy:** Help a young blacksmith restore a legendary forge.

**The Cartographer's Journal:** Discover hidden viewpoints across all five regions.

**A Friend Among Spirits:** Help a peaceful forest spirit recover its memories.

**The Lost Caravan:** Follow tracks, locate survivors, and restore a trade route.

**The Astral Collector:** Collect ancient fragments and unlock a cosmetic celestial cloak.

## World events

Implement rotating events such as:
- Enemy raids.
- Magical storms.
- Wandering merchants.
- Rare enemy appearances.
- Temporary treasure expeditions.
- Cooperative settlement defence.

Events should reward participation fairly and avoid excessive fear-of-missing-out mechanics.

---

# 11. DUNGEONS AND ENDGAME

Create at least three instanced or appropriately separated cooperative dungeons.

## Dungeon A — Ruins of the First Order

Recommended level: 15+

Features:
- Ancient ruins.
- Environmental puzzles.
- Guardian enemies.
- Optional treasure rooms.
- Final stone guardian encounter.

## Dungeon B — The Crystal Labyrinth

Recommended level: 30+

Features:
- Crystal mirrors.
- Magical barriers.
- Multi-stage traversal puzzles.
- Coordinated enemy encounters.
- Crystal guardian boss.

## Dungeon C — The Celestial Vault

Recommended level: 50+

Features:
- Floating platforms.
- Celestial mechanisms.
- Magical sentinels.
- Cooperative pressure-plate challenges with solo alternatives.
- Multi-phase boss.

## Endgame systems

After completing the main story, unlock:
- Repeatable dungeon difficulties.
- Optional advanced boss variants.
- Cosmetic achievements.
- Equipment upgrading.
- Exploration completion rewards.
- Challenging combat trials.
- Long-term crafting goals.

Endgame content should reward mastery rather than excessive repetitive grinding.

---

# 12. CRAFTING AND ECONOMY

Introduce a single primary earned currency: Gold.

Players earn Gold through gameplay.

## Crafting professions

- Blacksmithing
- Alchemy
- Enchanting

## Resources

Examples:
- Iron Ore
- Silver Ore
- Aether Crystal
- Emberwood
- Moonleaf
- Stormstone
- Astral Fragment

## Crafting stations

Create interactive:
- Forge
- Alchemy Table
- Enchanting Altar

Use ProximityPrompt or accessible UI interactions.

Crafting must:
- Display required materials.
- Validate inventory quantities.
- Consume resources atomically.
- Grant the correct item.
- Prevent rapid duplicate crafting requests.
- Show success and failure feedback.
- Persist results.

Avoid an uncontrolled player-generated economy.

---

# 13. SOUND DESIGN AND MUSIC

Sound is a core part of the game's identity.

Create a complete audio design specification and implement the runtime audio systems.

Use only original audio or assets with confirmed permission for use in the experience.

Do not invent asset IDs or use copyrighted music without authorisation.

If audio generation or uploading is not supported, provide clearly identified placeholders, precise sound briefs, asset-name references, and import instructions.

## Regional background music

Create or specify separate looping tracks for:

**Hearthglen:**
Gentle acoustic guitar, flutes, soft strings, peaceful melody.

**Emberwood:**
Low strings, wooden percussion, mysterious ambient tones.

**Crystal Fen:**
Soft bells, shimmering synthesis, magical pads.

**Stormreach:**
Deep percussion, dramatic orchestral strings, adventurous themes.

**Hollow Spire:**
Ethereal choir-like textures, soft piano, celestial ambience.

## Combat music

Each region must also have:
- Standard combat music.
- Boss battle music.
- Victory sting.

Boss music should become more intense as encounter phases change.

## Combat sound effects

Required cues:
- Sword swing.
- Sword impact.
- Shield block.
- Bow release.
- Arrow impact.
- Spell casting.
- Fire explosion.
- Ice magic.
- Lightning strike.
- Critical hit.
- Dodge movement.
- Character damage.
- Enemy damage.
- Enemy defeat.
- Boss roar.
- Boss attack warning.

## Environmental sound effects

Include:
- Birds.
- Wind.
- Rustling leaves.
- Water flow.
- Footsteps differentiated by surface.
- Forge hammering.
- Tavern ambience.
- Crackling fires.
- Thunder.
- Crystal resonance.
- Stone doors.
- Treasure chests.
- Magical portals.

## UI sounds

Include:
- Button hover.
- Button confirm.
- Menu open.
- Menu close.
- Inventory movement.
- Quest accepted.
- Quest completed.
- Item equipped.
- Level-up celebration.
- Achievement unlocked.
- Error notification.

## Audio implementation requirements

- Use SoundService and appropriate audio objects.
- Separate audio into Music, Ambience, Combat, UI, and Voice sound groups or equivalent mixers.
- Provide independent volume controls.
- Use spatial audio for world objects.
- Use non-spatial audio for interface notifications.
- Crossfade music between regions.
- Fade smoothly into combat music.
- Duck background music when important cues require clarity.
- Avoid overlapping excessive identical sounds.
- Pool or reuse audio objects when appropriate.
- Provide subtitled or visual alternatives for important sound-only information.
- Prevent sudden excessive loudness.
- Ensure audio works on mobile and desktop.

Provide a sound asset manifest specifying each event, filename or placeholder, category, trigger, loop behaviour, volume, and 3D rolloff settings.

---

# 14. USER INTERFACE AND USER EXPERIENCE

Create a polished fantasy-themed interface with readable typography.

## Main HUD

Display:
- Health bar.
- Mana bar.
- Stamina bar.
- XP bar.
- Player level.
- Current objective.
- Skill hotbar.
- Gold.
- Optional minimap or compass.

## Menus

Implement:
- Main Menu
- Character Creation
- Character Statistics
- Inventory
- Equipment
- Quest Journal
- Skill Tree
- World Map
- Crafting
- Shop
- Settings
- Party Menu
- Achievements

## Visual style

Use dark translucent panels with bronze and blue magical accents.

Use clearly distinguishable icons.

Menus should open and close smoothly.

Do not obscure important gameplay unnecessarily.

## Quest tracking

Display current quest objectives and progress.

Mark relevant NPCs and destinations in a reasonable way.

Allow quest tracking changes from the journal.

## Accessibility

- Support different screen sizes.
- Honour reduced-motion preferences.
- Provide readable text sizes.
- Use good contrast.
- Do not communicate important information through colour alone.
- Provide visual indications of important audio cues.
- Support keyboard, mouse, touch, and controller.
- Do not require precise small-screen tapping during combat.
- Avoid excessive flashing or screen shake.
- Respect Roblox platform accessibility preferences where available.

## Controls

**Desktop:**
- WASD: Movement
- Mouse: Camera
- Left-click: Basic attack
- Right-click: Block or aim
- Shift: Sprint
- Space: Jump
- Q: Dodge
- 1–4: Skills
- E: Interact
- I: Inventory
- J: Quest Journal
- M: Map

Create equivalent intuitive mobile and gamepad controls using ContextActionService and appropriate input handling.

---

# 15. MULTIPLAYER AND SOCIAL GAMEPLAY

Support 1–12 players per server.

## Parties

Players should be able to:
- Invite other players.
- Accept invitations.
- Leave parties.
- View party members.
- Cooperate in dungeons.
- Receive appropriate shared quest progress.
- See party health indicators.

## Cooperative combat

Boss difficulty should adjust reasonably to active participants.

Prevent players from receiving repeated rewards through exploitative re-entry or duplicated completion messages.

Avoid damage attribution systems that unfairly exclude supporting classes.

## Multiplayer requirements

- Server-authoritative inventory and currencies.
- Secure ability activation.
- Validated interactions.
- Controlled network communication.
- No trust in client-submitted damage values.
- Sensible enemy ownership and targeting.
- Appropriate handling of disconnects.
- Correct character respawning.
- Clean event and object cleanup.
- Reliable state synchronisation.

Use Roblox's built-in communication and text filtering systems for any chat features.

Do not introduce an unmoderated custom messaging system.

---

# 16. SAVE DATA AND PERSISTENCE

Implement reliable persistence through DataStoreService.

Save:
- Character level.
- XP.
- Class.
- Character appearance selections.
- Equipment.
- Inventory.
- Gold.
- Skill allocations.
- Quest progress.
- Story decisions.
- Unlocked regions.
- Fast travel locations.
- Achievements.
- Crafting progression.
- Settings where appropriate.

## Requirements

- Use stable per-user identifiers.
- Keep data schemas versioned.
- Validate loaded data.
- Handle missing and malformed saves safely.
- Use protected data store operations.
- Handle transient errors with appropriate retries.
- Use UpdateAsync where concurrency-safe updates are necessary.
- Account for concurrent sessions and lost-update risks.
- Save periodically.
- Save during PlayerRemoving.
- Attempt saves during BindToClose.
- Avoid excessive write frequency.
- Prevent duplicated or corrupted inventory entries.
- Do not overwrite valid data with empty data after a failed load.
- Clearly inform players when persistence is unavailable.
- Test using separate development and production data stores.

Include data migration handling for future versions.

Do not claim data saving is reliable until save/load and failure cases have been tested.

---

# 17. SECURITY AND ANTI-EXPLOIT

Treat the client as untrusted.

The server must validate every action affecting:
- Combat.
- Damage.
- Currency.
- Inventory.
- Shops.
- Experience.
- Quest rewards.
- Equipment.
- Ability use.
- Crafting.
- Trading, if later implemented.

## Requirements

- Validate RemoteEvent arguments.
- Rate-limit remote requests.
- Check player permissions and current state.
- Confirm interaction distances.
- Enforce ability cooldowns on the server.
- Validate item ownership.
- Validate purchase prices.
- Prevent negative or non-finite currency values.
- Prevent duplicate reward claims.
- Prevent arbitrary item creation.
- Limit oversized or malformed inputs.
- Avoid exposing privileged logic to clients.
- Handle network ownership concerns for sensitive interactions.

Use a clear boundary between client presentation and server gameplay logic.

Avoid relying on client-side anti-cheat alone.

---

# 18. PERFORMANCE AND OPTIMISATION

Optimise for desktop, console, and lower-performance mobile devices.

## Requirements

- Enable and configure StreamingEnabled when appropriate.
- Test logic against streamed-out Workspace objects.
- Reduce unnecessary replication.
- Avoid expensive continuous loops.
- Avoid excessive physics simulation.
- Keep particle effects controlled.
- Use object pooling for frequently spawned effects where beneficial.
- Avoid unnecessary persistent connections.
- Disconnect event listeners during cleanup.
- Use low-cost distant environment details.
- Reuse environment assets.
- Limit unnecessary animated NPCs.
- Optimise enemy AI update frequency.
- Keep ReplicatedStorage appropriately lightweight.
- Store server-only content in ServerStorage or ServerScriptService.
- Avoid replicating large collections of objects without need.

Use the Roblox MicroProfiler and performance statistics to identify bottlenecks.

Optimise from measured performance rather than assuming every issue requires the same solution.

Provide graphics quality options that adjust cosmetic effects without changing gameplay balance.

---

# 19. ROBLOX POLICY AND SAFETY REQUIREMENTS

The experience must be designed to comply with applicable Roblox Community Standards, Terms of Use, Intellectual Property rules, Creator Store requirements, and publishing policies.

## Content

- No graphic gore.
- No realistic dismemberment.
- No hateful or discriminatory content.
- No sexual content.
- No real-world extremist promotion.
- No illegal or regulated goods promotion.
- No real-world weapon construction instructions.
- No unauthorised copyrighted characters, brands, music, artwork, or models.
- No misleading external-link promotions.
- No inappropriate user-generated messaging.
- No deceptive monetisation.

Use stylised fantasy combat, readable effects, and age-appropriate storytelling.

Complete the required Roblox content maturity and compliance questionnaire accurately before publishing.

## Assets

Only use:
- Original models.
- Properly licensed assets.
- Roblox assets with appropriate permissions.
- Approved and accessible audio.

Inspect third-party models for unexpected scripts.

## Monetisation

Design monetisation to be optional.

Potential purchases:
- Cosmetic outfits.
- Weapon appearance skins.
- Character visual effects.
- Non-gameplay emotes.
- Cosmetic mounts.
- Optional decorative housing items if housing is implemented.

Do not sell exclusive access to required story progression.

Avoid pay-to-win systems.

Do not implement paid random rewards in the initial build.

Any future monetisation must follow Roblox's applicable commerce and policy requirements.

## Player privacy

Do not collect unnecessary personal information or request passwords, real-world addresses, or off-platform contact details.

Use Roblox-provided account identifiers appropriately.

---

# 20. ROBLOX STUDIO PROJECT ARCHITECTURE

Create a well-organised project.

Use a structure resembling:

ReplicatedStorage
- Shared
  - Configuration
  - ItemDefinitions
  - EnemyDefinitions
  - QuestDefinitions
  - AbilityDefinitions
  - ProgressionDefinitions
  - Utility
- Remotes
  - CombatRequest
  - AbilityRequest
  - InteractionRequest
  - InventoryRequest
  - QuestRequest
  - PartyRequest
  - StateUpdate

ServerScriptService
- ServerBootstrap
- Services
  - PlayerDataService
  - CombatService
  - EnemyService
  - QuestService
  - InventoryService
  - EquipmentService
  - ProgressionService
  - CraftingService
  - DungeonService
  - PartyService
  - RewardService
  - WorldEventService

ServerStorage
- EnemyModels
- BossModels
- ItemModels
- DungeonTemplates
- ServerOnlyAssets

StarterPlayer
- StarterPlayerScripts
  - ClientBootstrap
  - CombatController
  - MovementController
  - CameraController
  - AudioController
  - UIController
  - QuestController
  - InputController

StarterGui
- MainHUD
- InventoryUI
- QuestUI
- SkillsUI
- MapUI
- SettingsUI
- MainMenuUI
- CharacterCreationUI

Workspace
- World
  - Hearthglen
  - Emberwood
  - CrystalFen
  - Stormreach
  - HollowSpire
- NPCs
- SpawnLocations
- Interactables
- EnemySpawns
- WorldEffects

SoundService
- Music
- Ambience
- Combat
- UI

Adapt this structure where necessary to conform to actual Roblox instance requirements and prevent misplaced LocalScripts.

Use modular Luau rather than large monolithic scripts.

Create reusable definitions for items, enemies, abilities, and quests instead of hardcoding every individual object separately.

---

# 21. DEVELOPMENT ORDER

Build the game in functional stages.

Each stage must leave the project in a working state.

## Phase 1 — Foundation

Create:
- Correct Studio folder structure.
- Module architecture.
- Server/client communication layer.
- Player spawn system.
- Basic third-person movement.
- Basic HUD.
- Initial persistence.
- Basic combat interactions.

**Success condition:** Players can join, move, attack a training dummy, and see their health and stats.

## Phase 2 — Playable Village

Create:
- Hearthglen terrain.
- Village buildings.
- Trees, foliage, and environment models.
- Starter NPCs.
- Dialogue interactions.
- Starter enemies.
- Starter equipment.
- Quest tracking.
- Initial sound integration.

**Success condition:** Players can explore an attractive village and complete their first quest.

## Phase 3 — Full First Region

Implement:
- Complete levels 1–10.
- Class abilities.
- Inventory.
- Equipment.
- Loot rewards.
- Questline for Act I.
- Briarwarden boss.
- Persistent quest and equipment progress.
- Functional music transitions.

**Success condition:** The entire first region is enjoyable from beginning to end, including the boss encounter.

## Phase 4 — Core RPG Expansion

Implement:
- Skill trees.
- Crafting.
- Additional enemy behaviours.
- Region unlock system.
- Party system.
- Dungeons.
- Expanded equipment tiers.

## Phase 5 — Remaining World

Build Emberwood, Crystal Fen, Stormreach, and Hollow Spire.

Populate each region with:
- Full environment models.
- Enemies.
- NPCs.
- Main quests.
- Side quests.
- Bosses.
- Collectibles.
- Music and sound effects.

## Phase 6 — Endgame

Add:
- Advanced dungeons.
- Optional boss variants.
- Achievements.
- Final story choices.
- Equipment upgrades.
- Repeatable challenges.

## Phase 7 — Polish and Testing

Test:
- Combat responsiveness.
- Mobile controls.
- Controller controls.
- UI scaling.
- Saving and loading.
- Enemy pathfinding.
- Boss mechanics.
- Party cooperation.
- Data corruption scenarios.
- RemoteEvent abuse.
- Respawn behaviour.
- Region transitions.
- Performance on mobile.
- Audio playback and permissions.

---

# 22. REQUIRED QUALITY ASSURANCE

Provide test cases for every major system.

At minimum, verify:

1. A new player spawns successfully.
2. A player can complete the tutorial.
3. All three classes can attack.
4. Abilities consume the correct resources.
5. Cooldowns cannot be bypassed through remote spam.
6. Enemies move, attack, and respawn.
7. XP is awarded correctly.
8. Levelling updates statistics.
9. Quest objectives progress correctly.
10. A completed quest cannot award rewards repeatedly.
11. Equipment changes derived statistics correctly.
12. Inventory persists after rejoining.
13. Currency purchases cannot create negative balances.
14. Items cannot be duplicated through simultaneous transactions.
15. Bosses change phases properly.
16. Multiple players can fight the same boss.
17. Party members can complete cooperative objectives.
18. Players can leave and rejoin without losing validated progress.
19. Region streaming does not break client scripts.
20. Mobile UI remains readable and usable.
21. Missing audio assets do not crash the experience.
22. Disconnects during data writes are handled safely.
23. Death and respawning do not create duplicate abilities or listeners.
24. All progression gates are obtainable through ordinary gameplay.
25. Server and client output do not contain persistent unexpected errors.

Clearly distinguish tests that were actually run from tests that still require manual verification.

---

# 23. DELIVERABLES

Provide actual implementation assets rather than only descriptive concepts.

Where supported, deliver:

1. A Roblox Studio project file.
2. Complete Luau scripts.
3. Reusable ModuleScripts.
4. Generated environment models.
5. NPC and enemy model definitions.
6. Procedural asset generation scripts.
7. UI elements and their logic.
8. Quest and dialogue data.
9. Item and ability definitions.
10. Animation setup specifications.
11. Audio event and asset manifests.
12. Data persistence implementation.
13. Installation instructions.
14. Testing instructions.
15. A list of outstanding assets, limitations, and unverified behaviour.

For every important script:
- Specify where it belongs in Roblox Studio.
- Use valid Luau syntax.
- Include necessary dependencies.
- Avoid undefined services or module references.
- Provide complete code rather than pseudocode.
- Include meaningful error handling.
- Avoid obsolete APIs where supported modern alternatives exist.

If generating a full Studio project is not possible, provide executable Roblox Studio Command Bar or plugin-compatible setup scripts to construct the project, alongside complete runtime scripts.

If the output is too large for one response, deliver it in logical phases without silently removing required systems.

---

# 24. NON-NEGOTIABLE QUALITY STANDARDS

The finished game must not be:

- An empty baseplate.
- A collection of unrelated scripts.
- A map consisting only of plain placeholder blocks.
- A combat system with no animations or feedback.
- An RPG with no meaningful progression.
- A quest system consisting only of static text.
- A menu that displays buttons with no functionality.
- A game that permanently loses player progress.
- A visually impressive demo that cannot be played.
- An unoptimised experience unusable on mobile.
- A game containing unauthorised third-party assets.

Every core system must be integrated and testable.

Prioritise **functional, polished systems over promises of completeness**.

Use strong engineering practices and reusable assets so the game can be expanded safely.

---

# 25. FINAL DEVELOPMENT DIRECTIVE

Begin by establishing a complete technical architecture and building the first genuinely playable version of Aetherfall.

The first deliverable must include:

- A generated Hearthglen environment with recognisable buildings, vegetation, and terrain.
- A player spawn and character class selection system.
- Three working classes with at least one usable basic attack and one class ability each.
- A functional combat system.
- Three enemy types with AI.
- Two fully functioning quests.
- One NPC dialogue interaction.
- XP and levelling.
- A basic inventory and equipment system.
- A working HUD.
- Server-validated gameplay actions.
- Basic persistent player data.
- Ambient music and combat audio integration with safe placeholders where genuine assets are unavailable.
- Proper folder and script organisation.
- Clear testing and installation instructions.

After this working foundation, continue expanding toward the complete five-region, level 60 RPG specification.

Do not skip implementation details.

Do not invent successful test results or claim assets exist when they have only been described.

When the generation environment supports direct Roblox Studio editing, create and configure the actual objects, scripts, and systems.

When direct Studio editing is unavailable, produce all necessary implementation code and precise construction instructions.

**The overriding goal is to deliver a real, cohesive, replayable Roblox RPG with a high-quality world, satisfying combat, story progression, detailed models, immersive audio, secure multiplayer systems, and long-term character development.**

Begin development with Phase 1 and progress through the first playable region, ensuring the game remains runnable and testable at every stage.