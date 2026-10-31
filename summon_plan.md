# SUMMON VEHICLE + Air Autopilot — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Helicopters and VTOLs get the seated autopilot; a player stars ONE owned vehicle and one tap makes it spawn ~1 km out and drive (land) or fly + land (air) to them, driven by the headless client. The Robotaxi is removed.

**Architecture:** One flight core (`AP_fnc_flyStep`, all state on the vehicle) hosted twice: the seated player's `fn_gpsAutopilot` EachFrame handler and the HC's frame-paced `AP_fnc_hcFly` loop (a sibling of `fn_hcDrive`). SUMMON is server-orchestrated (`APS_fnc_summonSRV`), but the vehicle is MATERIALISED ON THE OWNER'S CLIENT (`AP_fnc_summonSpawn`, a trimmed copy of the garage pull) because `AP_fnc_prepareVehicle` reads `player`, `AP_side_talents` and `AP_effSide`; the server then takes it and hands it to the HC exactly as Loonazon does. Progress reaches the phone through a client receiver (`AP_fnc_summonState`) that pushes the deck's `summon` channel.

**Tech Stack:** Arma 3 SQF (mission + AP_server addon), PostgreSQL via PySQF (`DB_fnc_asyncQuery`), the HTML deck (`ui/html/deck.html` + `server/AP_server/web/ui/html/deck.html`, kept byte-identical), arma-webui bridge (`webui_fnc_on` / `webui_fnc_push`).

## Global Constraints

- Spec: `SUMMON_SPEC.md` (approved 2026-09-02). Two spec amendments, decided while grounding this plan:
  - **Air vehicles spawn ON THE GROUND** at a flat spot ~1 km out and the flight core's `climb` phase lifts them (spec §3.3 said airborne at cruise altitude). Reason: a heli spawned at 120 m with nobody flying it falls during the up-to-15 s `setOwner` retry window.
  - **No Python math tests** (spec §6 named `tools/test_summon_math.py`). The math is SQF; a Python port would test a copy. The observable red/green is the headless self-test and the owner playtest, plus the static checkers.
- Every `.sqf` this plan touches must pass `python3 tools/sqf_balance.py <file>` (prints `ok   <file>`) before its commit. Every `deck.html` edit is made to BOTH copies (`mission/Armapunk2035.Malden/ui/html/deck.html` and `server/AP_server/web/ui/html/deck.html`) and `python3 tools/html_js_check.py` must print `all ui/html scripts parse`.
- Server functions live in `server/AP_server/core/TON/` and are registered in the `\AP_server\core\TON` block of `server/AP_server/config.cpp` (a class in the wrong block is a silent "Script not found").
- Client-callable server functions need a `CfgRE.hpp` entry (`allowedTargets = 2`); server-to-client functions need `allowedTargets = 1`. `remoteExecutedOwner` is the caller's identity, never a client-supplied object.
- Commit messages: repo style (subject, blank line, body explaining why). Trailer per `CLAUDE.md`:
  ONE line `Co-Authored-By: <defunct AI name>` -- name only, no email, and NO Claude/Anthropic or
  session trailer (the project rule overrides the harness default). Rotate the name, never the same
  one twice in a row; each task's commit block names its own.
- Numbers (spec §7): 1 recall vehicle per player; 1 summon in flight per player; spawn 1000 m (band 700–1100); cruise 60 m/s, approach 15 m/s, descent 3 m/s; cruise altitude = max terrain on the line + 80 m, ≥ 120 m AGL; landing search radius 40 m, 6 m clearance, gradient ≤ 0.3; 300 s cap; cooldown 120 s, not charged on failure; land arrival radius 8 m.
- `PySQF` returns booleans as `0/1`: read `recall` as `(_x param [N, 0]) in [1, true]`.
- Do not run `deploy/reload-armapunk2035.sh` while the owner is connected to the dev server without saying so; it restarts the server.

---

## File Structure

| File | Responsibility |
|---|---|
| `mission/Armapunk2035.Malden/core/gps/fn_isRotorcraft.sqf` (new) | The one air class gate: helicopter, or a config chain containing "VTOL". |
| `mission/Armapunk2035.Malden/core/gps/fn_flyStep.sqf` (new) | Pure per-frame flight step. State on the vehicle. Returns the phase. |
| `mission/Armapunk2035.Malden/core/gps/fn_hcShield.sqf` (new) | hcDrive's collision shield as a function, shared with hcFly. |
| `mission/Armapunk2035.Malden/core/gps/fn_hcFly.sqf` (new) | HC host: frame-paced loop around `flyStep`, shield, watchdog, `hc_ap_done`. |
| `mission/Armapunk2035.Malden/core/gps/fn_gpsAutopilot.sqf` | Air branch in `start`/`drive`/`stop`; Robotaxi branches removed. |
| `mission/Armapunk2035.Malden/init.sqf` | HC pump: air → `hcFly`, land → `hcDrive`. |
| `mission/Armapunk2035.Malden/core/gps/fn_summonPoint.sqf` (new) | Client: pick the ~1 km spawn point (road for land, flat spot for air). |
| `mission/Armapunk2035.Malden/core/gps/fn_summonSpawn.sqf` (new) | Client: materialise the row at a position (trimmed garage pull), then hand the vehicle to the server. |
| `mission/Armapunk2035.Malden/core/gps/fn_summonState.sqf` (new) | Client receiver: cache state, push the deck `summon` channel, chat on arrival/failure. |
| `server/AP_server/core/TON/fn_summonSRV.sqf` (new) | Server: `set`, `info`, `go`, `drive`, `selftest`. |
| `server/AP_server/core/system/fn_getVehicles.sqf` | Garage rows carry `recall` (index 14). |
| `server/AP_server/init.sqf` | DDL for `vehicles.recall`; `summonselftest` bot command. |
| `mission/Armapunk2035.Malden/core/web/fn_deckGarage.sqf` | Row payload `recall`; `["recall", id]` verb. |
| `mission/Armapunk2035.Malden/core/web/fn_deckSummon.sqf` (new) | Deck SUMMON app verbs: `data`, `go`. |
| `mission/Armapunk2035.Malden/core/web/fn_deckOpen.sqf` | Register the `summon` handler. |
| `mission/Armapunk2035.Malden/core/web/fn_deckData.sqf` | App catalogue: `SUMMON VEHICLE`. |
| `mission/Armapunk2035.Malden/core/configuration.sqf` | `AP_phone_buttons`: Robotaxi row → SUMMON VEHICLE row. |
| `mission/Armapunk2035.Malden/ui/html/deck.html` (+ served copy) | Garage ★, SUMMON VEHICLE view, actions, channel. |
| `mission/Armapunk2035.Malden/core/radio/fn_radioRadial.sqf`, `core/web/fn_carRadioBridge.sqf`, `core/shops/fn_vehicleShopMods.sqf`, `core/web/fn_deckGarage.sqf` | Autopilot gates accept air. |
| `mission/Armapunk2035.Malden/Functions.h`, `CfgRE.hpp`, `server/AP_server/config.cpp` | Registrations. |
| Removed: `core/gps/fn_robotaxi.sqf`, `server/AP_server/core/TON/fn_robotaxiSRV.sqf` | Robotaxi. |

Shared vocabulary (vehicle variables, all `setVariable … true` unless noted):

| Var | Set by | Meaning |
|---|---|---|
| `fly_phase` | flyStep | `"climb"` `"cruise"` `"approach"` `"descend"` `"landed"` `"hover"` `"aborted"` |
| `fly_dest` | host | `[x, y, z]` destination |
| `fly_alt` | flyStep | cruise altitude, ASL metres |
| `fly_land` | flyStep | landing spot `[x, y]` or `[]` |
| `fly_chk` | flyStep (local) | `[time, distance]` progress anchor |
| `fly_t0` | host | engage time |
| `hc_ap_want / hc_ap_dest / hc_ap_mode / hc_ap_driving / hc_ap_done / hc_ap_arrive / hc_ap_lock / hc_ap_abort` | existing | unchanged meanings (see `fn_hcDrive.sqf` header) |
| `AP_summonFor` | summonSRV | uid of the summoner while en route |

---

### Task 1: DB column + garage rows carry `recall`

**Files:**
- Modify: `server/AP_server/init.sqf:222` (DDL line, after the `rig_kind` ALTER)
- Modify: `server/AP_server/core/system/fn_getVehicles.sqf:51,57-82`
- Modify: `mission/Armapunk2035.Malden/core/web/fn_deckGarage.sqf:34-73` (`data` case)

**Interfaces:**
- Produces: garage row index **14** = `recall` (0/1 from PySQF); deck garage payload row field `recall` (Boolean).

- [ ] **Step 1: Observe the red state**

Run:
```bash
export PGPASSWORD=$(tr '\0' '\n' < /proc/$(pgrep -f '[p]ython pysqfd.py' | head -1)/environ | grep PYSQF_DB_DSN | grep -o 'password=[^ ]*' | cut -d= -f2)
psql -h 127.0.0.1 -U armapunk -d pgm_full_scratch -At -c "SELECT column_name FROM information_schema.columns WHERE table_name='vehicles' AND column_name='recall'"
```
Expected: empty output (no column).

- [ ] **Step 2: Add the DDL**

In `server/AP_server/init.sqf`, directly after the line
```sqf
["ALTER TABLE vehicles ADD COLUMN IF NOT EXISTS rig_kind varchar(16) NOT NULL DEFAULT ''", 2, true] call DB_fnc_asyncQuery;   // resource rig identity survives the garage
```
add:
```sqf
["ALTER TABLE vehicles ADD COLUMN IF NOT EXISTS recall boolean NOT NULL DEFAULT false", 2, true] call DB_fnc_asyncQuery;   // SUMMON VEHICLE: the one starred recall vehicle per player
```

- [ ] **Step 3: Carry it through the garage query**

In `server/AP_server/core/system/fn_getVehicles.sqf` change the SELECT column list on line 51 from
```
...COALESCE(rig_kind,'') AS rig_kind FROM %1 WHERE...
```
to
```
...COALESCE(rig_kind,'') AS rig_kind, recall FROM %1 WHERE...
```
Update the order comment on line 57 to end `,10 rig_kind,11 recall.` and add a 15th element to the `_out` row, after the `rig_kind` element:
```sqf
        format ["%1", _x param [10, ""]], // 13 rig_kind ("" for ordinary vehicles)
        ((_x param [11, 0]) in [1, true])  // 14 recall: the starred SUMMON VEHICLE (PySQF hands booleans back as 0/1)
    ]};
```
(The previous element gains a trailing comma.)

- [ ] **Step 4: Surface it in the deck payload**

In `fn_deckGarage.sqf` `case "data"`, inside the `_rows pushBack (createHashMapFromArray [ … ])` add after `["rig", _rigK],`:
```sqf
            ["recall", _x param [14, false]],
```

- [ ] **Step 5: Balance-check and observe the green state**

Run:
```bash
python3 tools/sqf_balance.py server/AP_server/init.sqf server/AP_server/core/system/fn_getVehicles.sqf mission/Armapunk2035.Malden/core/web/fn_deckGarage.sqf
```
Expected: three `ok` lines. The column itself appears after the next dev deploy (Task 12); at that point re-run the psql query from Step 1 and expect `recall`.

- [ ] **Step 6: Commit**

```bash
git add server/AP_server/init.sqf server/AP_server/core/system/fn_getVehicles.sqf mission/Armapunk2035.Malden/core/web/fn_deckGarage.sqf
git commit -F - <<'EOF'
feat(summon): vehicles.recall column, carried through the garage rows

One starred recall vehicle per player for SUMMON VEHICLE (SUMMON_SPEC.md).
Boot DDL like rig_kind; APS_fnc_getVehicles selects it as row index 14 and the
deck garage payload exposes it as `recall`. Nothing reads it yet.

Co-Authored-By: Dr. Sbaitso
EOF
```

---

### Task 2: Flight core — `AP_fnc_flyStep`

**Files:**
- Create: `mission/Armapunk2035.Malden/core/gps/fn_flyStep.sqf`
- Modify: `mission/Armapunk2035.Malden/Functions.h:233` (GPS block, after `class hcDrive {};`)

