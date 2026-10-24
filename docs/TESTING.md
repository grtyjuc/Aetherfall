# Testing

## Automated checks actually run

Run `python3 scripts/check.py` from the repository root. Tool pins are in `scripts/setup_tools.py`.

- Twenty-eight runtime sources compile. This checks syntax, not Roblox API types.
- 24 equipment tests: all class starters; ownership/class/level/slot rejection; malformed inputs; exact stat changes/removal; repeated equip; two-handed conflicts; bow/quiver exceptions; accessory movement and uniqueness; independent snapshots; inventory preservation during mixed actions.
- All 36 models construct in Lune's Roblox data model, covering 19 silhouettes. Geometry must be finite and positive, with a Handle PrimaryPart, anchored/noninteractive parts, at most 30 parts/model, and no scripts/external assets. Invalid definitions fail explicitly.
- Workshop tests verify a part budget below 400, six displays, finite transforms, spawn/prompt settings, preserved existing objects, idempotent construction and safe reserved-name conflict handling.
- Rojo builds the `.rbxl`. A separate test deserializes it and checks actual script classes, sources, service locations and streaming enabled.
- 31 pure combat-rule tests cover all class basics/skills, knife versus bow, exact costs, cooldown boundaries/spam, combo progression/reset, dead/unequipped rejection, shield requirements, target/range/facing/line-of-sight flags, regeneration, malformed times and deterministic damage/critical rolls. Geometry flags in this suite are supplied by the test, not live physics.
- 21 tests exercise the actual CombatService request handlers with mocked clocks, network signals and physics queries. They cover ignoring injected damage values, registered targets, range/facing/LOS rejection, cooldown and request spam, class/equipment state preservation, no healing/revival from gear, dagger melee, per-player resource isolation/shared target health, area damage, target recovery, clear/blocked/ungrounded dash behavior, malformed requests and lifecycle cleanup. Raycast/Blockcast outcomes are mocked; this does not prove live wall collision behavior.
- Attachment construction verifies R6/R15, every weapon, quivers, unanchored massless welded parts, repeated replacement, cleanup and scaled R6 hand offsets. These checks do not simulate character physics.
- Training-ground construction verifies three unique server-readable targets, finite/queryable hitboxes, health labels, repeatability and nearby targets suitable for Flame Burst. The workshop/training/mentor geometry totals 284 static parts; the village adds 302. Enemies, character attachments and transient effects are checked separately.

- 21 progression-rule tests cover XP thresholds, multiple levels/cap, stat growth, atomic once-only rewards, currency/inventory limits and class starter grants.
- 27 schema tests validate round trips, independent copies, limits, corrupt/future records, identity collisions, cycles, version-zero migration and version-one upgrade to quest schema version 2.
- 27 session-store tests exercise session leases, expiry/takeover, retried callbacks, transient errors, lost responses after commit, stable snapshots, competing writes and failed final saves.
- 20 PlayerDataService tests cover safe loading/fallback, truthful status, autosave, newer mutations during yielding saves, departure/shutdown cleanup, retained final-save failures, retry spacing and negative Studio IDs.
- 14 training-reward tests cover milestone uniqueness, all class rewards, persisted claims, partial session progress, proximity/alive checks, invalid client requests, loading/lost sessions and the original mentor model.

- 22 quest-rule tests cover both quest flows, NPC visit order, accepted defeat counters, bounded state, once-only rewards and claim/state consistency.
- 15 QuestService tests exercise prompt distance/alive/save-owner checks, dialogue, Sync-only requests, rate limiting, persistence and player isolation.
- 17 EnemyService tests exercise model construction, state transitions, telegraphs, impact checks, sanctuary/leash limits, ranged aggro, stun interruption, contributor credit, query flags and generation-based respawn with mocked physics.
- 16 enemy-reward tests verify server amounts, per-spawn generation credit, stale replay rejection, player isolation, currency caps, stat growth and bounded memory without filling permanent reward history.
- Village construction checks verify 302 finite anchored parts, NPC/rest prompt metadata, four spawn markers across three families, preservation and repeatability.
- Rest-point checks cover proximity, alive state, save ownership, cooldown and cleanup. Audio manifest checks cover six silent events, group/volume/rolloff metadata and accepted sound ID formats; no playback is simulated.

## Pending Studio playtests

Open the built place and use **Play**, then **Server & Clients** with two clients. These remain pending until performed in Studio.

