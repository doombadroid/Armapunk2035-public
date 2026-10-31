/*
    AP_fnc_hcDrive  (LooneyBin, owner 2026-07-15) -- HEADLESS AUTOPILOT.
    Drives a LOCAL, driverless vehicle to a destination with the physics autopilot -- setVelocityModelSpace
    (throttle) + setAngularVelocity (pure-pursuit steer) over a road route from AP_fnc_routeFind. NO player,
    NO shared AP_gps* globals: every bit of state is loop-local or on the vehicle, so any number of vehicles
    drive at once. Runs on the machine that OWNS the vehicle -- the headless client (any distance from players)
    or the server. This is AP_fnc_gpsAutopilot's drive loop, forked player-less. Reusable for deliveries,
    convoys, escorts, patrols, chases.

    In:  [_veh, _dest, _mode]   _mode: "normal" (80) | "madmax" (150) | "sloth" (50)
    Out: true if it started driving, false if not local / no route.
    Sets on the vehicle (public): hc_ap_driving (bool while en route), hc_ap_done ("arrived"|"stuck"|"blocked"|
    "wrecked"|"timeout"|"no route") when it stops.
*/
params [["_veh", objNull, [objNull]], ["_dest", [0,0,0], [[]]], ["_mode", "normal", [""]]];
if (isNull _veh || {!local _veh} || {!(_veh isKindOf "LandVehicle")}) exitWith { false };
if (_veh getVariable ["hc_ap_driving", false]) exitWith { false };

private _route = [getPosATL _veh, _dest] call AP_fnc_routeFind;
private _pts = _route param [0, []];
if (!(_pts isEqualType []) || {count _pts < 4}) exitWith { _veh setVariable ["hc_ap_done", "no route", true]; false };
// Finish AT the exact destination: routeFind only snaps to the nearest road, so append the raw dest as a final
// point. The last leg then drives off-road right up to it -- e.g. a delivery van pulls up to the player instead
// of stopping at the nearest road. Capped at 90m off-road so a wilderness target doesn't trigger a giant
// off-road slog (beyond that, ending at the road is saner). Collision shield + stuck-watchdog keep it safe.
private _last = _pts select ((count _pts) - 1);
private _offRoad = _last distance2D _dest;
// always extend to the exact dest (routeFind ends at a road VERTEX that can sit ~10-30m off the real point,
// even when it's on the road) -- but cap the off-road reach at 90m so a wilderness target isn't a cross-country slog.
if (_offRoad > 2 && {_offRoad < 90}) then { _pts pushBack [_dest select 0, _dest select 1]; };

// re-assert the door lock where the vehicle is LOCAL (`lock` is an argument-local command -- a lock set by the
// server before the setOwner handoff doesn't reliably survive the locality transfer). Opt-in via hc_ap_lock.
if (_veh getVariable ["hc_ap_lock", false]) then { _veh lock 2; };
_veh setVariable ["hc_ap_abort", false, true];

_veh setVariable ["hc_ap_driving", true, true];
_veh setVariable ["hc_ap_done", "", true];
_veh engineOn true;
_veh disableBrakes true;   // kill the autobrake that cancels setVelocity

// Collision shield: a setVelocity-driven van with no human at the wheel clips town buildings and self-destructs
// in seconds (the robotaxi survives only because a player is driving). Ignore IMPACT/collision/fire damage, but
// STILL let weapons through so players can intercept a delivery van (the owner wants that). Added on the HC where
// the van is local; removed when the drive ends.
[_veh] call AP_fnc_hcShield;

// NOTE: an inert AI driver was tried as a "physics anchor" and made it WORSE -- a seated driver (even with
// disableAI + disableBrakes) holds the hull stationary against setVelocity, freezing the van at spawn. The empty
// van drives fine; keep it driverless.
_veh setVariable ["hc_ap_anchor", objNull];

