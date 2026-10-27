# Roadmap

Development is split into small milestones. Each milestone needs automated checks and Studio playtests before the next major expansion.

| Milestone | Scope | Status |
| --- | --- | --- |
| Equipment workshop | 39 items, procedural models, equip rules, inventory UI and blacksmith courtyard | Implemented; Studio playtests pending |
| Combat training | Held weapons, class attacks and skills, training dummies, resource HUD and server validation | Implemented; Studio playtests pending |
| Player progression | Versioned saves, inventory rewards, XP and levels | Implemented; live Studio save/load acceptance pending |
| Hearthglen village | NPC dialogue, three enemy families, two quests and silent audio hooks | Implemented; new Studio acceptance pending |
| Ancient grove | Briarwarden, rune discovery, first-shard quest and class rewards | Implemented; Studio encounter acceptance pending |
| Defensive combat | Directional dodge, shield guard and stamina-based sprint | Implemented; Studio controls/physics acceptance pending |
| Hearthglen Valley expansion | Remaining levels 1–10 quests, advanced abilities, loot and boss polish | Next |
| Core RPG systems | Crafting, upgrades, skill trees, parties and the first dungeon | Planned |
| World expansion | Emberwood, Crystal Fen, Stormreach and Hollow Spire, developed one region at a time | Planned |
| Endgame and polish | Boss variants, story choices, achievements, accessibility and performance | Planned |

## Equipment direction

Build choices include shields and foci, two-handed weapons, light mobility, heavy defence, precision accessories and bow/quiver loadouts. Ranger knives use melee attacks; bows use ranged shots. Shield Bash requires a shield. Sentinel melee weapons currently share the class combo.

Later updates will add regional materials and silhouettes, weapon-specific timing and reach, earned armour sets and passive effects. Legendary and mythic gear will arrive alongside the relevant regions. Selling, crafting and upgrades need persistent item identity and server-owned transactions first.

## Next acceptance checks

- Complete the new defensive-controls and grove Studio checklists; earlier builds have had initial smoke testing.
- Verify save/load, concurrent sessions and failed-load handling before adding persistent rewards.
- Ensure rejoining preserves validated inventory and progression without duplicate rewards.

The current build uses schema version 3 and migrates the previous village and progression saves. Ordinary enemy families share the first melee AI. Briarwarden has a separate sweep/root/core encounter; a minion phase, full boss animations, advanced enemy patterns and full levels 1–10 content remain future work. Audio hooks are silent until permitted asset IDs are configured.

Defensive combat reuses the existing stamina balance and saved schema. These controls add no persistent stance or movement data. Full body dodge/block animations, broader ability trees and final boss balance are still planned.
