# Small installments

The [master brief](MASTER_BRIEF.md) is the destination. Its first-playable requirements are split below to keep changes testable. Each installment should pass automated and Studio acceptance checks before expansion.

| Installment | Focus | Acceptance condition |
| --- | --- | --- |
| **1 — Implemented; Studio validation pending** | Equipment catalogue, models, equip rules, inspection UI, blacksmith courtyard | All 36 items inspectable; class loadouts valid; gear changes totals; invalid actions preserve state |
| **2 — Implemented; Studio validation pending** | Weapon attachments, class input, three basic attacks and one skill each, training dummies, health/resources HUD | Automated rules/construction pass; live class attacks, server spatial checks, input and respawn acceptance remain for Studio |
| 3 | Versioned persistence, validated inventory rewards, XP and levels | Rejoin restores state; failed loads cannot overwrite saves; concurrent writes and duplicate rewards tested |
| 4 | Hearthglen village, dialogue, three enemy families and AI, two quests, audio manifest and safe asset slots | Brief's first playable loop: explore, talk, fight, progress, equip, save; solo and two-player checks pass |
| 5 | Full levels 1–10 region, abilities, loot, quest progression, Briarwarden | First region complete end to end; earned gear supports distinct builds |
| 6 | Crafting/upgrades, skill trees, parties and first dungeon | Cooperative rewards, transactions and progression gates verified |
| 7+ | Emberwood, Crystal Fen, Stormreach and Hollow Spire, one region per installment | Each region receives exploration, quest, boss and audio checks before the next |
| Later | Endgame variants, story choices, achievements, measured performance/accessibility polish | Full QA matrix, mobile/console playtests and save-failure scenarios complete |

## Equipment variety

Installment 1 distinguishes shield/focus builds, two-handed weapons, light mobility, heavy defence, precision accessories and bow/quiver loadouts. Installment 2 attaches held gear and connects statistics to basic combat. Ranger knives use a melee action; bows use a shot. Shield Bash requires a shield. The Sentinel's melee families currently share the class combo rather than having separate advanced movesets.

Future installments add regional silhouettes and palettes, distinct attack timing/reach, earned sets with alternatives to random grinding, and tested passive effects. Add legendary/mythic gear when its regions/mechanics exist; all six rarity labels are already reserved. Save item identity before introducing selling/crafting/upgrades, and keep transactions server-owned.

Do not generate all five regions before testing the core loop. No full-RPG completion is claimed by these installments. Complete the pending Studio acceptance checks before expanding to persistence and reward transactions.
