# SUMMON VEHICLE + air autopilot — design spec

Owner request, 2026-09-02. Approved as designed the same day (approach A).

> "Build it, don't worry about planes. I want the headless client to drive them
> too. We're going to replace taxi with users setting 1 vehicle as a recall: it
> spawns 1 km out then drives or flies/lands at them."

Decisions taken in the brainstorm (owner's answers):

| Question | Answer |
|---|---|
| No headless client connected | **Refuse** ("no driver available"), same as Loonazon |
| Recall vehicle already out in the world | **Respawn 1 km out** — read fuel/damage/trunk off the live copy, delete it, spawn fresh |
| Cost | **Free, 120 s cooldown** |
| Trigger UI | Deck GARAGE row gets a **★ SET RECALL** toggle; the Robotaxi launcher tile becomes **SUMMON VEHICLE** |
| Planes | Out of scope. Helicopters and VTOLs only |

## 1. Scope

Two deliverables that share one flight controller:

1. **Air autopilot for the seated player** — the existing TAB-radial / deck AP
   wedge works in helicopters and VTOLs, flying to `AP_gpsDest`.
2. **SUMMON VEHICLE** — a player marks ONE owned vehicle as their recall
   vehicle; one tap spawns it ~1 km away and the headless client (HC) drives
   (land) or flies and lands (air) it to the player. Replaces the Robotaxi
   entirely.

Not in scope: planes, boats, gang vehicles, multiple recall vehicles, paid
summons, AI pilots.

## 2. Architecture — approach A: one flight core, two hosts

The ground autopilot exists twice (`fn_gpsAutopilot` for the seated player,
`fn_hcDrive` forked player-less for the HC) and every physics fix has had to
land in both. Flight does not repeat that.

```
AP_fnc_flyStep   [_veh, _dt]            pure per-frame step; ALL state on the vehicle
      ▲                    ▲
      │                    │
fn_gpsAutopilot        AP_fnc_hcFly     [_veh, _dest]   frame-paced loop on the HC
 (EachFrame EH,          (waitUntil diag_frameNo, like hcDrive; sets hc_ap_* vars)
  seated player)
```

`AP_fnc_flyStep` reads and writes only `_veh getVariable` state
(`fly_phase`, `fly_dest`, `fly_cruiseAlt`, `fly_land`, `fly_t0`, …) so any
number of aircraft fly at once and neither host needs globals. The step returns
the phase name; the host decides what to do when it reads `"landed"`,
`"hover"`, `"aborted"`.

### 2.1 Flight model

| Phase | Behaviour |
|---|---|
| `climb` | vertical to cruise altitude, nose toward the destination |
| `cruise` | straight line to the approach point at 60 m/s |
| `approach` | slow to 15 m/s over the last 250 m, level attitude |
| `descend` | 3 m/s down over the landing spot; 0.5 m/s for the last 3 m |
| `landed` | velocity zeroed, `engineOn false`, phase persists so the host can finish |

- **Cruise altitude** = the maximum terrain height sampled every 100 m along
  the straight line, plus 80 m, and never below 120 m AGL at the start point.
  Sampled once at start (`fly_cruiseAlt`), re-sampled only if the destination
  changes.
- **Movement** = a velocity blended toward a carrot 40 m ahead on the current leg; with a pilot
  aboard `setVelocity` drives the model, with the seat EMPTY the core integrates the position
  itself (`setPosASL`) and keeps its own velocity state, because an unmanned rotorcraft's model
  ignores `setVelocity` (measured 2026-09-02, see fn_flyStep.sqf)
  (`setVelocityModelSpace` is wrong for aircraft: model Y is not "forward" for
  a rotorcraft under bank) and `setVectorDirAndUp` for attitude: bank into
  turns up to 25°, pitch-down up to 10° in cruise, level in `approach`,
  `descend`, `landed`. Helicopters and VTOLs use the identical model (a VTOL is
  flown as a rotorcraft; no wing physics, no transition).
- **Frame pacing** is the hcDrive rule: one update per rendered frame,
  `_dt = (time - _lastT) min 0.2`. Never `uiSleep 0`.
- **Landing spot** (2026-09-07: `AP_fnc_flyLandSpot`, one picker for every host): the
  clear spot NEAREST the target where the aircraft can take off again. Candidates spiral
  out to 150 m and are tested nearest-first: no static object within rotor radius + 2 m
  (`isFlatEmpty`, bounding spheres), nothing alive or parked on the disc (`nearEntities`,
  the aircraft and its crew excepted — so never on the summoner), a clear 60 m column over
  the disc, gradient ≤ 0.3 over max(rotor radius, 8 m), land only, a VTOL never on a road.
  None → the aircraft holds a 2 m hover beside the target and the step returns `"hover"`;
  the host ends the flight there and reports it.
- **Safety** = hcDrive's shield and watchdogs, applied to aircraft: a
  `HandleDamage` EH that ignores impact/fire but allows weapon damage while
  under autopilot; a progress watchdog (distance-to-destination must fall ≥ 5 m
  every 6 s in cruise/approach, else `"aborted: stalled"`); a 300 s cap; abort
  on `!alive`, fuel < 0.5 %, or the vehicle leaving the host's locality.
- **Class gate**: `_veh isKindOf "Helicopter" || _veh isKindOf "VTOL_Base"`.
  Everything else is refused before any state is written.

### 2.2 Seated player autopilot (air)

`fn_gpsAutopilot "start"` gains an air branch: when the class gate passes it
skips the road-route preconditions (route points, on-road, near-route) and
instead requires `AP_gpsDest` set and the vehicle airborne or on the ground
with rotors free to start. It engages `AP_fnc_flyStep` from the same
`EachFrame` handler the car uses. Everything the player sees stays the same:
the AP wedge, the mode message, "touch the controls to take over" (collective,
cyclic or pedals disengage), the arrival message. The `AP_autopilot` module
gate is unchanged, so the garage's slot-9 Autopilot Module (and the "Autopilot
Certified" talent that waives it) must become buyable for air:
`canAutopilot` in `fn_deckGarage` and the combo gate in `fn_vehicleShopMods`
accept the air classes.

## 3. SUMMON VEHICLE

### 3.1 Data

- `vehicles.recall boolean NOT NULL DEFAULT false` — added at boot with the
  same `ALTER TABLE … ADD COLUMN IF NOT EXISTS` line `rig_kind` uses
  (`server/AP_server/init.sqf`). Exactly one row per `pid` may be true; the
  server enforces it (`UPDATE … SET recall = (id = $1) WHERE pid = $2`).
- Server-side per-player state, in memory only: `AP_summonActive` hashmap
  `uid → [vehicle, t0]` and `AP_summonCooldown` hashmap `uid → time`. Both
  reset on restart; a restart mid-summon leaves an active vehicle where it was,
  which is the same outcome as any other pulled vehicle.

### 3.2 Setting the recall vehicle

Deck GARAGE app: every row shows ★ (hollow) / ★ (filled). Tapping calls
`["recall", id]` on the existing `garage` verb, which forwards to
`APS_fnc_summonSRV ["set", id]`. The server verifies the row belongs to the
caller (`remoteExecutedOwner`, never the client's object), flips the column,
and pushes the refreshed garage payload. Any vehicle kind may be starred
(car, truck, heli, VTOL); planes and boats are refused at ★ time with
"can't be summoned", so the tile never offers something the driver can't do.

### 3.3 Summoning

Launcher tile **SUMMON VEHICLE** (economy row, the Robotaxi slot). One tap
sends `APS_fnc_summonSRV ["go"]`. The server, in order, refuses with a message
when:

1. no HC is connected (`AP_hcOwner <= 0`) — "no driver available right now";
2. no recall vehicle is starred, or its row is not `alive` — "star a vehicle in
   the garage first" / "your recall vehicle is wrecked";
3. cooldown (120 s from the last successful summon) — remaining seconds shown;
4. a summon for this player is already in progress;
5. the caller is inside a vehicle — "get out first";
6. the recall vehicle is out in the world AND occupied — "someone is in it".

Otherwise:

1. **Reclaim** — if the world copy exists (matched by `AP_vehId` / plate on
   `vehicles` in-world), read `fuel`, `damage`, `AP_vinv`, the physical cargo
   and `AP_vehAmmo`, then `deleteVehicle` it. If it does not exist, the row
   supplies fuel/damage/inventory as a normal garage pull does.
2. **Spawn point** —
   - land: pick a road ≥ 900 m and ≤ 1100 m from the player on a bearing
     from {0°, 72°, 144°, 216°, 288°} + random offset, for which
     `AP_fnc_routeFind` returns ≥ 4 points; none → 700 m; none → refuse
     "no road there — move closer to one";
   - air: the point 1000 m from the player on a random bearing, at the flight
     core's cruise altitude for that leg, nose toward the player, engine on,
     forward velocity 20 m/s.
3. **Spawn** — `APS_fnc_spawnVehicle`, extended so `_sp` may be a position
   array (today: marker name or object). The row's mods, colour, plate, alarm
   and trunk apply exactly as a garage pull; the reclaimed fuel/damage/trunk
   override the row's when present. `active` flips true through the existing
   `APS_fnc_vehicleSetActive` claim so the anti-dupe invariant holds.
4. **Hand-off** — set on the vehicle (public): `hc_ap_dest` (player's
   position, re-published every 5 s while en route so a moving player is
   followed), `hc_ap_mode "normal"`, `hc_ap_arrive 8`, `hc_ap_want true`,
   `AP_summonFor uid`; `lock 2` while en route (nobody can board it on the
   way); `setOwner AP_hcOwner` with the hcDrive retry until `local` is false
   on the server. The HC pump drives (`hcDrive`) or flies (`hcFly`) by class.
5. **Progress** — the server pushes `summon` to the owner every 2 s: state
   (`spawning`, `enroute`, `arrived`, `failed`), distance, ETA (distance /
   recent ground speed), and the failure reason. The launcher tile renders it.
6. **Arrival** (`hc_ap_done` = `arrived` / `landed` / `hover`) — engine off,
   `lock 0` (owner's keys as normal), `setOwner 2`, systemChat + phone toast
   "your <name> is here". `hover` says "couldn't find a flat spot — it's
   hovering over you, climb in".
7. **Failure** (`stuck`, `blocked`, `wrecked`, `timeout`, `aborted`,
   `lostlocality`, `no route`) — the vehicle stays where it stopped, unlocked,
   `setOwner 2`, the player is told where it is (grid) and the cooldown is NOT
   charged. Wrecked stays wrecked (a summoned vehicle is a real one).

The HC keeps ownership only while driving; nothing about the vehicle depends
on the HC after arrival or failure.

### 3.4 Removal of the Robotaxi

`core/gps/fn_robotaxi.sqf`, `server/…/fn_robotaxiSRV.sqf`, their
`Functions.h` / `config.cpp` classes, the `CfgRE` entry, the launcher row in
`core/configuration.sqf`, the `AP_robotaxi` rider-in-the-seat branches in
`fn_gpsAutopilot` (input gating, `AP_taxi_arrived`) and in `fn_hcDrive`, the
"NAV (ROBOTAXI)" strip text in `map.html`, the `g-robotaxi` glyph if nothing
else uses it, and the Robotaxi entry in `fn_deckData`'s app catalogue. The
Chauffeur quickhack keeps its own `AP_chauffeured` gate; it never used the
taxi flag.

## 4. UI

- **Garage app row**: ★ toggle, filled on the recall vehicle, with "RECALL"
  tag; tapping another row moves the star. Refusal (plane/boat) as a status
  strip message.
- **SUMMON VEHICLE tile** (launcher, economy row, replaces Robotaxi; glyph
  reuses `g-robotaxi`): a one-screen app showing the recall vehicle's name and
  kind, its state (`GARAGED` / `OUT · 2.3 km` / `EN ROUTE · 640 m · ~35 s` /
  `ARRIVED` / `FAILED: blocked at 121 045`), the cooldown countdown, and one
  button **SUMMON** (disabled with the refusal reason when the server would
  refuse — computed client-side from the same facts for responsiveness, but
  the server decides). No vehicle starred → the screen says so and links to
  the garage app.
- Native phone: untouched (the HTML deck is the phone now).

## 5. Security

- The server derives the caller from `remoteExecutedOwner`; the client sends
  no vehicle object, no position of its own, and no uid.
- `["set", id]` checks `pid = caller` on the row before writing.
- `["go"]` reads the destination as the caller's own unit position.
- The HC is trusted exactly as Loonazon trusts it today (it owns and moves the
  vehicle; the server retakes ownership at the end).
- All refusals and outcomes log through `APS_fnc_logIt` under `-SUMMON-`.

## 6. Testing

- **Headless self-test** `bot_commands summonselftest arg1=car|heli|vtol`:
  the server spawns a test vehicle of that kind 1 km from the `respawn_civilian`
  marker, hands it to the HC with the marker as the destination, and logs
  `[SUMMON-TEST] kind=<k> outcome=<done> dist=<m> t=<s>` into loonydev.log.
  Pass = `arrived`/`landed` within 20 m in under 300 s. Runs with the dev HC
  up (`arma3server_dev/hc_launch_once.sh`, launched inside a live Bash call;
  it drops on every reload).
- **Offline**: none of the flight math needs the game; the cruise-altitude
  sampler and the bearing/spawn-point picker get unit tests in
  `tools/test_summon_math.py` against a synthetic heightmap.
- **Owner playtest** (needstest.md rows): car summon from the garage; heli
  summon; VTOL summon; summon while the vehicle is out (respawn keeps fuel and
  trunk); every refusal path; cooldown; seated AP flight in a heli to a NAV
  set from the web map; disengage by touching the controls.

## 7. Ceilings and numbers

| Thing | Value |
|---|---|
| Recall vehicles per player | 1 |
| Summons in flight per player | 1 |
| Spawn distance | 1000 m (±100); land fallback 700 m |
| Cruise speed / approach / descent | 60 / 15 / 3 m/s |
| Cruise altitude | max terrain on the line + 80 m, ≥ 120 m AGL |
| Landing search | 150 m radius nearest-first, rotor radius + 2 m clearance, 60 m clear column, gradient ≤ 0.3 |
| Drive/flight cap | 300 s |
| Cooldown | 120 s, not charged on failure |
| Arrival radius (land) | 8 m |
| World | Malden, 12 800 m |

## 8. Files

New: `core/gps/fn_flyStep.sqf`, `core/gps/fn_hcFly.sqf`,
`server/AP_server/core/TON/fn_summonSRV.sqf`, `core/web/fn_deckSummon.sqf`,
`tools/test_summon_math.py`.
Changed: `fn_gpsAutopilot.sqf`, `init.sqf` (HC pump), `fn_spawnVehicle.sqf`,
`fn_deckGarage.sqf`, `fn_deckData.sqf`, `deck.html` (both copies),
`fn_radioRadial.sqf`, `fn_carRadioBridge.sqf`, `fn_vehicleShopMods.sqf`,
`core/configuration.sqf`, `Functions.h`, `config.cpp`, `CfgRE.hpp`,
`server/AP_server/init.sqf` (DDL), `fn_bot_commands` (self-test verb).
Removed: `fn_robotaxi.sqf`, `fn_robotaxiSRV.sqf`.

## Addendum 2026-09-02 (evening) — rotorcraft fly on the engine's AI

In-game the scripted flight core moved a pilotless aircraft by `setPosASL` (an unmanned rotorcraft
ignores `setVelocity`), which observers saw as position steps ("my Blackfish slowly teleports").
Measured alternatives, all on dev with the `summonselftest` variants `heli+pilot` / `heli+ai`:

- pilot with AI OFF: `setVelocity` is accepted but the model hover-holds — moves nothing;
- pilot with AI ON on the headless client: the engine flies it with real physics and a real,
  broadcast velocity — smooth for everyone. This is now the shipped design (`AP_fnc_hcFlyAI`).

Rules that fell out of it: the pilot is created on the SERVER (`createUnit` is a disabled command
on the HC) at the map corner, seated with `moveInDriver`, AI off, captive, invisible, undamageable;
the hand-off is `setGroupOwner` on his group (a crewed vehicle's locality is its driver's; `setOwner`
on the hull carries no one); the HC enables the AI and steers with group `move` + `doMove` re-issued
every 8 s (`addWaypoint` is disabled on the HC); helicopters land on an invisible helipad dropped at
the destination, ordered once near and slow, with the scripted core as fallback (60 s after the
order, a stalled hover, a pad conflict, a dead pilot); a VTOL cannot be spot-landed by the engine
AI, so 300 m out the pilot is removed and the scripted core takes the vertical descent. Every
outcome path removes the pilot; an aircraft still airborne on a non-landed outcome is landed in
place by the scripted core before it is locked. Air spawn points are never on a road. The pilotless
scripted core remains the seated-player autopilot's engine and the VTOL/fallback lander.

## Addendum 2026-09-03 — wrecked in transit = refunded to the garage

Owner's call: "if a summoned vehicle blows up because of the crash landing it refunds to garage."

**Window.** From the moment "drive" binds the vehicle until 20 s after the summon finishes, or until
a player boards it, whichever comes first. Death anywhere in that window is the summon's fault
(flight, landing, settling after touchdown); a boarded vehicle is the player's from then on and a
wreck follows the normal path (no refund, no special case).

**What "refund" writes.** The row goes back to `active = 0, alive = 1` with the `damage`, `fuel` and
`ammo` it had BEFORE the pull (read from the row at "drive", so a wreck in transit is not a free
repair). The trunk is read off the wreck through `DB_fnc_updateVehicle` (the one store path;
contraband kept, as the idle reaper keeps it — the player did not choose to store). Then the wreck
and its attachments are deleted so the plate exists in exactly one place. The deck shows "your X
was wrecked on the way — it is back in your garage"; the log carries a `-SUMMON-` refund line.

**Why nothing else can delete the row first.** `fn_vehicleDead` deletes an uninsured dead vehicle's
row, and the reaper calls it on first sight of any un-stamped wreck. Both honour the `insured`
object flag, so the summon sets `insured = true` on the vehicle for exactly as long as it owns it
and restores the prior value when it lets go. No race, no new gate in either file.

**Trust.** The trigger is the server's own `alive` read on the object it bound at "drive" — no
client message is involved. The SQL takes `_uid` from the caller's identity and the plate from the
DB row, never from the payload. A player CAN get a live, far-away world copy garaged by summoning
it and having it shot down (its trunk is serialised, contraband included) — that is what the idle
reaper already does to an abandoned vehicle, so it opens no new dupe.

## Addendum 2026-09-07 — one landing-spot picker: the nearest clear spot it can take off from

Owner: "the heli autopilot/summon needs to always land in a clear space closest to the player
where it can take off again." Three Orcas summoned in the La Trinite plaza that day landed among
the vending rows and the HQ fronts (HC log 18:18, 18:22, 18:25, all `landed`).

**Root cause.** The engine-AI host (`AP_fnc_hcFlyAI`, every heli summon since b0859) dropped its
invisible helipad at the summoner's exact position with no test, and `land "LAND"` sets the aircraft
down ON the pad wherever it is. The scripted core had a private spiral, but it cleared only 70 % of
half a hull (under the rotor radius), `isFlatEmpty` counts static objects only (BIKI: vehicles and
units are invisible to it), nothing looked upward, and it stopped at 60 m.

**Fix.** `AP_fnc_flyLandSpot [_target, _veh, _rMax]` → `[x, y]` or `[]`, registered, used by both
hosts. Gates, all of which a candidate must pass, tested nearest-first out to 150 m (rings 8 m apart,
~12 m along a ring, starting on the aircraft's side): `isFlatEmpty` with rotor radius + 2 m clearance
(rotor radius = the larger horizontal half-extent of `boundingBoxReal`, 3..14 m), gradient ≤ 0.3 over
max(radius, 8 m), land only; no car/aircraft/boat/person within the same clearance except the aircraft
and its crew; 60 m of nothing over the disc centre and four disc-edge points (`lineIntersectsSurfaces`
"GEOM"/"VIEW", the aircraft and its pilot ignored); a VTOL never on a road (b0854), a helicopter may.
- `AP_fnc_hcFlyAI`: pad and move order on the spot; when the summoner walks > 25 m it picks again and
  moves the pad only if the spot changed (> 5 m); no spot → the landing is handed to the scripted core
  (hover beside the summoner) instead of an AI landing on an untested pad; the hand-over passes the
  SUMMONER's position so the core's own pick agrees with the pad.
- `AP_fnc_flyStep`: the private spiral is gone; the picker runs at the cruise→approach hand-over and
  again when the destination moves. The seated autopilot and the emergency "land where it is" path
  inherit it unchanged.
- Logs: one `[FLYSPOT] target spot dist half clear tested ms veh` line per pick; `HCFLYAI start` now
  prints the pad and its distance to the summoner, `HCFLYAI end` the touchdown position, its distance
  to the pad and `isTouchingGround` — the next run is verifiable from the HC log alone.

**Residual decisions** (made without the owner, revisit if the walk-test disagrees): 150 m search
radius; +2 m over the rotor radius; 60 m column; gradient kept at the proven 0.3; helicopters may use
roads; worst case ~400 `isFlatEmpty` calls in one frame (a target deep in a town), once per flight.

**First live run (another session's deploy at 18:46 carried the commit).** Open plaza at
[7304,7733]: spot 16 m away, 7 candidates, landed 3 m from the pad. HQ plaza at [7139,7904]: 378
candidates, NONE, in 2 ms — `isFlatEmpty`'s proximity test counts PAVING (45 kerbs, cobblestone
squares, sidewalks, tree grates within 20 m, by bounding sphere), so a paved square reads as solid.
**v2 gates** (same nearest-first search): `isFlatEmpty` with proximity OFF (slope + water only);
VTOL never on a road; no object with its centre within rotor radius + 2 m that stands taller than
0.6 m (`nearestObjects`, height from `boundingBoxReal` — kerbs and paving are ground, lamp posts and
hedges are not; the aircraft, its crew and helipads ignored); `nearEntities` for people and vehicles;
downward rays (centre, 4 inner, 12 at radius + 2 m, 60 m → ground, "GEOM"/"VIEW") whose first hit
must be ≤ 0.6 m over the terrain. The `[FLYSPOT]` line now carries per-gate rejection counts
`rej[slope,road,object,entity,rays]` — read it before loosening a gate. Owner row 13 in needstest.md.

## Addendum 2026-09-07 (evening) — the headless client had no map

Owner, b1009 (picker v2 live): "it literally landed, then rotor tapped itself in a place it can't
possibly take off from." HC log: target [7250,7875], 176 nearer candidates rejected by the object
gate, spot [7192,7819] chosen 80 m out, landed 3 m from the pad. map_objects at that spot: a
`Land_Cargo20_grey_F` container 3.4 m away, two `Land_City2_8m_F` walls at 5.3 and 6.6 m, a
`Land_FireEscape_01_tall_F` at 7.4 m — every one an object-gate failure, had it existed there.

**Root cause.** The designer's map is streamed per client from `map_objects` (mapdb, 2026-09-04):
`initPlayerLocal.sqf` → `core\init.sqf` → `AP_fnc_mapStream`. The headless client runs none of that
(init.sqf exits into the driver pump), so its world is vanilla Malden: the landing picker, the AI
pilot, the collision raycasts in hcDrive and the cruise-altitude sampler all reasoned about a town
that, on that machine, was an empty field. The earlier plaza runs "worked" by luck.

**Fix.** The HC streams like a client, focused on its jobs: `AP_fnc_mapTick` now takes an array of
foci (`AP_mapFoci`, distances to the nearest; an explicit `AP_mapFocus` still wins, a player still
uses their own position, a headless client with no job streams nothing); the HC init runs
`AP_fnc_mapStreamInit` and a 2 s loop that sets the foci to every local vehicle with `hc_ap_want` /
`hc_ap_driving` plus its `hc_ap_dest`, then ticks. `AP_fnc_hcFlyAI` waits (≤ 12 s) for the
destination's cell to be `loaded` plus one create pass before it samples the cruise altitude or
picks the spot, and logs `HCFLYAI map: cell <k> loaded, N live objects`. `[FLYSPOT]` prints
`mapLive=N` — a blind host reads `mapLive=0`.

Verify after deploy: summon a heli into the HQ plaza; HC log must show `HCFLYAI map: ... loaded`
with a live count in the hundreds, then a `[FLYSPOT]` with `mapLive>0`, a spot clear of the
container yard, `padDist` ≤ 10 and `ground=true`. Owner row 13.

**b1010 (the streaming fix live), 19:35 run:** `HCFLYAI map: cell 7_7 loaded, 0 live objects`,
`mapLive=0`. The cell blob arrived at 19:35:03, the pick ran at 19:35:04, the streamer's create pass
ran at 19:35:07 (`tick: +1686`). Also the HC's far-bucket request at the second it connected was
refused (`no resolvable requester`) and nothing re-asked, so the towers never existed there.
Fixes: `AP_fnc_mapTick` re-asks a still-"wanted" far bucket after the retry interval and counts
full ticks (`AP_mapTickN`); `AP_fnc_hcFlyAI` waits for the cell AND two full ticks (≤ 20 s) and logs
the far state; the HC defines a no-op `AP_fnc_boostLamp` (row inits call it; client config only).

**"It lands, goes up a bit and drops" (owner, b1010).** On `landed` the HC published `hc_ap_done`
with the pilot's AI on and the engine running; the server handed the crewed hull back
(`setGroupOwner 2`), and an AI pilot in a running helicopter with no orders lifts off on the
locality change — the server then pulled him out a few metres up. Fix: on `landed` the HC
disables the pilot's AI and turns the engine off before publishing; the server, once the hull is
local again, turns the engine off (on the ground) and disables the AI before `moveOut`, and logs
`finish: z engine ground local before pilot removal`.

