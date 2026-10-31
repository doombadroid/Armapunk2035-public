# Malden Prison Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make Malden's prison work — fix the containment that currently teleports every prisoner to map origin, and give the prison break a working trigger: hack the north sally-port gate, 10 minutes on the clock, cops can disarm it, survivors get the escape offer.

**Architecture:** Four global markers plus a re-traced containment polygon fix the foundation. The gate at `[9767.504,3932.509]` is promoted from a client-local statue to one real networked object and resolved at boot into `AP_prisonGateIn` / `AP_prisonGateOut`. A client scroll action runs the Sequence Breach minigame and calls a new server function, which validates the caller and hands off to the existing `APS_fnc_handlePrisonBreak` mode 1 with all five of its guards intact. The 10-minute window replaces `fn_startPrisonBreak`'s hold condition. Release, opt-in dialog and the bounty/charge payload already exist and are not rebuilt.

**Tech Stack:** SQF (Arma 3), extDB3, mission PBO + `@AP_server` addon. Full design rationale: `maldenprison.md`.

## The verification cycle in this repo

**There is no test harness. SQF runs in-engine, and nothing in this repo can assert on a function's
return value outside a running server.** Do not write or invent a unit-test framework — the honest
red/green cycle here is a boot-time or in-game **probe** that logs the value under test, observed
failing before the change and passing after.

Every task below uses this cycle:

1. **Probe (RED).** Add a temporary `diag_log` that prints the value the task is about to change.
   Deploy. Read the log. **Confirm it shows the broken value.** If it already shows the correct
   value, stop — the premise is wrong and the task needs re-scoping, not implementing.
2. **Implement.**
3. **Balance-check.** `python3 tools/sqf_balance.py <each edited file>` — exit 0 required. This is the
   repo's standing pre-deploy gate and it is Arma-aware (`""` is an escaped quote, not `\"`;
   comments skipped; stack-based, never per-line deltas).
4. **Probe (GREEN).** Redeploy. Read the log. Confirm the correct value.
5. **Remove the probe**, balance-check again, commit.

Commands used throughout:

```bash
# balance gate (run on every edited file, every time)
python3 tools/sqf_balance.py <file> [<file> ...]

# DEV deploy — packs the PBO and restarts. DEV deploys are free; live is stage-only.
bash /home/timb/arma3server_dev/reload-armapunk2035.sh

# wait for boot to finish (~40-90s); this marker means the server is up
grep "read from bank" /home/timb/arma3server_dev/loonydev.log

# read probe output
grep -E "JAILPROBE|maldenPrison|GATEPROBE" /home/timb/arma3server_dev/loonydev.log

# client-side errors land in the Proton RPT, NOT the server log (newest by mtime)
ls -t ~/.local/share/Steam/steamapps/compatdata/107410/pfx/drive_c/users/steamuser/AppData/Local/Arma\ 3/*.rpt | head -1
```

**Server vs client, and it matters for where probes go:** `core/configuration.sqf` is loaded
**client-only** — `core/init.sqf:19` does
`[] call compile PreprocessFileLineNumbers "core\configuration.sqf"`, and `core/init.sqf` is
`execVM`'d from `initPlayerLocal.sqf:65`. So `AP_jailPoly` **does not exist on the server**. Any
probe that reads it must run on a client. Marker positions are readable from either side.

**A second client-side trap:** the dedicated server never compiles the client function files, so a
syntax error in one shows up only as a player's entire scroll menu silently vanishing — no error
anywhere. Task 10 carries the compile-probe that catches this.

## Global Constraints

Every task's requirements implicitly include all of these. Values are copied verbatim from
`CLAUDE.md`, `maldenprison.md` and the repo's standing orders.

- **Branch:** `main` in `~/Armapunk2035`. `git fetch origin` before starting — collaborators push
  straight to `origin/main`. (As of writing: 0 behind, **113 ahead** and unpushed.)
- **Commit trailer:** `Co-Authored-By: <funny defunct AI>` — name only, **no email**. Rotate; do not
  repeat back-to-back. Recently used, do not reuse: SmarterChild, Kitt, Zenbo, EmoSPARK, Boibot,
  Leachim, Speaktoit, Moxie, MGonz. **This overrides the harness default Claude/Anthropic trailer.**
- **Never name other Arma servers** — their staff, PBOs, dev handles or branded feature names —
  anywhere git-tracked.
- **`core/configuration.sqf` line 2 is a huge minified data line.** Edit the one assignment in place.
  **Never reformat the line.**
- **`CfgRE.hpp` is `mode = 1` (whitelist).** A new cross-machine function without an entry fails
  silently. `allowedTargets = 2` means client→server, `1` means server→client, `0` any. A new `case`
  inside an already-whitelisted function needs no entry.
- **Always call through `AP_fnc_MP`**, never raw remoteExec:
  `[[args], "fn_name", target, false] spawn AP_fnc_MP`.
- **Mission `CfgFunctions` shadows the addon's.** For any function with a `core/compat/` twin, the
  **mission** copy executes. `fn_startPrisonBreak`'s twins are byte-identical below an 8-line header
  and are synced **by hand** — no tooling regenerates them. Both get every change.
- **Never call `AP_fnc_jailSys`, `AP_fnc_wantedPardon` or `AP_fnc_setRestrained`** — those
  mission compat copies are `if (true) exitWith {};` stubs shadowing working server code. Live
  callers use the `APS_` tag.
- **Gates are offered on proximity, never `cursorObject`.** On a large wall-gate the cursor ray lands
  on the paving slab underfoot; this already made the Fed event unstartable
  (`.superpowers/sdd/gate-cursor-report.md`).
- **Never hardcode a door count or an animation name.** Enumerate at runtime.
- **`-SEC-` and audit rows take their subject from `remoteExecutedOwner`, never from the payload** —
  the payload is what a forged call would use to manufacture evidence against an innocent player.
- **Read `param`, not `select`, on `SRV_prisonData`.** It is seeded 2-element; `select 2` yields nil.
- **No gate search radius below ~5 m** until `debug/frame_probe.sqf`'s output has been read (Task 3
  step 1). The sqm↔runtime position delta is real — 1.7 m measured on the jewelry gate.
- **`UI_GRID_*` macros must be BARE**, never inside quotes — a quoted macro produces an invisible
  dialog with no error. (No dialogs are added by this plan, but Task 9 touches HUD code.)
- **DEV deploys are free. LIVE is stage-only** — never deploy or reboot live without the owner saying
  so that time. Deploy freeze 22:00–09:00.

---

### Task 1: Prison anchors — four markers and the containment polygon

The two edits ship together. Poly without markers reproduces the origin teleport exactly; markers
without the poly removes containment entirely.

**Files:**
- Modify: `mission/Armapunk2035.Malden/initServer.sqf` (marker block, after the bank-door block at `:108-118`)
- Modify: `mission/Armapunk2035.Malden/core/configuration.sqf:2` (`AP_jailPoly`, in place)
- Probe: `mission/Armapunk2035.Malden/initPlayerLocal.sqf` (temporary, client-side — the poly is client-only)

**Interfaces:**
- Consumes: nothing.
- Produces: global markers `jail_marker2`, `jail_marker_loonybin`, `jail_release2`, `corrections`;
  `AP_jailPoly` as a 9-vertex closed polygon of `[x,y,0]` triples. Tasks 3-10 and ~16 existing
  consumers read these by name.

- [ ] **Step 1: Write the probe (RED)**

Append to `mission/Armapunk2035.Malden/initPlayerLocal.sqf`, at the very end of the file:

```sqf
// -JAILPROBE- TEMPORARY, remove in step 6 of Task 1. Client-side on purpose: AP_jailPoly is loaded
// by core/configuration.sqf via core/init.sqf, which is execVM'd from this file, so the poly exists
// ONLY on clients. Marker positions are readable from either side and are logged here for one report.
[] spawn {
    waitUntil { !isNil "AP_jailPoly" };
    diag_log format ["-JAILPROBE- markers m2=%1 loonybin=%2 release2=%3 corrections=%4",
        getMarkerPos "jail_marker2", getMarkerPos "jail_marker_loonybin",
        getMarkerPos "jail_release2", getMarkerPos "corrections"];
    diag_log format ["-JAILPROBE- poly verts=%1 yardCentreInside=%2 outsideSouthWallInside=%3 firstVert=%4",
        count AP_jailPoly,
        ([9766.1, 3894.5, 0] inPolygon AP_jailPoly),
        ([9766.1, 3830.0, 0] inPolygon AP_jailPoly),
        AP_jailPoly param [0, []]];
};
```

- [ ] **Step 2: Deploy and confirm the probe FAILS**

```bash
python3 tools/sqf_balance.py mission/Armapunk2035.Malden/initPlayerLocal.sqf
bash /home/timb/arma3server_dev/reload-armapunk2035.sh
grep "read from bank" /home/timb/arma3server_dev/loonydev.log
```

Join with a client, then read the newest Proton RPT (the probe is client-side, so it lands there):

```bash
grep JAILPROBE "$(ls -t ~/.local/share/Steam/steamapps/compatdata/107410/pfx/drive_c/users/steamuser/AppData/Local/Arma\ 3/*.rpt | head -1)"
```

Expected, and this is the bug:

```
-JAILPROBE- markers m2=[0,0,0] loonybin=[0,0,0] release2=[0,0,0] corrections=[0,0,0]
-JAILPROBE- poly verts=4 yardCentreInside=false outsideSouthWallInside=false firstVert=[16809.6,13637.2,0]
```

All four markers at map origin; the poly is the 4-vertex Altis Pyrgos quad; the yard centre tests
**outside** it. If `yardCentreInside=true`, stop — the premise is wrong.

- [ ] **Step 3: Create the four markers**

In `mission/Armapunk2035.Malden/initServer.sqf`, immediately after the bank-door
`forEach ["AP_bank_door", "AP_bank_door_2"];` block:

