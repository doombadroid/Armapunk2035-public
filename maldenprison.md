# Malden prison: gate hack, containment, and the anchors both need

**Date:** 2026-07-29
**Status:** design approved section by section, then **built** — commits `c8a60d8` (anchors) through
`8976c3d0` (countdown). Everything verifiable without a game client has been verified on dev b0138; the
in-game runs in §7 steps 4-5 still need a human at a client.
**Scope:** three owner-requested features, which resolve into two subsystems plus a live bug fix.

---

## 1. What the owner asked for

Verbatim:

1. `[9767.47,3933.11,0.14]` — "you quick hack this gate it starts a 10 minute timer if the cops dont
   disarm it anyone inside gets the option to get released keeping bounty + getting 1 escape from jail"
2. "We need a TP zone for prisoners like we do on Altis"
3. "prisoners should get TPd back to the center if they get past the inner walls"

## 2. What the code actually says

Three findings reshaped the work before any decision was made.

### 2.1 Malden's jail is already broken

`core/civilian/fn_jailMe.sqf:94-96` already implements feature 3, byte-identical to Altis:

```sqf
if (!((getPosATL player) inPolygon AP_jailPoly) && !AP_laser_inprogress && !(AP_clientTrialData select 0)) then {
    systemChat "Stay within the confines of the yard!";
    player setPos(getMarkerPos "jail_marker_loonybin");};
```

It runs at 1 Hz (`:81`) on the prisoner's own client, inside `while {(AP_is_arrested param [0,0]) isEqualTo 1}`
(`:79`). But:

* `AP_jailPoly` in `core/configuration.sqf:2` is still the Altis Pyrgos quad
  (`[[16809.6,13637.2,0],[16741.1,13572.5,0],[16690.9,13623.6,0],[16758.9,13690.5,0]]`), and
  `fn_jailMe.sqf:94` is its only reader in the tree. Malden's world is 12800 m, so `inPolygon` is false
  everywhere on the map.
* None of the four jail markers exist. Malden's `mission.sqm` carries 228 markers and not one named
  `jail_*`, `corrections` or `prison*`, and nothing creates them at runtime. `getMarkerPos` on a missing
  marker returns `[0,0,0]` — a real, reachable position.

**Net effect today: every Malden prisoner is teleported to map origin once per second, for the length of
their sentence.** The 20-second boot marker sweep does not self-heal it — `initServer.sqf:171-186` deletes
only markers outside world bounds, and x=0 is neither `< 0` nor `> worldSize`.

Same failure class as the gather fields (`[0,0,0]` is reachable, not an error). Knock-on: while the markers
are absent, anyone standing at map origin satisfies the shank range gate (70 m of `jail_marker2`), the escape
query (100 m of `corrections`), the bounty-hunter arrest (19 m of `jail_release2`) and the cop Send-to-Prison
gate (30 m); and nobody can gather within 200 m of origin (`core/actions/fn_gatherObject.sqf:6`).

Features 2 and 3 are therefore one job, and it is a bug fix. The marker is the prerequisite for the poly:
poly without marker reproduces the origin teleport exactly, marker without poly removes containment entirely.

### 2.2 Feature 1's release payload is already written

`fn_jailMe.sqf:122-127`, `case (AP_breakout)`, already does precisely "released, keeps bounty, gets one
escape count":

* It does **not** wipe wanted — unlike the bail branch (`:118-121`) and the served-sentence branch
  (`:128-133`), which both fire `wantedListAdd 999` + `APS_fnc_wantedRemove`.
* It fires `[[13, player], "APS_fnc_wantedAdd", 2]` — charge 13 "Escaping Jail", $4,000 and +300 s on the
  next sentence (`core/config/fn_wantedChargesConfig.sqf:12`).
* It broadcasts the escape to `west`.

The opt-in dialog exists too: `dialog/function/fn_prisonBreakQuery.sqf` — 65 s `BIS_fnc_guiMessage`,
admin-jail-proof (`A_stats_crimes select 57`), trial-proof (`profileNamespace AP_requestedTrial`), and it
re-checks `SRV_prisonData select 1` on a late click. `core/compat/fn_prisonBreaker.sqf` flips `AP_breakout`
on real prisoners only.

New work for feature 1 is the **trigger, the timer and the cop disarm**. Not the release.

### 2.3 The prison break has never been startable on Malden

`AP_fnc_doPrisonBreak` — the laptop virus-upload trigger — has **zero callers in the tree**. No scroll
action offers it, and there is no laptop-class object within 170 m of the prison. So the gate hack does not
replace a working feature; it is the prison break's first working trigger. Nothing is retired.

## 3. The prison as a physical place

Derived from `core/config/fn_mapData.sqf` (15,726 rows) and the binarized `mission.sqm` via
`tools/sqm_read.py`. Everything below was measured, not estimated.

