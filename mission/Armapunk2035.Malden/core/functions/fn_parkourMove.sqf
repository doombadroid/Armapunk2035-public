/*
    AP_fnc_parkourMove -- the spawned mover for one vault / mantle / drop / wall run
    (owner 2026-09-16, plan "Feature A" > Motion). Started ONLY by AP_fnc_parkour:

        [_kind, _data, _serial, _helper] spawn AP_fnc_parkourMove;

    AP_fnc_parkour has already set AP_parkourState = _kind and AP_action_in_use = true in the same
    unscheduled frame as the keypress (that is the mutex; a second V cannot slip in between), bumped
    AP_parkourSerial, and -- owner 2026-09-16, review round 1 -- created the helper, stored it in
    AP_parkourHelper and attached the player at [0,0,attachZ] in that frame too, so the scheduler delay
    before this script's first slice cannot let the player run on and then snap him back. This script
    owns the flags and the helper from here until its teardown hands them back; every early exit
    below detaches and deletes the helper it was handed.

    ONE GLIDE PRIMITIVE FOR ALL FOUR MOVES, copied from core/actions/fn_fastRope.sqf:50-124. The
    player is attachTo'd to an invisible helper and the attachment OFFSET is walked at 20 Hz; the
    player is never simulated along the path. Why that and not setVelocity/setPos:
      - it holds a pose off the ground (fast-rope proves it for seconds at a time);
      - the path is deterministic: no capsule snagging on the lip, no engine locomotion fighting a
        scripted velocity;
      - there is no landing event, so the airborne law (core/fn_initCiv.sqf:142-175: airborne ->
        halofreefall_non, landing out of freefall -> prone) and live fall damage never trigger;
      - one setVelocity per move at most, so be.log stays quiet (setVelocity logs a line per call);
      - per-frame setPos networks as teleports to observers (fn_gpsAutopilot.sqf:7), whereas an
        attached unit follows its parent's interpolated transform.

    THE HELPER IS GLOBAL (Land_ClutterCutter_small_F through createVehicle, the fn_handleChair.sqf:12
    trick): a local helper cannot be resolved on remote machines, and then observers have nothing to
    interpolate against. Its origin is the ground and the man's origin is his feet, so an offset of
    [0,0,0] stands the player where he was (AP_parkourCfg_attachZ is the live fudge if the spike shows
    otherwise). It is stored in AP_parkourHelper so evh/fn_onPlayerRespawn.sqf and the guard below
    can delete it if this script ever dies. A DISCONNECT mid-move orphans it for longer than a move
    (the plan's "<= 2 s" was wrong): the mover dies with the client and the object passes to the
    server. Nothing in the mission can delete it then; it is left to the server's junk sweep
    (server/AP_server/core/system/fn_cleanup.sqf over `vehicles`, the 300 s "cleanupCartel" job; an
    untagged clutter cutter matches its generic branch -- unverified in game). The immediate fix still
    belongs server-side, in fn_playerDisconnected (delete a Land_ClutterCutter_small_F the leaving unit
    is attachedTo); later work in the plan.
    owner 2026-09-16 (review round 4): THE SWEEP NEVER TAKES A HELPER IN USE. Its generic branch now skips a
    Land_ClutterCutter_small_F whose attachedObjects is not empty (a player mid-move, or a seated chair,
    AP_fnc_handleChair), so it can no longer delete the helper a player hangs on (review round 2: ~0.2-0.8%
    of moves, dropped by the "helper-gone" soft abort). A helper with NOTHING attached is still reaped, by
    the first sweep that finds it, i.e. within about 300 s; a disconnect orphan qualifies once the leaving
    unit is off it (deleted or detached), and is skipped for as long as anything is still attached.

    KEYFRAMES are [[x, y, z], seconds, anim, sweep, surfaceWindow, homeOnAbort] in helper model space
    (x right, y along the move, z up), linearly interpolated with MEASURED dt clamped to 0.1 s -- a
    frame hitch slows the move, it never teleports it. A non-empty anim is switchMove'd on entering its
    keyframe and mirrored once. The wall run is not keyframed: its offset is a function of time, and
    its z also rides the ground found under the planned feet each tick (review round 1).

    COMPUTE IS SEPARATE FROM APPLY on purpose. _fnc_keyOffset / _fnc_wallOffset only produce the
    [x,y,z] for this tick and _fnc_apply is the single place that moves the player along the path
    (attachTo; the one other attachTo is AP_fnc_parkour's initial [0,0,attachZ], the path's start). The
    plan keeps a velocity-mode wall run as the documented alternative if the attached glide steps
    visibly for observers (SPIKE P3); that swap replaces _fnc_apply for the wall run and nothing else.

    SWEEPS are PREDICTIVE: the segment from last tick's planned position to this tick's, plus a 0.5 m
    lead, is ray-tested BEFORE the player is moved, so a hit stops him short instead of noticing after
    he is inside the wall. "head" (rises) = one ray ALONG THE PLANNED HEAD CHORD, from last tick's head
    to riseRayLen further along it, never past the rise keyframe's head; the chord runs riseHeadTop above
    headZ (owner 2026-09-16, review round 3: the r1/r2 ray went 0.4 m straight up, so over the approach
    it tested a band the probe never looked at, and a porch roof passed the probe and aborted every V;
    every head ray is now a piece of the one chord the probe's "rise" ray casts whole); "body" = rays
    along the travel at 0.9 and 1.6 m; a surface window = also a ray down 0.6 m from feet + 0.3 while the
    feet are over the obstacle (the mantle whose car drives off). The wall run adds a LOW corner ray at
    ground + wallStepUp + 0.05 (review round 2; benches, planters, bins; wallKneeAboveStep < 0 = off).
    owner 2026-09-16 (review round 4): the wall run's corner, low and head rays run from last tick's point
    to wallCornerLen further ALONG THE PLANNED PATH (split at the end of the ease), not along t, so each is a
    piece of what the probe casts: its 0.9 / 1.6 / knee polyline, and (head) its head-top line over the arc.
    Sweeps ignore the player and the helper.
    owner 2026-09-16 (review round 1): the probed obstacle is ignored ONLY AT OR BELOW ITS TOP (vault /
    mantle: P.z + H + sweepIgnoreMargin; drop: P.z + margin, the ledge top). A building is one object, so
    the old whole-object exemption also hid the lintel over the window being vaulted, the wall above a
    low opening and a roof railing, and the glide carried the player through them. The wall run's rays
    and the surface window ignore nothing (they must see the wall's own building / the surface), except
    that terrain never counts for the low corner ray (the ground ray follows terrain).

    ABORT POLICY (plan): dead / downed / restrained / in a vehicle / respawned -> tear down within one
    tick and do not touch the animation (those flows own it). Blocked / surface gone / helper gone /
    timeout -> in a "home" keyframe (the rise) re-attach at the start and stand up there; later,
    tear down in place, let the engine drop the player (<= 2.5 m by probe geometry), stand him up
    after he lands.

    ONE TEARDOWN, AND IT ALWAYS RUNS. Every loop exit falls through to the same block. SQF cannot
    catch a runtime error, so a guard script watches this one (scriptDone on _thisScript): if the
    mover ever ends with the state still busy and the serial still its own, the guard detaches,
    deletes the helper and hands the flags back. evh/fn_onPlayerRespawn.sqf is the second net.

    THE SERIAL. Global state (AP_parkourState / AP_action_in_use / AP_parkourHelper / AP_parkourNext)
    is only written while AP_parkourSerial still equals this move's serial. The respawn reset bumps
    it, so a mover that outlives its player (the unit is captured as _unit; `player` changes object
    at respawn) cannot clear a flag that now belongs to someone else, nor shove the new body.

    SPIKE toggles read here: animHold (P4: "cycle" | "static"), pushFwd/pushOut/pushUp and wallArc
    (P5), tick (P6), attachZ, wakeCorpse. All live via AP_parkourCfg_<key>, read once at the start of
    the move.

    Never touches enableSimulation (the spawn-hold watchdog acts on unsimulated players), forceWalk
    or enableStamina (fn_survival owns them), allowDamage (fall damage is avoided by geometry), or
    AP_holstered / hideWeapon (fn_qhEffect owns the weapon lock).
*/
params [["_kind", "", [""]], ["_data", createHashMap, [createHashMap]], ["_serial", -1, [0]], ["_helper", objNull, [objNull]]];