```sqf
// MALDEN PRISON 2026-07-29. Malden's mission.sqm carries 228 markers and NOT ONE of the four the jail
// system addresses, and nothing created them at runtime -- so getMarkerPos returned [0,0,0] for all
// four, which is a real, reachable position rather than an error. Two live consequences: fn_jailMe's
// containment test teleported every prisoner to map origin once a second (AP_jailPoly was still the
// Altis Pyrgos quad, so inPolygon was false everywhere on a 12800 m world), and every range gate keyed
// on these markers was satisfied by anyone standing at origin -- shank at 70 m, escape query at 100 m,
// bounty-hunter arrest at 19 m, cop Send-to-Prison at 30 m -- while nobody could gather within 200 m of
// it. The marker sweep further down does NOT clean this: it deletes only markers outside world bounds,
// and x = 0 is neither < 0 nor > worldSize.
//
// Positions are the designer's own prison, not invented: the yard is Land_BC_Court_F at
// [9766.07,3894.46], inside the ring of 88 connected Land_Mil_WallBig_4m_battered_F pieces, and the
// label sits on his marker_16 "Malden Prison" in sqm Layer `Prison`. jail_release2 is 8 m OUTSIDE the
// outer sally-port gate, mirroring Altis where release was 55 m outside the containment poly. All four
// spots were checked for geometry collisions -- nothing but sidewalk within 6 m of the release point.
//
// Same guarded shape as fed_reserve and the bank doors above: create only when absent, and say so, so a
// designer who later places one of these himself wins and the log records which happened.
{
    _x params ["_mName", "_mPos"];
    if ((getMarkerPos _mName) isEqualTo [0,0,0]) then {
        createMarker [_mName, _mPos];
        _mName setMarkerAlpha 0;
        diag_log format ["[maldenPrison] %1 marker created at %2", _mName, getMarkerPos _mName];
    } else {
        diag_log format ["[maldenPrison] %1 marker already present at %2", _mName, getMarkerPos _mName];
    };
} forEach [
    ["jail_marker2",         [9767.0, 3893.0, 0]],   // intake / cell spawn, yard centre
    ["jail_marker_loonybin", [9766.1, 3894.5, 0]],   // containment TP-back target, the basketball court
    ["jail_release2",        [9769.3, 3948.0, 0]]    // release point, 8 m outside the outer gate
];

// `corrections` is the one VISIBLE marker of the four -- it is the map label players read, and the one
// fn_startPrisonBreak recolours for the duration of a break (:22-23 red "Prison [Break in Progress]",
// :65-66 back to ColorWEST with the world-name label). Seed it with exactly what that fn restores, so a
// fresh boot and a completed break do not differ by one label. Marker type is cosmetic; "mil_dot"
// matches the designer's own spawn marker in custom_p3ds/malden_markers.sqf.
if ((getMarkerPos "corrections") isEqualTo [0,0,0]) then {
    createMarker ["corrections", [9765.2, 3895.3, 0]];
    "corrections" setMarkerType "mil_dot";
    "corrections" setMarkerColor "ColorWEST";
    "corrections" setMarkerText format ["%1 Maximum Security Prison", worldName];
    diag_log format ["[maldenPrison] corrections marker created at %1", getMarkerPos "corrections"];
} else {
    diag_log format ["[maldenPrison] corrections marker already present at %1", getMarkerPos "corrections"];
};
```

- [ ] **Step 4: Replace `AP_jailPoly`**

In `mission/Armapunk2035.Malden/core/configuration.sqf`, **line 2 is minified and append-only —
edit only this one assignment, in place, and do not reformat the line.**

Find:

```sqf
AP_jailPoly=[[16809.6,13637.2,0],[16741.1,13572.5,0],[16690.9,13623.6,0],[16758.9,13690.5,0]];
```

Replace with:

```sqf
AP_jailPoly=[[9721.2,3893.2,0],[9714.7,3884.0,0],[9742.1,3852.0,0],[9786.5,3850.7,0],[9810.6,3874.6,0],[9810.6,3916.0,0],[9786.7,3940.0,0],[9745.3,3940.0,0],[9722.5,3919.1,0]];
```

Traced from the 88-piece wall ring by angular ordering around the ring centroid (which drops the two
inward buttress spurs that make a naive nearest-neighbour walk self-intersect), then
Douglas-Peucker at 5 m. 9 vertices, 6,875 m² — within 1% of the Altis poly's ~6,800 m², which is why
the containment code needs no retuning. `fn_jailMe.sqf:94` is its only reader in the tree (verified).

- [ ] **Step 5: Deploy and confirm the probe PASSES (GREEN)**

```bash
python3 tools/sqf_balance.py mission/Armapunk2035.Malden/initServer.sqf mission/Armapunk2035.Malden/core/configuration.sqf mission/Armapunk2035.Malden/initPlayerLocal.sqf
bash /home/timb/arma3server_dev/reload-armapunk2035.sh
grep "read from bank" /home/timb/arma3server_dev/loonydev.log
grep maldenPrison /home/timb/arma3server_dev/loonydev.log
```

Expected in the server log — four lines, none of them `[0,0,0]`:

```
[maldenPrison] jail_marker2 marker created at [9767,3893,0]
[maldenPrison] jail_marker_loonybin marker created at [9766.1,3894.5,0]
[maldenPrison] jail_release2 marker created at [9769.3,3948,0]
[maldenPrison] corrections marker created at [9765.2,3895.3,0]
```

Then join a client and check the RPT:

```
-JAILPROBE- markers m2=[9767,3893,0] loonybin=[9766.1,3894.5,0] release2=[9769.3,3948,0] corrections=[9765.2,3895.3,0]
-JAILPROBE- poly verts=9 yardCentreInside=true outsideSouthWallInside=false firstVert=[9721.2,3893.2,0]
```

**Any `[0,0,0]` in those lines, or `yardCentreInside=false`, stops the task.**

- [ ] **Step 6: In-game containment check**

Jail yourself — cop **Send to Prison** within 30 m of `jail_release2`, or admin jail. Confirm all
four:

1. Intake lands you in the yard, not at map origin.
2. Standing still in the yard produces **no** teleport and **no** repeated chat line.
3. Walking out past the wall line gives `Stay within the confines of the yard!` and puts you back on
   the basketball court.
4. The jail timer bar counts down normally.

- [ ] **Step 7: Remove the probe and commit**

Delete the entire `-JAILPROBE-` block from `initPlayerLocal.sqf`, then:

```bash
python3 tools/sqf_balance.py mission/Armapunk2035.Malden/initPlayerLocal.sqf mission/Armapunk2035.Malden/initServer.sqf mission/Armapunk2035.Malden/core/configuration.sqf
git add mission/Armapunk2035.Malden/initServer.sqf mission/Armapunk2035.Malden/core/configuration.sqf
git commit
```

Commit message (subject ≤ 50 chars, body says why):

```
Give Malden's prison the four markers it addresses

None of jail_marker2, jail_marker_loonybin, jail_release2 or
corrections existed on this map, and getMarkerPos on a missing marker
returns [0,0,0] -- a real, reachable position. AP_jailPoly was still
the Altis Pyrgos quad, so fn_jailMe's inPolygon test was false
everywhere on a 12800 m world and teleported every prisoner to map
origin once a second, for the length of their sentence.

The poly is traced from the 88 connected Land_Mil_WallBig_4m_battered_F
pieces that actually enclose the yard -- 6,875 m2 against the Altis
poly's ~6,800, which is why the containment code needs no retuning.

Both edits ship together on purpose: the poly without the markers
reproduces the origin teleport exactly, and the markers without the
poly remove containment entirely.

Co-Authored-By: Dr. Sbaitso
```

---

### Task 2: Audit the range gates the markers just armed

No code unless a defect is found. Creating four markers that were pinned at map origin turns ~16
distance gates on at once, and one of them is the only reachable cop Send-to-Prison branch on this
map. This task is the reviewer's gate on that.

**Files:**
- Read only: the consumer list below. Modify only if a check fails.

**Interfaces:**
- Consumes: the four markers from Task 1.
- Produces: a written verdict per consumer, recorded in the commit message or in `maldenprison.md`.

- [ ] **Step 1: Check each consumer against the real position**

For each, confirm the range makes sense at the prison and that nothing off-map still satisfies it:

| consumer | gate |
|---|---|
| `core/civilian/fn_jailMe.sqf:1,96,121,127,133` | intake, TP-back, release |
| `core/civilian/fn_jailPlayer.sqf:15-19` | self-turn-in |
| `core/actions/fn_useShank.sqf:3` | 70 m of `jail_marker2` |
| `core/actions/fn_gatherObject.sqf:6` | **200 m gather ban** — confirm no gather field is inside it |
| `core/fn_setupActions.sqf:980` | bounty-hunter arrest, 19 m of `jail_release2` |
| `core/fn_setupActions.sqf:1107` | cop Send to Prison, 30 m — **the only reachable branch**, since all seven `AP_police_hq_polys` are still Altis |
| `core/cop/fn_copInteractionMenu.sqf:53` | cop menu entry |
| `dialog/function/fn_prisonBreakQuery.sqf:2` | 100 m of `corrections` |
| `initPlayerLocal.sqf:426` | 350 m participant HUD snapshot |
| `core/functions/fn_dynamicMapSystem.sqf:14` | 110 m streaming exclusion |
| `core/compat/fn_trialBegin.sqf:77` | trial |
| `core/compat/fn_startPrisonBreak.sqf:18,22,23,32,46,53,65,66` | alarm, marker, dispatch, MaxTac, the 100 m participant sweep |
| `server/AP_server/init.sqf:1059` | boot |
| `server/AP_server/core/jail/fn_trialRequest.sqf:21` | trial request |
| `server/AP_server/core/TON/fn_handlePrisonBreak.sqf:178,179,239,240` | marker restore |

- [ ] **Step 2: Verify the gather ban does not cover a live field**

