# Aetherfall: Shards of the Hollow Star

A fantasy action RPG for Roblox, set in the world of Hearthglen and the shattered Hollow Star.

**Current build: equipment and combat training.** This is a Studio-only development sandbox. All 36 items are provided in a level-10, session-only inventory. Leaving the session resets everything. The server intentionally refuses to start this sandbox outside Studio.

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
- Three stationary training dummies with shared health, multi-target spell testing, and automatic four-second recovery. No PvP, XP, or loot is awarded.
- Health/mana/stamina HUD, server-enforced costs/cooldowns/range/facing/line of sight, target selection, reduced-motion control, and original weapon motion/hit effects.

Equipped stats now affect damage, maximum health and walking speed. Equipment changes never heal or revive; class/equipment changes preserve resources and cooldowns. Shield Bash requires a shield, so two-handed Sentinel builds must switch back to use it. Quickstep moves at most 10 studs along a server-checked clear grounded path. Ranged damage resolves immediately after validation; projectile travel is cosmetic. Weapon-grip motion is procedural, not a full body animation set. Sell values are data only. Selling, crafting, upgrades, enemy AI, loot, quests and saving remain in the [roadmap](docs/ROADMAP.md).

## Build and open in Studio

Use **Rojo 7.7.1**, **Lune 0.11.1**, and Python 3. On Linux x86_64:

```sh
git clone https://github.com/grtyjuc/Roblox-game-V1.git
cd Roblox-game-V1
python3 scripts/setup_tools.py
python3 scripts/check.py
```

The installer downloads pinned official GitHub releases into ignored `.tools/` and verifies SHA256 checksums. It makes no global changes. Checks compile Luau, test rules/models/world, build the place, and verify the artifact. Both commands are repeatable.

On Windows/macOS, install matching official releases from [Rojo](https://github.com/rojo-rbx/rojo/releases/tag/v7.7.1) and [Lune](https://github.com/lune-org/lune/releases/tag/v0.11.1) on `PATH` (or in `.tools/`), then run `python scripts/check.py` from the repository root. The setup script supports Linux x86_64.

Open **`build/Aetherfall-Step-2.rbxl`** with Roblox Studio, then press **Play**. The world generates when the server starts. No Command Bar pasting, plugins, DataStore access, keys, or uploaded assets are required. Build without running tests:

```sh
.tools/rojo build default.project.json --output build/Aetherfall-Step-2.rbxl
```

For live syncing, use the matching official Rojo Studio plugin and `.tools/rojo serve default.project.json`. Opening the built place directly needs no plugin. Save a copy of manual Studio edits before rebuilding/syncing; edit Luau in `src/` to retain changes.

## Try it

1. Choose a class along the top. Its owned starter equipment is restored.
2. Select inventory gear and inspect its model, requirements and modifiers.
3. Choose **Equip**. The slot and totals change; incompatible gear returns a server error without changing the loadout.
4. For accessories, choose **Target: Acc. 1** or **Target: Acc. 2** in the detail panel, then equip. Occupied slots can be replaced independently.
5. Select an equipped slot and choose **Remove**. A greatsword clears a shield; bows/crossbows can retain a quiver.
6. Close the panel and walk around. Reopen with **I**, controller **Y**, touch **Gear**, or the anvil prompt. Scroll details to reach every slot on small screens.
7. Follow the side paths around the noticeboard to the straw dummies. Look toward a dummy to select it, or cycle with **T / R3**. Move close and face it for melee attacks.
8. Attack with **left click / R2 / touch Attack**; use your class skill with **1 / X / touch Skill**. Watch resources, cooldowns and dummy health. The two left dummies demonstrate Flame Burst's radius.
9. Try Ranger's bow versus knife, wand/focus versus staff, shield versus greatsword, and the HUD's reduced-motion setting. Dummies do not retaliate yet.

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

Clients submit action names, owned instance IDs and slot/class choices. The server calculates changes and statistics; shared rules do not grant client authority. Catalog IDs are stable; session instance IDs such as `gear_000001` are unique only within a player's current profile. Future persistence must preserve instance identity.

Combat requests send only an action and registered target ID; the server derives class, weapon, statistics, costs, cooldowns, spatial checks, critical rolls and damage. Attacks cannot target players or arbitrary Workspace objects. This is not a full movement anti-cheat system; checks use the character's server-observed position. World streaming never supplies combat authority to the client.

## Validation and limits

`python3 scripts/check.py` checks all 12 runtime sources, 24 equipment tests, 31 combat-rule tests, 16 mocked service-handler tests, all 36 procedural models, R6/R15 attachments, workshop/training construction and the generated place. These use Lune's data model and mocked service/physics queries, not the live Roblox engine. See [test coverage and pending Studio checks](docs/TESTING.md).

Automated checks pass. **Studio playtests are still pending**, including multiplayer, UI rendering, touch/controller navigation, streaming and collisions. See the [manual checklist](docs/TESTING.md).