### 3.1 There is exactly one wall ring

Wall pieces were grouped by connectivity (linked at ≤ 5.5 m; the segments are 4 m):

| structure | reality |
|---|---|
| `Land_Mil_WallBig_4m_battered_F` | **88 connected pieces**, one closed ring, 402 m of wall, **6,875 m²** enclosed |
| `Land_SportGround_fence_F` | 26 pieces in **6 unconnected stubs of 3-4**, all inside the yard — exercise cages, not an enclosure |
| `Land_HBarrier_*` (89 + 31 + 4 + 1) | **124 of 125 outside** the ring — a separate military camp to the N and W. The one exception sits at `[9716.3,3882.5]`, just inside the west spur. |

For reference the Altis jail poly encloses ~6,800 m². The Malden wall ring is within 1% of it, which is why
the same containment code fits without retuning.

An earlier reading of this geometry claimed a "74 × 83 m inner fence ring". That was an axis-aligned bounding
box of the six unconnected stubs and does not exist as an enclosure. It was corrected before the design was
settled; the poly below is traced from the 88-piece ring.

### 3.2 The owner's gate is the inner door of a sally port

The north wall steps inward at X 9760..9774 to form a gatehouse recess holding two gates in series:

```
        outside                     Y 3948   <- jail_release2 (clear ground, sidewalk only)
   =====================================  north wall, Y 3940
            [ 29489 ]   OUTER gate  Land_ConcreteWall_01_l_gate_F, mission.sqm, server-visible today
   ======            ======  recess steps in to Y 3934
            [  YOUR  ]   INNER gate  Land_BackAlley_01_l_gate_F, [9767.504,3932.509], mapData row 13445
             exitJail    named sqm object, Eden id 29535, 1.05 m away, referenced by nothing in the repo
   ======            ======
                yard      Land_BC_Court_F [9766.07,3894.46]  — 43 m from any wall
   cellblocks  Land_Barracks_01_dilapidated_F  [9750.0,3879.8] and [9782.5,3909.5]
```

Both gates opening is the escape route. The outer gate needs no map-pipeline change at all.

### 3.3 The gate the owner named cannot be animated as it stands

`[9767.47,3933.11,0.14]` resolves to mapData row 13445, 0.60 m away:

```
["Land_BackAlley_01_l_gate_F",[9767.504,3932.509,0.032],[[0.0000,1.0000,0.0000],[0.0000,0.0000,1.0000]],"",false]
```

The 5th field `false` means `initServer.sqf:160-162` never spawns it server-side; clients build it in
`core/functions/fn_createVehicleLocal.sqf:8` as `createSimpleObject` and then call `enableSimulation false`
(`:16`) and `enableDynamicSimulation false` (`:26`). A simple object is a baked statue: no doors, no animation
sources, and no networked object for the server to resolve. `animate` / `animateSource` / `animateDoor` are
inert on **every** machine, not merely on the server.

The owner chose to promote it. The precedent is in the same file: `fn_mapData.sqf` already carries an Altis
row of this same class with `"_serverObject = true;"` and a 5th field of `true`.

## 4. Decisions the owner made

| # | Decision | Choice |
|---|---|---|
| 1 | Which object the hack drives | **Promote row 13445** — the owner's exact gate becomes one real networked object |
| 2 | Event identity | **Same event, gate is the trigger.** One machine, one cooldown, one cop-cancel |
| 3 | "1 escape from jail" | **Charge 13, already built.** No stat slot, no consumable pass |
| 4 | Which walls contain prisoners | **The wall ring** (revised from the non-existent fence ring; see 3.1) |
| 5 | How the gate is hacked | **Scroll-action breach**, the Fed perimeter-gate shape |
| 6 | The designer's escape tunnel | **Sanctioned escape route** |
| 7 | Cop disarm | **Any cop, at the gate, server-validated.** Success closes the window, re-locks, re-arms cooldown |

## 5. Design

### 5.1 Foundation — four markers

Created in `initServer.sqf` in the guarded shape that file already uses three times (`fed_reserve` at
`:96-102`, the bank doors at `:108-118`): test `getMarkerPos == [0,0,0]`, `createMarker`,
`setMarkerAlpha 0`, `diag_log` the resolved position. Every position below was checked for geometry
collisions — nothing but sidewalk within 6 m of the release point, and the yard points sit on the
basketball court and its cobblestone pad.

| marker | position | role |
|---|---|---|
| `jail_marker2` | `[9767.0, 3893.0]` | intake / cell spawn, yard centre. Altis put intake ~1.5 m from the TP-back point; matched. |
| `jail_marker_loonybin` | `[9766.1, 3894.5]` | TP-back target — the basketball court, 43 m from any wall |
| `jail_release2` | `[9769.3, 3948.0]` | 8 m **outside** the outer gate. Altis had it 55 m outside the poly; matched. |
| `corrections` | `[9765.2, 3895.3]` | map label + event anchor — the designer's own `marker_16` "Malden Prison", inside sqm Layer `Prison` |

