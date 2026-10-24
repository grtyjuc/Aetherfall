# Aetherfall: Shards of the Hollow Star

A fantasy action RPG for Roblox, set in the world of Hearthglen and the shattered Hollow Star.

**Current build: Hearthglen village and its first quests.** New characters begin at level 1 with class starter gear. Complete training, meet the villagers and fight creatures in the fields to earn XP, gold and equipment. Saving uses an isolated development DataStore when Studio API access is available; otherwise the HUD clearly shows session-only mode. This development build runs in Studio, not published servers.

## Included now

- 14 weapons: swords, axe, mace, spear, greatsword, dagger, bows, crossbow, staves, and wands.
- 4 off-hands: shield, magical focus, quiver, and lantern.
- 12 armour pieces: militia plate, scout leather, and acolyte cloth; four slots per set.
- 6 accessories, with two independently selectable slots.
- Sentinel, Spellweaver, and Ranger loadouts; class/level requirements; rarity labels; additive stat tradeoffs.
- Server-owned item instances, validated equip/unequip, two-handed conflicts, bow/quiver compatibility, unique accessories, and request rate limiting.
- Category filters, level/name sorting, item inspection, original 3D previews, and derived-stat totals.
- A generated timber blacksmith workshop, forge, anvil, gardens, trees, and six displays. No external asset permissions are needed.
- R6/R15 held weapon and off-hand models, plus back-mounted quivers. Armour/accessory visuals remain inspection-only.
- Sentinel's three-hit Steel Slash combo and Shield Bash; Spellweaver's Arcane Bolt and Flame Burst; Ranger's Piercing Shot (Knife Cut with a dagger) and Quickstep.
- Three stationary training dummies with shared health, multi-target spell testing, and automatic four-second recovery. Training goals award XP and gold once; repeated dummy defeats do not generate rewards. No PvP.
- A connected village with five buildings, paths, gardens, fields, Elder Rowan, Smith Tessa and a rest well.
- Four roaming creatures across Meadow Slime, Wild Boar and Thornling families, with pursuit, readable attack windups, damage, leash recovery and respawn.
- Two quests: **A Stranger in Hearthglen** and **Trouble at the Fields**, with NPC dialogue, objectives and persistent once-only rewards.
- Repeatable creature XP/gold, shared defeat credit for recent nearby contributors, and a bounded generation guard against duplicate kill rewards.
- Health/mana/stamina HUD, server-enforced costs/cooldowns/range/facing/line of sight, target selection, reduced-motion control, and original weapon motion/hit effects.
- Level/XP/gold and objective HUD, Warden Mira training rewards, and level-based stat growth.
- Validated, versioned saves with session leases, autosave, bounded retries, final-save attempts and visible save status.

Equipped stats now affect damage, maximum health and walking speed. Equipment changes never heal or revive; class/equipment changes preserve resources and cooldowns. Shield Bash requires a shield, so two-handed Sentinel builds must switch back to use it. Quickstep moves at most 10 studs along a server-checked clear grounded path. Ranged damage resolves immediately after validation; projectile travel is cosmetic. Weapon-grip motion is procedural, not a full body animation set. Sell values are data only. Shield Bash also interrupts enemy attacks for one second. Village rest points restore health without reviving defeated characters. Selling, crafting, upgrades, random loot, bosses and the remaining story remain in the [roadmap](docs/ROADMAP.md). The three early enemy families currently share a simple melee state machine with different health, damage and speed.

## Open the ready-made Studio file

Download [Aetherfall.rbxl](studio/Aetherfall.rbxl) using GitHub's **Download raw file** button. In Roblox Studio, choose **File → Open from File**, select it, then press **Play**. The workshop and training grounds generate at startup. No plugins are required. Saving needs the separate Studio setup below; gameplay still works without it. The [previous progression build](studio/Aetherfall-Step-3.rbxl) and [all-equipment sandbox](studio/Aetherfall-Step-2.rbxl) remain available separately. New saves migrate to schema version 2; the older progression build cannot read upgraded saves.

## Build and open in Studio

Use **Rojo 7.7.1**, **Lune 0.11.1**, and Python 3. On Linux x86_64:

```sh
git clone https://github.com/grtyjuc/Aetherfall.git
cd Aetherfall
python3 scripts/setup_tools.py
python3 scripts/check.py
```

The installer downloads pinned official GitHub releases into ignored `.tools/` and verifies SHA256 checksums. It makes no global changes. Checks compile Luau, test rules/models/world, build the place, and verify the artifact. Both commands are repeatable.