private _cfg = {_this call AP_fnc_parkourCfg};
private _dbg = missionNamespace getVariable ["AP_parkourDebug", false];
private _unit = player;
private _mine = {(missionNamespace getVariable ["AP_parkourSerial", -1]) isEqualTo _serial};

// Early exits: let go of the helper AP_fnc_parkour attached the player to, then delete it.
private _fnc_dropHelper = {
    if !(isNull _helper) then {
        {detach _x} forEach (attachedObjects _helper);
        deleteVehicle _helper;
    };
};

// ---- the guard: recovers the flags if this script dies without reaching its teardown ---------
if !(isNil "_thisScript") then {[_thisScript, _serial] spawn {
    params ["_mover", "_serial"];
    waitUntil {uiSleep 0.5; scriptDone _mover};
    if (((missionNamespace getVariable ["AP_parkourSerial", -1]) isEqualTo _serial)
        && {!((missionNamespace getVariable ["AP_parkourState", "idle"]) isEqualTo "idle")}) then {
        diag_log format ["[AP-PROBE] parkour guard: mover %1 ended in state %2 without teardown -- recovering", _serial, AP_parkourState];
        private _h = missionNamespace getVariable ["AP_parkourHelper", objNull];
        if (!(isNull _h) && {(attachedTo player) isEqualTo _h}) then {detach player};
        if !(isNull _h) then {deleteVehicle _h};
        AP_parkourHelper = objNull;
        AP_action_in_use = false;
        AP_parkourNext = diag_tickTime + 1;
        AP_parkourState = "idle";
        // owner 2026-09-16 (review round 1): a mover that died on a script error left its last pose. The ladder hang
        // (mantle rise, drop fall, static-mode vault) has no exit without a ladder, so the player stood frozen in it.
        // Reset only that pose, and only when no other flow owns the animation now (downed, cuffed, seated) -- the
        // flags are already handed back above, so an error in the lookups below cannot strand them again.
        private _as = toLower (animationState player);
        if ((alive player) && {isNull (objectParent player)} && {isNull (attachedTo player)}
            && {!(missionNamespace getVariable ["AP_isDowned", false])} && {!(player getVariable ["AP_downed", false])}
            && {!(player getVariable ["AP_restrained", false])} && {!(player getVariable ["AP_civRestrained", false])}
            && {((_as find "ladder") isEqualTo 0)
                || {_as isEqualTo (toLower (["anim", "hang", ["weaponSet"] call AP_fnc_parkourCfg] call AP_fnc_parkourCfg))}}) then {
            player switchMove "";                 // the fn_fastRope.sqf:122 reset
            private _st = ["anim", "stop", ["weaponSet"] call AP_fnc_parkourCfg] call AP_fnc_parkourCfg;
            if !(_st isEqualTo "") then {
                player switchMove _st;
                // AP_fnc_animSync ignores "", so observers are sent the real stand state or they keep the hang.
                private _tg = (allPlayers select {(_x distance player) <= (["broadcastRange"] call AP_fnc_parkourCfg)}) - [player];
                if !(_tg isEqualTo []) then {[[player, _st], "AP_fnc_animSync", _tg, false] spawn AP_fnc_MP};
            };
        };
    };
}};