`corrections` also gets the text and `ColorWEST` that `fn_startPrisonBreak:65-66` restores it to at the end of
every break, so a boot and a completed break agree.

**Consumers that wake up the moment these exist,** each to be checked against the real position before the
commit: `fn_jailMe.sqf:1,96,121,127,133`; `core/civilian/fn_jailPlayer.sqf:15-19`;
`core/actions/fn_useShank.sqf:3` (70 m); `core/actions/fn_gatherObject.sqf:6` (200 m gather ban);
`core/fn_setupActions.sqf:980` (bounty-hunter arrest, 19 m) and `:1107` (cop Send to Prison, 30 m — the only
reachable branch on Malden, since all seven `AP_police_hq_polys` are still Altis);
`core/cop/fn_copInteractionMenu.sqf:53`; `dialog/function/fn_prisonBreakQuery.sqf:2` (100 m);
`initPlayerLocal.sqf:426` (350 m HUD); `core/functions/fn_dynamicMapSystem.sqf:14` (110 m streaming
exclusion); `core/compat/fn_trialBegin.sqf:77`; `core/compat/fn_startPrisonBreak.sqf:18,22,23,32,46,53,65,66`;
`server/AP_server/init.sqf:1059`; `server/AP_server/core/jail/fn_trialRequest.sqf:21`;
`server/AP_server/core/TON/fn_handlePrisonBreak.sqf:178,179,239,240`.

### 5.2 Foundation — the containment polygon

`AP_jailPoly` is replaced in `core/configuration.sqf:2`. That line is minified and append-only: edit the
one assignment in place, do not reformat the line.

Traced from the 88-piece wall ring — angular ordering around the ring centroid (which drops the two inward
buttress spurs that made a naive nearest-neighbour walk self-intersect), then Douglas-Peucker at 5 m:

```sqf
AP_jailPoly=[[9721.2,3893.2,0],[9714.7,3884.0,0],[9742.1,3852.0,0],[9786.5,3850.7,0],[9810.6,3874.6,0],[9810.6,3916.0,0],[9786.7,3940.0,0],[9745.3,3940.0,0],[9722.5,3919.1,0]];
```

9 vertices, 6,875 m². Verified point-in-polygon: the inner gate, `exitJail`, both cellblocks, the yard centre
and the tunnel mouth all test **inside**; the outer gate tests **outside** by 0.2 m, which is correct — it sits
*in* the wall line. The poly deliberately spans the recess mouth rather than following the wall into it, so a
prisoner standing at the inner gate is still contained.

5.1 and 5.2 must ship in the same commit.

Note for later: `AP_warzonePoly`, `AP_drugPenPoly`, `AP_eviFencePoly` and all seven
`AP_*_hq_poly` on that same line are also still Altis. The jewelry poly on the line was already
re-coordinated, so this is a half-finished pass. Out of scope here, but the jail poly is not the last one.
`AP_jailPos = getMarkerPos "corrections"` on the same line has zero readers and is not a hook.

### 5.3 Promote the gate

`core/config/fn_mapData.sqf` row 13445, matching the existing precedent row for this class verbatim:

```
- ["Land_BackAlley_01_l_gate_F",[9767.504,3932.509,0.032],[[0.0000,1.0000,0.0000],[0.0000,0.0000,1.0000]],"",false]
+ ["Land_BackAlley_01_l_gate_F",[9767.504,3932.509,0.032],[[0.0000,1.0000,0.0000],[0.0000,0.0000,1.0000]],"_serverObject = true;",true]
```

The rotation vectors are reproduced verbatim from the file — the row is one entry on a single minified line,
and only the 4th and 5th fields change.

The same edit goes into the byte-identical duplicate at `mission/Armapunk2035.Malden/mapImportAll_data.sqf` (mission ROOT, not core/config). Edits go through
`tools/eden_region.py` / `tools/mapdata_to_eden.py` (see `tools/MAP_EDITING.md`).

Side effect, intended: `core/functions/fn_dynamicMapSystem.sqf:11` skips `_xIsServer` rows, so the gate stops
being N client-local statues and becomes one real object.

A boot resolver in `initServer.sqf` publishes two handles so no client ever supplies a gate:

* `AP_prisonGateIn` — the promoted inner gate
* `AP_prisonGateOut` — the outer sqm gate, found by `nearestObjects`

Gates are driven with the enumerating primitive at
`server/AP_server/core/TON/fn_maldenJewelSRV.sqf:120-131` (`_fnc_driveGate`): `bis_disabled_Door_N` for
N = 1..`numberOfDoors`, then `animate` over the enumerated animation names, then the
`door_1_sound_source` / `door_1_noSound_source` pair, then `gate_max`. The bank drives the same class at
`fn_maldenBankSRV.sqf:68-94`. **Door counts and animation names are enumerated at runtime, never hardcoded** —
`Land_BackAlley_01_l_gate_F`'s set has not been read from config (no game available during design).

