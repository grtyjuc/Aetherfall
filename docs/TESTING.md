# Installments 1–2 checks

## Automated checks actually run

Run `python3 scripts/check.py` from the repository root. Tool pins are in `scripts/setup_tools.py`.

- Twelve runtime sources compile. This checks syntax, not Roblox API types.
- 24 equipment tests: all class starters; ownership/class/level/slot rejection; malformed inputs; exact stat changes/removal; repeated equip; two-handed conflicts; bow/quiver exceptions; accessory movement and uniqueness; independent snapshots; inventory preservation during mixed actions.
- All 36 models construct in Lune's Roblox data model, covering 19 silhouettes. Geometry must be finite and positive, with a Handle PrimaryPart, anchored/noninteractive parts, at most 30 parts/model, and no scripts/external assets. Invalid definitions fail explicitly.
- Workshop tests verify a part budget below 400, six displays, finite transforms, spawn/prompt settings, preserved existing objects, idempotent construction and safe reserved-name conflict handling.
- Rojo builds the `.rbxl`. A separate test deserializes it and checks actual script classes, sources, service locations and streaming enabled.
- 31 pure combat-rule tests cover all class basics/skills, knife versus bow, exact costs, cooldown boundaries/spam, combo progression/reset, dead/unequipped rejection, shield requirements, target/range/facing/line-of-sight flags, regeneration, malformed times and deterministic damage/critical rolls. Geometry flags in this suite are supplied by the test, not live physics.
- 16 tests exercise the actual CombatService request handlers with mocked clocks, network signals and physics queries. They cover ignoring injected damage values, registered targets, range/facing/LOS rejection, cooldown and request spam, class/equipment state preservation, no healing/revival from gear, dagger melee, per-player resource isolation/shared target health, area damage, target recovery, clear/blocked/ungrounded dash behavior, malformed requests and lifecycle cleanup. Raycast/Blockcast outcomes are mocked; this does not prove live wall collision behavior.
- Attachment construction verifies R6/R15, every weapon, quivers, unanchored massless welded parts, repeated replacement, cleanup and scaled R6 hand offsets. These checks do not simulate character physics.
- Training-ground construction verifies three unique server-readable targets, finite/queryable hitboxes, health labels, repeatability and nearby targets suitable for Flame Burst. World geometry totals 269 static parts (187 workshop + 82 training), excluding character attachments and transient effects.

## Manual Studio acceptance — NOT RUN in cloud

Open the built place and use **Play**, then **Server & Clients** with two clients. These remain pending until performed in Studio.

| Check | Expected result |
| --- | --- |
| Join/respawn | Spawn above path; exactly one UI/inventory; no persistent Output errors |
| Inspect all gear | Text, materials, proportions and camera framing correct for all 36 items |
| Class starters | Switching restores owned compatible gear without granting extra copies |
| Equip/remove | Exact displayed modifiers apply/remove once; repeated equip never stacks |
| Shield/greatsword | Greatsword clears shield; shield cannot equip while it is held |
| Ranger quiver | Bow/crossbow accept quiver; class change clears incompatible gear |
| Accessory 2 replacement | Select new accessory, target slot 2, equip; slot 1 unchanged |
| Invalid request | Client `EquipmentRequest:InvokeServer("Equip", "not_owned", "MainHand")` fails and changes no state |
| Malformed/spam | Table/numeric identifiers and excessive requests fail without errors or inventory changes |
| Player isolation | One player's equip/class actions never change the other's state |
| Anvil/controls | I/controller Y/touch Gear/anvil reopen UI; movement/camera work after closing |
| Phone/landscape | Readable text; both panels scroll; accessory targets and all eight slots reachable |
| Gamepad | Selection reaches every control and scrollable section without trapped focus |
| World/streaming | Roofs/signs/models render; path/spawn collisions work; inventory survives world streaming |
| Session reset | Stop/Play resets sandbox; UI says progress is not saved |
| Production guard | Separate private test publication grants no sandbox inventory/remotes outside Studio |
| Each class | Sentinel combo/Shield Bash, Spellweaver Bolt/Burst, Ranger Shot/Quickstep work against registered dummies |
| Knife versus bow | Ranger knife attacks within six studs only; bow fires ranged; HUD names update |
| Shield restriction | Removing shield makes Shield Bash reject without spending stamina or starting cooldown |
| Attack resources | Exact mana/stamina costs and displayed cooldowns; idle regen caps at 100 |
| Spatial validation | Behind/out-of-range/obstructed melee rejects; ranged rejects walls; no player damage |
| Multi-target spell | Flame Burst hits both close left targets if visible; it cannot hit a target behind cover |
| Quickstep | Moves no more than ten studs; full-body cast prevents wall clipping; rejects unsafe/ungrounded paths without spending |
| Cooldown bypass | Equip, unequip and class changes preserve active cooldowns/resources; death does not reset cooldowns |
| Actual gear effects | Damage matches displayed Attack/Magic; health/speed reflect gear; removing/re-equipping health gear never heals or revives |
| Dummy recovery | Zero HP blocks repeat damage; recovers once after four seconds; no rewards |
| Multiplayer | Clients share dummy health and see approved feedback; cooldown/resources remain per player |
| Respawn cleanup | Held gear appears once, HUD updates, old Humanoid listeners stop, no stale-grip errors |
| Inventory input | Clicking inventory controls never attacks; combat HUD/touch buttons hide while armoury is open |
| Reduced motion | Stops grip swings and moving/burst effects; damage text and all gameplay remain available |
| Character rigs | R6/R15 and scaled avatars hold gear at the hand/forearm/back without anchoring, flinging or collisions |

All live Studio tests above remain **unrun** in the cloud, even when the corresponding pure or mocked tests pass. Full body animations, enemy retaliation/AI, dodging invulnerability, audio, DataStore, quests and progression are not implemented yet.