// Someone reset us between the keypress and this script's first line (the respawn reset already detached and
// deleted AP_parkourHelper; dropping our own copy again is a no-op then).
if !(call _mine) exitWith {call _fnc_dropHelper};
if (!(_kind in ["vault", "mantle", "drop", "wallrun"]) || {!(_data isEqualType createHashMap)}) exitWith {
    diag_log format ["[AP-PROBE] parkour move: bad start kind=%1 -- releasing", _kind];
    call _fnc_dropHelper;
    AP_parkourHelper = objNull;
    AP_action_in_use = false;
    AP_parkourState = "idle";
};

// ---- tunables, read once --------------------------------------------------------------------
private _tick      = ["tick"] call _cfg;
private _dtClamp   = ["dtClamp"] call _cfg;
private _attachZ   = ["attachZ"] call _cfg;
private _hold      = ["animHold"] call _cfg;
private _static    = _hold isEqualTo "static";
private _range     = ["broadcastRange"] call _cfg;
private _lead      = ["sweepLead"] call _cfg;
private _sweepHs   = ["sweepHeights"] call _cfg;
private _headZ     = ["headZ"] call _cfg;
private _riseLen   = ["riseRayLen"] call _cfg;
private _headTop   = ["riseHeadTop"] call _cfg;
private _surfUp    = ["surfaceUp"] call _cfg;
private _surfLen   = ["surfaceLen"] call _cfg;
private _landTo    = ["landTimeout"] call _cfg;
private _landMin   = ["landMinTime"] call _cfg;
private _landAtl   = ["landAtl"] call _cfg;
private _landVz    = ["landVz"] call _cfg;
private _waterFeet = ["waterFeetZ"] call _cfg;
private _waterASL  = ["waterASL"] call _cfg;
private _ignMargin = ["sweepIgnoreMargin"] call _cfg;
private _set       = ["weaponSet"] call _cfg;
private _animOf    = {["anim", _this, _set] call AP_fnc_parkourCfg};
private _aRunOver   = "runOver" call _animOf;
private _aStandOver = "standOver" call _animOf;
private _aHang      = "hang" call _animOf;
private _aSprint    = "sprint" call _animOf;
private _aStop      = "stop" call _animOf;
private _aRun       = "run" call _animOf;

private _f  = _data getOrDefault ["f", [0, 1, 0]];
private _P  = _data getOrDefault ["P", getPosASL _unit];
private _obj = _data getOrDefault ["obj", objNull];
private _dirVec = if (_kind isEqualTo "wallrun") then {_data getOrDefault ["t", _f]} else {_f};
private _right  = [_dirVec select 1, -(_dirVec select 0), 0];

// ---- small functions ------------------------------------------------------------------------
private _fnc_toWorld = {
    params ["_o"];
    ((_P vectorAdd (_right vectorMultiply (_o select 0))) vectorAdd (_dirVec vectorMultiply (_o select 1))) vectorAdd [0, 0, _o select 2]
};

// _fallback: what a machine WITHOUT the state plays instead (a client-mod state, see the wall run). "" = nothing.
private _fnc_mirror = {
    params ["_anim", ["_fallback", ""]];
    if (_anim isEqualTo "") exitWith {};
    private _targets = (allPlayers select {(_x distance _unit) <= _range}) - [_unit];
    if (_targets isEqualTo []) exitWith {};
    [[_unit, _anim, _fallback], "AP_fnc_animSync", _targets, false] spawn AP_fnc_MP;
};

private _fnc_play = {
    params ["_anim", ["_broadcast", true], ["_fallback", ""]];
    if (_anim isEqualTo "") exitWith {};
    _unit switchMove _anim;
    if (_broadcast) then {[_anim, _fallback] call _fnc_mirror};
};

// COMPUTE: the offset a fraction _a of the way from _cur to _to. Pure.
private _fnc_keyOffset = {
    params ["_cur", "_to", "_a"];
    _cur vectorAdd ((_to vectorDiff _cur) vectorMultiply _a)
};

// APPLY: the only line that moves the player along a path.
private _fnc_apply = {
    params ["_off"];
    _unit attachTo [_helper, _off vectorAdd [0, 0, _attachZ]];
};

// "" = carry on; anything else = why the move must end now.
private _fnc_why = {
    switch (true) do {
        case (!(_unit isEqualTo player)): {"unit-swap"};
        case (!(alive _unit)): {"dead"};
        case (AP_isDowned || {_unit getVariable ["AP_downed", false]}): {"downed"};
        case (_unit getVariable ["AP_restrained", false]): {"restrained"};
        case (!(isNull (objectParent _unit))): {"vehicle"};
        case (isNull _helper): {"helper-gone"};
        case (!((attachedTo _unit) isEqualTo _helper)): {"detached"};
        default {""};
    }
};