### 5.4 The hack

The Fed perimeter-gate shape, which is the lowest-risk path in the tree because the server trusts no payload:

1. Scroll action offered on **proximity** to `AP_prisonGateIn`, gated on `AP_fnc_hasDeck`.
   **Never `cursorObject`.** `.superpowers/sdd/gate-cursor-report.md` records the measured failure: on a
   large wall-gate the cursor ray lands on the paving slab underfoot, so the exact-match clause can never be
   satisfied at usable range, and the Fed event was unstartable because of it.
2. Registering the action needs care: `core/fn_setupActions.sqf:2` is `private _plb_obj = player;`, so
   anything registered there attaches to the **player** — `_this select 0` is the player and any
   `player distance _target` gate silently becomes 0. Either host the action on `exitJail` / the gate object,
   or pass `cursorObject` explicitly the way the jewelry gate condition does (`fn_setupActions.sqf:878-879`).
3. Success runs `AP_fnc_cyberdeckSeq` (blocking; difficulty = buffer length 3..12; returns 1 breach /
   0 trace-fail / −1 abort; short-circuited by `AP_breachKitArmed`).
4. On breach: `[["gatehack"], "APS_fnc_prisonGateSRV", 2]` — a bare literal, no trusted payload.

Rejected: a catalogue quickhack row. The phone console cannot lock a world object at all
(`core/items/fn_qhConsole.sqf:170-171` scans only `CAManBase` and `Car/Air/Ship/Tank`, and the ICEBREAKER OS
button nulls `AP_cdTarget`), so it would work only from the SHIFT+Y VR dock via `targetKind "area"` with
server-side object resolution; no existing quickhack has a minigame; and `APS_fnc_qhSRV:26` takes the hacker's
identity from argument 3 of the client's own array, which every check downstream then runs against.

### 5.5 The 10-minute window

The server call goes into `APS_fnc_handlePrisonBreak` **mode 1 with all five existing guards intact** — active
check (`:43`), `APS_fnc_fedEventActive "prison"` exclusivity (`:45`), tenured cops (`:74`), the 30-minute
re-run cooldown (`:89`), and the 15-minute `SRV_lastRobbery` cross-heist lockout. All five `exitWith` a
broadcast **above** the `SRV_prisonData` stamp, so a refusal leaves no state.

`fn_startPrisonBreak` then changes in one place, its hold `waitUntil` at `:50`. Today it requires the breaker
to stay alive, unrestrained, out of vehicles and within 500 m of where the break started — a hold anchored on
the laptop. A hacker who cracked a gate is not holding anything, so the new condition watches two things only:
the 600 s clock, and a published disarm flag. `_breakTimer` becomes 600 for Malden, and the success test at
`:55` drops the hold clauses to match.

**This replaces the hold outright — it is not a second branch.** The only caller of the hold semantics was
`AP_fnc_doPrisonBreak`, which has no callers of its own (2.3), so no live path depends on the 500 m anchor,
and there is no "laptop mode" left to preserve. One code path, one timer.

**Which copy executes:** the mission compat copy, `core/compat/fn_startPrisonBreak.sqf` — mission
`CfgFunctions` shadows the addon's. This is recorded in the file's own header as a production incident: it once
shipped as `if (true) exitWith {};` and that no-op shadowed the real `@AP_server` implementation, so the
prison break never ran at all. The twin at `server/AP_server/core/jail/fn_startPrisonBreak.sqf` is
byte-identical below an 8-line header and gets the identical change, so they cannot drift.

Three unrelated `AP_fnc_` names in `core/compat/` are `if (true) exitWith {};` stubs that shadow working
server code — `jailSys`, `wantedPardon`, `setRestrained`. Every live caller uses the `APS_` tag. **Never call
the `AP_fnc_` name for those three.**

### 5.6 Release

No new release code. `fn_prisonBreakQuery` and `fn_prisonBreaker` already deliver the opt-in and the flip, and
`fn_jailMe.sqf:122-127` already keeps the bounty and adds charge 13.

**One change: drop the `setPos (getMarkerPos "jail_release2")` at `:127`.** The containment test lives *inside*
the loop that `:91` exits on breakout, so the moment a prisoner accepts, they are no longer contained. Let them
walk out through the open sally port, or take the tunnel. The open gate becomes the thing that matters instead
of scenery. The bail branch (`:121`) and the served-sentence branch (`:133`) keep their teleport to
`jail_release2`.

This also means **no containment-exemption flag is needed anywhere.** The escape and the poly never fight,
because breakout leaves the loop before the poly test runs.