[_veh, _pts, _mode] spawn {params ["_veh", "_pts", "_mode"];
    private _law = switch (_mode) do {
        case "madmax": { [(((getNumber (configOf _veh >> "maxSpeed")) * 0.93 / 3.6) max 16.7 min 41.7), 7.5, 8] };
        case "sloth":  { [13.9, 4.0, 5] };
        default        { [22.2, 5.5, 6] };};
    _law params ["_vMax", "_grip", "_brake"];
    private _cMargin = if (_mode isEqualTo "madmax") then { 0.72 } else { 1.0 };
    // how close (arc metres from the route end) counts as "arrived". 14m suits a robotaxi drop-off; a delivery
    // van that must pull right up to a player sets hc_ap_arrive low (~4). Read per-vehicle.
    private _arriveDist = _veh getVariable ["hc_ap_arrive", 14];
    private _n = count _pts;
    private _cum = [0];
    for "_i" from 0 to (_n - 2) do { _cum pushBack ((_cum select _i) + ((_pts select _i) distance2D (_pts select (_i + 1)))); };
    private _total = _cum select (_n - 1);
    // seed arc position at the nearest route point to the vehicle
    private _p0 = getPosASL _veh;
    private _best = 0; private _bd = 1e12;
    for "_i" from 0 to (_n - 1) do { private _d = _p0 distance2D (_pts select _i); if (_d < _bd) then { _bd = _d; _best = _i; }; };
    private _s = _cum select _best;
    private _seg = _best min (_n - 2);
    private _spd = (speed _veh / 3.6) max 0;
    private _end = time + 900; private _fno = diag_frameNo - 1; private _lastT = time;
    private _endPt = _pts select (_n - 1);   // real target -- the still-en-route test measures actual distance to it
    private _stuckAnchor = getPosASL _veh; private _stuckT = time;   // rolling-anchor stuck-watchdog (can't clear 4m in 7s)
    private _probeT = 0;   // [HCDRIVE-PROBE] cadence when the vehicle carries hc_ap_probe (the summon self-test sets it)
    private _recoveries = 0;   // reverse-and-retry attempts before we finally give up "blocked"
    private _reason = "";   // set explicitly on arrival; else diagnosed from state after the loop
    diag_log format ["HCDRIVE start: veh=%1 n=%2 total=%3 seedBest=%4 seedS=%5 seedD=%6 local=%7 canMove=%8", _veh, _n, round _total, _best, round _s, round _bd, local _veh, canMove _veh];

    private _fnSample = {params ["_sq"];
        _sq = (_sq max 0) min (_total - 0.01);
        private _g = _seg;
        while {_g > 0 && {(_cum select _g) > _sq}} do { _g = _g - 1; };
        while {_g < _n - 2 && {(_cum select (_g + 1)) <= _sq}} do { _g = _g + 1; };
        private _a = _pts select _g; private _b = _pts select (_g + 1);
        private _t = ((_sq - (_cum select _g)) / (((_cum select (_g + 1)) - (_cum select _g)) max 0.01)) min 1;
        [(_a select 0) + ((_b select 0) - (_a select 0)) * _t, (_a select 1) + ((_b select 1) - (_a select 1)) * _t]};

    // NOTE: no canMove guard -- canMove returns false for a DRIVERLESS vehicle even while it drives fine under
    // setVelocity (the robotaxi never hit this: a player sits in the seat). Genuine immobility -> stuck-watchdog.
    // ENGINE guard IS here: setVelocity happily shoves a dead-engine hull down the road, so without this a van
    // with its engine shot out just keeps driving. hc_ap_abort = external stop.
    while { !isNull _veh && {alive _veh} && {local _veh} && {time < _end} && {((getPosASL _veh) select 2) > -1.2}
            && {!(_veh getVariable ["hc_ap_abort", false])}
            && {(_veh getHitPointDamage "HitEngine") < 0.9} } do {
        // pace EXACTLY one update per rendered frame with the real engine delta. `uiSleep 0` can re-enter the
        // same frame many times, each advancing _s by commanded speed -> _s races ahead of the (slower) physical
        // van and false-"arrives". This mirrors the robotaxi's EachFrame handler.
        waitUntil { diag_frameNo != _fno };
        _fno = diag_frameNo;
        // integrate on REAL elapsed time since our last iteration, NOT diag_deltaTime (one frame). Under SQF-scheduler
        // contention (many concurrent drives) this loop runs every 2nd-3rd frame; per-frame dt then under-counts the
        // elapsed time -> arc-cursor _s desyncs from the physical van -> mis-governed speed + steering wobble -> crawl.
        // Real elapsed dt keeps _s synced no matter the loop rate (the one-iter-per-frame waitUntil still blocks racing).
        private _dt = (time - _lastT) min 0.2;
        if (_dt <= 0) then { _dt = diag_deltaTime max 0.01; };
        _lastT = time;
        private _pos = getPosASL _veh;
        while {_seg < _n - 2 && {(_cum select (_seg + 1)) <= _s}} do { _seg = _seg + 1; };
        private _left = _total - _s;

        // direction (10m baseline) + right-hand lane
        private _pA = [_s - 2.5] call _fnSample; private _pB = [_s + 2.5] call _fnSample;
        private _dA = [_s - 5] call _fnSample;   private _dB = [_s + 5] call _fnSample;
        private _dirX = (_dB select 0) - (_dA select 0); private _dirY = (_dB select 1) - (_dA select 1);
        private _dn = sqrt (_dirX * _dirX + _dirY * _dirY) max 0.01; _dirX = _dirX / _dn; _dirY = _dirY / _dn;

        // curvature-limited target speed (scan 5..90m)
        private _target = _vMax; private _bendAhead = 0; private _nearVc = _vMax;
        for "_k" from 1 to 18 do {private _d = _k * 5;
            private _c0 = [_s + _d - 5] call _fnSample; private _c1 = [_s + _d] call _fnSample; private _c2 = [_s + _d + 5] call _fnSample;
            private _bb1 = ((_c1 select 0) - (_c0 select 0)) atan2 ((_c1 select 1) - (_c0 select 1));
            private _bb2 = ((_c2 select 0) - (_c1 select 0)) atan2 ((_c2 select 1) - (_c1 select 1));
            private _dth = abs (((_bb2 - _bb1 + 540) mod 360) - 180);
            if (_d <= 15) then { _bendAhead = _bendAhead max _dth; };
            if (_dth > 2) then {private _rad = ((10 / (_dth * 0.017453)) max 4) min 400;
                private _vc = (sqrt (_grip * _rad * _cMargin)) min (2.0 * _rad);
                _target = _target min (sqrt ((_vc * _vc) + (0.8 * _brake * _d)));
                if (_d <= 22) then { _nearVc = _nearVc min _vc; };};};
        // ease to a stop at the route end. The zero-speed point must sit INSIDE the arrival radius or the van
        // halts short and never "arrives" (e.g. arriveDist 4 with a fixed 8m floor stalls it at ~8m). Scale it.
        if (_left < 60) then { _target = _target min (((_left - (_arriveDist * 0.55)) max 0) / 2.5); };

        // obstacle brake (people/vehicles in the lane ahead)
        private _brakeD = 12 + (_spd * _spd) / 9;
        private _aheadC = (getPosATL _veh) vectorAdd [_dirX * _brakeD * 0.55, _dirY * _brakeD * 0.55, 0];
        private _obsMin = 1e9; {
            // ignore OTHER autopilot-driven vehicles (hc_ap_driving): two AP vans both hold the right-hand lane, so
            // braking for each other just deadlocks them into a mutual crawl (convoys + concurrent deliveries) -- the
            // collision shield covers the rare actual contact. Real players/traffic are still braked for.
            if (_x isNotEqualTo _veh && {!(_x in crew _veh)} && {alive _x} && {!(_x getVariable ["hc_ap_driving", false])}) then {
                private _ox = ((getPosATL _x) select 0) - (_pos select 0);
                private _oy = ((getPosATL _x) select 1) - (_pos select 1);
                private _rel = _ox * _dirX + _oy * _dirY;
                private _lat = _ox * _dirY - _oy * _dirX;
                if (_rel > 2 && {abs _lat < 3.2}) then {_target = _target min (sqrt ((11 * ((_rel - 13) max 0)) max 0));
                    _obsMin = _obsMin min _rel;};};
        } forEach (_aheadC nearEntities [["Car", "Tank", "Air", "Ship", "CAManBase"], _brakeD * 0.6]);

        // SOLID GEOMETRY ahead (buildings / walls / rocks) -- the entity scan above only sees vehicles + people, so
        // a setVelocity van drives straight into a house, clips THROUGH the wall and floats. Raycast forward from
        // bumper height and brake to stop ~4.5m short of any real object (ignore terrain so hills don't false-fire).
        private _eye = _pos vectorAdd [0, 0, 0.6];
        private _reach = 6 + _spd * 1.3;
        private _rayHit = lineIntersectsSurfaces [_eye, [(_eye select 0) + _dirX * _reach, (_eye select 1) + _dirY * _reach, (_eye select 2)], _veh, objNull, true, 1, "GEOM", "NONE"];
        if (count _rayHit > 0) then {private _h0 = _rayHit select 0;
            if (!isNull (_h0 select 2)) then {                 // a real object, not terrain
                private _hd = _eye distance (_h0 select 0);
                _target = _target min (((_hd - 4.5) max 0) / 1.4);
                if (_hd < 5) then { _obsMin = 0; };            // wall right there -> full stop
            };};

        // integrate commanded speed
        private _accel = ((_target - _spd) max -14) min 3.4;
        private _newSpd = (_spd + _accel * _dt) max 0;
        _newSpd = _newSpd min _nearVc;
        if (_obsMin < 12) then { _newSpd = 0; };
        _spd = _newSpd;
        _s = (_s + _newSpd * _dt) min _total;

        // arrival: brake, then stop once actually stopped
        if (_left < _arriveDist) then { _newSpd = 0; _spd = 0; };
        if (_left < _arriveDist && {(abs speed _veh) / 3.6 < 0.8}) exitWith { _veh setVelocity [0, 0, 0]; _reason = "arrived"; };

        // pure-pursuit steer
        private _La = 10 + _newSpd * 0.9;
        _La = (_La * (1 - ((_bendAhead / 55) min 0.7))) max 4.5;
        private _lp = [_s + _La] call _fnSample; private _ld2 = [_s + _La + 4] call _fnSample;
        private _lx = (_ld2 select 0) - (_lp select 0); private _ly = (_ld2 select 1) - (_lp select 1);
        private _ln = sqrt (_lx * _lx + _ly * _ly) max 0.01; _lx = _lx / _ln; _ly = _ly / _ln;
        private _laneOff = 2.2 * (1 - ((_bendAhead / 45) min 0.9));
        private _aimX = (_lp select 0) + _ly * _laneOff; private _aimY = (_lp select 1) - _lx * _laneOff;
        private _want = ((_aimX - (_pos select 0)) atan2 ((_aimY - (_pos select 1))));
        private _yawErr = ((_want - getDir _veh + 540) mod 360) - 180;
        private _curYaw = (angularVelocity _veh) select 2;
        private _yawCmd = ((_yawErr * 0.04) - (_curYaw * 0.26)) max -2.3 min 2.3;

        // scrub speed when badly off-heading so the chassis can rotate back onto line -- but ONLY at speed. At low
        // speed setAngularVelocity is damped (see below), so slowing DOESN'T help the van turn, it just deepens the
        // yaw-error/speed death-spiral that pins the whole autopilot at ~14 km/h. Below 10 m/s we keep the speed and
        // force the turn with setDir instead.
        if (abs _yawErr > 22 && {_newSpd > 10}) then { _newSpd = _newSpd * ((1 - (((abs _yawErr) - 22) / 48)) max 0.5); };

        // LOW-SPEED STEERING: setAngularVelocity is heavily damped on a grounded car at low speed (wheels resist the
        // yaw), so a slow van can't rotate onto a bend -> yaw error climbs -> scrub slows it more -> crawl. Below 9
        // m/s, force the heading kinematically with setDir (undampable -- same trick as AP_fnc_hcTurnAround),
        // capped per frame so it stays smooth; setVelocityModelSpace then drives forward along the NEW heading.
        // Above 9 m/s the physics-legal setAngularVelocity tracks fine and stays smooth for players in the seat.
        private _lowSpeedTurn = (_newSpd < 9) && {(abs _yawErr) > 8};
        if (_lowSpeedTurn) then { _veh setDir ((getDir _veh) + (_yawErr max -6 min 6)); };
        _veh setVelocityModelSpace [0, _newSpd, (velocityModelSpace _veh) select 2];
        if (!_lowSpeedTurn) then { _veh setAngularVelocity [0, 0, _yawCmd]; };
        if ((_veh getVariable ["hc_ap_probe", false]) && {time >= _probeT}) then {
            _probeT = time + 2;
            diag_log format ["[HCDRIVE-PROBE] s=%1/%2 left=%3 cmd=%4 act=%5 tgt=%6 obs=%7 ray=%8 yawErr=%9 stuckAge=%10 pos=%11 dir=%12",
                round _s, round _total, round _left, round (_newSpd * 10) / 10, round ((speed _veh) / 3.6 * 10) / 10, round (_target * 10) / 10,
                (if (_obsMin > 1e8) then { -1 } else { round _obsMin }), count _rayHit, round _yawErr, round (time - _stuckT),
                (getPosATL _veh) apply { round (_x * 10) / 10 }, round getDir _veh];
        };

        // STUCK-WATCHDOG -- ROLLING ANCHOR. Keep an anchor point; whenever the van gets >4m from it, reset the anchor
        // to here. If the van CAN'T get 4m from the anchor for >7s (~<0.5 m/s) while still far from the goal, it's
        // genuinely stuck -> give up "blocked". Uses RAW distance (no arc-projection), so switchback/hairpin roads
        // that double back on themselves can't fool it (projection-based tries snapped to the arc-earlier parallel
        // segment and false-blocked moving vans); the 4m/7s band clears any real crawl but traps a pinned/walled van;
        // jitter <4m never resets the anchor so a pinned van still trips it. Two more subtleties baked in here:
        //  - `speed _veh` is useless (a setVelocity van pinned on a wall still reports high speed) -> measure position.
        //  - this `exitWith` sits at the while-body TOP LEVEL. Nested inside `if (...) then {...}` it would exit only
        //    the then-block, NOT the drive `while` -- the original watchdog did exactly that, so it latched
        //    _reason="blocked" but kept driving and every stuck van spun to the 15-min timeout. Keep it top-level.
        if ((_pos distance2D _stuckAnchor) > 4) then { _stuckAnchor = _pos; _stuckT = time; };
        private _stuckNow = ((time - _stuckT) > 7) && {(_pos distance2D _endPt) > (_arriveDist + 6)};
        if (_stuckNow && {_recoveries < 3}) then {
            // RECOVERY: don't surrender on the first wedge. Back off the obstacle (hcReverse is blocking + raycast-
            // guarded so it won't reverse into a wall), snap the heading toward the route ahead, and try again. Most
            // wedges are a nose into a wall/curb or a botched tight turn that a short reverse clears. Only after 3
            // failed recoveries is it truly "blocked".
            _recoveries = _recoveries + 1;
            [_veh, 11, 5] call AP_fnc_hcReverse;
            private _aim = [_s + 12] call _fnSample; private _rp = getPosASL _veh;
            _veh setDir (((_aim select 0) - (_rp select 0)) atan2 ((_aim select 1) - (_rp select 1)));
            _stuckAnchor = getPosASL _veh; _stuckT = time;
            _stuckNow = false;};
        if (_stuckNow) exitWith { _reason = "blocked"; };};
    // diagnose why the loop ended (arrival sets _reason explicitly; everything else is inferred here)
    if (_reason isEqualTo "") then {_reason = call {if (isNull _veh) exitWith { "vanished" };
            if (!alive _veh) exitWith { "wrecked" };
            if (!(local _veh)) exitWith { "lostlocality" };
            if ((_veh getHitPointDamage "HitEngine") >= 0.9) exitWith { "disabled" };
            if (_veh getVariable ["hc_ap_abort", false]) exitWith { "aborted" };
            if (((getPosASL _veh) select 2) <= -1.2) exitWith { "sank" };
            if (time >= _end) exitWith { "timeout" };"interrupted"};};
    diag_log format ["HCDRIVE end: veh=%1 reason=%2 local=%3 alive=%4 canMove=%5 posZ=%6", _veh, _reason, (!isNull _veh && {local _veh}), alive _veh, (!isNull _veh && {canMove _veh}), (if (isNull _veh) then {-99} else {round ((getPosASL _veh) select 2)})];
    private _anc = _veh getVariable ["hc_ap_anchor", objNull];
    if (!isNull _anc) then { deleteVehicle _anc; };
    if (!isNull _veh) then {private _eh = _veh getVariable ["hc_ap_dmgEH", -1];
        if (_eh >= 0) then { _veh removeEventHandler ["HandleDamage", _eh]; _veh setVariable ["hc_ap_dmgEH", nil]; };
        _veh setVariable ["hc_ap_anchor", nil];
        if (local _veh) then { _veh disableBrakes false; _veh setVelocity [0, 0, 0]; };
        // NATIVE-AI RESCUE (long-tail catch for 99%): the setVelocity controller + reverse-recovery couldn't clear
        // this spot (usually a tight intersection/switchback the hand-rolled steer can't maneuver). Hand the van to
        // ARMA'S OWN driving AI -- real pathfinding + stuck-handling -- to bull to the destination, then hand back a
        // clean driverless van. AI can drive a LOCKED van (lock blocks player get-in, not moveInDriver). ~60s budget;
        // bails if the AI itself stalls 14s. Success flips the outcome blocked -> arrived.
        // Publish the outcome FIRST. The rescue below needs createUnit, which CfgDisabledCommands.hpp turns off
        // on every non-server machine including this HC -- the engine refuses the command, the script dies on
        // the nil unit, and (before 2026-09-02) hc_ap_done was never written, so every "blocked" drive read as a
        // server-side TIMEOUT 5 minutes later. If the rescue ever does run and succeed, it re-publishes "arrived".
        _veh setVariable ["hc_ap_driving", false, true];
        _veh setVariable ["hc_ap_done", _reason, true];
        // hc_ap_abort: the server-side monitor has already concluded the run (it publishes hc_ap_done first), so a
        // rescue that could still run here (server-side hcDrive) must not fight a vehicle that was handed back
        if (_reason isEqualTo "blocked" && {local _veh} && {alive _veh} && {!(_veh getVariable ["hc_ap_abort", false])} && {(_veh getHitPointDamage "HitEngine") < 0.9}) then {
            private _grp = createGroup [civilian, true];
            private _drv = _grp createUnit ["C_man_1", getPosATL _veh, [], 0, "NONE"];
            if (isNil "_drv" || {isNull _drv}) exitWith {
                diag_log "HCDRIVE ai-rescue: unavailable here (createUnit is a disabled command on this machine)";
                if (!isNull _grp) then { deleteGroup _grp; };
            };
            _drv moveInDriver _veh;
            _drv setCaptive true; _drv allowDamage false;
            _grp setBehaviour "CARELESS"; _grp setSpeedMode "FULL"; _grp setCombatMode "BLUE";
            _veh engineOn true; _veh limitSpeed 90;
            if (!isNull (driver _veh)) then { (driver _veh) doMove _endPt; };
            private _aiEnd = time + 60; private _aiAnc = getPosASL _veh; private _aiAncT = time;
            waitUntil {uiSleep 1;
                if (!isNull (driver _veh) && {(_veh distance2D _endPt) > 14}) then { (driver _veh) doMove _endPt; };
                if ((getPosASL _veh) distance2D _aiAnc > 6) then { _aiAnc = getPosASL _veh; _aiAncT = time; };
                (isNull _veh) || {!alive _veh} || {!(local _veh)} || {(_veh distance2D _endPt) < (_arriveDist + 4)} || {time > _aiEnd} || {(time - _aiAncT) > 14}
            };
            if (!isNull _veh && {alive _veh} && {(_veh distance2D _endPt) < (_arriveDist + 6)}) then {
                _reason = "arrived"; diag_log "HCDRIVE ai-rescue: SUCCEEDED (blocked -> arrived)";
            } else { diag_log "HCDRIVE ai-rescue: failed (still blocked)"; };
            if (!isNull _drv) then { deleteVehicle _drv; };
            if (!isNull _grp) then { deleteGroup _grp; };
            if (!isNull _veh && {local _veh}) then { _veh limitSpeed -1; _veh setVelocity [0, 0, 0]; };
            if (_reason isEqualTo "arrived") then { _veh setVariable ["hc_ap_done", _reason, true]; };};};};
true
