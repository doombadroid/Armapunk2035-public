# Malden Federal Reserve — design

Owner brief 2026-07-27. The fork's Federal Reserve is Altis-shaped: it targets `Land_Dome_Big_F`
domes, `Land_Research_house_V1_F` inner safes and a `Land_BarGate_F` perimeter gate. **Malden has
none of those.** The map's Fed is a walled platform on the eastern island carrying ten
`Land_Medevac_house_V1_F` buildings in a ring, a centre building, a side-door structure and a
concrete sliding gate. Nothing about the Altis flow survives the move except the shape of the code.

This document is the whole feature: what it does, what it is built from, and what the server may
believe. Repo ships Malden only, so the Altis paths are **rewritten in place**, not duplicated.

Related and independent: the island's anti-air umbrella (`APS_fnc_fedAirDefenseSRV`) and the radar
tower sabotage (`APS_fnc_fedRadarSRV`). Neither gates this heist and this heist does not gate them.

---

## 1. Anchors

| Name | Position | What is there |
|---|---|---|
| `FED_CENTRE` | `[11197.8, 4459.3]` | ring centre; already the AA battery site |
| `GATE` | `[11237.5, 4382.56]` | `Land_ConcreteWall_01_l_gate_F` (2.1 m away in mission.sqm) |
| `DOME` | `[11197.99, 4459.21, 18.80]` | `Land_Dome_Big_F` — the 10-minute target |
| `CENTRE_BLDG` | `[11196.29, 4457.90, 18.45]` | `Land_Medevac_HQ_V1_F` — the Alamo target |
| `BOAT` | `[11153.3, 4534.19]`, dir 150 | open water off the west pier |

The ten safes are the ten `Land_Medevac_house_V1_F` in the ring. Owner's coordinates and their
mission.sqm counterparts, matched (every pair within 3.7 m):

| owner coord | sqm object | Δ |
|---|---|---|
| `[11219.5, 4460.22, 18.02]` | `[11216.84, 4459.61, 17.60]` | 2.7 m |
| `[11219.7, 4453.85, 17.51]` | `[11216.17, 4453.25, 17.60]` | 3.6 m |
| `[11216.9, 4447.24, 17.15]` | `[11213.49, 4447.32, 17.58]` | 3.4 m |
| `[11186.5, 4438.64, 17.66]` | `[11186.80, 4442.26, 17.29]` | 3.6 m |
| `[11180.4, 4443.68, 18.54]` | `[11182.22, 4446.71, 17.28]` | 3.5 m |
| `[11177.5, 4449.53, 19.33]` | `[11179.06, 4452.32, 17.28]` | 3.2 m |
| `[11174.6, 4456.98, 19.14]` | `[11177.80, 4458.53, 17.27]` | 3.6 m |
| `[11195.7, 4480.83, 21.32]` | `[11197.07, 4477.74, 17.61]` | 3.4 m |
| `[11202.8, 4480.58, 20.93]` | `[11203.37, 4476.90, 17.60]` | 3.7 m |
| `[11209.5, 4477.60, 20.08]` | `[11209.20, 4474.00, 17.60]` | 3.6 m |

### Boot resolution and logging

**Corrected 2026-07-27, after the first deploy.** The dome and the centre building are in neither
mission.sqm nor `custom_p3ds/` — they are entries in **`fn_mapData.sqf`**, the array of ~15,700
map objects this fork spawns by script rather than placing in the editor. The first boot pass looked
for them by proximity and found rocks (`w_sharpstone_02`) at sea level 19 m away, because on the
server they did not exist at all.

Two facts came out of that, and both change the design:

1. **The Fed does have a real dome**, and it is the Altis class: `Land_Dome_Big_F` at
   `[11197.99, 4459.21, 18.80]`, with `Land_Medevac_HQ_V1_F` 2 m from it. Owner's call: the **dome**
   is what the 10-minute terminal opens; the **Medevac HQ** is the Alamo Fed's centre building. The
   coordinates in the original brief were where the owner stood — 8.9 m and 21 m out — not the
   objects themselves.
2. **Both were invisible to the server and had no doors.** Their `fn_mapData` entries carried
   `isServer = false` and an empty init, and `fn_createVehicleLocal` turns that into
   `createSimpleObject` on each client — a baked statue with no doors, no animations and no
   interaction, which the server never spawns and therefore cannot see, lock or animate.

   Fixed by flipping the `isServer` field on those two entries to `true`. The server then takes the
   `isServer && isDedicated` branch and spawns each with `createVehicle` — a real networked object
   with working doors. `fn_dynamicMapSystem`, the client-side streaming half, only ever handles
   entries where `!(_xIsServer)`, so the clients skip them and nothing is spawned twice.