`fn_jailMe.sqf:110-117` is load-bearing and must not be bypassed by any new path: it clears `AP_arrested`
(public), resets `AP_is_arrested` and `AP_jailReleaseTime`, fires partial-5, zeroes `AP_inv_shank`,
clears `AP_action_in_use`, and calls `[true] spawn AP_fnc_loadGear`. A release that skips it leaves the
player either flagged arrested — a hard lockout across ~30 systems — or unflagged and still in jail gear.

### 5.7 The tunnel

`enterMine` (sqm id 29537, `[9796.5,3861.85]`, 45.8 m from the prison marker and inside the wall ring) gets the
condition it has never had. Its `addAction` comes from `initPlayerLocal.sqf:448` →
`custom_p3ds/malden_atmosphere.sqf:58-64` with a condition string of `""` — literally no condition, 5 m
radius — and teleports to the cave at `[2985.082,7089.092]`. `escapeJail` in the cave (sqm id 28430) returns
players to `[9893.784,2809.292]`, ~1.09 km south of the prison, with the comment `// jail break exit`.

As it stands a prisoner can walk out of the prison right now with no hack at all; and once the poly is live,
the same action becomes a 1 Hz teleport loop. Gating it on the escape being live makes it the second exit.

`exitMine` is expected by `malden_atmosphere.sqf:63` but is absent from the sqm, so the guarded `_fnAdd` logs
and skips it — the cave has no way back in. Left as is.

### 5.8 Cop disarm

Client side reuses `core/cop/fn_stopPrisonBreak.sqf:2-32` wholesale — five pre-guards and the standard
`AP_progress` bar on controls 38201/38202 — as a 30 s hold at the gate.

Server side does **not** copy the existing shape. `APS_fnc_handlePrisonBreak` case 2 (`:213-242`) checks
`side _caller isEqualTo west` and nothing else; the 12 m range and the 30 s hold live only in the client, so
one cop can cancel the event from anywhere on the map. The disarm instead follows `fn_maldenFedSRV.sqf:189-205`
`_fnc_caller`: derive the caller from `remoteExecutedOwner`, then re-validate alive / `west` / not restrained /
`vehicle _x == _x` / within 15 m of the gate.

Success closes the escape window, re-locks the gate, and arms the 30-minute cooldown.

**Sally-port weld rule.** `fn_maldenJewelSRV.sqf:43-50` records it: a gate sealed with no reachable opener is
welded for the life of the server, because sealing runs at boot *and* at every window close while `["open"]` is
the only release. So only the **outer** gate is sealed and re-locked; the inner gate is never sealed, and cops
can always walk prisoners in even with the hack on cooldown or refused. The Fed leaves two pedestrian gates
unsealed for exactly this reason (`fn_maldenFedSRV.sqf:279-290`).

Any `-SEC-` row raised on this path takes its subject from `remoteExecutedOwner`, never from the payload — the
payload is precisely what a forged call would use to manufacture evidence against an innocent player.

### 5.9 Signalling and HUD

The cop-facing chain is already written and currently dead, because `fn_newDispatch.sqf:11-12` suppresses the
map marker when the position is `[0,0,0]` or x ≤ 0. Section 5.1 turns all of it on with no new code:
broadcasts to civilian and west (`fn_startPrisonBreak:25-26`), `createDispatch "Prison Break"` at $5,000
(`:32`), `corrections` turned red and relabelled "Prison [Break in Progress]" (`:22-23`), and `Sound_Alarm` at
the prison (`:18`).

Added: cops get the existing `fed_countdown` message style, a 10-minute draining bar, which matches the window
exactly — rather than the single 15 s `federaleventcop` popup.

Two fixes to the participant bar at `initPlayerLocal.sqf:412-437`:

* `_dur = 500` is hardcoded, with a comment asserting it matches the break timer. The timer is **800**
  (`fn_startPrisonBreak:48`). The bar reaches 100% 300 s early — the "stuck at 87%, nothing happens" look.
  It becomes 600, matching the window.
* `_participant` snapshots `(player distance2D (getMarkerPos "corrections")) < 350` at kickoff, which today
  means an audience of nobody. Fixed by 5.1.

`dialog/chat_hud.hpp:24-32` `AP_prison_hud` (idd 247000, control 247001) is orphaned — the 2026-06-17 rework
replaced it with the standard `AP_progress` bar and nothing feeds it. Left inert; not revived.

**Alarm-source leak — fixed by 5.5, with no new state.** `_soundOn` at `fn_startPrisonBreak:18` is a **local**,
deleted only at `:64` when the hold thread reaches its own end. Today a cop stop ends the event by a different
path, so the siren plays until restart. The first instinct is the Fed's fix — publish the handle
(`AP_fedAlarmSound`, `fn_fedAlarm.sqf:77-81`) so any end path can delete it. That is unnecessary here: the
replacement `waitUntil` in 5.5 exits on the disarm flag **and** on `SRV_prisonData` slot 1 going false, so all
three end paths (expiry, cop disarm, the 1200 s watchdog) now fall through to the existing `deleteVehicle` at
`:64`. One condition change fixes the leak and the orphaned-thread bug together; no published handle is added.