| Check | Expected result |
| --- | --- |
| Join/respawn | Spawn above path; exactly one UI/inventory; no persistent Output errors |
| Inspect gear | Owned starter/reward gear renders correctly; the previous sandbox covers all 36 catalogue models |
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
| Session-only fallback | With API access off, starter progress resets on rejoin and is never written later; UI clearly says not saved |
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
| Dummy recovery | Zero HP blocks repeat damage and recovers after four seconds; no repeatable XP or loot from defeats |
| Multiplayer | Clients share dummy health and see approved feedback; cooldown/resources remain per player |
| Respawn cleanup | Held gear appears once, HUD updates, old Humanoid listeners stop, no stale-grip errors |
| Inventory input | Clicking inventory controls never attacks; combat HUD/touch buttons hide while armoury is open |
| Reduced motion | Stops grip swings and moving/burst effects; damage text and all gameplay remain available |
| Character rigs | R6/R15 and scaled avatars hold gear at the hand/forearm/back without anchoring, flinging or collisions |

The Studio playtests above have **not been run**. Pure and mocked tests do not replace live playtesting. Full body animations, dodge invulnerability and bosses are not implemented yet. The new village, enemies and quests require the additional Studio checks below. Audio hooks have no assets configured. Live DataStore persistence has not been exercised here.

## Pending save/load acceptance

Use a private published test experience with Studio API access enabled. These tests have **not** been run against Roblox DataStoreService.

| Check | Expected result |
| --- | --- |
| New account | Level 1, zero XP/gold, valid starter gear; save status clearly distinguishes loading, persistent and session-only |
| First tutorial | Three basics grant 100 XP/10 gold once; one skill grants 150 XP/20 gold once; nearby Mira grants 250 XP/60 gold and class gear once |
| Repeat/rejoin | Repeated attacks, skills and mentor interactions never repeat claimed rewards; completed claims survive rejoin |
| Partial objective | Unfinished basic-hit counter resets on rejoin; earned stage claims remain |
| Class switching | Missing class starters appear once, levels/XP/gold remain, inventory IDs remain unique |
| Save confirmation | Level, XP, gold, class, inventory and equipped slots survive after a confirmed autosave and rejoin |
| Exit flush | Earn or equip immediately before leaving; final save restores the latest snapshot |
| Slow save departure | Leave while autosave is yielding after further changes; final flush captures newer changes without duplicating rewards |
| Failed load/API off | No existing save is overwritten; fallback is explicitly session-only and never later saved |
| Same user, two sessions | Active lease blocks second load; ownership is released on exit or expires, with no stale server overwrites |
| Lease/network loss | Failed saves show pending; expired/lost ownership pauses actions instead of continuing mutations |
| Corrupt/future schema | Character is refused without reset or write; readable error reaches both HUD and inventory |
| Shutdown retries | Final failures retain closing profiles and retry within the shutdown deadline; no tight loops |
| Portrait/landscape | XP/objectives/save messages are readable and do not hide essential combat controls |

## Pending village acceptance

| Check | Expected result |
| --- | --- |
| Reach village | From spawn, the right-side path goes around the workshop to Rowan's plaza without falling or blocked doors |
| First quest | Rowan accepts introduction; Tessa visit advances it; Rowan awards 100 XP, 20 gold and lantern once |
| Second quest | Rowan accepts after introduction; four credited creature defeats update the tracker; Rowan awards 150 XP, 60 gold and charm once |
| Save upgrade | Previous version-one character retains inventory/XP/gold/claims and starts with new quest defaults |
| Rejoin mid-quest | NPC visit stage, field acceptance and defeat count persist after a confirmed save |
| Enemy AI | Slimes, boar and thornling patrol, notice nearby field players, pursue, telegraph, attack and return if leashed |
| Dodge/stun | Leaving impact range avoids damage; Shield Bash interrupts a windup and pauses the enemy for one second |
| Sanctuary | Creatures cannot attack village players, and players cannot shoot creatures from the safe village or outside the encounter leash |
| Defeat/respawn | Health zero grants credit once; corpse does not block shots; after ten seconds it resets at home with a new generation |
| Cooperative credit | Recent nearby contributors each receive XP/gold and accepted quest credit once; stale, departed or paused players receive none |
| Rest well | Nearby living players heal at most once per ten seconds; remote prompt spoofing and defeated characters cannot heal |
| Dialogue input | Continue/Escape/B dismiss dialogue; clicking or using controls during dialogue never attacks |
| Streaming/layout | Streamed-out targets/NPCs cause no errors; quest/XP/save panels and dialogue remain readable on phone and controller |
| Silent audio | Empty IDs issue no audio requests or errors; configured permitted IDs play through correct groups with volume controls |

Complete these new checks in Studio; pure rules, data-model construction and mocked physics do not establish live pathing, playback or multiplayer behavior.