Anchors are still resolved and logged at boot — class, model and distance, as `APS_fnc_fedRadarSRV`
does for the radar tower — but the search is now an exact class match at a known position rather
than a guess, and the log is a boot-time assertion that the promotion held.

The boot pass also logs, per safe, whether it found interior `buildingPos` positions — see §7.

`fed_reserve` marker is created at `FED_CENTRE` in `initServer.sqf`. That name already has
consumers in `server/AP_server/init.sqf` (dispatch target, a 600 m terrain-repair sweep, a
`Land_Cargo_Patrol_V1_F` cull) — **audit all of them before creating it**, since they have been
inert on this map and will start firing the moment the marker exists.

---

## 2. State

```
SRV_maldenFed = [phase, phaseEndsAt, alamo, alamoEndsAt, lockoutUntil]
```

`publicVariable`d on every transition, so clients and JIP joiners read one authority.

| phase | meaning |
|---|---|
| 0 | SECURE — gate, dome, ten safes and the centre all locked |
| 1 | BREACHED — gate hacked, alarm live, MaxSec alerted |
| 2 | COUNTDOWN — dome terminal won, 10:00 running |
| 3 | OPEN — dome doors open, gold spawned, loot phase |

`alamo`: `0` none · `1` counting (20:00) · `2` open, boat delivered.
`lockoutUntil`: serverTime before which the gate hack refuses (HIGH SECURITY).

### Security model

Clients **request**, the server **decides**. Every entry point re-derives the caller from
`remoteExecutedOwner`, re-checks that they are alive, civilian, un-restrained and within range of
the anchor they claim, and re-checks the phase. The CfgRE whitelist makes these callable by any
client with arbitrary arguments, so nothing the client says is trusted — the model is
`APS_fnc_fedRadarSRV` and `fn_chopShopSell`, not the Altis fed's `AP_vaultlocked` handshake (which
is set client-side and remains a known residual hole on Altis, tracked in AUDIT.md).

Minigame outcomes are inherently client-reported — that is true of every hack in this codebase and
is not made worse here. What the server refuses to take on trust is *where the caller is* and *what
phase the Fed is in*, which is what turns a forged call into a no-op.

---

## 3. Flow

### 3.1 Perimeter gate — always locked

The gate is locked at boot and after every reset, and there is no boltcutter path: the Sequence
Breach is the only way through.

- Scroll: **Breach Perimeter Gate**, requires a Cyberdeck, ≤ 5 m, phase 0, not in lockout.
- `[10] call AP_fnc_cyberdeckSeq` — buffer 10, the asylum-laptop tier.
- Win → server opens the gate, phase 0 → 1, and **the alarm fires**:
  - MaxSec broadcast on all channels,
  - red `mil_dot` map marker "Robbery in Progress" at `FED_CENTRE`,
  - police dispatch (`AP_fnc_createDispatch`),
  - wanted charge **id 5, Federal Reserve Robbery**, on every civilian within 200 m, re-swept every
    30 s so late arrivals are charged too,
  - the Fed counts as an active federal event, blocking bank/evidence/prison/convoy/asylum/jewelry.

MaxTac dispatch is **not** wired: `AP_fnc_maxtacDispatch` only has Altis and Australia spawn tables
and falls through on Malden. Left as a TODO rather than invented.

### 3.2 Dome terminal — the 10-minute crack

- Scroll at the `DOME` side door: **Breach Dome Terminal**, Cyberdeck, ≤ 4 m, phase 1.
- `[3] call AP_fnc_cyberdeckTerm` — difficulty 3, nine commands, the Fed tier.
- Win → phase 1 → 2, `phaseEndsAt = serverTime + 600`, and the top-right draining countdown box
  goes up (§6).
- Failure burns the deck cooldown the way `fn_openVault` does today (120 s), so a failed hack is a
  real setback rather than an instant retry.

At **0:00**: dome doors unlock and swing open, phase 2 → 3, and the gold spawns (§3.3).

### 3.3 The ten safes

Locked at boot: doors disabled and shut, `AP_vaultlocked = 1`.

