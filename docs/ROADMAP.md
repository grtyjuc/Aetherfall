# Roadmap

Development is split into small milestones. Each milestone needs automated checks and Studio playtests before the next major expansion.

| Milestone | Scope | Status |
| --- | --- | --- |
| Equipment workshop | 36 items, procedural models, equip rules, inventory UI and blacksmith courtyard | Implemented; Studio playtests pending |
| Combat training | Held weapons, class attacks and skills, training dummies, resource HUD and server validation | Implemented; Studio playtests pending |
| Player progression | Versioned saves, inventory rewards, XP and levels | Implemented; live Studio save/load acceptance pending |
| Hearthglen village | NPC dialogue, three enemy families, two quests and silent audio hooks | Implemented; new Studio acceptance pending |
| Hearthglen Valley | Levels 1–10, expanded abilities, loot, quest progression and Briarwarden | Next |
| Core RPG systems | Crafting, upgrades, skill trees, parties and the first dungeon | Planned |
| World expansion | Emberwood, Crystal Fen, Stormreach and Hollow Spire, developed one region at a time | Planned |
| Endgame and polish | Boss variants, story choices, achievements, accessibility and performance | Planned |

## Equipment direction

Build choices include shields and foci, two-handed weapons, light mobility, heavy defence, precision accessories and bow/quiver loadouts. Ranger knives use melee attacks; bows use ranged shots. Shield Bash requires a shield. Sentinel melee weapons currently share the class combo.

Later updates will add regional materials and silhouettes, weapon-specific timing and reach, earned armour sets and passive effects. Legendary and mythic gear will arrive alongside the relevant regions. Selling, crafting and upgrades need persistent item identity and server-owned transactions first.

## Next acceptance checks

- Complete the new village/quest/enemy Studio checklist; earlier builds have had initial smoke testing.
- Verify save/load, concurrent sessions and failed-load handling before adding persistent rewards.
- Ensure rejoining preserves validated inventory and progression without duplicate rewards.

The current village uses schema version 2, with migration from the previous progression build. Enemy families have distinct models and balance but share the first melee AI; advanced patterns, bosses and full body animations remain future work. Audio hooks are silent until permitted asset IDs are configured.
