/*
    APS_fnc_apStress  (LooneyBin, owner 2026-07-17) -- DEV-ONLY HC-autopilot stress/coverage harness.
    Spawns driverless vans (C_Van_02_vehicle_F) and drives them with AP_fnc_hcDrive across the WHOLE
    Altis road network to find every spot the autopilot fails. Server-local drive (no HC needed) -- the driving
    ALGORITHM is identical; only locality/offload differs, so this characterises the algorithm's crash spots.

    Coverage: grid-sample the map every _step m; at each cell find the nearest road = an "anchor"; run a leg from
    each anchor to its EAST and SOUTH neighbour anchor. Connected neighbours drive the local roads (tiling the whole
    surface); disconnected pairs report "no route" fast and are skipped in analysis.

    Logs to loonydev.log (parse offline):
      [APBC]  <id> <x> <y>                         breadcrumb every 4s while driving (the traced surface)
      [APRES] id=.. reason=.. s..=.. d..=.. e..=.. distLeft=.. dur=.. dmg=.. eng=.. fps=..   per-leg outcome
      [APSTRESS] ...                               harness lifecycle + final tally
    reason: arrived (ok) | blocked|stuck (AP jam) | wrecked|disabled|sank (dead) | "no route" (disconnected) | timeout

    In: ["run", _maxLegs, _maxConcurrent, _step, _legTimeout]   _maxLegs 0 = all;  defaults 0 / 4 / 1600 / 200
        ["stop"]                                    abort an in-flight run
*/
if (!isServer) exitWith {};
params [["_mode", "run", [""]], ["_maxLegs", 0, [0]], ["_maxC", 4, [0]], ["_step", 1600, [0]], ["_legTimeout", 200, [0]]];

if (isNil "AP_apGovDebug") then { AP_apGovDebug = false };   // set true to log [GOV] speed-governor breakdown
if (_mode isEqualTo "stop") exitWith { AP_apStop = true; diag_log "[APSTRESS] stop requested"; };

// DETERMINISTIC watchdog test: spawn a van on a road, drive it to a far dest, then PIN it in place. A pinned van
// the autopilot commands to move is exactly the arc-cursor-races-ahead case. Pre-fix -> watchdog blind -> spins to
// the 15-min timeout. Post-fix -> must fire "blocked" within ~6s. Logs [APPIN] result + seconds-to-bail.
if (_mode isEqualTo "pintest") exitWith {[] spawn {private _sp = [3000, 13000, 0]; private _r = _sp nearRoads 400;
        if (count _r > 0) then { _sp = getPosATL (_r select 0); };
        private _van = createVehicle ["C_Van_02_vehicle_F", _sp, [], 0, "NONE"];
        _van setPosATL _sp; _van setFuel 1; _van setVariable ["owner", "apstress", true];
        private _dest = _sp getPos [3000, 45];              // a far dest so actual-dist-to-end stays large
        private _pin = getPosASL _van;
        [_van, _pin] spawn { params ["_v", "_pin"]; for "_i" from 1 to 400 do { if (isNull _v) exitWith {}; _v setPosASL _pin; _v setVelocity [0,0,0]; uiSleep 0.1; }; };
        private _t0 = time;
        [_van, _dest, "normal"] call AP_fnc_hcDrive;
        waitUntil { uiSleep 0.5; (isNull _van) || {(_van getVariable ["hc_ap_done", ""]) isNotEqualTo ""} || {time > _t0 + 60} };
        private _done = if (isNull _van) then { "vanished" } else { _van getVariable ["hc_ap_done", ""] };
        diag_log format ["[APPIN] result=%1 secondsToBail=%2 (PASS if 'blocked' in <15s)", (if (_done isEqualTo "") then {"STILL-DRIVING(timeout60)"} else {_done}), round (time - _t0)];
        if (!isNull _van) then { deleteVehicle _van; };};};

AP_apStop = false;
AP_apActive = 0;

// ---------- 1. road anchors on a grid ----------
private _anchors = [];                                  // each: [gx, gy, pos]
for "_gx" from (_step/2) to 30720 step _step do {for "_gy" from (_step/2) to 30720 step _step do {private _c = [_gx, _gy, 0];
        private _rs = _c nearRoads (_step * 0.55);
        if (count _rs > 0) then {private _best = objNull; private _bd = 1e12;
            { private _d = _c distance2D _x; if (_d < _bd) then { _bd = _d; _best = _x; }; } forEach _rs;
            _anchors pushBack [_gx, _gy, getPosATL _best];};};};

// ---------- 2. legs: each anchor -> its east + south neighbour ----------
private _legs = []; {_x params ["_ax", "_ay", "_apos"];
    private _e = _anchors findIf { ((_x select 0) isEqualTo (_ax + _step)) && {(_x select 1) isEqualTo _ay} };
    if (_e > -1) then { _legs pushBack [_apos, (_anchors select _e) select 2] };
    private _s = _anchors findIf { ((_x select 0) isEqualTo _ax) && {(_x select 1) isEqualTo (_ay + _step)} };
    if (_s > -1) then { _legs pushBack [_apos, (_anchors select _s) select 2] };} forEach _anchors;