- **Crack Safe** — `[6] call AP_fnc_cyberdeckSeq`, buffer 6.
- **Plant Demo Charge** — consumes one `demoCharge`. **The Altis talent-43 gate is dropped**: any
  demo charge works.
- Both are available from **phase 2**, so a crew can pre-crack safes while the countdown runs. A
  safe opened early simply has its briefcase appear inside it at 0:00.

At phase 3 the server spawns **one `Land_Suitcase_F` per safe, 1–5 `goldbar` each** (`AP_droppedItems`,
the same pickup as death-drop suitcases and treasure chests), plus the existing **one crypto mining
component** beside a random case, once per event — that drop lives in `APS_fnc_fedGoldSpawn` today
and is kept.

### 3.4 Alamo Fed — the centre building

- Scroll at `CENTRE_BLDG`: **Start an Alamo Fed**, Cyberdeck, ≤ 5 m, **phase 3 and `alamo == 0`**.
- `[3] call AP_fnc_cyberdeckTerm` → `alamo = 1`, `alamoEndsAt = serverTime + 1200`, second
  countdown box.
- At **0:00**: the centre opens, `alamo = 2`, and it holds **10 gold bars as 5 cases × 2 bars**, so
  the crew shares rather than one player taking the lot.
- The getaway boat is delivered in the same transition (§3.5) and everyone is told so.

### 3.5 The getaway boat