// true when a GEOM ray from _from to _to hits something other than the player and the helper. A hit on the
// probed obstacle is skipped only when it lies at or below _ignoreBelowZ (ASL); the default ignores nothing.
private _fnc_hit = {
    params ["_from", "_to", ["_ignoreBelowZ", -1e9]];
    private _rows = lineIntersectsSurfaces [_from, _to, _unit, _helper, true, 3, "GEOM", "NONE"];
    (_rows findIf {
        !((!(isNull _obj)) && {((_x select 2) isEqualTo _obj) || {(_x select 3) isEqualTo _obj}} && {((_x select 0) select 2) <= _ignoreBelowZ})
    }) > -1
};

private _fnc_bodySweep = {
    params ["_from", "_to", ["_ignoreBelowZ", -1e9]];
    private _travel = _to vectorDiff _from;
    private _leadVec = if ((vectorMagnitude _travel) > 0.001) then {(vectorNormalized _travel) vectorMultiply _lead} else {_dirVec vectorMultiply _lead};
    private _blocked = false;
    {
        if ([_from vectorAdd [0, 0, _x], (_to vectorAdd _leadVec) vectorAdd [0, 0, _x], _ignoreBelowZ] call _fnc_hit) exitWith {_blocked = true};
    } forEach _sweepHs;
    _blocked
};

private _fnc_inWater = {
    (surfaceIsWater (getPosASL _unit)) && {((getPosASLW _unit) select 2) < _waterFeet}
};

private _fnc_canSnap = {
    (_unit isEqualTo player) && {alive _unit} && {!AP_isDowned} && {!(_unit getVariable ["AP_downed", false])}
    && {!(_unit getVariable ["AP_restrained", false])} && {isNull (objectParent _unit)} && {isNull (attachedTo _unit)}
    && {!(call _fnc_inWater)}
};

private _fnc_waitLand = {
    private _t0 = diag_tickTime;
    waitUntil {
        uiSleep _tick;
        private _el = diag_tickTime - _t0;
        !(alive _unit) || {!(_unit isEqualTo player)} || {_el > _landTo}
        || {(_el >= _landMin) && {(isTouchingGround _unit) || {(((getPosATL _unit) select 2) < _landAtl) && {((velocity _unit) select 2) >= _landVz}}}}
    };
};

private _fnc_state = {
    params ["_st"];
    if (call _mine) then {AP_parkourState = _st};
    if (_dbg) then {diag_log format ["[AP-PROBE] parkour move %1: state=%2 posATL=%3 anim=%4", _serial, _st, (getPosATL _unit) apply {parseNumber (_x toFixed 2)}, animationState _unit]};
};

// ---- start-of-move checks (a tick may have passed since the keypress) -----------------------
// The helper and the attach already exist (AP_fnc_parkour, keypress frame). A null _helper falls through to
// "helper-gone" on the first tick, a soft abort.
private _why = call _fnc_why;
if (_why in ["unit-swap", "dead", "downed", "restrained", "vehicle"]) exitWith {
    // Only a detach off OUR helper: a restrained player may already hang off his escort.
    call _fnc_dropHelper;
    if (call _mine) then {
        AP_parkourHelper = objNull;
        AP_action_in_use = false;
        AP_parkourNext = diag_tickTime + (["cdAbort"] call _cfg);
        AP_parkourState = "idle";
    };
};
if (call _mine) then {AP_parkourHelper = _helper; AP_action_in_use = true};

// ---- build the move -------------------------------------------------------------------------
// row: [offset, duration, anim, sweep ("head" | "body"), surfaceWindow [yMin, yMax] or [], homeOnAbort]
private _keys = [];
private _cooldown = 0;
private _endVel = [0, 0, 0];
private _endAnim = _aStop;
private _snapDelay = 0;
private _ignoreZ = -1e9;                  // sweeps skip obstacle hits at or below this ASL z (see _fnc_hit)
private _wallFwd = 0;                     // wall run: forward push-off speed, decided where the run ended
private _wallOut = 0;                     // wall run: push-off speed away from the wall, decided with it
switch (_kind) do {
    case "vault": {
        private _d = _data get "d";
        private _H = _data get "H";
        private _T = _data get "T";
        _ignoreZ = (_P select 2) + _H + _ignMargin;
        private _zl = _data get "zLandRel";
        private _lift = ["vaultLift"] call _cfg;
        private _inset = ["surfaceInset"] call _cfg;
        private _win = if (_T > (2 * _inset)) then {[_d + _inset, _d + _T - _inset]} else {[]};
        _keys = [
            [[0, _d - (["vaultK1Back"] call _cfg), _H + _lift], ["vaultK1Time"] call _cfg, [_aRunOver, _aHang] select _static, "head", [], true],
            [[0, _d + _T + (["vaultK2Over"] call _cfg), _H + _lift], ["vaultK2Time"] call _cfg, ["", _aStop] select _static, "body", _win, false],
            [[0, _d + _T + (["vaultK3Over"] call _cfg), _zl + (["vaultLandLift"] call _cfg)], ["vaultK3Time"] call _cfg, "", "body", [], false]
        ];
        _cooldown = ["cdVault"] call _cfg;
        _endVel = _f vectorMultiply (["vaultCarry"] call _cfg);
        _endAnim = _aRun;
    };
    case "mantle": {
        private _d = _data get "d";
        private _H = _data get "H";
        _ignoreZ = (_P select 2) + _H + _ignMargin;
        private _lift = ["mantleLift"] call _cfg;
        _keys = [
            [[0, _d - (["mantleK1Back"] call _cfg), _H + _lift], (["mantleRiseBase"] call _cfg) + ((["mantleRisePerM"] call _cfg) * _H), _aHang, "head", [], true],
            [[0, _d + (["mantleK2Fwd"] call _cfg), _H + _lift], ["mantleTopTime"] call _cfg, [_aStandOver, _aStop] select _static, "body", [_d + (["surfaceInset"] call _cfg), 1e9], false]
        ];
        _cooldown = ["cdMantle"] call _cfg;
    };
    case "drop": {
        private _D = _data get "D";
        private _rate = (["dropRate"] call _cfg) max 0.5;
        _ignoreZ = (_P select 2) + _ignMargin;
        // owner 2026-09-16 (review round 1): both keyframes shift forward by how far the measured lip lies past
        // dropEdgeFwd (the probe's "dropShift"), so the body clears the ledge's face wherever the lip is.
        private _shift = _data getOrDefault ["dropShift", 0];
        // K1 steps off the lip; aborting there returns to the ledge rather than dropping the full D.
        _keys = [
            [[0, (["dropK1Fwd"] call _cfg) + _shift, -(["dropK1Down"] call _cfg)], ["dropK1Time"] call _cfg, [_aStandOver, _aStop] select _static, "body", [], true],
            [[0, (["dropK2Fwd"] call _cfg) + _shift, -(_D - (["dropEndAbove"] call _cfg))], _D / _rate, _aHang, "body", [], false]
        ];
        _cooldown = ["cdDrop"] call _cfg;
        _snapDelay = ["dropSnapDelay"] call _cfg;
    };
    case "wallrun": {
        _cooldown = ["cdWallrun"] call _cfg;
    };
};