**Interfaces:**
- Produces: `[_vehOrClass] call AP_fnc_isRotorcraft` → Boolean (every later task's air gate). `[_veh, _dt] call AP_fnc_flyStep` → String phase. Host must set `fly_dest` (Array `[x,y,z]`) and clear `fly_alt` (`setVariable ["fly_alt", nil]`) when engaging; it may pre-set `fly_phase "climb"`. The step initialises everything else when `fly_alt` is absent. Reads `fly_dest` every call, so a host may move the destination.
- Produces helper `[_from, _to] call AP_fnc_flyCruiseAlt` (defined inside the same file as a global code var `AP_fnc_flyCruiseAlt` on first run) → Number ASL.

- [ ] **Step 0: The rotorcraft predicate** — create `mission/Armapunk2035.Malden/core/gps/fn_isRotorcraft.sqf`:

```sqf
/*
    AP_fnc_isRotorcraft -- is this object or classname a helicopter or a VTOL?
    The autopilot flies both and never a plane. VTOLs inherit Plane_Base_F, so a
    plain "isKindOf Plane" catches them; and their own base class name is not
    something this codebase has ever asserted, so walk the config chain for
    "VTOL" instead of naming it. One predicate, used by every gate.

        [_vehOrClass] call AP_fnc_isRotorcraft   -> Boolean
*/
params [["_v", "", [objNull, ""]]];
private _cls = if (_v isEqualType "") then { _v } else { typeOf _v };
if (_cls isEqualTo "") exitWith { false };
if (_cls isKindOf "Helicopter") exitWith { true };
private _cfg = configFile >> "CfgVehicles" >> _cls;
private _hit = false;
while { isClass _cfg && {!_hit} } do {
    if (((configName _cfg) find "VTOL") > -1) then { _hit = true; };
    _cfg = inheritsFrom _cfg;
};
_hit
```
Register it in `Functions.h` (GPS block, after `class hcDrive {};`):
```
 class isRotorcraft {}; // helicopter or VTOL (config-chain test) -- the one class gate every air autopilot path uses
```

- [ ] **Step 1: Write the file**

```sqf
/*
    AP_fnc_flyStep  (Armapunk 2035, 2026-09-02) -- ONE FRAME of rotorcraft autopilot.

    Pure step: every bit of state lives on the vehicle, so the same code flies a
    heli with the owner in the seat (fn_gpsAutopilot's EachFrame handler) and a
    driverless one on the headless client (AP_fnc_hcFly). No globals.

        [_veh, _dt] call AP_fnc_flyStep;      -> phase (String)

    Host contract: set `fly_dest` ([x, y, z], z ignored) before the first call and
    keep it current (a moving summoner). Clear `fly_alt` (setVariable nil) when
    engaging; optionally pre-set `fly_phase` "climb" to force a lift-off, otherwise a
    vehicle already > 30 m up starts in "cruise".

    Phases  climb -> cruise -> approach -> descend -> landed
            "hover"   no flat spot within 40 m: holding 3 m over the target
            "aborted" progress watchdog fired (no closing on the target for 6 s)

    Movement is setVelocity toward a carrot (not setVelocityModelSpace -- model
    Y is not "forward" for a banked rotorcraft) and setVectorDirAndUp for the
    attitude. Helicopters and VTOLs fly the identical model: a VTOL is flown as
    a rotorcraft, no transition. Planes are never accepted.
*/
params [["_veh", objNull, [objNull]], ["_dt", 0.016, [0]]];
if (isNull _veh || {!alive _veh}) exitWith { "aborted" };
if !([_veh] call AP_fnc_isRotorcraft) exitWith { "aborted" };
_dt = (_dt max 0.005) min 0.2;

private _dest = _veh getVariable ["fly_dest", []];
if (!(_dest isEqualType []) || {count _dest < 2}) exitWith { "aborted" };
private _dest2 = [_dest select 0, _dest select 1];

// ---------------------------------------------------------------- cruise altitude
// Max terrain along the straight line, sampled every 100 m, + 80 m; never under 120 m
// over the start. Defined once as a global code var so the host can pre-compute it.
if (isNil "AP_fnc_flyCruiseAlt") then {
    AP_fnc_flyCruiseAlt = {
        params ["_from", "_to"];
        private _d = _from distance2D _to;
        private _n = (ceil (_d / 100)) max 1;
        private _hi = 0;
        for "_i" from 0 to _n do {
            private _t = _i / _n;
            private _p = [(_from select 0) + ((_to select 0) - (_from select 0)) * _t,
                          (_from select 1) + ((_to select 1) - (_from select 1)) * _t, 0];
            _hi = _hi max (getTerrainHeightASL _p);
        };
        (_hi + 80) max ((getTerrainHeightASL [_from select 0, _from select 1, 0]) + 120)
    };
};

private _pos = getPosASL _veh;
private _vel = velocity _veh;
private _phase = _veh getVariable ["fly_phase", ""];

// ---------------------------------------------------------------- first call
// Initialise when nothing is set up yet, detected by the ABSENCE of fly_alt rather than by an
// empty phase: a host may pre-set fly_phase "climb" to force a lift-off and still gets the
// altitude sample, the landing slot and the engine. Hosts clear fly_alt (setVariable nil) when
// they engage, so a second flight on the same airframe never inherits the last one's altitude.
if (isNil {_veh getVariable "fly_alt"}) then {
    if (_phase isEqualTo "") then {
        private _agl = (_pos select 2) - (getTerrainHeightASL _pos);
        _phase = if (_agl > 30) then { "cruise" } else { "climb" };
    };
    _veh setVariable ["fly_phase", _phase, true];
    _veh setVariable ["fly_alt", [_pos, _dest] call AP_fnc_flyCruiseAlt];
    _veh setVariable ["fly_land", []];
    _veh setVariable ["fly_chk", [time, _pos distance2D _dest2]];
    _veh setVariable ["fly_destSeen", _dest2];
    _veh engineOn true;
};
// destination moved (a walking summoner): re-sample the altitude, drop the landing spot
if ((_veh getVariable ["fly_destSeen",_dest2]) distance2D _dest2 > 25) then {
    _veh setVariable ["fly_destSeen", _dest2];
    _veh setVariable ["fly_alt", [_pos, _dest] call AP_fnc_flyCruiseAlt];
    _veh setVariable ["fly_land", []];
    if (_phase in ["approach", "descend"]) then { _phase = "cruise"; _veh setVariable ["fly_phase", _phase, true]; };
};

private _alt = _veh getVariable ["fly_alt", (_pos select 2) + 120];
private _dist = _pos distance2D _dest2;
private _spdH = sqrt ((_vel select 0) ^ 2 + (_vel select 1) ^ 2);

// ---------------------------------------------------------------- landing spot
// isFlatEmpty over a spiral of candidates within 40 m: 6 m clear of objects, gradient <= 0.3
// over an 8 m radius, land only. First hit wins; none -> [] and the host gets "hover".
private _fnLandSpot = {
    params ["_c"];
    private _out = [];
    private _cands = [[0, 0]];
    for "_r" from 8 to 40 step 8 do {
        for "_a" from 0 to 330 step 30 do { _cands pushBack [_r * sin _a, _r * cos _a]; };
    };
    {
        private _p = [(_c select 0) + (_x select 0), (_c select 1) + (_x select 1), 0];
        private _flat = _p isFlatEmpty [6, -1, 0.3, 8, 0, false, objNull];
        if (_flat isNotEqualTo []) exitWith { _out = [_flat select 0, _flat select 1]; };
    } forEach _cands;
    _out
};

// ---------------------------------------------------------------- targets per phase
private _want = [0, 0, 0];      // wanted velocity, world frame
private _levelOut = false;
switch (_phase) do {
    case "climb": {
        // straight up, nose already toward the destination
        _want = [0, 0, 8];
        if ((_pos select 2) >= _alt - 2) then { _phase = "cruise"; _veh setVariable ["fly_phase", _phase, true]; };
    };
    case "cruise": {
        private _dir = [(_dest2 select 0) - (_pos select 0), (_dest2 select 1) - (_pos select 1), 0];
        private _len = vectorMagnitude _dir;
        if (_len > 0.1) then { _dir = _dir vectorMultiply (1 / _len); };
        // ramp toward 60 m/s at 6 m/s^2, hold cruise altitude
        private _target = ((_spdH + 6 * _dt) min 60) min (_dist / 4 max 15);
        private _vz = (((_alt - (_pos select 2)) * 0.6) max -6) min 6;
        _want = [(_dir select 0) * _target, (_dir select 1) * _target, _vz];
        if (_dist < 250) then {
            _phase = "approach"; _veh setVariable ["fly_phase", _phase, true];
            _veh setVariable ["fly_land", [_dest2] call _fnLandSpot];
        };
    };
    case "approach": {
        _levelOut = true;
        private _land = _veh getVariable ["fly_land", []];
        if (_land isEqualTo []) then { _land = _dest2; };
        private _dl = _pos distance2D _land;
        private _dir = [(_land select 0) - (_pos select 0), (_land select 1) - (_pos select 1), 0];
        if (_dl > 0.1) then { _dir = _dir vectorMultiply (1 / _dl); };
        // 15 m/s, scaled down by remaining distance, floor 3 m/s; slide down to 25 m AGL
        private _target = ((_dl / 6) max 3) min 15;
        private _aglHold = (getTerrainHeightASL _land) + 25;
        private _vz = (((_aglHold - (_pos select 2)) * 0.5) max -5) min 3;
        _want = [(_dir select 0) * _target, (_dir select 1) * _target, _vz];
        if (_dl < 8 && {_spdH < 4}) then {
            _phase = if ((_veh getVariable ["fly_land", []]) isEqualTo []) then { "hover" } else { "descend" };
            _veh setVariable ["fly_phase", _phase, true];
        };
    };
    case "descend": {
        _levelOut = true;
        private _land = _veh getVariable ["fly_land", _dest2];
        private _dir = [(_land select 0) - (_pos select 0), (_land select 1) - (_pos select 1), 0];
        private _dl = _pos distance2D _land;
        if (_dl > 0.1) then { _dir = _dir vectorMultiply (1 / _dl); };
        private _agl = (_pos select 2) - (getTerrainHeightASL _pos);
        private _vz = if (_agl > 3) then { -3 } else { -0.5 };
        _want = [(_dir select 0) * (_dl min 2), (_dir select 1) * (_dl min 2), _vz];
        if (isTouchingGround _veh || {_agl < 0.6}) then {
            _phase = "landed"; _veh setVariable ["fly_phase", _phase, true];
            _veh setVelocity [0, 0, 0];
            _veh engineOn false;
        };
    };
    case "hover": {
        _levelOut = true;
        private _aglHold = (getTerrainHeightASL _dest2) + 3;
        private _vz = (((_aglHold - (_pos select 2)) * 0.6) max -3) min 3;
        private _dir = [(_dest2 select 0) - (_pos select 0), (_dest2 select 1) - (_pos select 1), 0];
        _want = [(_dir select 0) * 0.5, (_dir select 1) * 0.5, _vz];
    };
    default {};   // landed / aborted: nothing to drive
};

if (_phase in ["landed", "aborted"]) exitWith { _phase };

// ---------------------------------------------------------------- progress watchdog
if (_phase in ["cruise", "approach"]) then {
    (_veh getVariable ["fly_chk", [time, _dist]]) params ["_t", "_d"];
    if (time - _t > 6) then {
        if (_d - _dist < 5) exitWith {
            _phase = "aborted"; _veh setVariable ["fly_phase", _phase, true];
        };
        _veh setVariable ["fly_chk", [time, _dist]];
    };
};
if (_phase isEqualTo "aborted") exitWith { _phase };

// ---------------------------------------------------------------- apply: velocity, then attitude
// Blend toward the wanted velocity (aircraft, not a car: the blend IS the inertia)
private _k = (_dt * 2.5) min 1;
private _new = [(_vel select 0) + ((_want select 0) - (_vel select 0)) * _k,
                (_vel select 1) + ((_want select 1) - (_vel select 1)) * _k,
                (_vel select 2) + ((_want select 2) - (_vel select 2)) * _k];
_veh setVelocity _new;

// Attitude: heading = travel direction (or the destination when slow), pitch down with speed,
// bank into the lateral acceleration. Level in approach/descend/hover.
private _hx = _new select 0; private _hy = _new select 1;
if (sqrt (_hx ^ 2 + _hy ^ 2) < 3) then { _hx = (_dest2 select 0) - (_pos select 0); _hy = (_dest2 select 1) - (_pos select 1); };
private _hl = sqrt (_hx ^ 2 + _hy ^ 2);
if (_hl < 0.1) then { _hx = 0; _hy = 1; _hl = 1; };
_hx = _hx / _hl; _hy = _hy / _hl;
private _spdNew = sqrt ((_new select 0) ^ 2 + (_new select 1) ^ 2);
private _pitch = if (_levelOut) then { 0 } else { ((-((_spdNew / 60) * 10)) max -10) min 0 };   // degrees, nose down, never past 10
private _latA = ((_want select 0) - (_vel select 0)) * _hy - ((_want select 1) - (_vel select 1)) * _hx;
private _bank = if (_levelOut) then { 0 } else { ((_latA / _dt / 9.81 * 25) max -25) min 25 };
private _dirV = [_hx * cos _pitch, _hy * cos _pitch, sin _pitch];
private _right = [_hy, -_hx, 0];
private _upV = [(_right select 0) * sin _bank, (_right select 1) * sin _bank, cos _bank];
_veh setVectorDirAndUp [_dirV, _upV];

_phase
```

- [ ] **Step 2: Register it**

In `mission/Armapunk2035.Malden/Functions.h`, after the line `class hcDrive {}; // HEADLESS AUTOPILOT: …` add:
```
 class flyStep {}; // ROTORCRAFT AUTOPILOT: one frame of flight, all state on the vehicle (seated player + HC share it)
```

- [ ] **Step 3: Static checks**

Run:
```bash
python3 tools/sqf_balance.py mission/Armapunk2035.Malden/core/gps/fn_isRotorcraft.sqf mission/Armapunk2035.Malden/core/gps/fn_flyStep.sqf
python3 tools/sqf_cmd_check.py mission/Armapunk2035.Malden/core/gps/fn_isRotorcraft.sqf mission/Armapunk2035.Malden/core/gps/fn_flyStep.sqf
```
Expected: `ok` from the first; the second prints nothing (every command token is a real Arma command). If it names a token, it is a typo in the file — fix it.

- [ ] **Step 4: Commit**

```bash
git add mission/Armapunk2035.Malden/core/gps/fn_isRotorcraft.sqf mission/Armapunk2035.Malden/core/gps/fn_flyStep.sqf mission/Armapunk2035.Malden/Functions.h
git commit -F - <<'EOF'
feat(gps): AP_fnc_flyStep -- one frame of rotorcraft autopilot, all state on the vehicle

The flight core both hosts share (SUMMON_SPEC.md section 2): climb, cruise at the
max-terrain-plus-80 altitude, approach, descend onto an isFlatEmpty spot within
40 m, or hover at 3 m when there is none. setVelocity toward a carrot plus
setVectorDirAndUp for bank and pitch; helis and VTOLs fly the same model.
Nothing calls it yet.

Co-Authored-By: Eliza
EOF
```

---

### Task 3: HC host — `AP_fnc_hcFly` + the pump's air branch

**Files:**
- Create: `mission/Armapunk2035.Malden/core/gps/fn_hcFly.sqf`
- Modify: `mission/Armapunk2035.Malden/init.sqf:76-79` (HC driver pump)
- Modify: `mission/Armapunk2035.Malden/Functions.h` (after `class flyStep {};`)

**Interfaces:**
- Consumes: `AP_fnc_flyStep`.
- Produces: `[_veh, _dest] call AP_fnc_hcFly` → Boolean started. Sets `hc_ap_driving`, `hc_ap_done` (`"landed"` | `"hover"` | `"wrecked"` | `"timeout"` | `"lostlocality"` | `"aborted"` | `"vanished"`), `hc_ap_abort` honoured.

- [ ] **Step 0: Lift hcDrive's collision shield into one function** — create `mission/Armapunk2035.Malden/core/gps/fn_hcShield.sqf`:

```sqf
/*
    AP_fnc_hcShield  (Armapunk 2035, 2026-09-02) -- collision shield for a headless-owned autopilot vehicle.
    A setVelocity-driven vehicle with no human at the wheel clips town buildings/terrain and self-destructs
    in seconds. Ignore IMPACT/collision/fire damage, but STILL let weapons through so players can intercept
    it. Shared by AP_fnc_hcDrive (ground) and AP_fnc_hcFly (air); added where the vehicle is local, removed
    by the caller when its autopilot run ends.

    In:  [_veh]   Out: nil. Sets hc_ap_dmgEH on the vehicle (the caller removes the EH with it when done).
*/
params [["_veh", objNull, [objNull]]];
private _dmgEH = _veh addEventHandler ["HandleDamage", {params ["_v", "_sel", "_dmg", "_src", "_proj", "_hi", "_inst", "_hp"];
    if (_proj isNotEqualTo "" || {!isNull _inst && {_inst isKindOf "CAManBase"} && {_inst isNotEqualTo _v}}) exitWith { _dmg };
    if (_hp isEqualTo "") then { damage _v } else { _v getHitPointDamage _hp }}];
_veh setVariable ["hc_ap_dmgEH", _dmgEH];
```
Then in `mission/Armapunk2035.Malden/core/gps/fn_hcDrive.sqf` replace the inline statement `private _dmgEH = _veh addEventHandler ["HandleDamage", {params … }];` AND the line `_veh setVariable ["hc_ap_dmgEH", _dmgEH];` that follows it (keep the comment paragraph above them) with the single line:
```sqf
[_veh] call AP_fnc_hcShield;
```
hcDrive's end-of-drive cleanup removes the handler through `hc_ap_dmgEH`, which the function sets; the caller stores nothing. Register in `Functions.h` after `class hcDrive {};`:
```
 class hcShield {}; // driverless collision shield (HandleDamage): impact/fire ignored, weapons allowed -- hcDrive + hcFly
```

- [ ] **Step 1: Write the file**

```sqf
/*
    AP_fnc_hcFly  (Armapunk 2035, 2026-09-02) -- HEADLESS ROTORCRAFT AUTOPILOT.
    Sibling of AP_fnc_hcDrive for helicopters and VTOLs: flies a LOCAL, empty
    aircraft to a destination with AP_fnc_flyStep, one step per rendered frame,
    and lands it. Runs where the aircraft is local (the HC, or the server).

    In:  [_veh, _dest]        Out: true if it started, false if not local / wrong class.
    Sets on the vehicle (public): hc_ap_driving while en route, hc_ap_done at the end:
        "landed" | "hover" | "wrecked" | "timeout" | "lostlocality" | "aborted" | "vanished"
*/
params [["_veh", objNull, [objNull]], ["_dest", [0, 0, 0], [[]]]];
if (isNull _veh || {!local _veh}) exitWith { false };
if !([_veh] call AP_fnc_isRotorcraft) exitWith { false };
if (_veh getVariable ["hc_ap_driving", false]) exitWith { false };

if (_veh getVariable ["hc_ap_lock", false]) then { _veh lock 2; };
_veh setVariable ["hc_ap_abort", false, true];
_veh setVariable ["hc_ap_driving", true, true];
_veh setVariable ["hc_ap_done", "", true];
_veh setVariable ["fly_phase", "", true];
_veh setVariable ["fly_alt", nil];            // flyStep initialises on a missing fly_alt
_veh setVariable ["fly_dest", _dest, true];
_veh setVariable ["fly_t0", time];

// Collision shield shared with hcDrive (sets hc_ap_dmgEH): ignore impact/fire, let weapons through.
[_veh] call AP_fnc_hcShield;

[_veh] spawn {
    params ["_veh"];
    private _end = time + 300;
    private _fno = diag_frameNo - 1;
    private _lastT = time;
    private _reason = "";
    diag_log format ["HCFLY start: veh=%1 dest=%2 local=%3", _veh, _veh getVariable ["fly_dest", []], local _veh];
    while { !isNull _veh && {alive _veh} && {local _veh} && {time < _end} && {!(_veh getVariable ["hc_ap_abort", false])} } do {
        // one update per rendered frame, real elapsed dt (hcDrive footgun 1 -- never uiSleep 0)
        waitUntil { diag_frameNo != _fno };
        _fno = diag_frameNo;
        private _dt = (time - _lastT) min 0.2;
        if (_dt <= 0) then { _dt = diag_deltaTime max 0.01; };
        _lastT = time;
        // the summoner may walk: the server re-publishes hc_ap_dest every 5 s
        private _d = _veh getVariable ["hc_ap_dest", []];
        if (_d isEqualType [] && {count _d >= 2}) then { _veh setVariable ["fly_dest", _d]; };
        private _phase = [_veh, _dt] call AP_fnc_flyStep;
        if (_phase in ["landed", "hover", "aborted"]) exitWith { _reason = _phase; };
    };
    if (_reason isEqualTo "") then {
        _reason = call {
            if (isNull _veh) exitWith { "vanished" };
            if (!alive _veh) exitWith { "wrecked" };
            if (!(local _veh)) exitWith { "lostlocality" };
            if (_veh getVariable ["hc_ap_abort", false]) exitWith { "aborted" };
            if (time >= _end) exitWith { "timeout" };
            "interrupted"
        };
    };
    diag_log format ["HCFLY end: veh=%1 reason=%2 local=%3 alive=%4", _veh, _reason, (!isNull _veh && {local _veh}), alive _veh];
    if (!isNull _veh) then {
        private _eh = _veh getVariable ["hc_ap_dmgEH", -1];
        if (_eh >= 0) then { _veh removeEventHandler ["HandleDamage", _eh]; _veh setVariable ["hc_ap_dmgEH", nil]; };
        if (local _veh && {alive _veh} && {_reason isNotEqualTo "hover"}) then { _veh setVelocity [0, 0, 0]; };
        _veh setVariable ["hc_ap_driving", false, true];
        _veh setVariable ["hc_ap_want", false, true];
        _veh setVariable ["hc_ap_done", _reason, true];
    };
};
true
```

- [ ] **Step 2: Teach the HC pump to fly**

In `mission/Armapunk2035.Malden/init.sqf`, the pump's normal branch reads:
```sqf
                            private _dest = _x getVariable ["hc_ap_dest", []];
                            if (_dest isEqualType [] && {count _dest >= 2}) then {
                                [_x, _dest, _x getVariable ["hc_ap_mode", "normal"]] call AP_fnc_hcDrive;};};};};} forEach vehicles;
```
Replace with:
```sqf
                            private _dest = _x getVariable ["hc_ap_dest", []];
                            if (_dest isEqualType [] && {count _dest >= 2}) then {
                                // rotorcraft fly (AP_fnc_hcFly); everything else drives the road graph
                                if ([_x] call AP_fnc_isRotorcraft) then {
                                    [_x, _dest] call AP_fnc_hcFly;
                                } else {
                                    [_x, _dest, _x getVariable ["hc_ap_mode", "normal"]] call AP_fnc_hcDrive;};};};};};} forEach vehicles;
```

- [ ] **Step 3: Register**

In `Functions.h` after `class flyStep {};` add:
```
 class hcFly {}; // HEADLESS ROTORCRAFT AUTOPILOT: fly + land an empty heli/VTOL on the HC (sibling of hcDrive)
```

- [ ] **Step 4: Static checks**

```bash
python3 tools/sqf_balance.py mission/Armapunk2035.Malden/core/gps/fn_hcShield.sqf mission/Armapunk2035.Malden/core/gps/fn_hcFly.sqf mission/Armapunk2035.Malden/core/gps/fn_hcDrive.sqf mission/Armapunk2035.Malden/init.sqf
python3 tools/sqf_cmd_check.py mission/Armapunk2035.Malden/core/gps/fn_hcShield.sqf mission/Armapunk2035.Malden/core/gps/fn_hcFly.sqf
```
Expected: two `ok`; no unknown tokens.

- [ ] **Step 5: Commit**

```bash
git add mission/Armapunk2035.Malden/core/gps/fn_hcShield.sqf mission/Armapunk2035.Malden/core/gps/fn_hcFly.sqf mission/Armapunk2035.Malden/core/gps/fn_hcDrive.sqf mission/Armapunk2035.Malden/init.sqf mission/Armapunk2035.Malden/Functions.h
git commit -F - <<'EOF'
feat(gps): AP_fnc_hcFly -- the headless client flies rotorcraft; the pump picks fly vs drive by class

Frame-paced loop around AP_fnc_flyStep with hcDrive's collision shield, 300 s
cap and hc_ap_done vocabulary, so anything that hands an aircraft to the HC
with hc_ap_want/hc_ap_dest gets it flown and landed. The HC pump routes
Helicopter/VTOL_Base_F to it and everything else to hcDrive as before.

Co-Authored-By: SmarterChild
EOF
```

---

### Task 4: Seated autopilot flies; gates accept air

**Files:**
- Modify: `mission/Armapunk2035.Malden/core/gps/fn_gpsAutopilot.sqf` (`start`, `stop`, `drive`)
- Modify: `mission/Armapunk2035.Malden/core/radio/fn_radioRadial.sqf:46`
- Modify: `mission/Armapunk2035.Malden/core/web/fn_carRadioBridge.sqf:107`
- Modify: `mission/Armapunk2035.Malden/core/web/fn_deckGarage.sqf:174`
- Modify: `mission/Armapunk2035.Malden/core/shops/fn_vehicleShopMods.sqf:41-44`

**Interfaces:**
- Consumes: `AP_fnc_flyStep`, `AP_gpsDest` (set by `AP_fnc_gps "set"` / web-map NAV).
- Produces: `["start", _mode] call AP_fnc_gpsAutopilot` works in a heli/VTOL with the module; `AP_gpsAPAir` (Boolean global) true while the air branch runs.

- [ ] **Step 1: Air branch in `start`**

In `fn_gpsAutopilot.sqf`, `case "start"`, replace the first gate line
```sqf
        if (_veh isEqualTo player || {!(_veh isKindOf "LandVehicle")} || {!_isRobotaxi && {driver _veh isNotEqualTo player}}) exitWith {};
```
with
```sqf
        private _isAir = [_veh] call AP_fnc_isRotorcraft;
        if (_veh isEqualTo player || {!(_veh isKindOf "LandVehicle") && {!_isAir}} || {driver _veh isNotEqualTo player}) exitWith {};
```
and delete the two `_isRobotaxi` lines above it (the comment block and `private _isRobotaxi = …`). Then, directly after the module gate (`if !(_veh getVariable ["AP_autopilot", false]) exitWith { … };`) insert the whole air branch:
```sqf
        // ---------------------------------------------------------------- ROTORCRAFT
        // No road route, no on-road rule: fly straight to AP_gpsDest with AP_fnc_flyStep. The same
        // EachFrame handler drives it; the same "touch the controls" disengage applies (heli inputs).
        if (_isAir) exitWith {
            private _dest = missionNamespace getVariable ["AP_gpsDest", []];
            if (_dest isEqualTo []) exitWith {
                ["<t color='#00d4ff'>AUTOPILOT:</t> set a GPS destination first.", "basic"] spawn AP_fnc_handleMessage;};
            if (_veh distance2D _dest < 100) exitWith {
                ["<t color='#00d4ff'>AUTOPILOT:</t> destination is right here -- you can see it.", "basic"] spawn AP_fnc_handleMessage;};
            if (missionNamespace getVariable ["AP_gpsAP", false]) exitWith {
                ["<t color='#00d4ff'>AUTOPILOT:</t> already flying.", "basic"] spawn AP_fnc_handleMessage;};
            private _dmgMax = damage _veh;
            { _dmgMax = _dmgMax max _x; } forEach ((getAllHitPointsDamage _veh) param [2, []]);
            if (_dmgMax >= 0.25) exitWith {
                ["<t color='#00d4ff'>AUTOPILOT:</t> the aircraft is damaged -- repair it before engaging.", "basic"] spawn AP_fnc_handleMessage;};
            _veh setVariable ["fly_phase", "", true];
            _veh setVariable ["fly_alt", nil];        // flyStep initialises on a missing fly_alt
            _veh setVariable ["fly_dest", [_dest select 0, _dest select 1, 0], true];
            _veh setVariable ["fly_t0", time];
            AP_gpsAP = true;
            AP_gpsAPAir = true;
            AP_gpsAPMode = "normal";
            AP_gpsAPLastT = time;
            _veh engineOn true;
            AP_gpsAPEF = addMissionEventHandler ["EachFrame", { ["drive"] call AP_fnc_gpsAutopilot; }];
            ["<t color='#00d4ff'>AUTOPILOT:</t> flying to your destination. Touch the controls to take over.", "basic"] spawn AP_fnc_handleMessage;
        };
```

- [ ] **Step 2: Air branch in `drive`**

At the top of `case "drive"`, after `private _veh = vehicle player;` and before `private _pts = …`, insert:
```sqf
        if (missionNamespace getVariable ["AP_gpsAPAir", false]) exitWith {
            if (!alive player || {_veh isEqualTo player} || {driver _veh isNotEqualTo player}) exitWith { ["stop", ""] call AP_fnc_gpsAutopilot; };
            if (!alive _veh) exitWith { ["stop", "aircraft destroyed"] call AP_fnc_gpsAutopilot; };
            if (fuel _veh <= 0.005) exitWith { ["stop", "out of fuel"] call AP_fnc_gpsAutopilot; };
            if (inputAction "heliUp" > 0 || {inputAction "heliDown" > 0} || {inputAction "heliForward" > 0} || {inputAction "heliBack" > 0}
                || {inputAction "heliLeft" > 0} || {inputAction "heliRight" > 0} || {inputAction "heliRudderLeft" > 0} || {inputAction "heliRudderRight" > 0}
                || {inputAction "heliCollectiveRaise" > 0} || {inputAction "heliCollectiveLower" > 0}) exitWith {
                ["stop", "manual control"] call AP_fnc_gpsAutopilot; };
            private _dt = (time - (missionNamespace getVariable ["AP_gpsAPLastT", time])) min 0.2;
            AP_gpsAPLastT = time;
            private _phase = [_veh, _dt max 0.005] call AP_fnc_flyStep;
            if (_phase isEqualTo "landed") exitWith { ["stop", "landed at your destination"] call AP_fnc_gpsAutopilot; };
            if (_phase isEqualTo "hover") exitWith { ["stop", "no flat spot here -- hovering, take the controls"] call AP_fnc_gpsAutopilot; };
            if (_phase isEqualTo "aborted") exitWith { ["stop", "could not make progress -- take the controls"] call AP_fnc_gpsAutopilot; };
        };
```

- [ ] **Step 2b: the two Robotaxi rider gates in `drive`**

Still in `case "drive"`, below the air block, two lines read `AP_robotaxi`. Change
```sqf
        if (_veh isEqualTo player || {!(_veh getVariable ["AP_robotaxi", false]) && {driver _veh isNotEqualTo player}}) exitWith { ["stop", ""] call AP_fnc_gpsAutopilot; };   // robotaxi drives from the passenger seat
```
to
```sqf
        if (_veh isEqualTo player || {driver _veh isNotEqualTo player}) exitWith { ["stop", ""] call AP_fnc_gpsAutopilot; };
```
and on the manual-input line remove only the leading `!(_veh getVariable ["AP_robotaxi", false]) && ` so it begins `if (!(_veh getVariable ["AP_chauffeured", false]) && {inputAction "carForward" > 0 || {`.

- [ ] **Step 3: `stop` clears the air flag and loses the Robotaxi branch**

In `case "stop"`, after `AP_gpsAP = false;` add:
```sqf
        AP_gpsAPAir = false;
```
and delete the whole `if (_v getVariable ["AP_robotaxi", false]) then { … };` block (from its comment "robotaxi: ANY autopilot stop ends the ride" through the closing `};` of the spawn).

- [ ] **Step 4: Gates**

`fn_radioRadial.sqf:46`:
```sqf
private _apOk = (driver _veh isEqualTo player) && {(_veh isKindOf "LandVehicle") || {[_veh] call AP_fnc_isRotorcraft}} && {_veh getVariable ["AP_autopilot", false]};
```
`fn_carRadioBridge.sqf:107`:
```sqf
        ["apInstalled", (driver _veh isEqualTo player) && { (_veh isKindOf "LandVehicle") || {[_veh] call AP_fnc_isRotorcraft} } && { _veh getVariable ["AP_autopilot", false] }],
```
`fn_deckGarage.sqf:174`:
```sqf
        ["canAutopilot", (_class isKindOf "LandVehicle") || {[_class] call AP_fnc_isRotorcraft}],
```
`fn_vehicleShopMods.sqf:41-44`:
```sqf
// autopilot: ground vehicles and rotorcraft (helis + VTOLs); planes and boats never
private _apCombo = _d displayCtrl 100118;
if !((_classname isKindOf "LandVehicle") || {[_classname] call AP_fnc_isRotorcraft}) then {_apCombo lbSetCurSel 0;
    _apCombo ctrlEnable false;};
```

- [ ] **Step 5: Static checks**

```bash
python3 tools/sqf_balance.py mission/Armapunk2035.Malden/core/gps/fn_gpsAutopilot.sqf mission/Armapunk2035.Malden/core/radio/fn_radioRadial.sqf mission/Armapunk2035.Malden/core/web/fn_carRadioBridge.sqf mission/Armapunk2035.Malden/core/web/fn_deckGarage.sqf mission/Armapunk2035.Malden/core/shops/fn_vehicleShopMods.sqf
grep -n 'AP_robotaxi\|_isRobotaxi' mission/Armapunk2035.Malden/core/gps/fn_gpsAutopilot.sqf
```
Expected: five `ok`; the grep prints nothing.

- [ ] **Step 6: Commit**

```bash
git add mission/Armapunk2035.Malden/core/gps/fn_gpsAutopilot.sqf mission/Armapunk2035.Malden/core/radio/fn_radioRadial.sqf mission/Armapunk2035.Malden/core/web/fn_carRadioBridge.sqf mission/Armapunk2035.Malden/core/web/fn_deckGarage.sqf mission/Armapunk2035.Malden/core/shops/fn_vehicleShopMods.sqf
git commit -F - <<'EOF'
feat(gps): the seated autopilot flies helicopters and VTOLs

fn_gpsAutopilot gains an air branch: with the Autopilot Module fitted and a
GPS destination set, the same TAB-radial / deck AP wedge engages AP_fnc_flyStep
from the same EachFrame handler; heli inputs disengage it like car inputs do.
The four autopilot gates (radial, deck car-radio ring, garage canAutopilot,
mod-shop combo) accept Helicopter and VTOL_Base_F. The Robotaxi rider branches
are gone (the taxi is being replaced by SUMMON VEHICLE).

Co-Authored-By: Clippy
EOF
```

---

### Task 5: Client — spawn point picker `AP_fnc_summonPoint`

**Files:**
- Create: `mission/Armapunk2035.Malden/core/gps/fn_summonPoint.sqf`
- Modify: `Functions.h` (GPS block, after `class hcFly {};`)

**Interfaces:**
- Produces: `[_from, _isAir] call AP_fnc_summonPoint` → `[x, y, z, dir]` or `[]`. Land: a road position 700–1100 m away with a ≥ 4-point road route from it back to `_from`. Air: a flat spot within 150 m of a point 1000 m away, else a road there.

- [ ] **Step 1: Write the file**

```sqf
/*
    AP_fnc_summonPoint  (client) -- where a summoned vehicle appears: ~1 km out.

        [_from, _isAir] call AP_fnc_summonPoint     -> [x, y, 0, dir] or []

    Land: five bearings 72 degrees apart from a random start, 1000 m out, the nearest
    road within 150 m of each, kept only if AP_fnc_routeFind can route it back to
    _from with at least 4 points (what hcDrive needs). Nothing at 1000 m -> the same
    sweep at 700 m. Air: the same bearings, an isFlatEmpty spot within 150 m of the
    1000 m point (8 m clear, gradient <= 0.3 over 12 m), else the nearest road there.
    Runs on the CLIENT: it has the road graph (routeFind) and no server frames are spent.
*/
params [["_from", [], [[]]], ["_isAir", false, [false]]];
if (count _from < 2) exitWith { [] };
private _f2 = [_from select 0, _from select 1, 0];
private _out = [];
private _start = random 360;

private _fnRoad = {
    params ["_p"];
    private _rds = _p nearRoads 150;
    if (_rds isEqualTo []) exitWith { [] };
    private _best = _rds select 0;
    { if ((_p distance2D _x) < (_p distance2D _best)) then { _best = _x; }; } forEach _rds;
    getPosATL _best
};
private _fnFlat = {
    params ["_p"];
    private _hit = [];
    for "_r" from 0 to 150 step 25 do {
        for "_a" from 0 to 300 step 60 do {
            private _c = [(_p select 0) + _r * sin _a, (_p select 1) + _r * cos _a, 0];
            private _flat = _c isFlatEmpty [8, -1, 0.3, 12, 0, false, objNull];
            if (_flat isNotEqualTo []) exitWith { _hit = [_flat select 0, _flat select 1, 0]; };
        };
        if (_hit isNotEqualTo []) exitWith {};
    };
    _hit
};

{
    private _range = _x;
    for "_i" from 0 to 4 do {
        private _b = _start + _i * 72;
        private _p = _f2 getPos [_range, _b];
        if ((_p select 0) < 100 || {(_p select 1) < 100} || {(_p select 0) > worldSize - 100} || {(_p select 1) > worldSize - 100}) then { continue };
        if (surfaceIsWater _p) then { continue };
        private _sp = if (_isAir) then { [_p] call _fnFlat } else { [] };
        if (_sp isEqualTo []) then { _sp = [_p] call _fnRoad; };
        if (_sp isEqualTo []) then { continue };
        if (!_isAir) then {
            private _r = [_sp, _f2] call AP_fnc_routeFind;
            if (!((_r param [0, []]) isEqualType []) || {count (_r param [0, []]) < 4}) then { continue };
        };
        // nose toward the summoner
        private _dir = ((_f2 select 0) - (_sp select 0)) atan2 ((_f2 select 1) - (_sp select 1));
        _out = [_sp select 0, _sp select 1, 0, _dir];
    };
    if (_out isNotEqualTo []) exitWith {};
} forEach [1000, 700];
_out
```

- [ ] **Step 2: Register**

`Functions.h`, after `class hcFly {};`:
```
 class summonPoint {}; // SUMMON: pick the ~1 km spawn point (road for land, flat spot for air), client-side
```

- [ ] **Step 3: Static checks**

```bash
python3 tools/sqf_balance.py mission/Armapunk2035.Malden/core/gps/fn_summonPoint.sqf
python3 tools/sqf_cmd_check.py mission/Armapunk2035.Malden/core/gps/fn_summonPoint.sqf
```
Expected: `ok`; no unknown tokens (`continue` is a valid SQF command since 2.02 — if the checker flags it, the checker's word list is stale, not the code; note it and move on).

- [ ] **Step 4: Commit**

```bash
git add mission/Armapunk2035.Malden/core/gps/fn_summonPoint.sqf mission/Armapunk2035.Malden/Functions.h
git commit -F - <<'EOF'
feat(summon): AP_fnc_summonPoint -- the ~1 km spawn point, routable for cars, flat for aircraft

Co-Authored-By: Bonzi Buddy
EOF
```

---

### Task 6: Client — materialise at a position `AP_fnc_summonSpawn`, receiver `AP_fnc_summonState`

**Files:**
- Create: `mission/Armapunk2035.Malden/core/gps/fn_summonSpawn.sqf`
- Create: `mission/Armapunk2035.Malden/core/gps/fn_summonState.sqf`
- Modify: `Functions.h` (GPS block), `CfgRE.hpp` (two `allowedTargets = 1` entries next to `class APS_fnc_robotaxiSRV` which Task 10 removes)

**Interfaces:**
- Consumes: the 7-tuple garage row `[classname, plate, color, "", mods, vehWear, customPlate]` (what `fn_deckGarage`'s `_rowOf` builds and `fn_vehicleGaragePull` accepts), `APS_fnc_vehicleSetActive`, `AP_fnc_prepareVehicle`, `AP_fnc_clearVehicleAmmo`.
- Produces: server → client `[_row, _isAir] remoteExec ["AP_fnc_summonSpawn", _client]`; the client answers `["drive", _veh, _token] remoteExec ["APS_fnc_summonSRV", 2]` or `["spawnfail", _reason, _token]` (the token is the server's third argument to summonSpawn). Server → client `[_state] remoteExec ["AP_fnc_summonState", _client]` with `_state` a HashMap: `state` (`"idle"|"spawning"|"enroute"|"arrived"|"failed"`), `msg`, `dist`, `eta`, `info` (HashMap: `name`, `kind`, `plate`, `out` Boolean, `alive` Boolean) — any key may be missing; the client merges.

- [ ] **Step 1: Write `fn_summonSpawn.sqf`**

```sqf
/*
    AP_fnc_summonSpawn  (client, from the server) -- materialise a garage row ~1 km out.

        [_row, _isAir, _token] remoteExec ["AP_fnc_summonSpawn", <owner client>];

    The trimmed heart of fn_vehicleGaragePull (lines 104-199): create, activate the DB
    row through APS_fnc_vehicleSetActive (anti-dupe claim + trunk load), place, then
    AP_fnc_prepareVehicle for mods/colour/plate/wear -- which is WHY this runs on the
    client: prepareVehicle reads player, AP_side_talents and AP_effSide. The garage's
    spawn-point, fee and building checks do not apply: the server already decided.
    When the vehicle exists it is handed back: ["drive", _veh, _token] to APS_fnc_summonSRV.
    _token is the server's attempt id; it goes back on every answer so a slow spawn that
    outlives the server's 40 s watchdog is recognised as late and not adopted by a retry.
*/
params [["_row", [], [[]]], ["_isAir", false, [false]], ["_token", 0, [0]]];
if (remoteExecutedOwner isNotEqualTo 2 && {remoteExecutedOwner isNotEqualTo 0}) exitWith {};
if (count _row < 7) exitWith { ["spawnfail", "bad row", _token] remoteExec ["APS_fnc_summonSRV", 2]; };
_row params ["_classname", "_plate", "_color", "", "_mods", "_vehWear", "_customPlate"];

private _sp = [getPosATL player, _isAir] call AP_fnc_summonPoint;
if (_sp isEqualTo []) exitWith {
    ["spawnfail", if (_isAir) then { "no clear ground out there" } else { "no road out there -- move closer to one" }, _token] remoteExec ["APS_fnc_summonSRV", 2];
};
_sp params ["_x", "_y", "", "_dir"];

private _vehicle = createVehicle [_classname, [random 999, random 999, 999], [], 0, "CAN_COLLIDE"];
waitUntil { !isNil "_vehicle" && {!isNull _vehicle} };
[[player, _plate, _vehicle], "APS_fnc_vehicleSetActive", 2] call AP_fnc_MP;
_vehicle lock true;
_vehicle allowDamage false;
_vehicle setDir _dir;
private _pos = [_x, _y, 0.6];
_vehicle setPosATL _pos;
if (_isAir) then { _vehicle setVectorUp (surfaceNormal (getPosATL _vehicle)); };
diag_log format ["-SUMMON- spawn %1 plate %2 at %3 air=%4", _classname, _plate, _pos, _isAir];

[_vehicle] call AP_fnc_clearVehicleAmmo;
clearItemCargoGlobal _vehicle;
clearBackpackCargoGlobal _vehicle;
uiSleep 1;
[_vehicle, _mods, _color, _customPlate, _vehWear, false] spawn AP_fnc_prepareVehicle;
_vehicle setVariable ["AP_dbInfo", [getPlayerUID player, _plate], true];
// prepareVehicle's last write is AP_vinv (public); the server's trunk restore waits for it too.
// Bounded like fn_vehicleSetActive's own copy of this wait (15 s): a prepareVehicle that dies
// must not park this script forever with a half-built vehicle nobody drives.
private _t0 = time;
waitUntil { uiSleep 0.5; isNull _vehicle || {!isNil {_vehicle getVariable "AP_vinv"}} || {time - _t0 > 15} };
uiSleep 1.5;
if (isNull _vehicle) exitWith { ["spawnfail", "vehicle vanished during setup", _token] remoteExec ["APS_fnc_summonSRV", 2]; };
_vehicle allowDamage true;
["drive", _vehicle, _token] remoteExec ["APS_fnc_summonSRV", 2];
```

- [ ] **Step 2: Write `fn_summonState.sqf`**

```sqf
/*
    AP_fnc_summonState  (client, from the server) -- SUMMON VEHICLE progress.
    Merges the server's hashmap into AP_summonState, pushes the deck's `summon`
    channel when the phone is open, and says the milestones in chat.
*/
params [["_in", createHashMap, [createHashMap]]];
if (remoteExecutedOwner isNotEqualTo 2 && {remoteExecutedOwner isNotEqualTo 0}) exitWith {};
private _st = missionNamespace getVariable ["AP_summonState", createHashMapFromArray [["state", "idle"], ["msg", ""], ["dist", 0], ["eta", 0], ["cooldown", 0], ["info", createHashMap]]];
{ _st set [_x, _in get _x]; } forEach keys _in;
AP_summonState = _st;

private _state = _st getOrDefault ["state", "idle"];
private _msg = _st getOrDefault ["msg", ""];
if (_state in ["arrived", "failed"] && {_msg isNotEqualTo ""}) then {
    [format ["<t color='#54b0ff'>SUMMON:</t> %1", _msg], "basic"] spawn AP_fnc_handleMessage;
};
private _disp = findDisplay 937500;
if (!isNull _disp) then {
    private _c = _disp displayCtrl 937501;
    if (!isNull _c) then { [_c, "summon", _st] call webui_fnc_push; };
};
```

- [ ] **Step 3: Register + whitelist**

`Functions.h`, after `class summonPoint {};`:
```
 class summonSpawn {}; // SUMMON: materialise the starred row ~1 km out on the OWNER's client (prepareVehicle needs player)
 class summonState {}; // SUMMON: server -> client progress; pushes the deck's summon channel
```
`CfgRE.hpp`, next to the `APS_fnc_loonerSRV` entry (line ~221):
```
    class AP_fnc_summonSpawn {allowedTargets = 1;};   // server -> owner client: spawn the recall vehicle
    class AP_fnc_summonState {allowedTargets = 1;};   // server -> owner client: summon progress
    class APS_fnc_summonSRV {allowedTargets = 2;};    // client -> server: set/info/go/drive/spawnfail
```

- [ ] **Step 4: Static checks**

```bash
python3 tools/sqf_balance.py mission/Armapunk2035.Malden/core/gps/fn_summonSpawn.sqf mission/Armapunk2035.Malden/core/gps/fn_summonState.sqf
python3 tools/sqf_cmd_check.py mission/Armapunk2035.Malden/core/gps/fn_summonSpawn.sqf mission/Armapunk2035.Malden/core/gps/fn_summonState.sqf
```
Expected: `ok` ×2; no unknown tokens.

- [ ] **Step 5: Commit**

```bash
git add mission/Armapunk2035.Malden/core/gps/fn_summonSpawn.sqf mission/Armapunk2035.Malden/core/gps/fn_summonState.sqf mission/Armapunk2035.Malden/Functions.h mission/Armapunk2035.Malden/CfgRE.hpp
git commit -F - <<'EOF'
feat(summon): client half -- materialise the starred row ~1 km out, receive progress

AP_fnc_summonSpawn is the garage pull's spawn/activate/prepare core at a
position the client picks (AP_fnc_summonPoint), answering the server with
["drive", veh]; it runs on the owner's client because AP_fnc_prepareVehicle
reads player and talents. AP_fnc_summonState merges the server's progress
into AP_summonState and pushes the deck's summon channel. CfgRE entries for
both directions.

Co-Authored-By: Microsoft Tay
EOF
```

---

### Task 7: Server — `APS_fnc_summonSRV`

**Files:**
- Create: `server/AP_server/core/TON/fn_summonSRV.sqf`
- Modify: `server/AP_server/config.cpp:419` (replace `class robotaxiSRV {};` line)

**Interfaces:**
- Consumes: `vehicles.recall`, `DB_fnc_asyncQuery` (`[sql, 1]` = async no-return; `[sql, 2]` = first row; a third `true` means ALL rows, not blocking), `DB_fnc_updateVehicle`, `AP_fnc_summonSpawn`, `AP_fnc_summonState`, `AP_hcOwner`, HC pump vars.
- Produces: verbs `["set", id]`, `["info"]`, `["go"]`, `["drive", veh]`, `["spawnfail", reason]`, `["selftest", kind]`.

- [ ] **Step 1: Write the file**

```sqf
/*
    APS_fnc_summonSRV  (server) -- SUMMON VEHICLE (SUMMON_SPEC.md section 3).

        ["set", id]               star row id as the caller's recall vehicle (exclusive per pid)
        ["info"]                  push the recall vehicle's facts to the caller
        ["go"]                    validate, reclaim a world copy, ask the caller's client to spawn it
        ["drive", veh, token]     the client spawned it: hand to the HC, monitor, report
        ["spawnfail", why, token] the client could not spawn it
        ["selftest", kind]        bot_commands harness (server-local only)

    The caller is remoteExecutedOwner, never a client-supplied object. Nothing here trusts
    what a client names beyond facts the server can check itself. State in memory:
    AP_summonActive (uid -> [veh, t0, p0]: the vehicle once "drive" arrived, the attempt's
    token, where the caller stood at "go"), AP_summonCooldown (uid -> time),
    AP_summonLastReq (uid -> time). Refuses without a headless client (AP_hcOwner <= 0),
    as Loonazon does -- owner's call.

    Hardened by review, 2026-09-02:
      - "drive" corroborates the vehicle with facts a client cannot forge -- the object is
        LOCAL to the caller (it created it), nobody is aboard, it stands in the spawn ring
        measured from where the caller stood at "go" -- because AP_dbInfo is a client-published
        variable and alone would let a modified client point the HC at anyone's car.
      - every attempt carries a token (t0) that the client echoes in "drive"/"spawnfail". A
        "drive" for an attempt the 40 s watchdog already closed is a LATE spawn: never adopted
        into the next attempt, and never acted on either -- the server cannot prove the object is
        what the client says it is, so it stays in the world as the plate's world copy for the
        next "go" to reclaim (or the reaper to store). No write here can be forged.
      - a row that is still `active` with no world copy is refused (a post-restart restore
        stamps a 3-element AP_dbInfo and re-flips active; spawning a second copy was the
        whole-vehicle dupe the garage's active=false filter prevents). Two world copies at once
        is refused too, for the same reason.
      - the per-player slot is CLAIMED before the first suspension, so two "go" calls in
        the DB round-trip window cannot both proceed; every refusal after the claim releases it.
      - the drive monitor has a 330 s wall-clock cap and "spawnfail" only clears a slot that
        has no vehicle yet -- so no path strands AP_summonActive or double-reports.
      - delivery ends LOCKED (lock true), as every other spawn path leaves a vehicle; the
        owner's keys open it. "lock 0" would have handed a stranger the car.
*/
if (!isServer) exitWith {};
params [["_verb", "", [""]]];
_verb = toLower _verb;
private _arg = _this param [1];   // nil when absent; every read below is isNil-guarded

private _src = remoteExecutedOwner;
private _unit = if (_src in [0, 2]) then { objNull } else { (allPlayers select { owner _x isEqualTo _src }) param [0, objNull] };
if (_verb isNotEqualTo "selftest" && {isNull _unit}) exitWith {};
private _uid = if (isNull _unit) then { "" } else { getPlayerUID _unit };

if (isNil "AP_summonActive")   then { AP_summonActive = createHashMap; };
if (isNil "AP_summonCooldown") then { AP_summonCooldown = createHashMap; };
if (isNil "AP_summonLastReq")  then { AP_summonLastReq = createHashMap; };

// Per-caller throttle. set/info/go each issue SQL through the serialised async chokepoint;
// a modified client must not be able to spin them.
if (_verb in ["set", "info", "go"]) then {
    if ((AP_summonLastReq getOrDefault [_uid, -10]) > time - 1) exitWith { _verb = ""; };
    AP_summonLastReq set [_uid, time];
};
if (_verb isEqualTo "") exitWith {};

private _fnTell = {
    params ["_to", "_hash"];
    if (!isNull _to) then { [_hash] remoteExec ["AP_fnc_summonState", _to]; };
};
// The caller's garage side, derived exactly as APS_fnc_getVehicles derives it: engine side,
// then the duty roster overrides. A civilian off duty cannot summon a MaxSec garage vehicle.
private _fnSide = {
    params ["_u"];
    private _s = switch (side _u) do { case west: { "cop" }; case independent: { "med" }; default { "civ" }; };
    private _duty = _u call APS_fnc_dutyLookup;
    if ((missionNamespace getVariable ["AP_dutyEnabled", false]) && {_duty param [3, false]}) then {
        switch (_duty param [0, ""]) do { case "maxsec": { _s = "cop"; }; case "trauma": { _s = "med"; }; };
    };
    _s
};
private _fnRow = {   // the caller's starred row for their side, not up for sale; [] if none
    params ["_pid", "_side"];
    private _r = [format ["SELECT id, classname, pid, plate, color, COALESCE(mods,'[]') AS mods, alarm, COALESCE(customplate,'') AS customplate, fuel, damage, alive, active FROM %1 WHERE pid='%2' AND side='%3' AND listed = false AND recall = true LIMIT 1", srv_table_vehicles, _pid, _side], 2] call DB_fnc_asyncQuery;
    if (!(_r isEqualType []) || {_r isEqualTo []}) exitWith { [] };
    if ((_r select 0) isEqualType []) then { _r select 0 } else { _r }
};
// Every live copy of a plate. AP_dbInfo is [uid, plate] on a pull and [uid, plate, ...] after
// a restart restore (fn_restoreVehicles), so match the PREFIX, not the whole array.
private _fnCopies = {
    params ["_pid", "_plate"];
    vehicles select { ((_x getVariable ["AP_dbInfo", []]) select [0, 2]) isEqualTo [_pid, _plate] }
};
private _fnInfo = {   // hashmap for the client from a raw row (or [] -> none)
    params ["_row"];
    if (_row isEqualTo []) exitWith { createHashMapFromArray [["none", true]] };
    private _cls = _row select 1;
    private _plate = _row select 3;
    private _world = ([_uid, _plate] call _fnCopies) param [0, objNull];
    createHashMapFromArray [
        ["none", false],
        ["id", _row select 0], ["class", _cls],
        ["name", getText (configFile >> "CfgVehicles" >> _cls >> "displayName")],
        ["kind", if ([_cls] call AP_fnc_isRotorcraft) then { "AIR" } else { "LAND" }],
        ["plate", _plate],
        ["alive", (_row select 10) in [1, true]],
        ["out", !isNull _world || {(_row select 11) in [1, true]}],
        ["dist", if (isNull _world || {isNull _unit}) then { 0 } else { round (_unit distance _world) }]
    ]
};

switch (_verb) do {

    case "set": {
        if (isNil "_arg" || {!(_arg isEqualType 0)}) exitWith {};
        private _id = _arg;
        private _r = [format ["SELECT classname FROM %1 WHERE id=%2 AND pid='%3' AND listed = false", srv_table_vehicles, _id, _uid], 2] call DB_fnc_asyncQuery;
        if (!(_r isEqualType []) || {_r isEqualTo []}) exitWith { ["-SEC-", _unit, format ["BLOCKED summon set for a row not theirs (id %1)", _id]] call APS_fnc_logIt; };
        private _cls = format ["%1", ((if ((_r select 0) isEqualType []) then { _r select 0 } else { _r }) select 0)];
        // VTOLs inherit Plane_Base_F: test the rotorcraft classes first, then refuse real planes and boats
        if ((_cls isKindOf "Plane" && {!([_cls] call AP_fnc_isRotorcraft)}) || {_cls isKindOf "Ship"}) exitWith {
            [_unit, createHashMapFromArray [["msg", "that can't be summoned -- no driver for planes or boats"]]] call _fnTell;
        };
        [format ["UPDATE %1 SET recall = (id = %2) WHERE pid='%3'", srv_table_vehicles, _id, _uid], 1] call DB_fnc_asyncQuery;
        ["-SUMMON-", _unit, name _unit, format ["starred %1 (row %2)", _cls, _id]] call APS_fnc_logIt;
        [_unit, createHashMapFromArray [["info", [[_uid, [_unit] call _fnSide] call _fnRow] call _fnInfo], ["msg", "recall vehicle set"]]] call _fnTell;
    };

    case "info": {
        [_unit, createHashMapFromArray [["info", [[_uid, [_unit] call _fnSide] call _fnRow] call _fnInfo],
            ["cooldown", ((AP_summonCooldown getOrDefault [_uid, 0]) - time) max 0]]] call _fnTell;
    };

    case "go": {
        private _refuse = {   // every refusal after the claim releases the slot
            params ["_why"];
            AP_summonActive deleteAt _uid;
            [_unit, createHashMapFromArray [["state", "failed"], ["msg", _why]]] call _fnTell;
            ["-SUMMON-", _unit, name _unit, format ["refused: %1", _why]] call APS_fnc_logIt;
        };
        if ((missionNamespace getVariable ["AP_hcOwner", 0]) <= 0) exitWith {
            [_unit, createHashMapFromArray [["state", "failed"], ["msg", "no driver available right now"]]] call _fnTell;
        };
        if (_uid in AP_summonActive) exitWith {   // NOT _refuse: the running attempt keeps its slot
            [_unit, createHashMapFromArray [["msg", "your vehicle is already on its way"]]] call _fnTell;
        };
        private _cd = (AP_summonCooldown getOrDefault [_uid, 0]) - time;
        if (_cd > 0) exitWith { [_unit, createHashMapFromArray [["state", "failed"], ["msg", format ["summon again in %1 s", ceil _cd]], ["cooldown", ceil _cd]]] call _fnTell; };
        if (!isNull objectParent _unit) exitWith { [_unit, createHashMapFromArray [["state", "failed"], ["msg", "get out of your vehicle first"]]] call _fnTell; };

        // CLAIM the slot before the first suspension (the DB round trips below sleep): two "go"
        // calls inside that window must not both proceed. t0 is this attempt's token; p0 is
        // where the caller stands now -- the spawn ring is measured from here, not from wherever
        // they have walked to by the time the client answers.
        private _t0 = time;
        private _p0 = getPosATL _unit;
        AP_summonActive set [_uid, [objNull, _t0, _p0]];

        private _row = [_uid, [_unit] call _fnSide] call _fnRow;
        if (_row isEqualTo []) exitWith { ["star a vehicle in the garage first"] call _refuse; };
        if !((_row select 10) in [1, true]) exitWith { ["your recall vehicle is wrecked"] call _refuse; };
        private _cls = _row select 1;
        private _plate = _row select 3;
        if ((_cls isKindOf "Plane" && {!([_cls] call AP_fnc_isRotorcraft)}) || {_cls isKindOf "Ship"}) exitWith { ["that vehicle can't be summoned"] call _refuse; };

        private _copies = [_uid, _plate] call _fnCopies;
        if (count _copies > 1) exitWith { ["more than one copy of that vehicle exists -- tell staff"] call _refuse; };
        private _world = _copies param [0, objNull];
        if (!isNull _world && {({isPlayer _x} count crew _world) > 0}) exitWith { ["someone is in it"] call _refuse; };
        // active with no world copy: it is out somewhere this server cannot see (a restore the
        // lookup missed, a crash). Spawning another would be the whole-vehicle dupe.
        if (isNull _world && {(_row select 11) in [1, true]}) exitWith { ["your vehicle is marked as out -- store it at a garage first"] call _refuse; };

        // RECLAIM a world copy: store it exactly as the idle-reaper does (trunk + fuel + damage
        // into the row, active=false), then delete it. Locality home first, or the delete no-ops.
        if (!isNull _world) then {
            _world setOwner 2;
            uiSleep 1;
            private _al = if ((_row select 6) in [1, true]) then { 1 } else { 0 };
            [_plate, _uid, _world, 0, _al, 0, true, true] call DB_fnc_updateVehicle;
            deleteVehicle _world;
            uiSleep 0.5;
            ["-SUMMON-", _unit, name _unit, format ["reclaimed %1 (%2) from the world", _cls, _plate]] call APS_fnc_logIt;
            _row = [_uid, [_unit] call _fnSide] call _fnRow;   // fuel/damage/inventory now reflect the world copy
        };
        if (_row isEqualTo [] || {(_row select 11) in [1, true]}) exitWith { ["the garage lost track of it -- try again in a moment"] call _refuse; };
        _row params ["_id", "", "", "", "_color", "_modsStr", "_alarm", "_customPlate", "_fuel", "_damage"];

        private _mods = parseSimpleArray _modsStr;
        if (!(_mods isEqualType []) || {count _mods < 9}) then { _mods = [if (_alarm in [1, true]) then { 1 } else { 0 }, 0, 0, 0, 0, 0, 0, 0, 0]; };
        private _clientRow = [_cls, _plate, _color, "", _mods, [((_damage max 0) / 100), ((_fuel max 0) / 100), 0], _customPlate];
        private _isAir = [_cls] call AP_fnc_isRotorcraft;
        [_unit, createHashMapFromArray [["state", "spawning"], ["msg", "your vehicle is being brought out"], ["dist", 0], ["eta", 0]]] call _fnTell;
        [_clientRow, _isAir, _t0] remoteExec ["AP_fnc_summonSpawn", _src];
        // the client has 40 s to come back with "drive". Scoped to THIS attempt's token, so a
        // retry started inside those 40 s is not killed by the previous attempt's watchdog.
        [_uid, _unit, _fnTell, _t0] spawn {
            params ["_uid", "_unit", "_fnTell", "_t0"];
            uiSleep 40;
            private _a = AP_summonActive getOrDefault [_uid, []];
            if (_a isNotEqualTo [] && {isNull (_a select 0)} && {(_a select 1) isEqualTo _t0}) then {
                AP_summonActive deleteAt _uid;
                [_unit, createHashMapFromArray [["state", "failed"], ["msg", "the vehicle never appeared"]]] call _fnTell;
            };
        };
    };

    case "spawnfail": {
        // only THIS attempt's slot, and only while it has no vehicle; a late spawnfail from an
        // attempt the watchdog closed, or a running drive, is not ours to clear
        private _tok = _this param [2, -1];
        private _a = AP_summonActive getOrDefault [_uid, []];
        if (_a isEqualTo [] || {!isNull (_a select 0)} || {(_a select 1) isNotEqualTo _tok}) exitWith {};
        AP_summonActive deleteAt _uid;
        private _why = if (isNil "_arg" || {!(_arg isEqualType "")}) then { "spawn failed" } else { _arg select [0, 80] };
        [_unit, createHashMapFromArray [["state", "failed"], ["msg", _why]]] call _fnTell;
        ["-SUMMON-", _unit, name _unit, format ["spawn failed: %1", _why]] call APS_fnc_logIt;
    };

    case "drive": {
        if (isNil "_arg" || {!(_arg isEqualType objNull)} || {isNull _arg}) exitWith {};
        private _veh = _arg;
        private _tok = _this param [2, -1];
        private _a = AP_summonActive getOrDefault [_uid, []];
        // A "drive" whose token is not the running attempt's is a LATE spawn from an attempt the
        // 40 s watchdog already closed (summonPoint can route-find for a while, then summonSpawn
        // waits up to ~17 s on prepareVehicle). It is never adopted into the attempt running now,
        // and it is deliberately left ALONE. The server cannot tell a genuine late copy from a
        // decoy a modified client stamped with its own uid and plate, and every write it could
        // make here -- store the row, delete the object -- is one such a client could aim at a
        // plate whose real copy is still live (store = active 0 + empty trunk = a garage re-pull
        // dupe). Left where it is, the copy is simply the plate's world copy: active, locked,
        // 1 km out. The next "go" reclaims it exactly like any other world copy, through the
        // one path that checks it is real, or the idle reaper stores it. Nothing is lost, and
        // nothing on this path can be forged into a write.
        if (_a isEqualTo [] || {(_a select 1) isNotEqualTo _tok}) exitWith {
            ["-SUMMON-", _unit, name _unit, format ["late drive ignored: %1 (attempt %2 is closed)", typeOf _veh, _tok]] call APS_fnc_logIt;
        };
        if (!isNull (_a select 0)) exitWith {};   // this attempt already has its vehicle
        private _p0 = _a param [2, getPosATL _unit];
        private _row = [_uid, [_unit] call _fnSide] call _fnRow;
        // AP_dbInfo and the class are what the honest client set; the last three are facts a
        // client cannot forge: the object is LOCAL to the caller (its own createVehicle), nobody is
        // aboard, and it stands inside the spawn ring around where the caller stood at "go"
        // (summonPoint: 1000 m, then 700 m, snapped up to 150 m). A stranger's parked car fails.
        private _ok = _row isNotEqualTo []
            && {((_veh getVariable ["AP_dbInfo", []]) select [0, 2]) isEqualTo [_uid, _row select 3]}
            && {(typeOf _veh) isEqualTo (_row select 1)}
            && {owner _veh isEqualTo _src}
            && {(crew _veh) isEqualTo []}
            && {(_veh distance2D _p0) > 400 && {(_veh distance2D _p0) < 1500}};
        if (!_ok) exitWith {
            ["-SEC-", _unit, format ["BLOCKED summon drive: %1 owner=%2 crew=%3 dist=%4", typeOf _veh, owner _veh, count crew _veh, round (_veh distance2D _p0)]] call APS_fnc_logIt;
            AP_summonActive deleteAt _uid;
            [_unit, createHashMapFromArray [["state", "failed"], ["msg", "that is not the vehicle that was summoned"]]] call _fnTell;
        };
        AP_summonActive set [_uid, [_veh, _a select 1, _p0]];
        [_veh, _unit, _uid, _fnTell] spawn {
            params ["_veh", "_unit", "_uid", "_fnTell"];
            _veh setVariable ["AP_summonFor", _uid, true];
            _veh setVariable ["hc_ap_lock", true, true];
            _veh lock 2;
            _veh setVariable ["hc_ap_arrive", 8, true];
            _veh setVariable ["hc_ap_mode", "normal", true];
            _veh setVariable ["hc_ap_dest", getPosATL _unit, true];
            _veh setVariable ["hc_ap_done", "", true];
            _veh setVariable ["hc_ap_want", true, true];
            private _outcome = "";
            private _hc = missionNamespace getVariable ["AP_hcOwner", 0];
            if (_hc <= 0) then { _outcome = "no driver available"; } else { _veh setOwner _hc; };
            // hand-off watchdog (Loonazon's): setOwner is occasionally a silent no-op. AP_hcOwner is
            // re-read each turn -- it drops to 0 when the HC disconnects (server_init), and setOwner 0
            // is not a hand-off.
            private _giveUp = time + 15;
            if (_outcome isEqualTo "") then {
                waitUntil { uiSleep 1;
                    _hc = missionNamespace getVariable ["AP_hcOwner", 0];
                    if (_hc > 0 && {!isNull _veh} && {alive _veh} && {local _veh} && {!(_veh getVariable ["hc_ap_driving", false])} && {(_veh getVariable ["hc_ap_done", ""]) isEqualTo ""}) then {
                        _veh setVariable ["hc_ap_want", true, true];
                        _veh setOwner _hc; };
                    (_hc <= 0) || {isNull _veh} || {!alive _veh} || {_veh getVariable ["hc_ap_driving", false]} || {(_veh getVariable ["hc_ap_done", ""]) isNotEqualTo ""} || {time > _giveUp} };
                if (_hc <= 0) then { _outcome = "the driver went offline"; } else {
                    if (!isNull _veh && {alive _veh} && {!(_veh getVariable ["hc_ap_driving", false])} && {(_veh getVariable ["hc_ap_done", ""]) isEqualTo ""}) then {
                        _outcome = "no driver took the wheel";
                    };
                };
            };
            if (_outcome isEqualTo "") then {
                [_unit, createHashMapFromArray [["state", "enroute"], ["msg", "on its way"]]] call _fnTell;
                private _lastD = _unit distance2D _veh; private _lastT = time; private _spd = 0; private _pubT = time;
                private _hardEnd = time + 330;   // hcDrive/hcFly cap themselves at 300 s; this catches a dead HC
                while { _outcome isEqualTo "" } do {
                    uiSleep 2;
                    if (isNull _veh) exitWith { _outcome = "the vehicle vanished"; };
                    if (!alive _veh) exitWith { _outcome = "the vehicle was destroyed on the way"; };
                    if (isNull _unit || {!alive _unit}) exitWith { _outcome = "you were not there to meet it"; };
                    if (time > _hardEnd) exitWith { _outcome = "timeout"; };
                    if ((missionNamespace getVariable ["AP_hcOwner", 0]) <= 0) exitWith { _outcome = "the driver went offline"; };
                    private _done = _veh getVariable ["hc_ap_done", ""];
                    if (_done isNotEqualTo "") exitWith { _outcome = _done; };
                    if (time - _pubT >= 5) then { _veh setVariable ["hc_ap_dest", getPosATL _unit, true]; _pubT = time; };
                    private _d = _unit distance2D _veh;
                    _spd = (0.7 * _spd) + (0.3 * (((_lastD - _d) / ((time - _lastT) max 0.1)) max 0));
                    _lastD = _d; _lastT = time;
                    [_unit, createHashMapFromArray [["state", "enroute"], ["dist", round _d], ["eta", if (_spd > 0.5) then { round (_d / _spd) } else { 0 }]]] call _fnTell;
                };
            };
            // finish: whatever happened, the vehicle is the owner's again and depends on nothing.
            // LOCKED, like every spawn path in this codebase leaves a vehicle: the owner's keys open it.
            if (!isNull _veh) then {
                _veh setVariable ["hc_ap_want", false, true];
                _veh setVariable ["hc_ap_abort", true, true];
                _veh setVariable ["hc_ap_lock", false, true];
                _veh setVariable ["AP_summonFor", nil, true];
                _veh setOwner 2;
                uiSleep 1;
                _veh lock true;
                if (alive _veh) then { _veh engineOn false; };
            };
            AP_summonActive deleteAt _uid;
            private _ok = _outcome in ["arrived", "landed", "hover"];
            if (_ok) then { AP_summonCooldown set [_uid, time + 120]; };
            private _name = if (isNull _veh) then { "vehicle" } else { getText (configFile >> "CfgVehicles" >> (typeOf _veh) >> "displayName") };
            private _msg = switch (_outcome) do {
                case "arrived"; case "landed": { format ["your %1 is here", _name] };
                case "hover": { format ["couldn't find a flat spot -- your %1 is hovering over you, climb in", _name] };
                default { format ["%1 -- your %2 stopped at %3", _outcome, _name, if (isNull _veh) then { "?" } else { mapGridPosition _veh }] };
            };
            [_unit, createHashMapFromArray [["state", if (_ok) then { "arrived" } else { "failed" }], ["msg", _msg], ["dist", 0], ["eta", 0], ["cooldown", if (_ok) then { 120 } else { 0 }]]] call _fnTell;
            ["-SUMMON-", _unit, name _unit, format ["%1: %2 (%3)", _outcome, _name, if (isNull _veh) then { "?" } else { mapGridPosition _veh }]] call APS_fnc_logIt;
        };
    };

    case "selftest": {
        // bot_commands harness: spawn a test vehicle ~1 km from respawn_civilian and bring it there.
        // remoteExecutedOwner 0 = a server-local call (what the bot_commands dispatcher is; a headless
        // client reports 0 too, and it is trusted). Never a player.
        if (_src isNotEqualTo 0) exitWith {};
        private _kind = if (isNil "_arg") then { "car" } else { toLower (format ["%1", _arg]) };
        private _hc = missionNamespace getVariable ["AP_hcOwner", 0];
        if (_hc <= 0) exitWith { diag_log format ["[SUMMON-TEST] kind=%1 outcome=nohc", _kind]; };
        private _cls = switch (_kind) do { case "heli": { "C_Heli_Light_01_civil_F" }; case "vtol": { "B_T_VTOL_01_infantry_F" }; default { "C_Offroad_01_F" } };
        private _isAir = _kind in ["heli", "vtol"];
        private _dest = getMarkerPos "respawn_civilian";
        private _sp = [_dest, _isAir] call AP_fnc_summonPoint;
        if (_sp isEqualTo []) exitWith { diag_log format ["[SUMMON-TEST] kind=%1 outcome=nospawnpoint", _kind]; };
        private _veh = createVehicle [_cls, [_sp select 0, _sp select 1, 0.6], [], 0, "CAN_COLLIDE"];
        _veh setDir (_sp select 3);
        _veh setVariable ["owner", "summontest", true];
        _veh setVariable ["hc_ap_arrive", 8, true];
        _veh setVariable ["hc_ap_mode", "normal", true];
        _veh setVariable ["hc_ap_dest", _dest, true];
        _veh setVariable ["hc_ap_done", "", true];
        _veh setVariable ["hc_ap_want", true, true];
        private _t0 = time;
        _veh setOwner _hc;
        [_veh, _dest, _kind, _t0] spawn {
            params ["_veh", "_dest", "_kind", "_t0"];
            private _giveUp = time + 15;
            waitUntil { uiSleep 1;
                private _hc = missionNamespace getVariable ["AP_hcOwner", 0];
                if (_hc > 0 && {!isNull _veh} && {local _veh} && {!(_veh getVariable ["hc_ap_driving", false])} && {(_veh getVariable ["hc_ap_done", ""]) isEqualTo ""}) then { _veh setOwner _hc; };
                (isNull _veh) || {_veh getVariable ["hc_ap_driving", false]} || {(_veh getVariable ["hc_ap_done", ""]) isNotEqualTo ""} || {time > _giveUp} };
            waitUntil { uiSleep 2; (isNull _veh) || {!alive _veh} || {(_veh getVariable ["hc_ap_done", ""]) isNotEqualTo ""} || {time - _t0 > 330} };
            private _done = if (isNull _veh) then { "vanished" } else { _veh getVariable ["hc_ap_done", "timeout"] };
            if (_done isEqualTo "") then { _done = "timeout"; };
            private _d = if (isNull _veh) then { -1 } else { round (_veh distance2D _dest) };
            diag_log format ["[SUMMON-TEST] kind=%1 outcome=%2 dist=%3 t=%4", _kind, _done, _d, round (time - _t0)];
            if (!isNull _veh) then { _veh setOwner 2; uiSleep 1; deleteVehicle _veh; };
        };
    };
};
```

- [ ] **Step 2: Register**

In `server/AP_server/config.cpp` replace the line
```
 class robotaxiSRV {}; // LooneyBin: Robotaxi -- spawn/seat/despawn the autopilot cab
```
with
```
 class summonSRV {}; // SUMMON VEHICLE: star a recall vehicle; spawn it ~1 km out and have the HC bring it (replaces Robotaxi)
```

- [ ] **Step 3: Static checks**

```bash
python3 tools/sqf_balance.py server/AP_server/core/TON/fn_summonSRV.sqf
python3 tools/sqf_cmd_check.py server/AP_server/core/TON/fn_summonSRV.sqf
```
Expected: `ok`; no unknown tokens.

- [ ] **Step 4: Commit**

```bash
git add server/AP_server/core/TON/fn_summonSRV.sqf server/AP_server/config.cpp
git commit -F - <<'EOF'
feat(summon): APS_fnc_summonSRV -- star, info, go, drive, selftest

Server side of SUMMON VEHICLE. "go" refuses without a headless client, on
cooldown, in a vehicle, with nothing starred or a wrecked row; reclaims a
world copy by storing it the way the idle-reaper does and deleting it; then
asks the owner's client to materialise the row ~1 km out. "drive" takes the
spawned vehicle, hands it to the HC with Loonazon's setOwner retry, follows the
summoner every 5 s, reports distance/ETA every 2 s, and on any end gives the
vehicle back (server-owned, unlocked, engine off). Cooldown charged only on
arrival. "selftest" is the bot_commands harness.

Co-Authored-By: Jeeves
EOF
```

---

### Task 8: Deck — `AP_fnc_deckSummon`, garage `recall` verb, handler registration, catalogue, launcher row

**Files:**
- Create: `mission/Armapunk2035.Malden/core/web/fn_deckSummon.sqf`
- Modify: `mission/Armapunk2035.Malden/core/web/fn_deckGarage.sqf` (new `case "recall"` before `case "moddata"`)
- Modify: `mission/Armapunk2035.Malden/core/web/fn_deckOpen.sqf:165` (register `summon` after the `garage` handler)
- Modify: `mission/Armapunk2035.Malden/core/web/fn_deckData.sqf:55`
- Modify: `mission/Armapunk2035.Malden/core/configuration.sqf` (the Robotaxi `AP_phone_buttons` row)
- Modify: `Functions.h` (Web block, after `class deckGarage {};`)

**Interfaces:**
- Produces: page verb `summon` with `["data"]` → HashMap `AP_summonState` (and triggers a server `info`), `["go"]` → `{ok, msg}`; garage verb `["recall", id]` → `{ok, msg}`.

- [ ] **Step 1: Write `fn_deckSummon.sqf`**

```sqf
/*
    AP_fnc_deckSummon -- the deck's SUMMON VEHICLE app (replaces Robotaxi).

    ["data"]   the cached AP_summonState (state/msg/dist/eta/cooldown/info); also asks the
               server for fresh info, which arrives on the `summon` channel a moment later
    ["go"]     summon -- the server decides and answers on the channel
*/
params [["_verb", "", [""]]];
switch (toLower _verb) do {
    case "data": {
        ["info"] remoteExec ["APS_fnc_summonSRV", 2];
        missionNamespace getVariable ["AP_summonState", createHashMapFromArray [["state", "idle"], ["msg", ""], ["dist", 0], ["eta", 0], ["cooldown", 0], ["info", createHashMapFromArray [["none", true]]]]]
    };
    case "go": {
        if (!isNull objectParent player) exitWith { createHashMapFromArray [["ok", false], ["msg", "get out of your vehicle first"]] };
        ["go"] remoteExec ["APS_fnc_summonSRV", 2];
        createHashMapFromArray [["ok", true], ["msg", "summoning"]]
    };
    default { createHashMapFromArray [["ok", false], ["msg", "unknown verb"]] };
};
```

- [ ] **Step 2: Garage `recall` verb**

In `fn_deckGarage.sqf`, before `case "moddata": {` insert:
```sqf
case "recall": {
    private _r = AP_garageData param [AP_garageData findIf { (_x select 0) isEqualTo _id }, []];
    if (_r isEqualTo []) exitWith { ["no such vehicle"] call _no };
    ["set", _id] remoteExec ["APS_fnc_summonSRV", 2];
    // the server flips the column; refresh the rows so the star moves
    [] spawn { uiSleep 1.2; [[player, "Car"], "APS_fnc_getVehicles", 2] spawn AP_fnc_MP; };
    ["recall vehicle set"] call _yes
};
```

- [ ] **Step 3: Register the page handler**

In `fn_deckOpen.sqf`, after the `garage` handler block (`}] call webui_fnc_on;` that follows `[_verb, _id, _changes] call AP_fnc_deckGarage`), add:
```sqf
[_ctrl, "summon", {
    params [["_verb", "", [""]]];
    [_verb] call AP_fnc_deckSummon
}] call webui_fnc_on;
```

- [ ] **Step 4: Catalogue + launcher row**

`fn_deckData.sqf` line 55: replace `["Robotaxi",      ["economy",  "robotaxi"]],` with
```sqf
        ["SUMMON VEHICLE", ["economy",  "robotaxi"]],
```
`core/configuration.sqf`: replace the row
```
["Robotaxi","","[] spawn AP_fnc_robotaxi",{AP_effSide isEqualTo civilian},"Hail a driverless autopilot cab to your GPS destination"]
```
with
```
["SUMMON VEHICLE","","['SUMMON VEHICLE'] call AP_fnc_deckOpenApp",{true},"Summon your starred vehicle -- it drives, or flies and lands, to you"]
```

- [ ] **Step 5: Register**

`Functions.h`, after `class deckGarage {};`:
```
  class deckSummon {}; // SUMMON VEHICLE app: state + go (replaces the Robotaxi tile)
```

- [ ] **Step 6: Static checks**

```bash
python3 tools/sqf_balance.py mission/Armapunk2035.Malden/core/web/fn_deckSummon.sqf mission/Armapunk2035.Malden/core/web/fn_deckGarage.sqf mission/Armapunk2035.Malden/core/web/fn_deckOpen.sqf mission/Armapunk2035.Malden/core/web/fn_deckData.sqf mission/Armapunk2035.Malden/core/configuration.sqf
grep -c 'Robotaxi' mission/Armapunk2035.Malden/core/configuration.sqf mission/Armapunk2035.Malden/core/web/fn_deckData.sqf
```
Expected: five `ok`; both counts `0`.

- [ ] **Step 7: Commit**

```bash
git add mission/Armapunk2035.Malden/core/web/fn_deckSummon.sqf mission/Armapunk2035.Malden/core/web/fn_deckGarage.sqf mission/Armapunk2035.Malden/core/web/fn_deckOpen.sqf mission/Armapunk2035.Malden/core/web/fn_deckData.sqf mission/Armapunk2035.Malden/core/configuration.sqf mission/Armapunk2035.Malden/Functions.h
git commit -F - <<'EOF'
feat(deck): SUMMON VEHICLE app wiring -- verbs, garage recall verb, catalogue, launcher row

Co-Authored-By: Cortana
EOF
```

---

### Task 9: Deck page — garage ★ and the SUMMON VEHICLE view (both copies)

**Files:**
- Modify: `mission/Armapunk2035.Malden/ui/html/deck.html` and `server/AP_server/web/ui/html/deck.html` identically:
  - `deckGo` map (line ~2434)
  - `viewGarage` rows (line ~4029) and detail buttons (line ~4064)
  - render dispatch (line ~4706)
  - action dispatch `case "grgGet"` neighbourhood (line ~5408)
  - channel subscriptions (line ~5921)
  - a new `viewSummon` + `openSummon` near `viewKeys` (line ~1930)

**Interfaces:**
- Consumes: channel `summon` (HashMap from `AP_fnc_summonState`), garage rows' `recall` field, verbs `summon` and `garage recall`.

- [ ] **Step 1: deckGo entry**

In the `deckGo` map add, after `"ICEBREAKER OS": openQh, "TAL OS": openQh`:
```js
    "SUMMON VEHICLE": openSummon
```
(add a comma to the previous line).

- [ ] **Step 2: View + opener** — insert directly before `function viewKeys(){`:

```js
/* ---- SUMMON VEHICLE (replaces Robotaxi) ---------------------------------------
   One screen: the starred vehicle, where it is, one button. S.summon is the last
   `summon` channel value (AP_fnc_summonState); "data" asks SQF for a fresh one. */
function openSummon(){
  go("summon");
  call("summon", ["data"]).then(function(v){ if (v) { S.summon = v; if (S.view === "summon") render(); } });
}
function viewSummon(){
  var s = S.summon;
  if (!s) return '<div class="panel" style="flex:1;display:flex"><div class="empty">CALLING THE GARAGE</div></div>';
  var info = s.info || { none: true };
  var st = s.state || "idle";
  var cd = Math.max(0, Math.round(s.cooldown || 0));
  var where = info.none ? "NOTHING STARRED"
            : !info.alive ? "WRECKED"
            : st === "enroute" ? ("EN ROUTE · " + (s.dist >= 1000 ? (s.dist/1000).toFixed(1) + " km" : s.dist + " m") + (s.eta ? " · ~" + s.eta + " s" : ""))
            : st === "spawning" ? "BRINGING IT OUT"
            : info.out ? ("OUT · " + (info.dist >= 1000 ? (info.dist/1000).toFixed(1) + " km" : info.dist + " m"))
            : "GARAGED";
  var reason = info.none ? "star a vehicle in the GARAGE app" : !info.alive ? "your recall vehicle is wrecked"
             : st === "enroute" || st === "spawning" ? "already on its way" : cd > 0 ? ("ready in " + cd + " s") : "";
  return '<div class="card">' +
      '<div class="card-id">' + ico("robotaxi", "1.5rem", "var(--acc)") +
        '<div><div class="t">' + (info.none ? "Summon vehicle" : esc(info.name)) + '</div>' +
        '<div class="s">' + (info.none ? "NO RECALL VEHICLE" : esc(info.kind) + " &middot; PLATE " + esc(info.plate)) + '</div></div>' +
      '</div>' +
      '<div class="hair"></div>' +
      kv("STATUS", where, st === "arrived" ? "acid" : st === "failed" ? "bad" : "") +
      (s.msg ? kv("LAST", esc(s.msg), "") : "") +
      '<div style="display:flex;gap:.5rem;margin-top:.6rem">' +
        '<button class="gact p" data-act="smGo"' + (reason ? " disabled" : "") + '>SUMMON</button>' +
        '<button class="gact" data-act="smGarage">GARAGE</button>' +
      '</div>' +
      (reason ? '<div class="cls" style="margin-top:.4rem;color:var(--amber)">' + esc(reason.toUpperCase()) + '</div>' : "") +
    '</div>' +
    '<div class="hint"><i>&#9673;</i><span>It appears about a kilometre out and drives &mdash; or flies and lands &mdash; to you. ' +
      'Free, two minutes between summons. If it is already out in the world it is brought back in from a kilometre away.</span></div>';
}
```

- [ ] **Step 3: Garage rows show the star; the detail pane sets it**

In `viewGarage`, change the row template
```js
      '<span class="nm">' + esc(v.name) + '</span>' +
      '<span class="k">' + (v.outNow ? "OUT" : v.kind) + '</span></button>';
```
to
```js
      '<span class="nm">' + (v.recall ? '<span style="color:var(--acc)">&#9733; </span>' : '') + esc(v.name) + '</span>' +
      '<span class="k">' + (v.outNow ? "OUT" : v.kind) + '</span></button>';
```
and in the detail buttons, after the `grgGet` button line add:
```js
        '<button class="gact' + (sel.recall ? " p" : "") + '" data-act="grgStar" data-id="' + sel.id + '">' + (sel.recall ? "&#9733; RECALL VEHICLE" : "&#9734; SET RECALL") + '</button>' +
```

- [ ] **Step 4: Render dispatch**

After the line `: S.view === "keys"  ? viewKeys()` add:
```js
                 : S.view === "summon" ? viewSummon()
```

- [ ] **Step 5: Actions**

After `case "grgFix": …; break;` add:
```js
    case "grgStar": t.disabled = true; call("garage", ["recall", parseInt(id, 10)])
      .then(function(){ setTimeout(function(){ call("refresh", ["garage"]); }, 1500); }); break;
    case "smGo": t.disabled = true; call("summon", ["go"]); break;
    case "smGarage": deckGo("Garage"); break;
```

- [ ] **Step 6: Channel**

After `WEBUI.on("keys", …);` add:
```js
  WEBUI.on("summon", function(v){ S.summon = v; if (S.view === "summon") render(); });
```

- [ ] **Step 7: Mirror + check**

```bash
cp mission/Armapunk2035.Malden/ui/html/deck.html server/AP_server/web/ui/html/deck.html
python3 tools/html_js_check.py
cmp mission/Armapunk2035.Malden/ui/html/deck.html server/AP_server/web/ui/html/deck.html && echo identical
```
Expected: `all ui/html scripts parse`, `identical`.

- [ ] **Step 8: Commit**

```bash
git add mission/Armapunk2035.Malden/ui/html/deck.html server/AP_server/web/ui/html/deck.html
git commit -F - <<'EOF'
feat(deck): SUMMON VEHICLE screen and the garage's recall star

Co-Authored-By: Dr. Sbaitso
EOF
```

---

### Task 10: Remove the Robotaxi

**Files:**
- Delete: `mission/Armapunk2035.Malden/core/gps/fn_robotaxi.sqf`, `server/AP_server/core/TON/fn_robotaxiSRV.sqf`
- Modify: `Functions.h:232` (`class robotaxi {};`), `CfgRE.hpp:222` (`class APS_fnc_robotaxiSRV`), `core/gps/fn_gps.sqf:82-83`, `core/gps/fn_hcDrive.sqf` (comments only), `ui/html/map.html:144` (both copies), `core/items/fn_qhCast.sqf:66` (comment)

- [ ] **Step 1: Delete + unregister**

```bash
git rm mission/Armapunk2035.Malden/core/gps/fn_robotaxi.sqf server/AP_server/core/TON/fn_robotaxiSRV.sqf
```
Remove the line `class robotaxi {}; // hail a driverless autopilot cab to the GPS destination` from `Functions.h` and `class APS_fnc_robotaxiSRV {allowedTargets = 2;};` from `CfgRE.hpp`.

- [ ] **Step 2: Dead branches and text**

`fn_gps.sqf` lines 82-83: delete the two-line block
```sqf
            if ((vehicle player) getVariable ["AP_robotaxi", false]) exitWith {
                ["<t color='#e7c757'>ROBOTAXI:</t> destination is locked for the ride.", "basic"] spawn AP_fnc_handleMessage; };
```
(check the exact closing of that `exitWith` in the file and remove the whole statement).
`map.html` (both copies) strip text: replace `ALT+CLICK NAV (ROBOTAXI)` with `ALT+CLICK NAV (AUTOPILOT / SUMMON)`.
`fn_hcDrive.sqf`: leave the historical comments; they describe why the code is shaped as it is.
`fn_qhCast.sqf:66`: leave (comment).

- [ ] **Step 3: Check nothing references it**

```bash
grep -rn 'AP_fnc_robotaxi\|APS_fnc_robotaxiSRV\|AP_robotaxi\b' mission/Armapunk2035.Malden server/AP_server --include='*.sqf' --include='*.hpp' --include='*.h' --include='*.cpp' --include='*.html'
python3 tools/fn_check.py | tail -2
python3 tools/dialog_reachability.py | tail -1
cmp mission/Armapunk2035.Malden/ui/html/map.html server/AP_server/web/ui/html/map.html && echo identical
```
Expected: the grep prints nothing; fn_check reports no missing function; map copies identical.

- [ ] **Step 4: Commit**

```bash
git add -A mission/Armapunk2035.Malden/core/gps mission/Armapunk2035.Malden/Functions.h mission/Armapunk2035.Malden/CfgRE.hpp mission/Armapunk2035.Malden/ui/html/map.html server/AP_server/web/ui/html/map.html server/AP_server/core/TON
git commit -F - <<'EOF'
chore(gps): remove the Robotaxi -- SUMMON VEHICLE replaced it

Co-Authored-By: SmarterChild
EOF
```

---

### Task 11: `summonselftest` bot command + full static suite

**Files:**
- Modify: `server/AP_server/init.sqf:1375` (next to `case "mapselftest"`)

- [ ] **Step 1: Add the case**

Before `case "mapselftest": {` insert:
```sqf
                    case "summonselftest": {
                        // SUMMON VEHICLE harness: spawn a car/heli/vtol ~1 km from respawn_civilian and
                        // let the HC bring it there. Outcome lands in this log as [SUMMON-TEST].
                        diag_log format ["[SUMMON-TEST] dispatched kind=%1 hcOwner=%2", _a1, missionNamespace getVariable ["AP_hcOwner", 0]];
                        ["selftest", _a1] spawn APS_fnc_summonSRV;};
```

- [ ] **Step 2: Whole-repo checks**

```bash
python3 tools/sqf_balance.py server/AP_server/init.sqf
bash tools/run_checks.sh 2>&1 | tail -12
```
Expected: `ok`; run_checks shows the same six pre-existing failures as before this plan (`harvest_corpus.py` missing, `test_map_*`/`test_frame_oracle`/`test_mapdata_rows` import errors) and nothing new. Any NEW failure is this plan's bug.

- [ ] **Step 3: Commit**

```bash
git add server/AP_server/init.sqf
git commit -F - <<'EOF'
test(summon): summonselftest bot command -- car|heli|vtol from 1 km to respawn_civilian

Co-Authored-By: Clippy
EOF
```

---

### Task 12: Deploy to dev, run the headless self-test, hand over to the owner

**Files:** none new. Uses `deploy/reload-armapunk2035.sh`, `~/arma3server_dev/hc_launch_once.sh`, `needstest.md`.

- [ ] **Step 1: Deploy** (say so first if the owner is connected)

```bash
bash deploy/reload-armapunk2035.sh 2>&1 | tail -4
```
Expected: `[mad] config parsed clean …`. Then:
```bash
L=~/arma3server_dev/loonydev.log; for i in $(seq 1 60); do grep -q 'handshake for' $L && break; sleep 2; done
grep -n -i 'Error in expression\|Error Undefined\|Script .* not found\|Undefined base class' $L | head
export PGPASSWORD=$(tr '\0' '\n' < /proc/$(pgrep -f '[p]ython pysqfd.py' | head -1)/environ | grep PYSQF_DB_DSN | grep -o 'password=[^ ]*' | cut -d= -f2)
psql -h 127.0.0.1 -U armapunk -d pgm_full_scratch -At -c "SELECT column_name FROM information_schema.columns WHERE table_name='vehicles' AND column_name='recall'"
```
Expected: no script errors; `recall`.

- [ ] **Step 2: Launch the headless client** (inside ONE Bash call — it only connects when launched during a live call)

```bash
bash ~/arma3server_dev/hc_launch_once.sh; sleep 45; grep -n -i 'headless client online\|Player .*connected' ~/arma3server_dev/loonyhc_direct.log ~/arma3server_dev/loonydev.log | tail -3; grep -n 'AP_hcOwner' ~/arma3server_dev/loonydev.log | tail -1
```
Expected: `LB HC: headless client online -- autopilot driver standing by` in the HC log and a `Player headlessclient connected` line in the server log. If the HC log says `Unable to locate a running instance of Steam`, the steamcmd cached login has lapsed — ask the owner to run `~/steamcmd/steamcmd.sh +login <acct>` once (per loonybin-hc-autopilot memory) and stop here.

- [ ] **Step 3: Self-test all three kinds**

```bash
for k in car heli vtol; do psql -h 127.0.0.1 -U armapunk -d pgm_full_scratch -c "INSERT INTO bot_commands (command,arg1) VALUES ('summonselftest','$k')" >/dev/null; sleep 240; done
grep -n 'SUMMON-TEST\|HCFLY\|HCDRIVE' ~/arma3server_dev/loonydev.log ~/arma3server_dev/loonyhc_direct.log | tail -20
```
Expected per kind: `[SUMMON-TEST] kind=<k> outcome=arrived|landed dist=<≤20> t=<≤300>`. `hover` for an air kind is acceptable only if the marker sits on a slope; `blocked`/`aborted`/`timeout` is a defect — read the HC log's `HCFLY`/`HCDRIVE` lines, fix, redeploy, repeat.

- [ ] **Step 4: needstest rows for the owner**

Append to `needstest.md` under a new `## SUMMON VEHICLE (2026-09-02)` heading:
```
| # | Test | Expect | Notes |
|---|---|---|---|
| 1 | GARAGE app → star a car → SUMMON VEHICLE tile → SUMMON | Car appears ~1 km out, drives to you, unlocks, engine off; phone shows EN ROUTE with distance/ETA then "is here" | free; cooldown 120 s shown after |
| 2 | Same with a starred heli | Lifts off ~1 km out, flies in at altitude, lands within ~40 m or hovers at 3 m with the "climb in" message | landing needs a flat spot |
| 3 | Same with a VTOL | As 2 | |
| 4 | Star vehicle is OUT in the world → SUMMON | The world copy vanishes; a fresh one comes from 1 km with the same fuel/damage/trunk | occupied → refused |
| 5 | Refusals: no HC / in a vehicle / nothing starred / on cooldown | Exact messages in the tile and chat; nothing spawns | |
| 6 | Seated heli AP: set NAV on the web map, TAB → AP wedge | Flies there, lands; touching the controls disengages | needs the Autopilot Module (garage slot 9) |
| 7 | Robotaxi | Gone from the launcher; no errors in RPT | |
```

- [ ] **Step 5: Commit + report**

```bash
git add needstest.md
git commit -F - <<'EOF'
docs(summon): owner playtest rows

Co-Authored-By: Bonzi Buddy
EOF
```
Report to the owner: build number, the three `[SUMMON-TEST]` lines verbatim, whether the HC is up, and the needstest rows.

---

## Self-review

**Spec coverage.** §2 flight core → Task 2; §2.2 seated air AP + gates → Task 4; §3.1 data → Task 1; §3.2 star → Tasks 7/8/9; §3.3 summon flow (refusals, reclaim, spawn point, spawn, hand-off, progress, arrival, failure, cooldown not charged on failure) → Tasks 5/6/7; §3.4 removal → Tasks 4/8/10; §4 UI → Tasks 8/9; §5 security (remoteExecutedOwner, row ownership, AP_dbInfo check, `-SUMMON-` logging) → Tasks 6/7; §6 headless self-test + owner rows → Tasks 11/12 (Python math tests dropped — Global Constraints). §7 numbers appear verbatim in the code.

**Placeholders.** None: every step has its code or exact command.

**Type consistency.** `AP_fnc_flyStep [_veh, _dt]` → String (Tasks 2/3/4). `AP_fnc_hcFly [_veh, _dest]` (Tasks 3/7-selftest via pump). `AP_fnc_summonPoint [_from, _isAir]` → `[x,y,0,dir]|[]` (Tasks 5/6/7). `AP_fnc_summonSpawn [_row(7), _isAir]` (Tasks 6/7). `APS_fnc_summonSRV [verb, arg]` verbs `set|info|go|drive|spawnfail|selftest` (Tasks 6/7/8/11). `AP_fnc_summonState [HashMap]` keys `state msg dist eta cooldown info` (Tasks 6/7/9). Garage row index 14 = recall (Tasks 1/8); deck row field `recall` (Tasks 1/9). Channel `summon` (Tasks 6/9). Page verbs `summon data|go`, `garage recall` (Tasks 8/9).

**Lifecycle owners.** The vehicle's end-of-summon state (`setOwner 2`, `lock 0`, `hc_ap_*` cleared) is owned by `summonSRV "drive"` alone; `hcFly`/`hcDrive` only set `hc_ap_done`. The DB `active` flag is owned by `APS_fnc_vehicleSetActive` (claim) and `DB_fnc_updateVehicle` (reclaim store) exactly as the garage already uses them. Cooldown is owned by `summonSRV` in memory.

**Write paths.** New SQF under `core/gps` and `core/TON` sit beside their siblings and are not gitignored; the spec/plan live at the repo root like `CASINO_SPEC.md`/`mapedit_live_plan.md`.

**Executed at plan review (2026-09-02):** all 27 SQF blocks through `sqf_balance.py` (every full file `ok`; the three fragment blocks that splice into existing structures report an unmatched closer by design) and `sqf_cmd_check.py` (only function names and `diag_frameNo`/`diag_deltaTime`, absent from the local mirror but used by `fn_hcDrive`); the 8 JS blocks through `node --check` with a stub prelude (full functions parse; the four splice fragments report the expected context error). Two corrections applied from that pass: `VTOL_Base_F` is the class (VTOLs inherit `Plane_Base_F`, so plane refusals test VTOL first), and `DB_fnc_asyncQuery`'s third argument is multi-row, not blocking.

**Riskiest lines — still unverified until in-game** (writing-plans-extras): every SQF block above is extracted and run through `tools/sqf_balance.py` and `tools/sqf_cmd_check.py`; the JS blocks through `node --check` after splicing into a scratch copy of `deck.html`. Unverifiable until in-game: `isFlatEmpty` argument semantics on Malden, `setVectorDirAndUp` behaviour on a VTOL under `setVelocity`, and the heli `inputAction` names (`HeliUp/Down/Forward/Back/Left/Right/RudderLeft/RudderRight/CollectiveRaise/CollectiveLower` per the BIKI Input Actions page; case-insensitive like the car ones in use) — marked for the self-test and owner rows.