`B_Boat_Armed_01_minigun_F` at `[11153.3, 4534.19]`, **bearing 150**, placed on the water surface at
that XY (the owner's z of 8.65 is above the waterline; the piers there sit at −4.8).

- Turret **live, normal ammo**.
- `AP_vcap = 999999` — unlimited virtual (T) inventory, the asylum Tempest's mechanism, read by
  `fn_openInventory`.
- **10 `goldbar` preloaded** in its virtual trunk.
- `AP_eventVeh = true`.
- **Keys to every alive civilian within 400 m of `FED_CENTRE`** — keyed off the Fed, not the boat,
  because the boat sits ~120 m off the west shore and a boat-centred radius would miss the crew
  still inside the compound. Each gets `AP_fnc_addVehicle2Chain`.

Carrying gold is deliberately slow (`fn_survival` applies the over-weight walk penalty to anyone
holding a `goldbar` without talent 224), which is what makes the boat worth the 20 minutes.

---

## 4. Failure — HIGH SECURITY

A sweep runs every 30 s while phase is 1–3. It counts players who are **alive, not `west`, not
`AP_restrained`, within 200 m of `FED_CENTRE`**.

**Two consecutive empty sweeps** (a 60 s grace, so a wipe or a brief retreat is not an instant loss)
→ HIGH SECURITY:

1. relock gate, dome, all ten safes and the centre (`APS_fnc_fedLockdown`),
2. delete un-looted gold cases (`owner` in `fed_gold`, `fed_component`, `alamo_gold`),
3. delete the boat **only if it is still un-driven** — empty and within 150 m of its spawn. A boat
   the crew actually escaped in is theirs,
4. clear both timers, phase → 0, `alamo` → 0,
5. `lockoutUntil = serverTime + 300` — **5 minutes**, and the gate hack refuses until then,
6. broadcast to everyone, and retitle the map marker "Elevated Security" before deleting it.

**TODO after testing: lengthen the 5-minute lockout.** Filed in TODO.md.

The Malden Fed uses **only** `lockoutUntil`. It neither sets nor reads `SRV_lastRobbery` (the
15-minute cross-heist cooldown) and drops the Altis 60-minute post-robbery lockout, both of which
would swamp a 5-minute window. Revisit at public launch.

### Cop counterplay

**Secure the Reserve** — `west`, on foot, within 50 m of `FED_CENTRE`, phase 1–3, and only while the
robber count is **0**. Runs the same reset immediately, skipping the 60 s grace. Server re-checks
the count, so a cop cannot end a heist that is still being held.

---

## 5. Cop requirement

**Zero** for testing, on the owner's call. The server-authoritative check is written but its
threshold is 0, with the restore value in a comment beside it, matching how the Altis fed carries
its own beta waiver. **TODO: restore before public launch.**

---

## 6. Timers in the top right

Both countdowns reuse the bank's mechanism: `AP_fnc_handleMessage` with a message type whose
`_duration` is the countdown, rendered by `fn_createMessage` as a coloured box with a bar that
drains, self-clearing when its condition goes false.

Two new types in `dialog/function/fn_handleMessage.sqf`:

| type | duration | condition |
|---|---|---|
| `fed_countdown` | 600 | `{(SRV_maldenFed param [0,0]) isEqualTo 2}` |
| `alamo_countdown` | 1200 | `{(SRV_maldenFed param [2,0]) isEqualTo 1}` |

Sent at each timer's start to every player within 400 m of `FED_CENTRE`, cops included — MaxSec
knowing exactly when the doors pop is good for the fight, and they already have the marker.

---

## 7. Known gaps, stated rather than hidden

- **Gold spawn spot.** Each case goes to a random interior `buildingPos` of its safe. If a
  `Land_Medevac_house_V1_F` reports no `buildingPos`, the fallback is the owner's coordinate, which
  is ~3 m *outside* the door — lootable without breaching. The boot log records which path each of
  the ten took, so this is visible before anyone plays it.
- **Sell path.** `goldbar` is configured (illegal price 55,000) but `fn_mapData` still holds Altis
  dealer coordinates, so Malden may have nowhere to sell it. Out of scope here; flagged so the loot
  is not dead on arrival.
- **MaxTac** has no Malden spawn table (§3.1).
- **Minigame outcomes are client-reported** (§2).

---

## 8. Files

**Server** (`server/AP_server/`)

| File | Change |
|---|---|
| `core/TON/fn_maldenFedSRV.sqf` | **new** — boot resolve + lockdown, breach handlers, both timers, gold, boat, sweep, reset |
| `core/system/fn_fedLockdown.sqf` | rewrite for Malden classes (gate, dome, ten safes, centre) |
| `core/TON/fn_fedGoldSpawn.sqf` | retarget to the ten safes; keep the mining-component drop |
| `core/bank/fn_fedAlarm.sqf` | retarget: cop gate 0, marker, dispatch, charge id 5 |
| `core/system/fn_resetFed.sqf` | clear `SRV_maldenFed` too, so `!srv resetfed` still works |
| `core/system/fn_fedEventActive.sqf` | read `SRV_maldenFed` for the `fed` slot |
| `config.cpp`, `init.sqf` | register the new function; call the boot pass |

**Mission** (`mission/Armapunk2035.Malden/`)

| File | Change |
|---|---|
| `core/actions/fn_openGate.sqf` | rewrite — Sequence Breach on the concrete gate, no boltcutter |
| `core/actions/fn_openVault.sqf` | rewrite — dome terminal breach, requests phase 2 |
| `core/actions/fn_openSafe.sqf` | add the Malden safe class, drop the talent-43 gate, require phase ≥ 2 |
| `core/actions/fn_alamoFed.sqf` | **new** — centre scroll → terminal → request |
| `core/fn_setupActions.sqf` | six action entries: gate, dome terminal, crack safe, demo charge, alamo, cop secure |
| `core/functions/fn_activeFederalEvent.sqf` | read `SRV_maldenFed` |
| `dialog/function/fn_handleMessage.sqf` | two new countdown types |
| `CfgRE.hpp`, `Functions.h` | whitelist the new remoteExec target; register the new client function |
| `initServer.sqf` | create the `fed_reserve` marker (after auditing its existing consumers) |

---

## 9. Test plan (dev server, `~/loonydev`)

1. Boot. Read the RPT: every anchor resolved, classes and distances logged, ten safes matched,
   `buildingPos` availability reported per safe. Paste the lines back; hardcode the classes.
2. Everything locked before anyone touches it — gate, dome, ten safes, centre.
3. Gate hack → alarm, marker, dispatch, charge on everyone in the compound, other federal events
   refuse to start.
4. Dome terminal → 10:00 box; at 0:00 doors open and ten cases exist, each **inside** its building.
5. Crack one safe with the sequence game, one with a demo charge. Both work; neither needs talent 43.
6. Alamo → 20:00 box; at 0:00 centre opens with 10 bars, boat is on the water at bearing 150, keys
   held by everyone who was in the compound, trunk holds 10 bars and accepts far more.
7. Walk everyone out. After two empty sweeps: everything relocks, un-looted gold and an un-driven
   boat are gone, and the gate refuses for 5 minutes.
8. Cop counterplay: with the compound empty, **Secure the Reserve** ends it immediately; with a
   robber inside, the action is unavailable and a forged call is refused.
9. `!srv resetfed` clears a stuck run without a reboot.