if (_dbg) then {
    diag_log format ["[AP-PROBE] parkour move %1: start kind=%2 set=%3 hold=%4 P=%5 keys=%6", _serial, _kind, _set, _hold, _P, _keys apply {[_x select 0, _x select 1, _x select 2]}];
};

private _home = false;
private _endReason = "";          // wall run: why the run ended normally (push-off follows)
private _lastWorld = _P;
private _plannedEnd = _P;
private _last = diag_tickTime;

if (_kind isEqualTo "wallrun") then {
    // ================= WALL RUN =================
    private _nAway   = _data get "n";
    private _dWall   = _data get "dWall";
    private _xSign   = _data get "xSign";
    private _holdD   = ["wallHoldDist"] call _cfg;
    private _ease    = (["wallEaseTime"] call _cfg) max 0.01;
    private _runT    = (["wallRunTime"] call _cfg) max 0.1;
    private _v       = (((_data getOrDefault ["speed", 20]) / 3.6) max (["wallSpeedMin"] call _cfg)) min (["wallSpeedMax"] call _cfg);
    private _arc     = ["wallArc"] call _cfg;
    private _chestZ  = ["wallChestZ"] call _cfg;
    private _cLen    = ["wallContactLen"] call _cfg;
    private _corner  = ["wallCornerLen"] call _cfg;
    private _gRay    = ["wallGroundRay"] call _cfg;
    private _maxDrop = ["maxLandingDrop"] call _cfg;
    private _stepUp  = ["wallStepUp"] call _cfg;
    private _stepDn  = ["wallStepDown"] call _cfg;
    private _kneeAbove = ["wallKneeAboveStep"] call _cfg;
    private _feetClear = ["wallFeetClear"] call _cfg;
    private _xTarget = _xSign * (_dWall - _holdD);
    private _animDur = ["animDuration", _aSprint] call _cfg;
    private _t = 0;
    private _gz = _P select 2;            // ASL ground under the last applied position (the take-off feet at first)

    // z here is the arc only; the loop adds the ground offset (_gz - P.z) once the ground ray has found it.
    private _fnc_wallOffset = {
        params ["_time"];
        [_xTarget * ((_time / _ease) min 1), _v * _time, _arc * (sin (180 * _time / _runT))]
    };

    // true when the polyline _pts (world points), raised by _dz, hits something (_fnc_hit rules: nothing ignored).
    private _fnc_hitPath = {
        params ["_pts", "_dz"];
        private _hit = false;
        for "_i" from 1 to ((count _pts) - 1) do {
            if ([(_pts select (_i - 1)) vectorAdd [0, 0, _dz], (_pts select _i) vectorAdd [0, 0, _dz]] call _fnc_hit) exitWith {_hit = true};
        };
        _hit
    };

    // owner 2026-09-16 (review round 1): ground under the column at world xy, searched from _stepUp above the
    // current ground height (a ray started under a slope sees nothing). [] = no usable ground: missing, a fall of
    // more than _stepDn in one step (a lip), more than maxLandingDrop below the take-off feet, or water.
    private _fnc_wallGround = {
        params ["_xy"];
        private _g = lineIntersectsSurfaces [[_xy select 0, _xy select 1, _gz + _stepUp], [_xy select 0, _xy select 1, _gz - _gRay], _unit, _helper, true, 1, "GEOM", "NONE"];
        if (_g isEqualTo []) exitWith {[]};
        private _hit = (_g select 0) select 0;
        if (((_gz - (_hit select 2)) > _stepDn) || {((_P select 2) - (_hit select 2)) > _maxDrop}
            || {(surfaceIsWater _hit) && {(_hit select 2) < _waterASL}}) exitWith {[]};
        _hit
    };

    // owner 2026-09-20: the client mod's wall-run clip (fn_parkourCfg "wallClip"). xSign < 0 = wall on the LEFT = the L
    // rtm. A one-shot: issued once, never re-issued (_animDur 0), and machines without the mod get the sprint instead.
    private _aWall = _aSprint;
    if (["wallClip"] call _cfg) then {
        private _clip = format ["AP_WallRun%1_%2", ["R", "L"] select (_xSign < 0), _set];
        if (isClass (configFile >> "CfgMovesMaleSdr" >> "States" >> _clip)) then {_aWall = _clip; _animDur = 0};
    };
    [_aWall, true, _aSprint] call _fnc_play;
    private _nextAnim = diag_tickTime + _animDur;
    private _deadline = diag_tickTime + _runT + (["moveTimeout"] call _cfg);

    while {true} do {
        uiSleep _tick;
        private _now = diag_tickTime;
        private _dt = ((_now - _last) max 0) min _dtClamp;
        _last = _now;
        _why = call _fnc_why;
        if !(_why isEqualTo "") exitWith {};
        if (_now > _deadline) exitWith {_why = "timeout"};
        // owner 2026-09-16 (review round 1): Esc clears AP_action_in_use mid-move; take it back so H / the action
        // key / restrain cannot fire on the attached player for the rest of the run.
        if (call _mine) then {AP_action_in_use = true};
        _t = _t + _dt;
        if (_t >= _runT) exitWith {_endReason = "time"};

        private _off = [_t] call _fnc_wallOffset;
        // ground first: every ray below, and the applied offset, ride on the ground found here.
        private _gHit = [[_off] call _fnc_toWorld] call _fnc_wallGround;
        if (_gHit isEqualTo []) exitWith {_endReason = "ground"};
        private _gzNew = _gHit select 2;      // becomes _gz only once this tick is applied
        _off set [2, (_off select 2) + (_gzNew - (_P select 2))];
        private _world = [_off] call _fnc_toWorld;

        // contact: the wall must still be there. Length tracks the eased gap so the first ticks do not miss.
        // owner 2026-09-16 (review round 5): at STANDING chest height over this tick's ground, not on the arc. The probe
        // proves the wall only at wallRayHeights (0.9 / 1.6), and on the arc (up to ground + 2.15) the ray passed over a
        // 1.7-2.1 m garden / stone wall and ended the run "contact" ~0.3-0.7 s in.
        private _cFrom = [_world select 0, _world select 1, _gzNew + _chestZ];
        private _gap = (_dWall - (abs (_off select 0))) max 0;
        if ((lineIntersectsSurfaces [_cFrom, _cFrom vectorAdd (_nAway vectorMultiply (-(_gap + (_cLen - _holdD)))), _unit, _helper, true, 1, "GEOM", "NONE"]) isEqualTo []) exitWith {_endReason = "contact"};
        // owner 2026-09-16 (review round 4): THE AHEAD RAYS RIDE THE PLANNED PATH. They used to lead wallCornerLen along t
        // from this tick's point, which during the ease sits back toward the player's own lane, so they swept a band the
        // probe never cast (a planter in the lane, a bin beside the diagonal) and a run it accepted ended on tick 1. The
        // lead is now wallCornerLen further ALONG THE PATH (run time + wallCornerLen / v), with a vertex at the end of the
        // ease when a ray crosses it, so every piece lies on the probe's polyline (P -> ease end -> hold line).
        private _gOff = _gzNew - (_P select 2);
        private _tLead = _t + (_corner / (_v max 0.1));
        private _vOffs = ([[_tLead], [_ease, _tLead]] select (((_t - _dt) < _ease) && {_tLead > _ease})) apply {[_x] call _fnc_wallOffset};
        private _pts = [_lastWorld] + (_vOffs apply {[[_x select 0, _x select 1, _off select 2]] call _fnc_toWorld});   // this tick's height
        // corner: anything ahead along the run (the wall's own building included).
        if ((_sweepHs findIf {[_pts, _x] call _fnc_hitPath}) > -1) exitWith {_endReason = "corner"};
        // owner 2026-09-16 (review round 2): the LOW corner ray (fn_parkourCfg "wallKneeAboveStep"). Ground + wallStepUp +
        // wallKneeAboveStep, never below wallFeetClear over the planned feet: anything standing on the ground that the
        // ground ray (it starts at wallStepUp, inside such an object) and the corner rays (feet + 0.9 and up) both miss.
        // Terrain rows do not count -- the ground ray follows terrain, and a slope is not a corner.
        // owner 2026-09-16 (review r3): wallKneeAboveStep < 0 = this ray is off (tested first, so nothing is cast).
        // owner 2026-09-16 (review r4): each END at its own ground and feet. One height for both put the start (last tick's
        // feet, lower on the rising arc) under the probe's knee ray: 0.37 m above the ground at 20 Hz, 0.29 m at a hitch.
        private _lowHit = false;
        if (_kneeAbove >= 0) then {
            private _kz = _stepUp + _kneeAbove;
            private _lo = [[_lastWorld select 0, _lastWorld select 1, (_gz + _kz) max ((_lastWorld select 2) + _feetClear)]];
            {_lo pushBack [_x select 0, _x select 1, (_gzNew + _kz) max ((_x select 2) + _feetClear)]} forEach (_pts select [1, 3]);
            for "_i" from 1 to ((count _lo) - 1) do {
                if (((lineIntersectsSurfaces [_lo select (_i - 1), _lo select _i, _unit, _helper, true, 3, "GEOM", "NONE"]) findIf {!(isNull (_x select 2))}) > -1) exitWith {_lowHit = true};
            };
        };
        if (_lowHit) exitWith {_endReason = "corner"};
        // head: only while the arc is still rising. owner 2026-09-16 (review round 4): the head top (headZ + riseHeadTop)
        // along the same path pieces, each vertex at ITS OWN point of the arc -- the line the probe casts ("wallrun", head
        // room). It was riseRayLen straight up from this tick's head, above anything the probe tested, so an awning or a
        // balcony over the run started it and ended it ~0.4 s later with a forward push-off under the overhang.
        if ((_t < (_runT / 2)) && {[[_lastWorld] + (_vOffs apply {[[_x select 0, _x select 1, (_x select 2) + _gOff]] call _fnc_toWorld}), _headZ + _headTop] call _fnc_hitPath}) exitWith {_endReason = "head"};

        [_off] call _fnc_apply;
        _lastWorld = _world;
        _gz = _gzNew;

        // P4: in "cycle" mode the sprint is re-issued locally once per cycle (never broadcast per tick).
        if (!_static && {_animDur > 0} && {_now >= _nextAnim}) then {
            [_aSprint, false] call _fnc_play;
            _nextAnim = _now + _animDur;
        };
    };
    _plannedEnd = _lastWorld;
    // owner 2026-09-16 (review round 1): FORWARD PUSH ONLY ONTO GROUND. A run that ended at a corner or at a ground
    // edge pushes off with pushCornerFwd (0): pushFwd along t would throw the player into the corner / over the
    // drop that just ended the run. Any other end first checks the ground pushLandAhead along t.
    // owner 2026-09-16 (review round 4): a "head" end too -- the overhang that ended it is ahead, along t.
    _wallFwd = if (_endReason in ["corner", "ground", "head"]) then {["pushCornerFwd"] call _cfg} else {["pushFwd"] call _cfg};
    private _landAhead = ["pushLandAhead"] call _cfg;
    if ((_wallFwd > 0) && {_landAhead > 0}) then {
        if (([_lastWorld vectorAdd (_dirVec vectorMultiply _landAhead)] call _fnc_wallGround) isEqualTo []) then {
            _wallFwd = ["pushCornerFwd"] call _cfg;
        };
    };
    // owner 2026-09-18 (codex review): THE PUSH-OFF LANDS ON GROUND TOO. The ground rays above ride the run line and look
    // along t only; pushOut then threw the player off the SIDE of a pier / catwalk / roof edge, past maxLandingDrop or
    // into water. Same ground rule (_fnc_wallGround) at the points the push-off's own horizontal velocity reaches after
    // each of pushLandTimes; any of them unusable = no out-push and pushCornerFwd, so the player comes off in the lane
    // under the run, which every tick's ground ray has already passed. [] = no check.
    _wallOut = ["pushOut"] call _cfg;
    private _pushH = (_dirVec vectorMultiply _wallFwd) vectorAdd (_nAway vectorMultiply _wallOut);
    if (((["pushLandTimes"] call _cfg) findIf {([_lastWorld vectorAdd (_pushH vectorMultiply _x)] call _fnc_wallGround) isEqualTo []}) > -1) then {
        _wallOut = 0;
        _wallFwd = ["pushCornerFwd"] call _cfg;
        _endReason = _endReason + "+side";
    };
} else {
    // ================= KEYFRAMED MOVES =================
    private _total = 0;
    {_total = _total + (_x select 1)} forEach _keys;
    private _deadline = diag_tickTime + _total + (["moveTimeout"] call _cfg);
    private _k = 0;
    private _segT = 0;
    private _cur = [0, 0, 0];
    [(_keys select 0) select 2] call _fnc_play;

    while {_k < (count _keys)} do {
        uiSleep _tick;
        private _now = diag_tickTime;
        private _dt = ((_now - _last) max 0) min _dtClamp;
        _last = _now;
        (_keys select _k) params ["_to", "_dur", "_anim", "_sweep", "_win", "_kHome"];
        _home = _kHome;
        _why = call _fnc_why;
        if !(_why isEqualTo "") exitWith {};
        if (_now > _deadline) exitWith {_why = "timeout"};
        if (call _mine) then {AP_action_in_use = true};   // owner 2026-09-16 (review r1): undo an Esc mid-move (see the wall run)

        // ---- compute ----
        _segT = _segT + _dt;
        private _a = if (_dur > 0) then {(_segT / _dur) min 1} else {1};
        private _off = [_cur, _to, _a] call _fnc_keyOffset;
        private _world = [_off] call _fnc_toWorld;

        // ---- sweep (before moving) ----
        private _blocked = if (_sweep isEqualTo "head") then {
            // owner 2026-09-16 (review round 3): the lead runs ALONG the planned head chord (header, SWEEPS), riseLen past
            // this tick's point and never past the keyframe, and the whole chord sits riseHeadTop above headZ. Every ray is
            // then a piece of the segment (feet + headZ + riseHeadTop) -> (K1 head + riseHeadTop) that the probe's "rise"
            // ray casts whole, with this same ignore rule, so a V the probe accepts is not aborted by a band above the
            // chord it never tested (r2's straight-up lead, capped only near the keyframe: porch roof, lintel, awning).
            // The r2 case still holds: nothing here reaches above the K1 head + riseHeadTop, the probe's top overhead ray.
            private _hz = _headZ + _headTop;
            private _aLead = (_a + (_riseLen / ((vectorMagnitude (_to vectorDiff _cur)) max 0.1))) min 1;
            private _hTo = ([[_cur, _to, _aLead] call _fnc_keyOffset] call _fnc_toWorld) vectorAdd [0, 0, _hz];
            [_lastWorld vectorAdd [0, 0, _hz], _hTo, _ignoreZ] call _fnc_hit
        } else {
            [_lastWorld, _world, _ignoreZ] call _fnc_bodySweep
        };
        if (_blocked) exitWith {_why = "blocked"};
        if (!(_win isEqualTo []) && {(_off select 1) >= (_win select 0)} && {(_off select 1) <= (_win select 1)}) then {
            if !([_world vectorAdd [0, 0, _surfUp], _world vectorAdd [0, 0, _surfUp - _surfLen]] call _fnc_hit) then {_why = "surface"};
        };
        if !(_why isEqualTo "") exitWith {};

        // ---- apply ----
        [_off] call _fnc_apply;
        _lastWorld = _world;

        if (_a >= 1) then {
            _cur = _to;
            _k = _k + 1;
            _segT = 0;
            if (_k < (count _keys)) then {
                private _next = (_keys select _k) select 2;
                [_next] call _fnc_play;
                if (_dbg) then {diag_log format ["[AP-PROBE] parkour move %1: keyframe %2 anim=%3 posATL=%4", _serial, _k, _next, (getPosATL _unit) apply {parseNumber (_x toFixed 2)}]};
            };
        };
    };
    _plannedEnd = if (_why isEqualTo "") then {[(_keys select ((count _keys) - 1)) select 0] call _fnc_toWorld} else {_lastWorld};
};