// shuffle so the east+south legs of one anchor (adjacent in the list, same spawn point) don't launch back-to-back
// and materialise on top of each other. Spreading them in time lets each clear the anchor before the next spawns.
_legs = _legs call BIS_fnc_arrayShuffle;
if (_maxLegs > 0 && {_maxLegs < count _legs}) then { _legs resize _maxLegs; };
diag_log format ["[APSTRESS] === START === anchors=%1 legs=%2 step=%3 maxC=%4", count _anchors, count _legs, _step, _maxC];

// ---------- 3. run legs on a rolling concurrency window ----------
[_legs, _maxC, _legTimeout] spawn {params ["_legs", "_maxC", "_legTimeout"];
    private _id = 0; {if (AP_apStop) exitWith {};
        _x params ["_start", "_dest"];
        waitUntil { uiSleep 0.3; (AP_apActive < _maxC) || AP_apStop };
        if (AP_apStop) exitWith {};
        AP_apActive = AP_apActive + 1;
        [_id, _start, _dest, _legTimeout] spawn {params ["_id", "_start", "_dest", "_legTimeout"];
            private _t0 = time;
            // placement radius 22 so two legs sharing an anchor don't spawn ON TOP of each other (that reads as an
            // instant "wrecked" -- a harness artifact, not an AP crash). Ground the engine-chosen XY, keep it clear.
            private _van = createVehicle ["C_Van_02_vehicle_F", [_start select 0, _start select 1, 0], [], 22, "NONE"];
            _van setPosATL [(getPosATL _van) select 0, (getPosATL _van) select 1, 0];
            _van setVectorUp (surfaceNormal (getPosATL _van));
            _van setFuel 1;
            _van lock 2;
            _van setVariable ["owner", "apstress", true];       // survive fn_cleanup (ownerless = instant reap)
            _van setVariable ["hc_ap_arrive", 14, true];
            // spawn-collision guard: if it materialised inside something it's damaged within a moment -> not a crash
            uiSleep 0.7;
            if (isNull _van || {(damage _van) > 0.15}) exitWith {
                diag_log format ["[APRES] id=%1 reason=spawncollide sx=%2 sy=%3 dx=%4 dy=%5 ex=%2 ey=%3 distLeft=-1 dur=0 dmg=1 eng=1 fps=%6",
                    _id, round (_start select 0), round (_start select 1), round (_dest select 0), round (_dest select 1), round diag_fps];
                if (!isNull _van) then { deleteVehicle _van; };
                AP_apActive = AP_apActive - 1;};
            // breadcrumb the traced path
            [_van, _id] spawn {params ["_v", "_id"];
                while { !isNull _v && {(_v getVariable ["hc_ap_done", ""]) isEqualTo ""} } do {private _p = getPosATL _v;
                    diag_log format ["[APBC] %1 %2 %3", _id, round (_p select 0), round (_p select 1)];
                    uiSleep 4;};};
            // DRIVE (server-local): hcDrive returns fast after starting its own per-frame loop; wait on hc_ap_done
            private _ok = [_van, _dest, "normal"] call AP_fnc_hcDrive;
            private _reason = "";
            if (!_ok) then {_reason = _van getVariable ["hc_ap_done", "startfail"];} else {
                // harness-level per-leg deadline: a leg that neither arrives nor trips hcDrive's own watchdog by
                // _legTimeout is recorded as "slow" (an AP problem area: crawling/oscillating/frozen) and killed so
                // the concurrency window keeps moving. hcDrive's internal 15-min timeout is far too long for a sweep.
                private _dl2 = time + _legTimeout;
                waitUntil { uiSleep 1; (isNull _van) || {(_van getVariable ["hc_ap_done", ""]) isNotEqualTo ""} || {time > _dl2} };
                _reason = if (isNull _van) then { "vanished" }
                    else { private _d = _van getVariable ["hc_ap_done", ""]; if (_d isEqualTo "") then { "slow" } else { _d } };};
            private _gone = isNull _van;
            private _ep  = if (_gone) then { _dest } else { getPosATL _van };
            private _dl  = if (_gone) then { -1 } else { round (_van distance2D _dest) };
            private _dmg = if (_gone) then { 1 } else { damage _van };
            private _eng = if (_gone) then { 1 } else { _van getHitPointDamage "HitEngine" };
            diag_log format ["[APRES] id=%1 reason=%2 sx=%3 sy=%4 dx=%5 dy=%6 ex=%7 ey=%8 distLeft=%9 dur=%10 dmg=%11 eng=%12 fps=%13",
                _id, _reason, round (_start select 0), round (_start select 1), round (_dest select 0), round (_dest select 1),
                round (_ep select 0), round (_ep select 1), _dl, round (time - _t0), (round (_dmg * 100)) / 100, (round (_eng * 100)) / 100, round diag_fps];
            if (!isNull _van) then { deleteVehicle _van; };
            AP_apActive = AP_apActive - 1;};
        _id = _id + 1;} forEach _legs;
    waitUntil { uiSleep 2; AP_apActive <= 0 };
    diag_log format ["[APSTRESS] === ALL DONE === legs_launched=%1", _id];};
true