The 200 m ban is centred on `corrections` at `[9765.2,3895.3]`. Cross-check against the wired
gather zones (`initServer.sqf:63-95` creates them as aliases on the designer's markers):

```bash
grep -n "illegal_marker\|tobacco_1\|fentanyl_1\|vineyard_1\|rock_1\|oil_\|mine_" mission/Armapunk2035.Malden/initServer.sqf | head -20
```

Confirm none of the resolved positions is within 200 m of the prison. Report the closest.

- [ ] **Step 3: Record the verdict and commit**

If every check passes, no code changes — record the verdict in the Task 1 commit's follow-up or as a
short section appended to `maldenprison.md`. If any check fails, fix it in this task and say which.

---

### Task 3: Promote the gate and resolve it at boot

**Files:**
- Modify: `mission/Armapunk2035.Malden/core/config/fn_mapData.sqf` (row 13445, minified line 67)
- Modify: `mission/Armapunk2035.Malden/mapImportAll_data.sqf:66` (byte-identical dup)
- Modify: `mission/Armapunk2035.Malden/initServer.sqf` (boot resolver)

**Interfaces:**
- Consumes: nothing from earlier tasks.
- Produces: `AP_prisonGateIn` and `AP_prisonGateOut` — both `object`, both `publicVariable`'d,
  either possibly `objNull`. Tasks 4, 5 and 7 read them. Also produces the runtime door-count and
  animation-name list for `Land_BackAlley_01_l_gate_F`, logged once at boot.

- [ ] **Step 1: Read the frame probe before choosing any radius**

```bash
grep -n "prison" mission/Armapunk2035.Malden/debug/frame_probe.sqf
```

It carries seven prison rows and its `[FRAMEPROBE]` output is not in the repo. Run it and read the
measured sqm↔runtime delta. It was 1.7 m for the jewelry gate
(`server/AP_server/core/TON/fn_maldenJewelSRV.sqf:305-312`). **Do not pick a search radius below
~5 m until this number is in hand.** Record it in the commit message.

- [ ] **Step 2: Write the probe (RED)**

Add to `mission/Armapunk2035.Malden/initServer.sqf`, temporarily:

```sqf
// -GATEPROBE- TEMPORARY, remove in step 7 of Task 3.
[] spawn {
    uiSleep 20;   // let the mapData spawn pass finish
    private _p = [9767.504, 3932.509, 0.032];
    private _near = nearestObjects [_p, ["Land_BackAlley_01_l_gate_F", "Land_ConcreteWall_01_l_gate_F"], 25];
    diag_log format ["-GATEPROBE- server sees %1 gate object(s) within 25 m of %2", count _near, _p];
    {
        diag_log format ["-GATEPROBE-   %1 at %2 (%3 m) doors=%4 anims=%5",
            typeOf _x, getPosATL _x, round (_x distance _p),
            getNumber (configFile >> "CfgVehicles" >> (typeOf _x) >> "numberOfDoors"),
            animationNames _x];
    } forEach _near;
    diag_log format ["-GATEPROBE- exitJail isNull=%1", isNull (missionNamespace getVariable ["exitJail", objNull])];
};
```

- [ ] **Step 3: Deploy and confirm the probe FAILS**

```bash
python3 tools/sqf_balance.py mission/Armapunk2035.Malden/initServer.sqf
bash /home/timb/arma3server_dev/reload-armapunk2035.sh
grep "read from bank" /home/timb/arma3server_dev/loonydev.log
grep GATEPROBE /home/timb/arma3server_dev/loonydev.log
```

Expected: the server sees the **outer** sqm gate (`Land_ConcreteWall_01_l_gate_F`, ~8 m away) but
**not** the inner `Land_BackAlley_01_l_gate_F` — that row's 5th field is `false`, so
`initServer.sqf:160-162` never spawned it server-side. `exitJail isNull=false` (it is a named sqm
object and exists on every machine).

If `Land_BackAlley_01_l_gate_F` already appears, the row was promoted by someone else — stop and
re-scope.

- [ ] **Step 4: Promote the mapData row**

The row is one entry on a single minified line. **Only the 4th and 5th fields change.** The same
file already carries an Altis row of this exact class with `"_serverObject = true;"` and `true`, so
this is the file's own precedent, not a new pattern.

In `mission/Armapunk2035.Malden/core/config/fn_mapData.sqf`, find:

```
["Land_BackAlley_01_l_gate_F",[9767.504,3932.509,0.032],[[0.0000,1.0000,0.0000],[0.0000,0.0000,1.0000]],"",false]
```

Replace with:

```
["Land_BackAlley_01_l_gate_F",[9767.504,3932.509,0.032],[[0.0000,1.0000,0.0000],[0.0000,0.0000,1.0000]],"_serverObject = true;",true]
```

Apply the identical edit to `mission/Armapunk2035.Malden/mapImportAll_data.sqf:66`.
Verify the two stay in step:

```bash
grep -c '"_serverObject = true;",true\]' mission/Armapunk2035.Malden/core/config/fn_mapData.sqf
grep -o '\["Land_BackAlley_01_l_gate_F",\[9767.504[^]]*\][^]]*\][^]]*\][^]]*\]' mission/Armapunk2035.Malden/mapImportAll_data.sqf
```

Intended side effect: `core/functions/fn_dynamicMapSystem.sqf:11` skips `_xIsServer` rows, so the
gate stops being N client-local statues and becomes one real networked object.

- [ ] **Step 5: Add the boot resolver**

In `mission/Armapunk2035.Malden/initServer.sqf`, after the prison marker block from Task 1:

```sqf
// MALDEN PRISON GATES 2026-07-29. The prison's north entrance is a sally port: the wall steps inward at
// X 9760..9774 and holds two gates in series. The INNER one is the owner's coordinate and was a
// client-local createSimpleObject statue with simulation disabled -- no doors, no animation sources, and
// no networked object, so animate/animateSource were inert on EVERY machine, not merely on the server.
// Its mapData row is promoted in this same commit; this resolves both gates once, at boot, and publishes
// them, so no client ever supplies a gate object to the server.
//
// Radius: 8 m, not tight. The sqm/mapData position frame and the runtime frame differ -- measured at
// 1.7 m for the jewelry gate (fn_maldenJewelSRV.sqf:305-312) -- so a radius under ~5 m can miss a gate
// that is right where it should be. Both classes are searched at both anchors because the two gates are
// only 7.6 m apart and either search would otherwise be able to find the wrong one.
[] spawn {
    private _fnc_pick = {
        params ["_pos", "_class"];
        private _hits = nearestObjects [_pos, [_class], 8];
        if (_hits isEqualTo []) exitWith { objNull };
        _hits select 0
    };
    // Wait for the mapData spawn pass rather than guessing at a sleep: the gate cannot resolve before
    // the row that creates it has run, and a fixed sleep would silently resolve to objNull on a slow boot.
    private _deadline = time + 120;
    private _gIn = objNull;
    private _gOut = objNull;
    waitUntil {
        uiSleep 2;
        _gIn  = [[9767.504, 3932.509, 0.032], "Land_BackAlley_01_l_gate_F"]     call _fnc_pick;
        _gOut = [[9769.31,  3940.18,  0],     "Land_ConcreteWall_01_l_gate_F"] call _fnc_pick;
        ((!isNull _gIn) && {!isNull _gOut}) || {time > _deadline}
    };
    AP_prisonGateIn  = _gIn;
    AP_prisonGateOut = _gOut;
    publicVariable "AP_prisonGateIn";
    publicVariable "AP_prisonGateOut";
    diag_log format ["[maldenPrison] gateIn=%1 null=%2 at %3 doors=%4 anims=%5",
        typeOf AP_prisonGateIn, isNull AP_prisonGateIn, getPosATL AP_prisonGateIn,
        if (isNull AP_prisonGateIn) then {-1} else {
            getNumber (configFile >> "CfgVehicles" >> (typeOf AP_prisonGateIn) >> "numberOfDoors")},
        if (isNull AP_prisonGateIn) then {[]} else {animationNames AP_prisonGateIn}];
    diag_log format ["[maldenPrison] gateOut=%1 null=%2 at %3 doors=%4 anims=%5",
        typeOf AP_prisonGateOut, isNull AP_prisonGateOut, getPosATL AP_prisonGateOut,
        if (isNull AP_prisonGateOut) then {-1} else {
            getNumber (configFile >> "CfgVehicles" >> (typeOf AP_prisonGateOut) >> "numberOfDoors")},
        if (isNull AP_prisonGateOut) then {[]} else {animationNames AP_prisonGateOut}];
};
```

- [ ] **Step 6: Deploy and confirm GREEN**

```bash
python3 tools/sqf_balance.py mission/Armapunk2035.Malden/initServer.sqf mission/Armapunk2035.Malden/core/config/fn_mapData.sqf mission/Armapunk2035.Malden/mapImportAll_data.sqf
bash /home/timb/arma3server_dev/reload-armapunk2035.sh
grep "read from bank" /home/timb/arma3server_dev/loonydev.log
grep -E "GATEPROBE|maldenPrison. gate" /home/timb/arma3server_dev/loonydev.log
```

Expected: both `null=false`; the probe now reports **2** gate objects; and both `doors=` and `anims=`
lines are populated. **Write the reported `doors` and `anims` values into the Task 4 commit
message** — they are the first time this class's animation set has been read on this project, and
Task 4's helper depends on the enumeration finding them.

If `gateIn null=true`, the promotion did not take. Check `fn_mapData.sqf` actually shipped in the PBO
(the deploy repacks) before changing anything else.

- [ ] **Step 7: Remove the probe and commit**

```bash
# delete the -GATEPROBE- block
python3 tools/sqf_balance.py mission/Armapunk2035.Malden/initServer.sqf
git add mission/Armapunk2035.Malden/initServer.sqf mission/Armapunk2035.Malden/core/config/fn_mapData.sqf mission/Armapunk2035.Malden/mapImportAll_data.sqf
git commit
```

```
Make the prison's inner gate a real object the server owns

The gate at [9767.504,3932.509] was a client-local createSimpleObject
with simulation disabled -- a baked statue with no doors and no
animation sources, so animate and animateSource were inert on every
machine, not just on the server, and there was no networked object for
the server to resolve. Promoting its mapData row spawns one real gate
instead of N client statues, which is the same thing the Fed's dome and
centre rows do; fn_mapData already carried an Altis row of this exact
class with the same two fields set.

The prison's north entrance is a sally port -- two gates 7.6 m apart in
a wall recess -- so both are resolved at boot and published, and the
server never takes a gate object from a client. The resolver waits for
the mapData spawn pass rather than sleeping a guessed interval, and
searches at 8 m because the sqm and runtime position frames differ by
~1.7 m on this map.

Co-Authored-By: Jabberwacky
```

---

### Task 4: `APS_fnc_prisonGateSRV` — gate drive, seal, and the disarm latch

**Files:**
- Create: `server/AP_server/core/TON/fn_prisonGateSRV.sqf`
- Modify: `server/AP_server/config.cpp` (register it)
- Modify: `mission/Armapunk2035.Malden/CfgRE.hpp` (whitelist it, `allowedTargets = 2`)
- Modify: `mission/Armapunk2035.Malden/initServer.sqf` (temporary boot self-test)

**Interfaces:**
- Consumes: `AP_prisonGateIn`, `AP_prisonGateOut` (Task 3).
- Produces: `APS_fnc_prisonGateSRV` with string modes `"boot"`, `"gatehack"`, `"disarm"`, `"relock"`.
  Publishes `AP_prisonDisarmed` (bool). Task 5 calls `"gatehack"`, Task 7 calls `"disarm"`, Task 6
  reads `AP_prisonDisarmed`.

- [ ] **Step 1: Write the function**

Create `server/AP_server/core/TON/fn_prisonGateSRV.sqf`:

```sqf
/*
    APS_fnc_prisonGateSRV -- the Malden prison's sally-port gates, the 10-minute escape window's
    physical half, and the cop disarm latch.

    Modes:
      ["boot"]      server-internal. Seal the OUTER gate, clear the disarm latch.
      ["gatehack"]  civ, from AP_fnc_prisonGate after a successful Sequence Breach. Validates the
                    caller, opens both gates, hands the event to APS_fnc_handlePrisonBreak mode 1.
      ["disarm"]    cop, from AP_fnc_stopPrisonBreak's hold. Validates the caller, sets the latch,
                    re-locks the OUTER gate.
      ["relock"]    server-internal, end of window. Re-locks the OUTER gate.

    WHICH GATE IS SEALED, AND WHY ONLY ONE. fn_maldenJewelSRV.sqf:43-50 records the rule: a gate sealed
    with no reachable opener is welded for the life of the server, because sealing runs at boot AND at
    every window close while ["open"] is the only release. So only the OUTER gate is ever sealed. The
    INNER gate is never locked, so cops can always walk prisoners in even with the hack on cooldown,
    refused by the cop gate, or blocked by another federal event. The Fed leaves two pedestrian gates
    unsealed for exactly this reason (fn_maldenFedSRV.sqf:279-290).

    The caller is derived from remoteExecutedOwner, never from the payload -- the payload is precisely
    what a forged call would use to name an innocent player in a -SEC- row.
*/
params [["_mode", "", [""]]];

// --- gate primitives, lifted from fn_maldenJewelSRV.sqf:110-131 --------------------------------------
// Never hardcode a door count or an animation name: this class's set was read at runtime for the first
// time in the previous commit, and a hardcoded name that is wrong fails silently.
private _fnc_doorAnims = {
    params ["_obj"];
    (animationNames _obj) select {
        private _a = toLower _x;
        ((_a find "door") >= 0 || {(_a find "gate") >= 0}) && {(_a find "locked") isEqualTo -1}
    }
};

private _fnc_doorSources = {
    params ["_obj", "_phase"];
    { _obj animateSource [_x, _phase]; } forEach ["door_1_sound_source", "door_1_noSound_source"];
};

// Phase 0 = shut and locked (doors DISABLED), phase 1 = open and free (doors ENABLED). The disable flag
// is the INVERSE of the phase, and that is the only asymmetry. Order is the bank's and it is
// load-bearing: write bis_disabled_Door_N FIRST so no fresh hand-open can begin while the rest runs,
// THEN drive the animations and their sources, which un-does an open a player did by hand earlier.
private _fnc_driveGate = {
    params ["_obj", "_phase"];
    if (isNull _obj) exitWith { false };
    private _n = getNumber (configFile >> "CfgVehicles" >> (typeOf _obj) >> "numberOfDoors");
    private _dis = 1 - _phase;
    for "_i" from 1 to _n do { _obj setVariable [format ["bis_disabled_Door_%1", _i], _dis, true]; };
    { _obj animate [_x, _phase, true]; } forEach ([_obj] call _fnc_doorAnims);
    [_obj, _phase] call _fnc_doorSources;
    _obj setVariable ["gate_max", _phase, true];
    true
};

// --- caller validation, lifted from fn_maldenFedSRV.sqf:189-205 --------------------------------------
// _side is a parameter because this fn serves both a civ mode and a cop mode off one validator.
private _fnc_caller = {
    params ["_anchor", "_maxDist", "_side"];
    private _src = remoteExecutedOwner;
    if (_src isEqualTo 0) exitWith { [true, objNull] };               // server-internal: no check, no caller
    private _c = (allPlayers select { owner _x isEqualTo _src }) param [0, objNull];
    if (isNull _c
        || {!alive _c}
        || {side _c isNotEqualTo _side}
        || {_c getVariable ["AP_restrained", false]}
        || {_c getVariable ["AP_downed", false]}
        || {!(isNull objectParent _c)}
        || {isNull _anchor}
        || {(_c distance _anchor) > _maxDist}) exitWith {
        ["-SEC-", _c, format ["BLOCKED prisonGateSRV mode %1 (dist %2) by %3", _mode,
            if (isNull _c || {isNull _anchor}) then {-1} else {round (_c distance _anchor)},
            if (isNull _c) then {"?"} else {getPlayerUID _c}]] call APS_fnc_logIt;
        [false, objNull]
    };
    [true, _c]
};

private _gIn  = missionNamespace getVariable ["AP_prisonGateIn",  objNull];
private _gOut = missionNamespace getVariable ["AP_prisonGateOut", objNull];

switch (toLower _mode) do {

    case "boot": {
        [_gOut, 0] call _fnc_driveGate;
        AP_prisonDisarmed = false;
        publicVariable "AP_prisonDisarmed";
        diag_log format ["[maldenPrison] boot: outer gate sealed (%1), inner gate left free (%2), latch cleared",
            !isNull _gOut, !isNull _gIn];
    };

    case "gatehack": {
        // 8 m, the looser OUTER bound on purpose: AP_fnc_prisonGate refuses at 6 m and the scroll
        // action offers at 6 m, so a player who can see the option can never be refused for the reason
        // it was offered, and this stays the backstop rather than the UX bound.
        ([_gIn, 8, civilian] call _fnc_caller) params ["_ok", "_c"];
        if (!_ok) exitWith {};

        // Every gate on the event itself stays in APS_fnc_handlePrisonBreak mode 1, which owns the
        // active check, the fed-event exclusivity, the tenured-cop requirement, the 30-minute re-run
        // cooldown and the 15-minute cross-heist lockout -- and refuses ABOVE its own SRV_prisonData
        // stamp, so a refusal here leaves no state and no open gate.
        if (SRV_prisonData param [1, false]) exitWith {
            [[2, "There is already a prison break in progress!"], "AP_fnc_broadcast", _c, false, false] spawn AP_fnc_MP;
        };

        AP_prisonDisarmed = false;
        publicVariable "AP_prisonDisarmed";

        [1, _c, getPlayerUID _c, group _c] call APS_fnc_handlePrisonBreak;

        // Open both gates ONLY if the event actually started -- handlePrisonBreak stamps slot 1 below
        // all five of its guards, so this reads its verdict rather than assuming one.
        if (SRV_prisonData param [1, false]) then {
            [_gIn,  1] call _fnc_driveGate;
            [_gOut, 1] call _fnc_driveGate;
            ["-PRISON-", _c, format ["GATE HACK accepted, window open, by %1", getPlayerUID _c]] call APS_fnc_logIt;
        };
    };

    case "disarm": {
        // 15 m: the client hold refuses past 12 m, so the server stays the looser outer bound.
        ([_gIn, 15, west] call _fnc_caller) params ["_ok", "_c"];
        if (!_ok) exitWith {};
        if !(SRV_prisonData param [1, false]) exitWith {
            [[2, "There is no prison break to stop!"], "AP_fnc_broadcast", _c, false, false] spawn AP_fnc_MP;
        };
        AP_prisonDisarmed = true;
        publicVariable "AP_prisonDisarmed";
        [_gOut, 0] call _fnc_driveGate;
        ["-PRISON-", _c, format ["GATE HACK disarmed by %1", getPlayerUID _c]] call APS_fnc_logIt;
    };

    case "relock": {
        [_gOut, 0] call _fnc_driveGate;
    };

    default {
        diag_log format ["[maldenPrison] prisonGateSRV: unknown mode '%1'", _mode];
    };
};
```

- [ ] **Step 2: Register the function**

In `server/AP_server/config.cpp`, inside the `class AP_System` block (tag `TON`), beside the
other `TON/` entries, add:

```cpp
class prisonGateSRV {};
```

Confirm the surrounding class's `file` is the `TON` directory before adding — the registration must
resolve to `server\AP_server\core\TON\fn_prisonGateSRV.sqf`:

```bash
grep -n -B6 "class maldenFedSRV" server/AP_server/config.cpp
```

- [ ] **Step 3: Whitelist it for client→server calls**

In `mission/Armapunk2035.Malden/CfgRE.hpp`, matching the shape of the neighbouring entries:

```cpp
class APS_fnc_prisonGateSRV { allowedTargets = 2; };
```

`mode = 1` is a whitelist — without this entry, Task 5's and Task 7's calls fail **silently**.
Check the exact syntax used by a sibling first:

```bash
grep -n -A2 "APS_fnc_maldenFedSRV" mission/Armapunk2035.Malden/CfgRE.hpp
```

- [ ] **Step 4: Call `"boot"` from the resolver, and add the self-test (RED then GREEN in one deploy)**

At the end of the Task 3 resolver `spawn` block in `initServer.sqf`, after the two `publicVariable`
lines:

```sqf
    ["boot"] call APS_fnc_prisonGateSRV;
```

And temporarily, after it:

```sqf
    // -GATEPROBE- TEMPORARY, remove in step 6 of Task 4. Drives the outer gate shut -> open -> shut and
    // logs the door-disable flag each time, which is the one piece of gate state readable without a
    // client. Proves the enumerator found real animation names on this class rather than silently
    // finding none.
    private _readState = {
        params ["_obj", "_tag"];
        diag_log format ["-GATEPROBE- %1 doors_disabled_1=%2 gate_max=%3 animPhase=%4",
            _tag,
            _obj getVariable ["bis_disabled_Door_1", "unset"],
            _obj getVariable ["gate_max", "unset"],
            if (isNull _obj) then {-1} else {_obj animationPhase ((animationNames _obj) param [0, ""])}];
    };
    [AP_prisonGateOut, "outer after boot seal"] call _readState;
    ["relock"] call APS_fnc_prisonGateSRV;
    uiSleep 2;
    [AP_prisonGateOut, "outer after relock"] call _readState;
```

- [ ] **Step 5: Deploy and read the self-test**

```bash
python3 tools/sqf_balance.py server/AP_server/core/TON/fn_prisonGateSRV.sqf mission/Armapunk2035.Malden/initServer.sqf
bash /home/timb/arma3server_dev/reload-armapunk2035.sh
grep "read from bank" /home/timb/arma3server_dev/loonydev.log
grep -E "GATEPROBE|maldenPrison. boot" /home/timb/arma3server_dev/loonydev.log
```

Expected:

```
[maldenPrison] boot: outer gate sealed (true), inner gate left free (true), latch cleared
-GATEPROBE- outer after boot seal doors_disabled_1=1 gate_max=0 animPhase=0
-GATEPROBE- outer after relock doors_disabled_1=1 gate_max=0 animPhase=0
```

`doors_disabled_1=unset` or `animPhase=-1` means the enumerator found nothing and the gate is not
actually being driven — **stop and fix before continuing**, because Tasks 5-7 all assume this works.

- [ ] **Step 6: Remove the self-test and commit**

```bash
# delete the -GATEPROBE- block, keep the ["boot"] call
python3 tools/sqf_balance.py server/AP_server/core/TON/fn_prisonGateSRV.sqf mission/Armapunk2035.Malden/initServer.sqf
git add server/AP_server/core/TON/fn_prisonGateSRV.sqf server/AP_server/config.cpp mission/Armapunk2035.Malden/CfgRE.hpp mission/Armapunk2035.Malden/initServer.sqf
git commit
```

```
Add the prison gate authority, sealing only the outer gate

APS_fnc_prisonGateSRV owns the sally port's two gates, the cop disarm
latch and nothing else -- the event itself stays in
APS_fnc_handlePrisonBreak mode 1, so all five of its guards still
decide whether a break may start, and the gates open only if it stamps
the event active.

Only the OUTER gate is ever sealed. fn_maldenJewelSRV records why: a
gate sealed with no reachable opener is welded for the life of the
server, because sealing runs at boot and at every window close while
open is the only release. The inner gate is left free so cops can walk
prisoners in even when the hack is on cooldown or refused.

The caller is derived from remoteExecutedOwner, never from the payload,
because the payload is what a forged call would use to name an innocent
player in a -SEC- row. Door counts and animation names are enumerated
at runtime -- the previous commit read this class's set for the first
time on this project.

Co-Authored-By: Cleverbot
```

---

### Task 5: The client breach action

**Files:**
- Create: `mission/Armapunk2035.Malden/core/actions/fn_prisonGate.sqf`
- Modify: `mission/Armapunk2035.Malden/Functions.h` (register it)
- Modify: `mission/Armapunk2035.Malden/core/fn_setupActions.sqf` (scroll offer)

**Interfaces:**
- Consumes: `AP_prisonGateIn` (Task 3); `APS_fnc_prisonGateSRV` mode `"gatehack"` (Task 4).
- Produces: `AP_fnc_prisonGate`, called by the scroll action with no arguments.

- [ ] **Step 1: Write the action**

Create `mission/Armapunk2035.Malden/core/actions/fn_prisonGate.sqf`, modelled on
`core/actions/fn_openGate.sqf` — the Fed perimeter gate, which is the lowest-risk shape in the tree
because the server is handed no payload it has to trust:

```sqf
/*
    AP_fnc_prisonGate -- breach the Malden prison's inner sally-port gate.

    Everything this decides is re-decided on the server (APS_fnc_prisonGateSRV "gatehack", which then
    defers to APS_fnc_handlePrisonBreak mode 1 and its five guards). What happens here is the minigame
    and the local feedback; the gates, the window, the alarm and the dispatch are the server's.

    The refusals below are messaging, not security. They exist so a player learns why the option did
    nothing, and they are deliberately the same bounds the scroll action offers on.
*/
if !(playerSide isEqualTo civilian) exitWith {};
if !(isNull objectParent player) exitWith {[2, "You cannot do this from within a vehicle."] call AP_fnc_broadcast};
if (AP_action_in_use) exitWith {};
if (!(call AP_fnc_hasDeck)) exitWith {[2, "You need ICEBREAKER firmware to breach the gate."] call AP_fnc_broadcast};
if (player getVariable ["AP_restrained", false] || {player getVariable ["AP_arrested", false]}) exitWith {};

// 6 m, matching the scroll action's offer radius in fn_setupActions exactly: the option must never be
// visible at a range this refuses. The server re-checks at 8 m, looser on purpose.
private _gate = missionNamespace getVariable ["AP_prisonGateIn", objNull];
if (isNull _gate || {(player distance _gate) > 6}) exitWith {
    [2, "You are not at the prison gate."] call AP_fnc_broadcast};

if (SRV_prisonData param [1, false]) exitWith {
    [2, "There is already a prison break in progress!"] call AP_fnc_broadcast};
if (["prison"] call AP_fnc_activeFederalEvent) exitWith {
    ["There is already another Federal Event happening.", "basic"] spawn AP_fnc_handleMessage};

AP_action_in_use = true;
private _r = [10] call AP_fnc_cyberdeckSeq;
AP_action_in_use = false;
if !(_r isEqualTo 1) exitWith {
    if (_r isEqualTo 0) then {[2, "The trace caught you -- the gate stays shut."] call AP_fnc_broadcast;};
};

[["gatehack"], "APS_fnc_prisonGateSRV", 2] spawn AP_fnc_MP;
```

Buffer length `10` matches the Fed gate. **This is one of the four open items in `TODO.md` — confirm
the owner's number before the final commit** and change the single literal if he wants a different
tier (valid range 3..12).

- [ ] **Step 2: Register the client function**

In `mission/Armapunk2035.Malden/Functions.h`, in the class whose `file` is `core\actions`, beside
the sibling entries:

```cpp
class prisonGate {};
```

Verify the right class first — a client fn that is not in `Functions.h` does not exist:

```bash
grep -n -B8 "class openGate" mission/Armapunk2035.Malden/Functions.h
```

- [ ] **Step 3: Add the scroll offer**

In `mission/Armapunk2035.Malden/core/fn_setupActions.sqf`, next to the Fed gate entry at `:642`.

**`core/fn_setupActions.sqf:2` is `private _plb_obj = player;`** — every action registered in this
file attaches to the **player**, so `_this select 0` is the player and any `player distance _target`
gate silently becomes 0. The condition therefore reads the published gate from `missionNamespace`
directly, exactly as the Fed entry does. **Keep the whole `pushBack` on ONE line** — this file is
formatter-sensitive and the Fed entry is one line for the same reason.

```sqf
                // PRISON SALLY-PORT GATE. Proximity, NEVER cursorObject: on a large wall-gate the
                // cursor ray lands on the paving slab underfoot, which is exactly why the Fed's
                // equivalent action was unstartable until f7f0ef9 (.superpowers/sdd/gate-cursor-report.md).
                // 6 m is deliberately AP_fnc_prisonGate's own refusal bound, so a player who can see
                // the option can never be refused for the reason it was offered; the server's 8 m is the
                // looser outer bound and is meant to be.
                AP_actions pushBack(_plb_obj addAction ["<t color='#FF0000'>Breach Prison Gate</t>",AP_fnc_prisonGate,"",0,false,false,"",'(playerSide isEqualTo civilian) && (!isNull (missionNamespace getVariable [ "AP_prisonGateIn", objNull ] )) && ((player distance (missionNamespace getVariable [ "AP_prisonGateIn", objNull ] )) <= 6) && (!((missionNamespace getVariable [ "SRV_prisonData", [ 0, false ] ] ) param [ 1, false ] )) && ((call AP_fnc_hasDeck)) && (!AP_action_in_use) && (isNull objectParent player) && (!(player getVariable [ "AP_arrested", false ] ))',6]);
```

The `AP_arrested` clause keeps the option off a prisoner standing at the inside face of the same
gate — a prisoner escapes via the query dialog, not by hacking his own cell door.

- [ ] **Step 4: Verify it parses, then that it appears**

```bash
python3 tools/sqf_balance.py mission/Armapunk2035.Malden/core/actions/fn_prisonGate.sqf mission/Armapunk2035.Malden/core/fn_setupActions.sqf
grep -c "Breach Prison Gate" mission/Armapunk2035.Malden/core/fn_setupActions.sqf   # expect exactly 1
bash /home/timb/arma3server_dev/reload-armapunk2035.sh
grep "read from bank" /home/timb/arma3server_dev/loonydev.log
```

Then in-game, as a civilian with ICEBREAKER firmware:

1. Stand within 6 m of `[9767.5,3932.5]` → **Breach Prison Gate** appears in the scroll menu.
2. Walk to 10 m → it disappears.
3. Check the RPT for errors. **If your entire scroll menu vanished, `fn_setupActions.sqf` has a
   syntax error** — the dedicated server never compiles client files, so that is the only symptom
   you get.

Do **not** fire it yet — Task 6 owns the window it starts.

- [ ] **Step 5: Commit**

```bash
git add mission/Armapunk2035.Malden/core/actions/fn_prisonGate.sqf mission/Armapunk2035.Malden/Functions.h mission/Armapunk2035.Malden/core/fn_setupActions.sqf
git commit
```

```
Offer the prison gate breach by proximity, with the deck

The prison break has never been startable on this map:
AP_fnc_doPrisonBreak has no callers anywhere in the tree, no scroll
action offers it, and there is no laptop prop within 170 m of the
prison. This is the trigger it was missing, not a replacement for one.

Shaped after the Fed perimeter gate, which hands the server no payload
it has to trust -- the client runs the Sequence Breach and sends a bare
literal. Offered on proximity and never on cursorObject, because on a
gate this size the cursor ray lands on the paving slab underfoot, which
is what made the Fed's own action unofferable until f7f0ef9.

Offer radius and refusal radius are both 6 m so the option can never be
visible at a range the function refuses.

Co-Authored-By: ELIZA
```

---

### Task 6: The 10-minute window

**Files:**
- Modify: `mission/Armapunk2035.Malden/core/compat/fn_startPrisonBreak.sqf:39-55` (**the copy that executes**)
- Modify: `server/AP_server/core/jail/fn_startPrisonBreak.sqf` (byte-identical twin, same change)

**Interfaces:**
- Consumes: `AP_prisonDisarmed` (Task 4); `SRV_prisonData` slot 1.
- Produces: no new names. Changes the meaning of `_breakTimer` to 600 on Malden.

- [ ] **Step 1: Confirm the twins are in step before touching either**

```bash
diff <(sed -n '9,$p' mission/Armapunk2035.Malden/core/compat/fn_startPrisonBreak.sqf) server/AP_server/core/jail/fn_startPrisonBreak.sqf
```

Expected: empty, exit 0. They are synced **by hand** — no tooling regenerates them, despite an
earlier commit message claiming otherwise (corrected in `TODO.md`). If they already differ, stop and
reconcile first.

- [ ] **Step 2: Replace the hold condition**

The old `waitUntil` at `:50` demands the breaker stay alive, unrestrained, out of vehicles and within
500 m — a hold anchored on the laptop. Replace it, plus `_breakTimer` at `:48` and the success test at
`:55`.

`_breakTimer` — find:

```sqf
_breakTimer = if (worldName == "Australia") then { 600 } else { 800 };
```

Replace with:

```sqf
// owner 2026-07-29: MALDEN = 600 s, the gate hack's 10-minute window. This is no longer a HOLD -- the
// hacker cracked a gate and is free to leave -- so the timer is the whole of it. Australia keeps 600 and
// the others keep 800 because their trigger is still the (currently callerless) laptop upload.
// MUST match the participant bar's _dur in initPlayerLocal.sqf.
_breakTimer = switch (worldName) do { case "Australia": { 600 }; case "Malden": { 600 }; default { 800 } };
```

`waitUntil` — find:

```sqf
waitUntil {sleep 2; (!alive _unit || _unit getVariable ["restrained",false] || vehicle _unit != _unit || (_unit distance2D _holdAnchor) > 500 || (time - _start) > _breakTimer)};
```

Replace with:

```sqf
// owner 2026-07-29: the gate hack replaces the hold OUTRIGHT -- this is not a second branch. The only
// caller of the hold semantics was AP_fnc_doPrisonBreak, which has no callers of its own, so no live
// path depends on the 500 m anchor and there is no "laptop mode" left to preserve.
// THREE bugs die with the old condition, all recorded in TODO.md under 2026-07-28:
//   1. ORPHANED THREAD. The old condition watched the BREAKER, not SRV_prisonData, so after a cop stop
//      this script ran on to re-broadcast its own failure message and re-restore the marker. Watching
//      slot 1 ends the thread when the event ends.
//   2. THE ALARM LEAK. _soundOn is a LOCAL deleted only at the deleteVehicle below. Because all three
//      end paths (expiry, disarm, the 1200 s watchdog) now fall through to it, the siren can no longer
//      outlive the event. No published handle is needed -- this condition IS the fix.
//   3. THE DEAD RESTRAINED CHECK. `_unit getVariable ["restrained", false]` read a variable name
//      nothing in the tree ever sets; the codebase uses AP_restrained. It goes away with the clause.
// `param`, never `select`, on SRV_prisonData: it is seeded 2-element and select on a missing slot
// yields nil, which would halt this thread rather than ending the break.
waitUntil {sleep 2; ((time - _start) > _breakTimer)
    || (missionNamespace getVariable ["AP_prisonDisarmed", false])
    || !(SRV_prisonData param [1, false])};
```

Success test — find:

```sqf
if ((time - _start) > _breakTimer && alive _unit && vehicle _unit == _unit && !(_unit getVariable ["restrained",false])) then {
```

Replace with:

```sqf
// owner 2026-07-29: matches the condition above clause for clause. The window either ran its full
// length undisarmed with the event still active, or it did not. The breaker's own state is deliberately
// absent: he cracked a gate ten minutes ago and may be dead, arrested or on the far side of the island,
// and none of that should decide whether the prisoners get their offer.
if (((time - _start) > _breakTimer)
    && !(missionNamespace getVariable ["AP_prisonDisarmed", false])
    && (SRV_prisonData param [1, false])) then {
```

- [ ] **Step 3: Make the MaxTac dispatch safe**

Still in the same file, inside the `[_npc] spawn {...}` block, immediately **after** the
`_maxtacPos = switch (worldName) do {...};` statement and **before** the
`if(AP_activeMAXTAC || !AP_prison_inProgress || count _units < 2) exitWith {};` line:

```sqf
// owner 2026-07-29: that switch has Altis/Tanoa/Stratis/Australia, NO Malden case and NO default, so
// _maxtacPos is nil on this map and fn_maxtacDispatch:50 then evaluates `(_locations select 0) select 1` on
// it. The bank's equivalent table (fn_bankDrillVault.sqf:93) has a default; this one does not. Four real
// Malden insertion positions are an open item in TODO.md -- until they land, skip MaxTac and SAY SO,
// rather than letting the event die on a nil. A silent cap reads as "covered" when it is not.
if (isNil "_maxtacPos" || {!(_maxtacPos isEqualType [])} || {_maxtacPos isEqualTo []}) exitWith {
    diag_log format ["[maldenPrison] no MaxTac insertion table for world '%1' -- MaxTac not deployed for this prison break", worldName];
};
```

- [ ] **Step 4: Mirror into the twin and prove they match**

Apply the identical three edits to `server/AP_server/core/jail/fn_startPrisonBreak.sqf`, then:

```bash
diff <(sed -n '9,$p' mission/Armapunk2035.Malden/core/compat/fn_startPrisonBreak.sqf) server/AP_server/core/jail/fn_startPrisonBreak.sqf
python3 tools/sqf_balance.py mission/Armapunk2035.Malden/core/compat/fn_startPrisonBreak.sqf server/AP_server/core/jail/fn_startPrisonBreak.sqf
```

Expected: `diff` empty, exit 0. Both balance checks exit 0.

- [ ] **Step 5: Fire it end to end (GREEN)**

Deploy, then as a civilian with a deck, with **one prisoner in the cells** and the cop requirement
satisfied (or `AP_betaZeroCops` set on DEV):

```bash
bash /home/timb/arma3server_dev/reload-armapunk2035.sh
grep "read from bank" /home/timb/arma3server_dev/loonydev.log
```

1. Breach the gate. Confirm within seconds: both gates open, the alarm starts, `corrections` turns
   red and reads **Prison [Break in Progress]**, and civ + west both get the broadcast.
2. Confirm the log:
   ```bash
   grep -E "maldenPrison|-PRISON-|MaxTac insertion" /home/timb/arma3server_dev/loonydev.log
   ```
   Expect `GATE HACK accepted, window open`, and the MaxTac skip line naming `Malden`.
3. Let the full 600 s run. Confirm the prisoner gets the **Escape from Prison?** dialog, and that the
   event ends: alarm stops, marker restored to `ColorWEST`.
4. Confirm the alarm actually stopped. That is bug 2 above, and it is the one worth watching for.

- [ ] **Step 6: Commit**

```bash
git add mission/Armapunk2035.Malden/core/compat/fn_startPrisonBreak.sqf server/AP_server/core/jail/fn_startPrisonBreak.sqf
git commit
```

```
Make the prison break a 10-minute clock, not a 500m hold

The hold existed because the trigger was a laptop virus upload the
breaker had to stand next to. That trigger has no callers anywhere in
the tree, and the gate hack that replaces it leaves the hacker free to
walk away, so the timer is now the whole of the event.

Three logged bugs die with the old condition. It watched the breaker
rather than SRV_prisonData, so a cop-stopped break left this script
running on to re-broadcast its own failure and re-restore the marker.
Because it never reached the deleteVehicle at the end on that path, the
siren outlived the event -- all three end paths now fall through to it,
so the leak is closed without publishing a handle. And its restrained
clause read a variable name nothing in the tree ever sets; the codebase
uses AP_restrained.

The MaxTac switch has no Malden case and no default, so _maxtacPos was nil
and maxtacDispatch would evaluate select on it. It now skips and logs
until real insertion positions land -- a silent cap reads as covered
when it is not.

Co-Authored-By: Tay
```

---

### Task 7: The cop disarm

**Files:**
- Modify: `mission/Armapunk2035.Malden/core/cop/fn_stopPrisonBreak.sqf`
- Modify: `mission/Armapunk2035.Malden/core/fn_setupActions.sqf` (cop scroll offer)

**Interfaces:**
- Consumes: `AP_prisonGateIn` (Task 3); `APS_fnc_prisonGateSRV` mode `"disarm"` (Task 4).
- Produces: no new names. `AP_fnc_stopPrisonBreak` now takes no argument and reads the published
  gate.

- [ ] **Step 1: Retarget the cop hold onto the gate**

`fn_stopPrisonBreak.sqf` currently takes a laptop object as `_target` and measures 12 m to it. The
laptop does not exist on this map. Replace the parameter and both distance gates with the published
gate, and route the completion at the end to the authoritative server mode.

Replace the first line:

```sqf
params[["_target", objNull, [objNull]]];
```

with:

```sqf
// owner 2026-07-29: the hold is now anchored on the PRISON GATE, not the laptop -- Malden has no laptop
// prop and AP_fnc_doPrisonBreak, the only thing that ever passed one, has no callers. Read the
// published gate rather than trusting an argument: fn_setupActions attaches its actions to the PLAYER
// (`private _plb_obj = player;` at :2), so an argument-passed target would be the player and every
// distance gate here would silently measure 0.
private _target = missionNamespace getVariable ["AP_prisonGateIn", objNull];
if (isNull _target) exitWith {["The prison security system cannot be reached.", "basic"] spawn AP_fnc_handleMessage;};
```

Replace **both** occurrences of:

```sqf
if ((player distance _target) > 12) exitWith {
    ["You need to stay near the laptop to finish restoring the security system!", "basic"] spawn AP_fnc_handleMessage;};
```

with:

```sqf
if ((player distance _target) > 12) exitWith {
    ["You need to stay at the prison gate to finish restoring the security system!", "basic"] spawn AP_fnc_handleMessage;};
```

Replace the completion call:

```sqf
["You have restored the security system to the Prison!", "basic"] spawn AP_fnc_handleMessage; [
    [2, player, getPlayerUID player], "APS_fnc_handlePrisonBreak", 2] spawn AP_fnc_MP;
```

with:

```sqf
// owner 2026-07-29: route through APS_fnc_prisonGateSRV "disarm" instead of handlePrisonBreak case 2.
// Case 2's entire server-side check is `side _caller isEqualTo west` -- no distance, no rank, no object
// -- so the 12 m and the 30 s above live ONLY here, in the client, and one cop could cancel the event
// from the far side of the map. "disarm" re-derives the caller from remoteExecutedOwner and re-checks
// alive / west / not restrained / not downed / not in a vehicle / within 15 m of the gate, then sets the
// latch and re-locks the outer gate. It also ends the event, so this is not a second cancel path.
["You have restored the security system to the Prison!", "basic"] spawn AP_fnc_handleMessage;
[["disarm"], "APS_fnc_prisonGateSRV", 2] spawn AP_fnc_MP;
```

Also fix the three `select 1` reads on `SRV_prisonData` in this file (`param`, not `select` — the
array is 2-element and a future third slot must not be able to diverge them). Each

```sqf
if !(SRV_prisonData select 1) exitWith {
```

becomes

```sqf
if !(SRV_prisonData param [1, false]) exitWith {
```

Note the file has a pre-existing `_cp` vs `_cP` casing inconsistency at the `if (_cp >= 1)` line —
SQF is case-insensitive on variable names, so it works. **Leave it alone**; it is not this task's
business and changing it adds diff noise to a security-relevant file.

- [ ] **Step 2: Add the cop scroll offer**

In `mission/Armapunk2035.Malden/core/fn_setupActions.sqf`, near the civ breach entry from Task 5,
on ONE line:

```sqf
                // COP DISARM. Same 12 m the hold refuses at; the server re-checks at 15 m as the looser
                // outer bound. Offered only while a break is actually running.
                AP_actions pushBack(_plb_obj addAction ["<t color='#3399FF'>Restore Prison Security</t>",AP_fnc_stopPrisonBreak,"",0,false,false,"",'(playerSide isEqualTo west) && (!isNull (missionNamespace getVariable [ "AP_prisonGateIn", objNull ] )) && ((player distance (missionNamespace getVariable [ "AP_prisonGateIn", objNull ] )) <= 12) && (((missionNamespace getVariable [ "SRV_prisonData", [ 0, false ] ] ) param [ 1, false ] )) && (!AP_action_in_use) && (isNull objectParent player)',12]);
```

- [ ] **Step 3: Verify and test both branches**

```bash
python3 tools/sqf_balance.py mission/Armapunk2035.Malden/core/cop/fn_stopPrisonBreak.sqf mission/Armapunk2035.Malden/core/fn_setupActions.sqf
grep -c "Restore Prison Security" mission/Armapunk2035.Malden/core/fn_setupActions.sqf   # expect exactly 1
grep -c "SRV_prisonData select 1" mission/Armapunk2035.Malden/core/cop/fn_stopPrisonBreak.sqf   # expect 0
bash /home/timb/arma3server_dev/reload-armapunk2035.sh
```

Needs two clients — one civ hacker, one cop.

1. Hack the gate. As the cop, confirm **Restore Prison Security** appears within 12 m of the gate and
   not at 20 m.
2. Complete the 30 s hold. Confirm: the alarm stops, the outer gate closes, the inner gate stays
   open, `corrections` goes back to `ColorWEST`, and the prisoner gets **no** escape dialog.
3. ```bash
   grep -E "\-PRISON-|\-SEC-" /home/timb/arma3server_dev/loonydev.log
   ```
   Expect `GATE HACK disarmed by <UID>`.
4. **Negative test.** Hack again; as the cop, stand ~40 m from the gate and call the server mode
   directly from the debug console:
   ```sqf
   [["disarm"], "APS_fnc_prisonGateSRV", 2] spawn AP_fnc_MP;
   ```
   Expect a `-SEC- BLOCKED prisonGateSRV mode disarm (dist 40) by <UID>` row and **no** disarm. This
   is the check the old case-2 path did not have, so it is the one worth proving.
5. Confirm a new break can start after the 30-minute cooldown, and is refused before it.

- [ ] **Step 4: Commit**

```bash
git add mission/Armapunk2035.Malden/core/cop/fn_stopPrisonBreak.sqf mission/Armapunk2035.Malden/core/fn_setupActions.sqf
git commit
```

```
Make the cop disarm answer at the gate, and prove it there

The cancel path's entire server-side check was `side _caller isEqualTo
west`. The 12 m range and the 30 s hold lived only in the client, so
one officer could cancel a prison break from the far side of the map.
It now routes through APS_fnc_prisonGateSRV, which re-derives the
caller from remoteExecutedOwner and re-checks alive, side, restrained,
downed, vehicle and distance before touching any state.

The hold was also anchored on a laptop this map does not have, passed
in by a function with no callers. It reads the published gate instead
-- fn_setupActions attaches its actions to the player, so an
argument-passed target would have been the player and every distance
gate would have measured zero.

Co-Authored-By: Clippy
```

---

### Task 8: Release on foot, and the tunnel

**Files:**
- Modify: `mission/Armapunk2035.Malden/core/civilian/fn_jailMe.sqf:127`
- Modify: `mission/Armapunk2035.Malden/custom_p3ds/malden_atmosphere.sqf`

**Interfaces:**
- Consumes: `SRV_prisonData` slot 1; `AP_breakout`.
- Produces: no new names.

- [ ] **Step 1: Let escapees walk out**

In `fn_jailMe.sqf`, the `case (AP_breakout)` branch ends with a teleport. The containment test at
`:94` lives **inside** the loop that `:91` exits on breakout, so an escapee is already uncontained the
moment they accept — teleporting them to the release point throws away the open gate the whole event
was about.

Find, inside `case (AP_breakout):`:

```sqf
            uiSleep 2;
            player setPos(getMarkerPos "jail_release2");};
```

Replace with:

```sqf
            uiSleep 2;};
// owner 2026-07-29: NO teleport on the breakout branch. The escape is a gate that opened; walk out of
// it, or take the mine. The containment test at :94 is inside the loop :91 exits on breakout, so the
// player is already uncontained here and needs no exemption flag -- which is also why this design adds
// none. Bail (:121) and served-sentence (:133) keep their setPosATL to _jailReleasePos: those are
// releases through the front office, not an escape.
```

Then confirm the two other branches are untouched:

```bash
grep -n "_jailReleasePos\|jail_release2" mission/Armapunk2035.Malden/core/civilian/fn_jailMe.sqf
```

Expected: `setPosATL _jailReleasePos` still present in the `_bail` branch and the served branch;
**no** `getMarkerPos "jail_release2"` remaining in the breakout branch.

- [ ] **Step 2: Gate the tunnel**

`_fnAdd` in `malden_atmosphere.sqf` registers each teleport with a condition string of `""` — no
condition at all — and a 5 m radius. `enterMine` sits inside the wall ring, 45.8 m from the prison
marker, so a prisoner can walk out of the prison right now with no hack; and once containment is live
it becomes a 1 Hz teleport loop.

Give `_fnAdd` an optional condition, defaulting to today's behaviour so the other two rows are
unaffected. Change the signature and the `addAction`:

```sqf
    params ["_varName", "_label", "_dest", "_lightAfter", ["_cond", "", [""]]];
```

and the action's 8th element from `""` to `_cond`:

```sqf
    _obj addAction [_label, {
        params ["", "", "", "_args"];
        _args params ["_dest", "_lightAfter"];
        playSound3D ["A3\Sounds_F\structures\doors\MetalBigDoor_01_open", player];
        [player, _dest] call playerTeleport;
        if (_lightAfter isEqualTo "cave") then { [] call setCaveLighting } else { [] call setDay };
    }, [_dest, _lightAfter], 5, false, true, "", _cond, 5];
```

Then give the prison-side row its condition:

```sqf
// owner 2026-07-29: enterMine is INSIDE the prison's wall ring, 45.8 m from the prison marker, and had
// no condition whatsoever -- so any prisoner could walk out of the prison through it with no hack at
// all, and once AP_jailPoly went live it became a 1 Hz teleport loop (cave -> fails inPolygon ->
// setPos back to the yard -> action still there). Gated on a live escape: a prisoner who has accepted
// the breakout, or anyone not currently jailed. The mine is the escape's second exit, not a free door.
["enterMine",  "Enter Mine",  [2985.082, 7089.092, 17.600], "cave", "!(player getVariable ['AP_arrested', false]) || AP_breakout"] call _fnAdd;
["exitMine",   "Exit Mine",   [9797.093, 3864.503,  0.152], "day"]  call _fnAdd;   // mine -> surface
["escapeJail", "Escape Jail", [9893.784, 2809.292,  0.000], "day"]  call _fnAdd;   // jail break exit
```

`exitMine` still has no sqm object of that name, so `_fnAdd`'s existing `isNull` guard logs and skips
it — unchanged, and the cave still has no way back in.

- [ ] **Step 3: Test both**

```bash
python3 tools/sqf_balance.py mission/Armapunk2035.Malden/core/civilian/fn_jailMe.sqf mission/Armapunk2035.Malden/custom_p3ds/malden_atmosphere.sqf
bash /home/timb/arma3server_dev/reload-armapunk2035.sh
```

1. As a jailed player with **no** break running: stand at `enterMine` → **Enter Mine** must **not**
   appear. This is the hole that is open today.
2. As a non-jailed civilian at the same spot → it **does** appear and works.
3. Hack the gate, run the window out, accept the escape. Confirm you are **not** teleported, you are
   standing where you were, the gates are open, and you can walk out **or** take the mine.
4. Confirm the bounty survived and the charge landed: check your wanted level and look for charge 13
   "Escaping Jail".
5. Pay bail from a fresh sentence → still teleported to `jail_release2`. Serve a sentence out → still
   teleported. Both branches must be unchanged.

- [ ] **Step 4: Commit**

```bash
git add mission/Armapunk2035.Malden/core/civilian/fn_jailMe.sqf mission/Armapunk2035.Malden/custom_p3ds/malden_atmosphere.sqf
git commit
```

```
Let an escapee walk out of the gate he opened

The breakout branch teleported the prisoner to the release point, which
threw away the thing the whole event is about. Containment is tested
inside the loop the breakout exits, so an escapee is already free at
that point and needs no exemption flag -- which is why this design adds
none. Bail and served sentences keep their teleport: those are releases
through the front office, not escapes.

The designer's mine entrance sits inside the wall ring with no
condition on its action at all, so a prisoner could walk out of the
prison through it today with no hack, and once the containment poly
went live it became a one-per-second teleport loop. It now needs a live
escape, which makes it the second exit rather than a free door.

Co-Authored-By: Bob (the 2005 chatbot)
```

---

### Task 9: The countdown players and cops actually see

**Files:**
- Modify: `mission/Armapunk2035.Malden/initPlayerLocal.sqf` (participant bar `_dur`)
- Modify: `mission/Armapunk2035.Malden/core/compat/fn_startPrisonBreak.sqf` (cop countdown message)
- Modify: `server/AP_server/core/jail/fn_startPrisonBreak.sqf` (twin)

**Interfaces:**
- Consumes: `SRV_prisonData` slots 0 and 1.
- Produces: no new names.

- [ ] **Step 1: Fix the bar that finishes early**

In `initPlayerLocal.sqf`, find:

```sqf
    private _dur = 500;   // owner 2026-06-18: MUST match fn_startPrisonBreak's breakTimer (Altis = 500s) so the bar
```

The comment says it must match `_breakTimer`. `_breakTimer` was `800`, so the bar reached 100% three
hundred seconds early — the "stuck at 87%, nothing happens" report. Replace the assignment and its
comment block with:

```sqf
    // owner 2026-07-29: 600, matching fn_startPrisonBreak's _breakTimer for Malden (the gate hack's
    // 10-minute window). The old value was 500 under a comment asserting it matched a timer that was
    // actually 800, so the bar hit 100% three hundred seconds early -- the "stuck at 87%, never
    // finishes" look. There is no cross-machine source for this number to read: SRV_prisonData carries
    // the START time, not the duration, so the two literals have to be kept in step by hand. If
    // _breakTimer changes, change this.
    private _dur = 600;
```

- [ ] **Step 2: Give cops a countdown instead of one popup**

In both `fn_startPrisonBreak` copies, after the existing west broadcast at `:26`, add:

```sqf
// owner 2026-07-29: a 15 s popup for a 10-minute event told cops it started and nothing else. The
// fed_countdown style is a DRAINING bar over its duration, which is the readout this event wanted all
// along -- and it is already built, so this is a style argument, not new UI.
[["The prison's security system has been compromised -- the gate is open.", "fed_countdown"], "AP_fnc_handleMessage", west, false] spawn AP_fnc_MP;
```

Confirm the style name against the handler before deploying — a wrong key renders nothing:

```bash
grep -n "fed_countdown" mission/Armapunk2035.Malden/dialog/function/fn_handleMessage.sqf
```

If `fed_countdown` hardcodes a 10-minute duration internally, it matches the window exactly. If it
reads a duration from a variable, pass 600.

- [ ] **Step 3: Keep the twins in step, verify, test**

```bash
diff <(sed -n '9,$p' mission/Armapunk2035.Malden/core/compat/fn_startPrisonBreak.sqf) server/AP_server/core/jail/fn_startPrisonBreak.sqf
python3 tools/sqf_balance.py mission/Armapunk2035.Malden/initPlayerLocal.sqf mission/Armapunk2035.Malden/core/compat/fn_startPrisonBreak.sqf server/AP_server/core/jail/fn_startPrisonBreak.sqf
bash /home/timb/arma3server_dev/reload-armapunk2035.sh
```

In-game, with a civ within 350 m of the prison when the break starts, and a cop anywhere:

1. The participant bar appears and reaches 100% **exactly** when the escape dialog fires — not before.
2. The cop sees a draining countdown, not a popup that vanishes.
3. A civ who was 400 m away at kickoff sees **no** bar (the snapshot is deliberate).

- [ ] **Step 4: Commit**

```bash
git add mission/Armapunk2035.Malden/initPlayerLocal.sqf mission/Armapunk2035.Malden/core/compat/fn_startPrisonBreak.sqf server/AP_server/core/jail/fn_startPrisonBreak.sqf
git commit
```

```
Make the prison countdown agree with the prison timer

The participant bar hardcoded 500 seconds under a comment asserting it
matched fn_startPrisonBreak's timer, which was 800 -- so it reached
100% three hundred seconds early and then sat there, which is the
"stuck at 87%, never finishes" report. It is 600 now, the gate window's
length. SRV_prisonData carries the start time and not the duration, so
there is no shared source to read and the two literals are kept in step
by hand; the comment says so.

Cops got one 15-second popup for a ten-minute event. The draining
fed_countdown style already exists and is the readout this wanted.

Co-Authored-By: Ask Jeeves
```

---

### Task 10: Registration sweep, full-tree gate, and the two-client run

**Files:**
- Verify: every file touched by Tasks 1-9
- Modify: only if the sweep finds something

**Interfaces:**
- Consumes: everything above.
- Produces: a green pre-deploy gate and a signed-off in-game run.

- [ ] **Step 1: Confirm every new function is registered and whitelisted**

```bash
grep -n "prisonGateSRV" server/AP_server/config.cpp
grep -n "class prisonGate" mission/Armapunk2035.Malden/Functions.h
grep -n "prisonGateSRV" mission/Armapunk2035.Malden/CfgRE.hpp
```

All three must hit. `CfgRE.hpp` is `mode = 1` — a missing entry fails **silently**, which is the
worst failure mode in this codebase.

- [ ] **Step 2: Balance-check every edited file**

```bash
python3 tools/sqf_balance.py \
  mission/Armapunk2035.Malden/initServer.sqf \
  mission/Armapunk2035.Malden/initPlayerLocal.sqf \
  mission/Armapunk2035.Malden/core/configuration.sqf \
  mission/Armapunk2035.Malden/core/config/fn_mapData.sqf \
  mission/Armapunk2035.Malden/mapImportAll_data.sqf \
  mission/Armapunk2035.Malden/core/fn_setupActions.sqf \
  mission/Armapunk2035.Malden/core/actions/fn_prisonGate.sqf \
  mission/Armapunk2035.Malden/core/civilian/fn_jailMe.sqf \
  mission/Armapunk2035.Malden/core/cop/fn_stopPrisonBreak.sqf \
  mission/Armapunk2035.Malden/core/compat/fn_startPrisonBreak.sqf \
  mission/Armapunk2035.Malden/custom_p3ds/malden_atmosphere.sqf \
  server/AP_server/core/TON/fn_prisonGateSRV.sqf \
  server/AP_server/core/jail/fn_startPrisonBreak.sqf
```

Every line must read `ok` with exit 0.

- [ ] **Step 3: Compile-probe the edited client functions**

The dedicated server never compiles client function files, so a syntax slip in one shows up only as a
player's entire scroll menu silently vanishing. Add temporarily to `initServer.sqf`:

```sqf
// -COMPILEPROBE- TEMPORARY, remove before commit. `compile preprocessFileLineNumbers` PARSES without
// running, so this catches a syntax error in a client file that the server would otherwise never see.
{
    private _r = [_x, false];
    try { _r = [_x, !isNil { compile preprocessFileLineNumbers _x }] } catch { _r = [_x, false] };
    diag_log format ["-COMPILEPROBE- %1 %2", if (_r select 1) then {"ok    "} else {"FAILED"}, _r select 0];
} forEach [
    "core\actions\fn_prisonGate.sqf",
    "core\civilian\fn_jailMe.sqf",
    "core\cop\fn_stopPrisonBreak.sqf",
    "core\compat\fn_startPrisonBreak.sqf",
    "core\fn_setupActions.sqf"
];
```

```bash
bash /home/timb/arma3server_dev/reload-armapunk2035.sh
grep COMPILEPROBE /home/timb/arma3server_dev/loonydev.log
```

Every line must read `ok`. Then delete the probe and re-balance-check `initServer.sqf`.

- [ ] **Step 4: The full two-client run, both outcomes**

Two clients: one civ with ICEBREAKER firmware, one cop. Plus one prisoner (the cop can jail the civ's
alt, or use admin jail).

**Run A — the cops answer:**
1. Prisoner is jailed, lands in the yard, is contained.
2. Civ breaches the gate → both gates open, alarm, red marker, dispatch to west, cop countdown.
3. Cop holds **Restore Prison Security** at the gate for 30 s → alarm stops, outer gate re-locks,
   inner gate stays open, marker restored, prisoner gets **no** dialog and keeps serving.
4. A second breach is refused for 30 minutes, with the cooldown message naming the minutes left.

**Run B — the cops do not:**
1. Breach the gate, let the full 600 s run.
2. Prisoner gets **Escape from Prison?** and accepts.
3. Prisoner is **not** teleported, keeps the full bounty, gains charge 13 "Escaping Jail", and
   `west` sees the escape broadcast.
4. Prisoner walks out through the open sally port, and can also take the mine.
5. Event ends cleanly: alarm stopped, marker restored, cooldown armed.

**Run C — the refusals leave nothing behind:**
1. Breach with the event already active → refused, no second window, gates unchanged.
2. Breach during another federal event → refused with the fed-event message.
3. Breach inside the 15-minute cross-heist lockout → refused with the "security is high" message.
4. After each, confirm `SRV_prisonData` slot 1 is still `false` and the outer gate is still sealed.

- [ ] **Step 5: Check the logs one last time**

```bash
grep -E "\-JAILDBG-|\-SEC-|\-PRISON-|maldenPrison" /home/timb/arma3server_dev/loonydev.log
grep -iE "error|undefined variable" /home/timb/arma3server_dev/loonydev.log | tail -30
grep -iE "error|undefined variable" "$(ls -t ~/.local/share/Steam/steamapps/compatdata/107410/pfx/drive_c/users/steamuser/AppData/Local/Arma\ 3/*.rpt | head -1)" | tail -30
```

No new errors on either side. Every `-SEC-` row must name the **actual** caller.

- [ ] **Step 6: Final commit**

```bash
git add -A
git status --short   # confirm ONLY intended files; dist/ is untracked and stays that way
git commit
```

```
Close out the Malden prison pass

Registration, whitelist and balance gate verified across all thirteen
edited files, the client functions compile-probed from the server
(which never compiles them itself, so a syntax slip there shows up only
as a player's whole scroll menu vanishing), and both outcomes plus the
three refusal paths walked with two clients.

Co-Authored-By: Racter
```

---

## Self-Review

**1. Spec coverage.** Every numbered section of `maldenprison.md` maps to a task:

| spec | task |
|---|---|
| 5.1 four markers | 1 (+ 2 audits the consumers it lists) |
| 5.2 containment polygon | 1 |
| 5.3 promote the gate + resolver | 3 |
| 5.4 the hack | 5 |
| 5.5 the 10-minute window | 6 |
| 5.6 release | 8 |
| 5.7 tunnel | 8 |
| 5.8 cop disarm | 4 (server) + 7 (client + offer) |
| 5.9 signalling and HUD | 9 (bar, cop countdown); alarm leak resolved in 6 |
| 5.10 MaxTac make-safe | 6 step 3 |
| 5.11 restart behaviour | no task — explicitly no new persistence |
| 5.12 latch and end paths | no task — unchanged; Task 6 step 5 confirms it still fires once |
| §7 verification plan | steps 0-1 → Task 3 step 1 and every balance step; 2 → Task 10 step 3; 3 → Task 1 step 5; 4 → Task 1 step 6; 5 → Task 10 step 4; 6 → Task 10 step 5 |

Gaps found and closed while reviewing: the spec's §7 step 0 (frame probe) had no home — it is now
Task 3 step 1, before any radius is chosen. The `fed_countdown` duration is unverified, so Task 9
step 2 checks it against the handler rather than assuming.

**2. Placeholder scan.** No "TBD", no "add error handling", no "similar to Task N" — the two
`_fnc_driveGate` / `_fnc_caller` helpers are written out in full in Task 4 rather than referenced.
One deliberate open value remains: the minigame buffer length in Task 5 is `10`, flagged in-plan as
an owner decision with the valid range, matching its `TODO.md` entry.

**3. Type consistency.** Checked across tasks: `AP_prisonGateIn` / `AP_prisonGateOut` (objects,
published in Task 3, read in 4/5/7); `AP_prisonDisarmed` (bool, published in Task 4, read in 6);
`APS_fnc_prisonGateSRV` modes `"boot"` / `"gatehack"` / `"disarm"` / `"relock"` (Task 4 defines all
four; Task 5 calls `"gatehack"`, Task 7 calls `"disarm"`, Task 3 calls `"boot"`, Task 6's end path
does not call `"relock"` — the disarm path re-locks directly, so `"relock"` is reachable only from a
future reset path and is documented as server-internal); `AP_fnc_prisonGate` (Task 5, no
arguments); `AP_fnc_stopPrisonBreak` (Task 7, argument dropped — nothing else calls it, verified
by the offer being its only registration site). `_breakTimer` = 600 in Task 6 and `_dur` = 600 in
Task 9 agree, and both carry a comment naming the other.