// ================= TEARDOWN (every path above arrives here) =================
private _hard = _why in ["unit-swap", "dead", "downed", "restrained", "vehicle"];
if (_dbg) then {
    private _pos = getPosASL _unit;
    diag_log format ["[AP-PROBE] parkour move %1: end kind=%2 why=%3 endReason=%4 home=%5 posATL=%6 zErr=%7 anim=%8",
        _serial, _kind, _why, _endReason, _home, (getPosATL _unit) apply {parseNumber (_x toFixed 2)},
        ((_pos select 2) - (_plannedEnd select 2)) toFixed 2, animationState _unit];
};

if (_hard) then {
    // Dead / downed / cuffed / seated / respawned: get the body off the helper and step away.
    if (!(isNull _helper) && {(attachedTo _unit) isEqualTo _helper}) then {detach _unit};
    if ((alive _unit) && {_unit isEqualTo player} && {isNull (objectParent _unit)}) then {_unit setVelocity [0, 0, 0]};
    if !(isNull _helper) then {deleteVehicle _helper};
    // Unmeasured: whether a body released mid-air drops. Live lever, default off (see fn_parkourCfg "wakeCorpse").
    if (!(alive _unit) && {isNull (attachedTo _unit)} && {["wakeCorpse"] call _cfg}) then {_unit awake true};
    _cooldown = ["cdAbort"] call _cfg;
} else {
    if (_why isEqualTo "") then {
        if (_kind isEqualTo "wallrun") then {
            // ---- push-off (SPIKE P5 numbers) ----
            ["pushoff"] call _fnc_state;
            private _tv = _data get "t";
            private _nv = _data get "n";
            private _vel = ((_tv vectorMultiply _wallFwd) vectorAdd (_nv vectorMultiply _wallOut)) vectorAdd [0, 0, ["pushUp"] call _cfg];
            detach _unit;
            _unit setVelocity _vel;
            if !(isNull _helper) then {deleteVehicle _helper};
            if (call _mine) then {AP_parkourHelper = objNull};
            call _fnc_waitLand;           // the sprint anim is kept in the air
            ["recover"] call _fnc_state;
            if (call _fnc_canSnap) then {[_aStop] call _fnc_play};
        } else {
            // ---- normal finish of a keyframed move ----
            detach _unit;
            _unit setVelocity _endVel;
            if !(isNull _helper) then {deleteVehicle _helper};
            if (_snapDelay > 0) then {
                ["recover"] call _fnc_state;
                uiSleep _snapDelay;
            };
            if (call _fnc_canSnap) then {[_endAnim] call _fnc_play};
        };
    } else {
        // ---- soft abort: blocked / surface / timeout / helper-gone / detached ----
        _cooldown = ["cdAbort"] call _cfg;
        if (_home && {!(isNull _helper)} && {(attachedTo _unit) isEqualTo _helper}) then {
            [[0, 0, 0]] call _fnc_apply;  // back to where the move began
            uiSleep _tick;
            detach _unit;
            _unit setVelocity [0, 0, 0];
            if !(isNull _helper) then {deleteVehicle _helper};
        } else {
            if (!(isNull _helper) && {(attachedTo _unit) isEqualTo _helper}) then {detach _unit};
            if (isNull (attachedTo _unit)) then {_unit setVelocity [0, 0, 0]};
            if !(isNull _helper) then {deleteVehicle _helper};
            if (call _mine) then {AP_parkourHelper = objNull};
            ["recover"] call _fnc_state;
            call _fnc_waitLand;
        };
        if (_why in ["blocked", "surface"]) then {
            if (_dbg) then {diag_log format ["[AP-PROBE] parkour move %1: aborted (%2) at %3", _serial, _why, getPosATL _unit]};
        };
        if (call _fnc_canSnap) then {[_aStop] call _fnc_play};
    };
};

if (call _mine) then {
    AP_parkourHelper = objNull;
    AP_action_in_use = false;
    AP_parkourNext = diag_tickTime + _cooldown;
    AP_parkourState = "idle";
};
if (_dbg) then {
    diag_log format ["[AP-PROBE] parkour move %1: idle posATL=%2 anim=%3 dmg=%4 touching=%5", _serial, (getPosATL _unit) apply {parseNumber (_x toFixed 2)}, animationState _unit, (damage _unit) toFixed 3, isTouchingGround _unit];
};