### 5.10 MaxTac — made safe, coordinates outstanding

`fn_startPrisonBreak:39-44`'s `_maxtacPos = switch (worldName)` has cases for Altis, Tanoa, Stratis and
Australia, **no Malden case and no default**. `_maxtacPos` is therefore nil and
`core/compat/fn_maxtacDispatch.sqf:50` evaluates `(_locations select 0) select 1` on it. The bank's equivalent
table (`fn_bankDrillVault.sqf:93`) has a default; this one does not.

Make-safe: if the world has no table, skip MaxTac and log it. The event still runs.

**Insertion coordinates are not invented here.** Malden has no cop spawn markers at all —
`dialog/function/fn_spawnPointCfg.sqf` references `cop_spawn_1..7`, and `custom_p3ds/malden_markers.sqf`
creates exactly one marker, `civ_spawn_1` at La Trinite, from `CfgWorlds >> Malden >> Names`. Four Malden
insertion positions are needed from the owner or the designer. Until then MaxTac is off for this event. This
also means cops have no spawn points on Malden at all, which is a separate problem worth raising.

### 5.11 Restart behaviour

Sentences persist: `AP_is_arrested` slot 2 is refreshed every tick (`fn_jailMe.sqf:105`) and flushed every
60 s via partial-5 to `players.arrested`. The 10-minute window does not — it is a server global, the same as
every other heist. A restart mid-window strands prisoners mid-decision: they reload still arrested, serving the
remainder, with no escape offer. Accepted; the existing 1200 s watchdog clears `SRV_prisonData` so a new break
can start. No new persistence is added.

### 5.12 Latch and end paths

`AP_prisonEndArmed` is a one-shot latch, seeded true at `server/AP_server/init.sqf:280` and opened in
exactly one place — case 1's `SRV_prisonData` stamp, below every guard. Three end paths test and close it
(natural expiry, cop disarm, the 1200 s watchdog), with no suspension point between read and write, so under
SQF's cooperative scheduler the check-and-set is atomic. First end wins; the other two become no-ops. The gate
trigger changes none of this.

## 6. Risks accepted, and why

**Containment is client-side and stays that way.** The 104 outer wall pieces, 26 fence pieces, both barracks
and the watchtowers are all client-local `createSimpleObject` rows with simulation disabled. The server cannot
see, animate, damage or delete any of them, and cannot verify that a prisoner is physically inside anything. A
modified client that skips `fn_jailMe.sqf:94` walks out of the yard with no server-side consequence. This is
pre-existing and unchanged by this work; making it authoritative is a separate project.

**The release decision runs on the prisoner's own client.** `AP_breakout` is a plain client global. The only
thing standing between a modified client and a free release with full bounty is the AND with server state at
`fn_jailMe.sqf:91`, `(SRV_prisonData select 1) && AP_breakout`. This design adds no new client-reachable
flag to that expression — which is the single most important constraint on any future change here.

**And that AND is weaker than it reads.** `deploy/battleye/publicvariable.txt` is the single rule `1 ""`, and
action 1 is LOG, not kick or block (recorded in `TODO.md` under the 2026-07-28 findings). So a modified client
can broadcast any public variable it likes, `SRV_prisonData` included, and the server only writes a log line.
Every server-authority gate that leans on a published global — `SRV_prisonData`, `SRV_lastRobbery`,
`AP_tenuredCopCount` — is affected. Nothing in this design makes it worse, and the cop disarm is deliberately
built on `remoteExecutedOwner` rather than on published state for exactly this reason. But the release gate is
not sound until a real BE whitelist lands on the box (allow server-originated names, kick on client-originated
writes). That is box configuration, not git-tracked here.

### 6.1 Pre-existing prison-break bugs this work fixes as a side effect

All four are recorded independently in `TODO.md` under the 2026-07-28 findings, and none were introduced here.
Replacing the hold `waitUntil` (5.5) resolves the first two outright:

* **A cop-stopped break left an orphaned `startPrisonBreak` running.** Its `waitUntil` watched the breaker, not
  `SRV_prisonData`, so after a cop stop the script ran on to re-broadcast its own failure message and re-restore
  the marker. The replacement condition watches the window and the disarm flag, so the thread ends when the
  event does.
* **The "restrained" abort path never worked.** Both the `waitUntil` and the success test read
  `_unit getVariable ["restrained", false]`, and nothing in the tree sets a variable of that name — the codebase
  uses `AP_restrained`. The hold clauses go away entirely, so the dead check goes with them.