On Windows/macOS, install matching official releases from [Rojo](https://github.com/rojo-rbx/rojo/releases/tag/v7.7.1) and [Lune](https://github.com/lune-org/lune/releases/tag/v0.11.1) on `PATH` (or in `.tools/`), then run `python scripts/check.py` from the repository root. The setup script supports Linux x86_64.

Open **`build/Aetherfall-Step-4.rbxl`** with Roblox Studio, then press **Play**. The world generates when the server starts. No Command Bar pasting, plugins, keys, or uploaded assets are required for session-only play. Build without running tests:

```sh
.tools/rojo build default.project.json --output build/Aetherfall-Step-4.rbxl
```

For live syncing, use the matching official Rojo Studio plugin and `.tools/rojo serve default.project.json`. Opening the built place directly needs no plugin. Save a copy of manual Studio edits before rebuilding/syncing; edit Luau in `src/` to retain changes.

## Try it

1. Wait for your character to load, then choose a class along the top. Missing class starter items are granted once; switching does not reset XP, gold or earned rewards.
2. Select inventory gear and inspect its model, requirements and modifiers.
3. Choose **Equip**. The slot and totals change; incompatible gear returns a server error without changing the loadout.
4. For accessories, choose **Target: Acc. 1** or **Target: Acc. 2** in the detail panel, then equip. Occupied slots can be replaced independently.
5. Select an equipped slot and choose **Remove**. A greatsword clears a shield; bows/crossbows can retain a quiver.
6. Close the panel and walk around. Reopen with **I**, controller **Y**, touch **Gear**, or the anvil prompt. Scroll details to reach every slot on small screens.
7. Follow the side paths around the noticeboard to the straw dummies. Look toward a dummy to select it, or cycle with **T / R3**. Move close and face it for melee attacks.
8. Attack with **left click / R2 / touch Attack**; use your class skill with **1 / X / touch Skill**. Watch resources, cooldowns and dummy health. The two left dummies demonstrate Flame Burst's radius.
9. Land three basic attacks and use one class skill. Return to **Warden Mira** by the left approach path for the final training reward. The full tutorial earns 500 XP, 90 gold and one class-specific weapon. Partial basic-hit progress resets on rejoin; completed reward stages persist when saving is available. Dummies do not retaliate.
10. Follow the path around the right side of the workshop into Hearthglen. Talk to **Elder Rowan** in the plaza, meet **Smith Tessa**, then return to Rowan to complete the introduction.
11. Speak to Rowan again to accept **Trouble at the Fields**. Follow the east road beyond the village fence, defeat four creatures, and return for the quest reward. Read the attack warning and step away before impact. Ranger Quickstep can avoid attacks; Sentinel Shield Bash interrupts them.
12. Rest at the village well to restore health. Its server-enforced cooldown is ten seconds. Attacks against creatures require entering their field encounter area; they cannot damage villagers or players in the safe village.
13. More advanced items remain in the catalogue for future loot. Use the previous sandbox to inspect all 36 items; they are no longer all granted to new progression characters.

## Test saving in Studio

1. Open the place and publish it to a **private test experience** you own.
2. In Studio, open **Game Settings → Security**, enable **Studio Access to API Services**, and save the setting.
3. Stop and start Play again. The save label should change from session-only to a loaded persistent session.
4. Earn a reward or change equipment, wait for a confirmed save, stop Play, then rejoin. Check the level, XP, gold, inventory, equipped slots and claimed rewards.

The DataStore is `Aetherfall_Development_v1`, keyed by Roblox user ID. Autosave runs every 60 seconds; sessions renew a 180-second ownership lease. Exit and shutdown attempt a final save with bounded retries. A failed load never enables writes; session-only fallback is never uploaded later. Rejoin after changing API settings. Fake players with nonpositive Studio test IDs always use session-only mode.

A locked, corrupted, unknown-version or lost-lease character is paused rather than replaced. Wait for the previous session to release its lease or expire before rejoining. Failed saves remain pending and are retried; the UI does not report success until confirmed. Abrupt server termination can lose changes since the last confirmed save. Schema version 2 adds quest progress and preserves earlier version-one inventory, XP, gold and rewards during migration. Production saving is not enabled in this build, and live Roblox durability still needs the [save/load acceptance checks](docs/TESTING.md).

## Audio setup

The audio controller includes separate Music, Ambience, Combat and UI groups, region fades, and hooks for hits, enemy windups and quest events. **No audio assets are bundled, so the build is silent by default.** Set accessible, permitted `rbxassetid://...` IDs in `src/shared/AudioManifest.luau` and rebuild to test playback. Empty IDs make no audio requests and do not block gameplay.

Volumes are controlled through the local player attributes `AetherfallMusicVolume`, `AetherfallAmbienceVolume`, `AetherfallCombatVolume` and `AetherfallUIVolume`, each from 0 to 1. A settings-menu interface is planned. Playback and asset permissions still need Studio testing.

## Architecture

`default.project.json` maps source to actual Roblox services:

| Source | Studio location | Responsibility |
| --- | --- | --- |
| `src/shared/EquipmentCatalog.luau` | ReplicatedStorage.Shared | Immutable item definitions |
| `src/shared/EquipmentRules.luau` | ReplicatedStorage.Shared | Pure transactions and stats |
| `src/shared/EquipmentModels.luau` | ReplicatedStorage.Shared | Original procedural previews |
| `src/server/WorkshopWorld.luau` | ServerScriptService.Workshop | World construction |
| `src/server/Workshop.server.luau` | ServerScriptService.Workshop | Session ownership and remotes |
| `src/client/Workshop.client.luau` | StarterPlayer.StarterPlayerScripts.EquipmentWorkshop | Inventory UI and inspection |
| `src/shared/CombatConfig.luau` | ReplicatedStorage.Shared | Class/weapon actions and initial balance |
| `src/shared/CombatRules.luau` | ReplicatedStorage.Shared | Atomic action, resource, cooldown and damage rules |
| `src/server/EquipmentVisuals.luau` | ServerScriptService.Workshop | Safe held-gear attachments and cleanup |
| `src/server/TrainingWorld.luau` | ServerScriptService.Workshop | Original training targets and their metadata |
| `src/server/CombatService.luau` | ServerScriptService.Workshop | Target whitelist, spatial checks, damage and respawn lifecycle |
| `src/client/Combat.client.luau` | StarterPlayer.StarterPlayerScripts.EquipmentWorkshop | HUD, input, local target selection and approved feedback |
| `src/shared/ProgressionRules.luau` | ReplicatedStorage.Shared | XP, levels, currency and atomic rewards |
| `src/server/PlayerSchema.luau` | ServerScriptService.Workshop | Versioned bounded save validation and migration |
| `src/server/SessionStore.luau` | ServerScriptService.Workshop | UpdateAsync ownership leases and confirmed writes |
| `src/server/PlayerDataService.luau` | ServerScriptService.Workshop | Loading, autosave, lifecycle and save status |
| `src/server/TrainingRewards.luau` | ServerScriptService.Workshop | Mentor model, objective progress and server-only rewards |
| `src/client/Progression.client.luau` | StarterPlayer.StarterPlayerScripts.EquipmentWorkshop | XP, objectives, gold and save-state HUD |
| `src/server/VillageWorld.luau` | ServerScriptService.Workshop | Village, quest NPCs, rest point and spawn markers |
| `src/shared/QuestRules.luau` | ReplicatedStorage.Shared | Quest progression and once-only reward transactions |
| `src/server/QuestService.luau` | ServerScriptService.Workshop | Validated NPC interactions and quest state |
| `src/shared/EnemyDefinitions.luau` | ReplicatedStorage.Shared | Server combat/reward balance |
| `src/server/EnemyService.luau` | ServerScriptService.Workshop | Enemy models, AI, telegraphs, credit and respawn |
| `src/server/EnemyRewards.luau` | ServerScriptService.Workshop | Bounded per-generation XP/gold rewards |
| `src/server/RestService.luau` | ServerScriptService.Workshop | Safe rest validation and health restoration |
| `src/client/Quest.client.luau` | StarterPlayer.StarterPlayerScripts.EquipmentWorkshop | Quest tracker and dialogue |
| `src/shared/AudioManifest.luau` | ReplicatedStorage.Shared | Optional audio event configuration |
| `src/client/Audio.client.luau` | StarterPlayer.StarterPlayerScripts.EquipmentWorkshop | Sound groups and event/region hooks |

Clients submit action names, owned instance IDs and slot/class choices. The server calculates changes and statistics; shared rules do not grant client authority. Catalog IDs are stable; item instance IDs such as `gear_000001` are unique within a player profile and retain their identity across saves.

Combat requests send only an action and registered target ID; the server derives class, weapon, statistics, costs, cooldowns, spatial checks, critical rolls and damage. Attacks cannot target players or arbitrary Workspace objects. This is not a full movement anti-cheat system; checks use the character's server-observed position. World streaming never supplies combat authority to the client.

## Validation and limits

`python3 scripts/check.py` checks all 28 runtime sources, 255 rule/service cases, all 36 procedural models, R6/R15 attachments, village/rest/audio construction and the generated place. It also refreshes the downloadable `studio/Aetherfall.rbxl`. Persistence and service tests use mocked DataStore, clocks, network and physics queries. They do not run the Roblox engine or prove live save reliability. See [test coverage and pending Studio checks](docs/TESTING.md).

Automated checks pass. **Detailed village Studio playtests are still pending**, including enemy movement, quest completion, multiplayer, UI rendering, touch/controller navigation, streaming and collisions. See the [manual checklist](docs/TESTING.md).