* **The progress bar finished 300 s early** — fixed in 5.9.
* **`SRV_prisonData select 2` reads a slot that does not exist**, at both client read sites, falling through to
  a default of 1 while the server reads `param [2, 1]`. They agree only by coincidence. Not fixed here (it is
  not on this design's path), but any touched read site uses `param`, never `select`, so this work adds no new
  instance of it.

**Client-authoritative bail is a parallel bypass.** `core/actions/fn_postBail.sqf` debits the client's own
`AP_atmcash` and sets `AP_bail_paid`, which `fn_jailMe.sqf:90` trusts with no server validation. Untouched
here, and no new sink copies that trust model.

**`SRV_prisonData` cannot be extended.** It is seeded two-element at `init.sqf:267` and slot 2 is interpreted
as the cop-count requirement by both sides (`fn_handlePrisonBreak.sqf:73`, `fn_doPrisonBreak.sqf:19`), with an
explicit warning at `init.sqf:273-275` not to stuff other state into a spare slot. Nothing in this design
writes a third slot.

**Stat-slot corruption is adjacent but not touched.** `prisonsdone` (slot 118) has no writer; the two prison
titles (`core/config/fn_titleCfg.sqf` ids 139 "Alcatraz Warden" and 217 "Escape Artist") read slot 109, which
holds corn; `moneyspentbail` writes slot 91 while `fn_titleCfg` and `fn_talSRV.sqf:33` read slot 82. Choosing
charge 13 over a new escape counter keeps this design clear of all of it. Verified-free slots, if one is ever
wanted: 27, 62-65, 110-113, 126, 128, 140-142.

**The boot bar-gate opener is not a conflict here.** `server/AP_server/init.sqf:1074` force-opens every
`Land_BarGate_F` on the map at every boot, unconditionally. The nearest one (sqm id 29581 at
`[9683.81,3869.62]`) is 34 m **outside** the wall ring — it belongs to the military camp, not the prison. No
interaction with this work.

**Unverified at design time.** All of the above is static analysis; no game was available. Specifically:
`Land_BackAlley_01_l_gate_F`'s `numberOfDoors` and animation-name set were not read from config (hence the
runtime enumerator), and no prisoner has been jailed on Malden to watch the `[0,0,0]` teleport manifest.

## 6.2 Verified on dev, and what is still owed

Run on dev b0134-b0138. **Verified:**

* **The bug was real.** Before the fix, on the running server:
  `-JAILPROBE- markers m2=[0,0,0] loonybin=[0,0,0] release2=[0,0,0] corrections=[0,0,0]`.
* **All four markers now create at their real positions**, logged individually at boot.
* **The packed PBO carries the new polygon** and contains zero occurrences of the Altis one. The poly
  itself was checked geometrically: 9 vertices, 6,875 m², with the inner gate, `exitJail`, both
  cellblocks, the yard and the tunnel mouth inside, and the outer gate outside by 0.2 m.
* **The gate promotion took.** `gateIn = Land_BackAlley_01_l_gate_F null=false at [9767.5,3932.51]` —
  the server had previously seen *no* gate at that point, only the outer one 8 m away.
* **The two gates have different animation sets**, which is why they are enumerated and not hardcoded:
  inner `["door_1_rot","door_1_handle_rot_1","door_1_handle_rot_2","door_1_locked_rot","door_1_handle_locked_rot"]`,
  outer `["door_1_move","door_1_locked_move"]`. The `locked` filter is load-bearing on both.
* **The gate drive works, including the case the write-order exists for.** Boot seal →
  `disabled_1=1 gate_max=0 phase=0`; opened by hand → `phase=1`; `["relock"]` → `phase=0`.
* **The 200 m gather ban clears every wired field by 2,555 m** (nearest is `oil_3` at 2,755 m). Every
  other marker-gated range was checked against the real position.
* **All six edited client files parse**, via `compile preprocessFileLineNumbers` from the server — the
  dedicated server never compiles them, so a syntax slip would otherwise surface only as a player's
  entire scroll menu silently vanishing.
* **The balance gate passes** on all thirteen edited files, and the `startPrisonBreak` twins are
  byte-identical below the 8-line compat header (the server copy is regenerated from the mission copy).
* **Both scroll actions landed in the correct `playerSide` case** — the breach in `case civilian:`, the
  disarm in `case west:`. The Fed gate they were modelled on sits inside an
  `if(player distance getMarkerPos"fed_reserve"<=400)` block, which would have made either action
  offer only near the Fed.

**Not verified — needs a client:** in-game containment (intake, no teleport, the wall message), the
scroll options appearing and disappearing at their radii, and the three runs in §7 step 4 (cops answer /
cops do not / refusals leave nothing behind).

**One pre-existing error, ruled out as ours:** `Error: Object(2 : 344) not found` appears at boot in
b0137 and b0138 — two deploys with entirely different changes — several seconds *before* the gate
resolver runs, with no clients connected. Pre-existing restart noise.

## 7. Verification plan

No test harness exists in this repo — SQF runs in-engine — so verification is staged and manual.

0. **Run `debug/frame_probe.sqf` first.** It already carries seven prison rows, and its `[FRAMEPROBE]` output
   is not in the repo. The sqm↔runtime position-frame delta is real and was measured at 1.7 m for the jewelry
   gate (`fn_maldenJewelSRV.sqf:305-312`). No gate search radius is chosen below ~5 m until that log is read.
1. `python3 tools/sqf_balance.py` on every edited file — the repo's standing pre-deploy gate, and Arma-aware
   (`""` is an escaped quote; comments skipped; stack-based, never per-line deltas).
2. Compile-probe the edited client functions from `initServer.sqf` with
   `compile preprocessFileLineNumbers`, which parses without running and logs ok/FAILED per file. Removed
   before shipping. This is how the gather-fields pass validated client SQF with no client attached; the
   dedicated server otherwise never compiles those files, so a syntax slip shows up only as a player's entire
   scroll menu silently vanishing.
3. DEV deploy (`bash /home/timb/arma3server_dev/reload-loonydev.sh`), wait for the "read from bank" marker,
   then confirm four `[maldenPrison] ... marker created at ...` lines and the gate resolver's log for both
   handles. **Any `[0,0,0]` in those lines stops the deploy.**
4. Jail yourself (cop Send to Prison, or admin jail): intake lands in the yard, there is no 1 Hz teleport,
   and walking past the wall produces "Stay within the confines of the yard!" and returns you to the court.
5. Two clients for the hack, both branches:
   * hack → cop disarm → siren stops, both gates re-lock, 30-minute cooldown armed;
   * hack → let the full 600 s run → the escape query fires, bounty survives, charge 13 lands, both gates
     open, and the prisoner walks out on foot.
6. Check `-JAILDBG-` and `-SEC-` rows for each run. Client-side errors land in the Proton RPT, not the server
   log.

## 8. Files this touches

| file | change |
|---|---|
| `mission/Armapunk2035.Malden/initServer.sqf` | four markers; gate resolver publishing `AP_prisonGateIn` / `AP_prisonGateOut` |
| `mission/Armapunk2035.Malden/core/configuration.sqf` | `AP_jailPoly` (line 2, minified — edit in place, do not reformat) |
| `mission/Armapunk2035.Malden/core/config/fn_mapData.sqf` | row 13445 promoted |
| `mission/Armapunk2035.Malden/mapImportAll_data.sqf` | same edit, byte-identical dup at `:66` |
| `mission/Armapunk2035.Malden/core/fn_setupActions.sqf` | breach scroll action, proximity-gated |
| `mission/Armapunk2035.Malden/core/actions/` | new breach action fn (minigame → server call) |
| `mission/Armapunk2035.Malden/core/civilian/fn_jailMe.sqf` | drop the `setPos` at `:127` |
| `mission/Armapunk2035.Malden/core/cop/fn_stopPrisonBreak.sqf` | retargeted at the gate |
| `mission/Armapunk2035.Malden/core/compat/fn_startPrisonBreak.sqf` | hold `waitUntil` → clock + disarm flag; `_breakTimer` 600; publish the alarm handle; MaxTac make-safe |
| `server/AP_server/core/jail/fn_startPrisonBreak.sqf` | identical change (byte-identical twin) |
| `mission/Armapunk2035.Malden/custom_p3ds/malden_atmosphere.sqf` | `enterMine` condition |
| `mission/Armapunk2035.Malden/initPlayerLocal.sqf` | `_dur` 500 → 600 |
| `server/AP_server/core/TON/fn_prisonGateSRV.sqf` | **new** — gate drive, window, authoritative disarm |
| `server/AP_server/core/TON/fn_handlePrisonBreak.sqf` | disarm routed to the authoritative caller check |
| `server/AP_server/config.cpp` | register the new server fn |
| `mission/Armapunk2035.Malden/Functions.h` | register the new client fn |
| `mission/Armapunk2035.Malden/CfgRE.hpp` | entry for the new server fn, `allowedTargets = 2` |

`CfgRE.hpp` is `mode = 1` (whitelist): a new cross-machine function without an entry fails silently. A new
`case` inside an existing whitelisted function needs no entry.

## 9. Open items for the owner

1. **Four Malden MaxTac insertion positions** (5.10). Until then MaxTac is off for this event.
2. **Minigame difficulty** for the gate breach — the Fed gate uses `[10] call AP_fnc_cyberdeckSeq`; buffer
   length is 3..12.
3. **Cops have no spawn points on Malden** (`cop_spawn_1..7` referenced, none created). Out of scope, but it
   is a live gap.
4. **The other Altis polygons** on `configuration.sqf:2` are still Altis (5.2). The jail poly is not the last
   one to re-coordinate.
