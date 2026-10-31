// DEV INSTRUMENTATION -- parkour spikes (owner 2026-09-16, plan "Feature A" > SPIKE P1-P6 and Verification).
// Not referenced by anything; run it from the debug console on the dev server, one mode at a time. Paste ONLY the
// text after the leading // of a command line below (from [ to the semicolon); the description is the line above it.
//
// Verification sampler: arms for N seconds, logs every move at 20 Hz
//     ["trace", 120] execVM "debug\probe_parkour.sqf";
// SPIKE P1: stand facing a fence / wall, GEOM vs FIRE vs VIEW
//     ["fence"] execVM "debug\probe_parkour.sqf";
// SPIKE P3/P4: attached rise 2 m + forward 1 m in 0.8 s, two anims
//     ["glide"] execVM "debug\probe_parkour.sqf";
// SPIKE P5: lift N m on a helper, detach with the push-off velocity
//     ["pushoff", 1.2] execVM "debug\probe_parkour.sqf";
// V latch: log every V KeyDown / KeyUp for N seconds (tap V, hold V 3 s, double-tap V)
//     ["keys", 20] execVM "debug\probe_parkour.sqf";
//
// Everything lands in the client RPT tagged [AP-PROBE] parkour-spike (the Proton path in CLAUDE.md), with a short
// systemChat summary. The command lines carry nothing after the semicolon, so they survive the console's one-line
// flatten (owner 2026-09-16, review round 1: they used to have the description trailing on the same line).
//
// What each mode is for, and how to read it:
//   trace   sets AP_parkourDebug (restored when the window closes), so AP_fnc_parkourProbe prints one line per V press
//           and AP_fnc_parkourMove prints its keyframes, end reason and zErr (actual minus planned z at teardown).
//           This sampler adds, while AP_parkourState is not idle and for 1.5 s after: t state posATL vel anim touching
//           attached dmg, plus one line per state change. A bad move shows as a state that never returns to idle, a
//           dmg delta, a prone anim ("ppne") after recover, or |zErr| > 0.15.
//   fence   answers "does this obstacle have a GEOM face, or only FIRE/VIEW?" -- every row of every forward ray per
//           LOD, the top ray at two insets (thin fences fall behind a 0.15 m inset), the thickness ray, and then
//           AP_fnc_parkourProbe's verdict with faceLods forced to GEOM, FIRE and the shipped GEOM+FIRE in turn. Record
//           the class name and the verdicts; AP_parkourCfg_faceLods / AP_parkourCfg_topInset are the levers.
//   glide   the attached offset walk the mover uses, twice: ladder-static, then the running step-over. It logs
//           animationState and getUnitMovesInfo's move progress every tick. P4 question: does the step-over's
//           progress keep advancing / wrapping while attached (it cycles), or freeze? P3 question needs a SECOND
//           CLIENT standing ~10 m away: smooth motion, or visible 20 Hz steps? Compare with a fast-rope descent.
//           Stand in the open: this mode does not sweep for walls, it only refuses when something is right there.
//   pushoff the wall-run exit in the open: lift, sprint anim, detach, setVelocity with the CURRENT cfg push numbers
//           (AP_parkourCfg_pushFwd/Out/Up -- set them first to try another arc). Samples until 2 s after landing.
//           P5 question: damage delta and whether the stance went prone. There is deliberately NO stance snap here.
//   keys    owner 2026-09-16 (review round 2): the per-press latch (fn_parkour.sqf, "ONE MOVE PER PHYSICAL PRESS")
//           ends a press on a V KeyUp, which nobody has watched under Proton. Adds a V KeyDown + KeyUp logger to
//           display 46 for N seconds (removed after), one line per event: dtPrev since the previous V event,
//           inputAction "GetOver", and the latch as it was BEFORE the mission's handler saw that KeyDown (display
//           EHs run last-added first). Read the HOLD: one "up" at the release = detectable autorepeat, the latch
//           works as built. An up+down pair per repeat with the up->down dtPrev under latchRepeatGap (0.05) = X11
//           style, still handled. Pairs further apart than that: raise AP_parkourCfg_latchRepeatGap. The second
//           "down" of the hold is the OS repeat delay; above latchStaleTime (1.2) raise AP_parkourCfg_latchStaleTime.
//
// glide and pushoff take the parkour mutex (AP_parkourState = "probe", AP_action_in_use = true) so V, the action
// key and the drag action stay out while they run, publish the helper in AP_parkourHelper so the respawn reset can
// delete it, and always hand both flags back and delete the helper on the way out -- including when the player
// dies mid-probe. owner 2026-09-16 (review round 1): death is detected on the unit captured at the start (_u), not
// with `alive player`: after the first death of a session respawnDelay=0 makes `player` the new, alive unit before
// the next 0.05 s check, so a lethal pushoff used to be sampled and summarised on the respawned body (ddmg 0, prone).
// On a death: no pass 2, no stand-up anim, the summary says died=true with ddmg from the corpse, and the flags are
// handed back only if the state is still "probe" (the respawn reset may already have done it).
if (!hasInterface) exitWith {};
params [["_mode", "trace", [""]], ["_arg", -1, [0]]];

private _tag = "[AP-PROBE] parkour-spike";
private _cfg = {_this call AP_fnc_parkourCfg};
private _r2 = {_this apply {parseNumber (_x toFixed 2)}};

private _fnc_mirror = {
    params ["_anim"];
    if (_anim isEqualTo "") exitWith {};
    private _targets = (allPlayers select {(_x distance player) <= (["broadcastRange"] call _cfg)}) - [player];
    if (_targets isEqualTo []) exitWith {};
    [[player, _anim], "AP_fnc_animSync", _targets, false] spawn AP_fnc_MP;
};

// Mutex modes refuse unless nothing else owns the player.
private _fnc_canTakeMutex = {
    if !(alive player) exitWith {systemChat "probe_parkour: dead"; false};
    if !(isNull (objectParent player)) exitWith {systemChat "probe_parkour: get out of the vehicle"; false};
    if !(isNull (attachedTo player)) exitWith {systemChat "probe_parkour: you are attached to something"; false};
    if !((missionNamespace getVariable ["AP_parkourState", "idle"]) isEqualTo "idle") exitWith {systemChat "probe_parkour: a parkour move is running"; false};
    if (missionNamespace getVariable ["AP_action_in_use", false]) exitWith {systemChat "probe_parkour: AP_action_in_use is set"; false};
    if !(isNull (missionNamespace getVariable ["AP_dragging", objNull])) exitWith {systemChat "probe_parkour: release the body first"; false};
    true
};

// true when the space the probe will move through (up and ahead) is clear.
private _fnc_openSpace = {
    params ["_up", "_ahead", "_f"];
    private _P = getPosASL player;
    private _clear = (lineIntersectsSurfaces [_P vectorAdd [0, 0, 1.8], _P vectorAdd [0, 0, 1.8 + _up], player, objNull, true, 1, "GEOM", "NONE"]) isEqualTo [];
    {
        if !((lineIntersectsSurfaces [_P vectorAdd [0, 0, _x], (_P vectorAdd [0, 0, _x]) vectorAdd (_f vectorMultiply _ahead), player, objNull, true, 1, "GEOM", "NONE"]) isEqualTo []) exitWith {_clear = false};
    } forEach [0.9, 1.6, 2.6, 3.6];
    _clear
};

private _fnc_makeHelper = {
    params ["_f"];
    private _P = getPosASL player;
    private _h = createVehicle ["Land_ClutterCutter_small_F", getPosATL player, [], 0, "CAN_COLLIDE"];
    _h setVectorDirAndUp [_f, [0, 0, 1]];
    _h setPosASL _P;
    AP_parkourHelper = _h;
    _h
};

// The unit a mutex mode started on; "gone" = dead or no longer the player (respawned).
private _u = player;
private _fnc_gone = {!(alive _u) || {!(_u isEqualTo player)}};

private _fnc_release = {
    params ["_h"];
    if !(isNull _h) then {{detach _x} forEach (attachedObjects _h)};
    if (!(call _fnc_gone) && {isNull (attachedTo _u)}) then {_u setVelocity [0, 0, 0]};
    if !(isNull _h) then {deleteVehicle _h};
    AP_parkourHelper = objNull;
};

private _fnc_handBack = {
    private _h = missionNamespace getVariable ["AP_parkourHelper", objNull];
    if !(isNull _h) then {[_h] call _fnc_release};
    if ((missionNamespace getVariable ["AP_parkourState", "idle"]) isEqualTo "probe") then {
        AP_action_in_use = false;
        AP_parkourState = "idle";
    };
};

switch (_mode) do {
    // =====================================================================================================
    case "trace": {
        private _secs = if (_arg > 0) then {_arg} else {120};
        private _prevDbg = missionNamespace getVariable ["AP_parkourDebug", false];
        AP_parkourDebug = true;
        diag_log format ["%1 trace armed for %2 s", _tag, _secs];
        systemChat format ["probe_parkour: trace armed for %1 s (AP_parkourDebug on)", _secs];
        private _end = diag_tickTime + _secs;
        private _lastState = "idle";
        private _activeUntil = -1;
        private _moveT0 = diag_tickTime;
        private _dmg0 = damage player;
        while {diag_tickTime < _end} do {
            private _st = missionNamespace getVariable ["AP_parkourState", "idle"];
            if !(_st isEqualTo _lastState) then {
                if (_lastState isEqualTo "idle") then {_moveT0 = diag_tickTime; _dmg0 = damage player};
                diag_log format ["%1 state %2 -> %3 t=%4 posATL=%5 anim=%6", _tag, _lastState, _st, (diag_tickTime - _moveT0) toFixed 2, (getPosATL player) call _r2, animationState player];
                _lastState = _st;
            };
            if !(_st isEqualTo "idle") then {_activeUntil = diag_tickTime + 1.5};
            if (diag_tickTime <= _activeUntil) then {
                diag_log format ["%1 t=%2 state=%3 posATL=%4 vel=%5 anim=%6 touching=%7 attached=%8 dmg=%9 ddmg=%10",
                    _tag, (diag_tickTime - _moveT0) toFixed 2, _st, (getPosATL player) call _r2, (velocity player) call _r2,
                    animationState player, isTouchingGround player, attachedTo player, (damage player) toFixed 3, ((damage player) - _dmg0) toFixed 3];
            };
            uiSleep 0.05;
        };
        AP_parkourDebug = _prevDbg;
        diag_log format ["%1 trace closed (AP_parkourDebug back to %2)", _tag, _prevDbg];
        systemChat "probe_parkour: trace closed";
    };

    // =====================================================================================================
    case "fence": {
        private _P = getPosASL player;
        private _dir = getDir player;
        private _f = [sin _dir, cos _dir, 0];
        private _heights = ["rayHeights"] call _cfg;
        private _reach = ["reachFwd"] call _cfg;
        private _cur = cursorObject;
        diag_log format ["%1 fence: cursorObject=%2 (%3) dist=%4 posASL=%5 dir=%6", _tag, _cur, (if (isNull _cur) then {""} else {typeOf _cur}), (if (isNull _cur) then {-1} else {(player distance _cur) toFixed 2}), _P call _r2, _dir toFixed 1];
        private _summary = [];
        {
            private _lod = _x;
            private _face = [];
            {
                private _from = _P vectorAdd [0, 0, _x];
                private _rows = lineIntersectsSurfaces [_from, _from vectorAdd (_f vectorMultiply _reach), player, objNull, true, 3, _lod, "NONE"];
                if (_rows isEqualTo []) then {
                    diag_log format ["%1 fence %2 h=%3: no hit", _tag, _lod, _x];
                } else {
                    private _h = _x;
                    {
                        private _o = _x select 2;
                        private _par = _x select 3;
                        private _n = _x select 1;
                        private _d = ((_x select 0) vectorDiff _from) vectorDotProduct _f;
                        private _isFace = !(isNull _o) && {(abs (_n select 2)) < (["faceMaxNz"] call _cfg)} && {(_n vectorDotProduct _f) < (["faceFacing"] call _cfg)};
                        diag_log format ["%1 fence %2 h=%3 row%4: obj=%5 (%6) parent=%7 d=%8 n=%9 face=%10",
                            _tag, _lod, _h, _forEachIndex, _o, (if (isNull _o) then {"terrain"} else {typeOf _o}),
                            (if (isNull _par) then {""} else {typeOf _par}), _d toFixed 2, _n call _r2, _isFace];
                        if (_forEachIndex isEqualTo 0 && {_isFace} && {(_face isEqualTo []) || {_d < (_face select 0)}}) then {_face = [_d, _x select 0, _o]};
                    } forEach _rows;
                };
            } forEach _heights;
            if (_face isEqualTo []) then {
                _summary pushBack format ["%1: no face", _lod];
            } else {
                private _fp = _face select 1;
                {
                    private _txy = _fp vectorAdd (_f vectorMultiply _x);
                    private _top = lineIntersectsSurfaces [[_txy select 0, _txy select 1, (_P select 2) + (["topRayUp"] call _cfg)], [_txy select 0, _txy select 1, (_P select 2) + (["topRayDown"] call _cfg)], player, objNull, true, 1, _lod, "NONE"];
                    diag_log format ["%1 fence %2 top inset=%3: %4", _tag, _lod, _x,
                        (if (_top isEqualTo []) then {"no hit"} else {format ["H=%1 nz=%2 obj=%3", ((((_top select 0) select 0) select 2) - (_P select 2)) toFixed 2, (((_top select 0) select 1) select 2) toFixed 2, typeOf ((_top select 0) select 2)]})];
                } forEach [0.15, 0.05];
                private _thFrom = _fp vectorAdd (_f vectorMultiply (["thickReach"] call _cfg));
                private _th = lineIntersectsSurfaces [_thFrom, _fp, player, objNull, true, 3, _lod, "NONE"];
                diag_log format ["%1 fence %2 thickness rows: %3", _tag, _lod, _th apply {[typeOf (_x select 2), (((_x select 0) vectorDiff _fp) vectorDotProduct _f) toFixed 2]}];
                _summary pushBack format ["%1: face d=%2 %3", _lod, (_face select 0) toFixed 2, typeOf (_face select 2)];
            };
        } forEach ["GEOM", "FIRE", "VIEW"];

        // The real classifier under each LOD list. The override is restored exactly (nil if it was unset).
        private _prevLods = missionNamespace getVariable "AP_parkourCfg_faceLods";
        private _prevDbg = missionNamespace getVariable ["AP_parkourDebug", false];
        AP_parkourDebug = true;
        {
            missionNamespace setVariable ["AP_parkourCfg_faceLods", _x];
            private _res = [] call AP_fnc_parkourProbe;
            private _d = _res select 1;
            private _line = format ["probe %1 -> %2 (%3) H=%4 T=%5 d=%6", _x, _res select 0, _d getOrDefault ["why", ""], (_d getOrDefault ["H", -1]) toFixed 2, (_d getOrDefault ["T", -1]) toFixed 2, (_d getOrDefault ["d", -1]) toFixed 2];
            diag_log format ["%1 fence %2", _tag, _line];
            _summary pushBack _line;
        } forEach [["GEOM"], ["FIRE"], ["GEOM", "FIRE"]];
        // owner 2026-09-16 (review round 1): debug flag first, and never read _prevLods while it is nil -- in this
        // scheduled script that threw "Undefined variable" and aborted before AP_parkourDebug was restored.
        AP_parkourDebug = _prevDbg;
        if (isNil "_prevLods") then {
            missionNamespace setVariable ["AP_parkourCfg_faceLods", nil];
        } else {
            missionNamespace setVariable ["AP_parkourCfg_faceLods", _prevLods];
        };
        {systemChat _x} forEach _summary;
    };

    // =====================================================================================================
    case "glide": {
        if !(call _fnc_canTakeMutex) exitWith {};
        private _dir = getDir player;
        private _f = [sin _dir, cos _dir, 0];
        if !([2.6, 1.6, _f] call _fnc_openSpace) exitWith {systemChat "probe_parkour: glide needs 2.6 m overhead and 1.6 m ahead clear -- move into the open"};
        AP_parkourState = "probe";
        AP_action_in_use = true;
        private _set = ["weaponSet"] call _cfg;
        private _attachZ = ["attachZ"] call _cfg;
        private _passes = [["hang", ["anim", "hang", _set] call _cfg], ["runOver", ["anim", "runOver", _set] call _cfg]];
        diag_log format ["%1 glide start set=%2 passes=%3 attachZ=%4", _tag, _set, _passes, _attachZ];
        private _died = false;
        {
            _x params ["_label", "_anim"];
            if (call _fnc_gone) exitWith {_died = true};
            private _h = [[sin (getDir _u), cos (getDir _u), 0]] call _fnc_makeHelper;
            _u setVelocity [0, 0, 0];
            _u attachTo [_h, [0, 0, _attachZ]];
            _u setDir 0;
            _u switchMove _anim;
            [_anim] call _fnc_mirror;
            // [target offset, seconds]: rise 2 m + forward 1 m in 0.8 s, hold 0.5 s, come down 0.6 s
            private _segs = [[[0, 1, 2], 0.8], [[0, 1, 2], 0.5], [[0, 1, 0], 0.6]];
            private _cur = [0, 0, 0];
            private _t0 = diag_tickTime;
            private _last = diag_tickTime;
            private _dead = false;
            {
                _x params ["_to", "_dur"];
                private _segIdx = _forEachIndex;
                private _segT = 0;
                while {_segT < _dur} do {
                    uiSleep 0.05;
                    if (call _fnc_gone) exitWith {_dead = true};
                    private _dt = ((diag_tickTime - _last) max 0) min 0.1;
                    _last = diag_tickTime;
                    _segT = _segT + _dt;
                    private _off = _cur vectorAdd ((_to vectorDiff _cur) vectorMultiply ((_segT / _dur) min 1));
                    _u attachTo [_h, _off vectorAdd [0, 0, _attachZ]];
                    private _mi = getUnitMovesInfo _u;
                    diag_log format ["%1 glide %2 seg=%3 t=%4 off=%5 posATL=%6 anim=%7 moveProgress=%8 moveTime=%9 moveDur=%10",
                        _tag, _label, _segIdx, (diag_tickTime - _t0) toFixed 2, _off call _r2, (getPosATL _u) call _r2,
                        animationState _u, (_mi param [0, -1]) toFixed 3, (_mi param [1, -1]) toFixed 3, (_mi param [2, -1]) toFixed 3];
                };
                if (_dead) exitWith {};
                _cur = _to;
            } forEach _segs;
            [_h] call _fnc_release;
            if !(call _fnc_gone) then {
                private _stop = ["anim", "stop", _set] call _cfg;
                _u switchMove _stop;
                [_stop] call _fnc_mirror;
            };
            diag_log format ["%1 glide %2 done dead=%3 posATL=%4 anim=%5 touching=%6", _tag, _label, _dead, (getPosATL _u) call _r2, animationState _u, isTouchingGround _u];
            if (_dead) exitWith {_died = true};
            uiSleep 2;
        } forEach _passes;
        call _fnc_handBack;
        systemChat format ["probe_parkour: glide done%1 -- read [AP-PROBE] parkour-spike glide in the RPT", ["", " (DIED mid-probe, pass 2 skipped)"] select _died];
    };

    // =====================================================================================================
    case "pushoff": {
        if !(call _fnc_canTakeMutex) exitWith {};
        private _lift = if (_arg > 0) then {_arg} else {1.2};
        private _dir = getDir player;
        private _f = [sin _dir, cos _dir, 0];
        private _left = [-(_f select 1), _f select 0, 0];     // stands in for the wall normal: pushed to the left
        if (!([_lift + 1.5, 4, _f] call _fnc_openSpace) || {!([_lift + 1.5, 3, _left] call _fnc_openSpace)}) exitWith {
            systemChat "probe_parkour: pushoff needs open space above, ahead and to your left -- move into the open";
        };
        AP_parkourState = "probe";
        AP_action_in_use = true;
        private _set = ["weaponSet"] call _cfg;
        private _attachZ = ["attachZ"] call _cfg;
        private _sprint = ["anim", "sprint", _set] call _cfg;
        private _vel = ((_f vectorMultiply (["pushFwd"] call _cfg)) vectorAdd (_left vectorMultiply (["pushOut"] call _cfg))) vectorAdd [0, 0, ["pushUp"] call _cfg];
        private _dmg0 = damage _u;
        private _h = [_f] call _fnc_makeHelper;
        _u setVelocity [0, 0, 0];
        _u attachTo [_h, [0, 0, _attachZ]];
        _u setDir 0;
        _u switchMove _sprint;
        [_sprint] call _fnc_mirror;
        private _last = diag_tickTime;
        private _segT = 0;
        private _dead = false;
        while {_segT < 0.4} do {
            uiSleep 0.05;
            if (call _fnc_gone) exitWith {_dead = true};
            private _dt = ((diag_tickTime - _last) max 0) min 0.1;
            _last = diag_tickTime;
            _segT = _segT + _dt;
            _u attachTo [_h, [0, 0, (_lift * ((_segT / 0.4) min 1)) + _attachZ]];
        };
        diag_log format ["%1 pushoff lift=%2 vel=%3 set=%4 dmg0=%5 posATL=%6 anim=%7", _tag, _lift, _vel call _r2, _set, _dmg0 toFixed 3, (getPosATL _u) call _r2, animationState _u];
        if !(isNull _h) then {{detach _x} forEach (attachedObjects _h)};
        if (!_dead && {!(call _fnc_gone)}) then {_u setVelocity _vel};
        if !(isNull _h) then {deleteVehicle _h};
        AP_parkourHelper = objNull;

        private _t0 = diag_tickTime;
        private _landT = -1;
        private _maxAtl = 0;
        private _sawProne = false;
        private _sawHalo = false;
        while {!_dead && {(diag_tickTime - _t0) < 6} && {(_landT < 0) || {(diag_tickTime - _landT) < 2}}} do {
            uiSleep 0.05;
            if (call _fnc_gone) exitWith {_dead = true};
            private _t = diag_tickTime - _t0;
            private _atl = (getPosATL _u) select 2;
            private _anim = toLower (animationState _u);
            _maxAtl = _maxAtl max _atl;
            if ("ppne" in _anim) then {_sawProne = true};
            if ("halofreefall" in _anim) then {_sawHalo = true};
            if ((_landT < 0) && {_t >= 0.2} && {isTouchingGround _u}) then {
                _landT = diag_tickTime;
                diag_log format ["%1 pushoff LANDED t=%2 dmg=%3 anim=%4", _tag, _t toFixed 2, (damage _u) toFixed 3, animationState _u];
            };
            diag_log format ["%1 pushoff t=%2 posATL=%3 vel=%4 anim=%5 touching=%6 dmg=%7",
                _tag, _t toFixed 2, (getPosATL _u) call _r2, (velocity _u) call _r2, animationState _u, isTouchingGround _u, (damage _u) toFixed 3];
        };
        // _u is still the original unit after a death, so ddmg reads the corpse (1.0), not the respawned body.
        private _line = format ["pushoff done: died=%7 ddmg=%1 peakATL=%2 landed=%3 prone=%4 halofreefall=%5 finalAnim=%6",
            ((damage _u) - _dmg0) toFixed 3, _maxAtl toFixed 2, _landT > 0, _sawProne, _sawHalo, animationState _u, _dead];
        diag_log format ["%1 %2", _tag, _line];
        systemChat ("probe_parkour: " + _line);
        call _fnc_handBack;
    };

    // =====================================================================================================
    case "keys": {
        disableSerialization;
        private _secs = if (_arg > 0) then {_arg} else {20};
        private _d46 = findDisplay 46;
        if (isNull _d46) exitWith {systemChat "probe_parkour: display 46 not found"};
        AP_parkourKeyLog = [];
        private _ehDown = _d46 displayAddEventHandler ["KeyDown", {
            if (!(isNil "AP_parkourKeyLog") && {(_this select 1) in (actionKeys "GetOver")}) then {
                AP_parkourKeyLog pushBack ["down", diag_tickTime, inputAction "GetOver", missionNamespace getVariable ["AP_parkourLatch", false]];
            };
            false
        }];
        private _ehUp = _d46 displayAddEventHandler ["KeyUp", {
            if (!(isNil "AP_parkourKeyLog") && {(_this select 1) in (actionKeys "GetOver")}) then {
                AP_parkourKeyLog pushBack ["up", diag_tickTime, inputAction "GetOver", missionNamespace getVariable ["AP_parkourLatch", false]];
            };
            false
        }];
        diag_log format ["%1 keys armed for %2 s (latchRepeatGap=%3 latchStaleTime=%4 GetOver keys=%5)", _tag, _secs, ["latchRepeatGap"] call _cfg, ["latchStaleTime"] call _cfg, actionKeys "GetOver"];
        systemChat format ["probe_parkour: keys armed for %1 s -- tap V, hold V 3 s, double-tap V", _secs];
        uiSleep _secs;
        _d46 displayRemoveEventHandler ["KeyDown", _ehDown];
        _d46 displayRemoveEventHandler ["KeyUp", _ehUp];
        private _log = +AP_parkourKeyLog;
        AP_parkourKeyLog = nil;
        private _prevT = -1;
        private _downs = 0;
        private _ups = 0;
        private _run = 0;
        private _maxRun = 0;
        private _pairGap = 1e9;           // shortest up -> next down gap (a per-repeat KeyUp shows up here near 0)
        private _prevType = "";
        {
            _x params ["_type", "_t", "_ia", "_latch"];
            private _dt = if (_prevT < 0) then {-1} else {_t - _prevT};
            diag_log format ["%1 keys %2 t=%3 dtPrev=%4 inputAction=%5 latchBefore=%6", _tag, _type, _t toFixed 3, _dt toFixed 3, _ia toFixed 2, _latch];
            if (_type isEqualTo "down") then {
                _downs = _downs + 1;
                _run = _run + 1;
                _maxRun = _maxRun max _run;
                if (_prevType isEqualTo "up") then {_pairGap = _pairGap min _dt};
            } else {
                _ups = _ups + 1;
                _run = 0;
            };
            _prevT = _t;
            _prevType = _type;
        } forEach _log;
        private _line = format ["keys done: downs=%1 ups=%2 longestDownRun=%3 shortestUpToDown=%4", _downs, _ups, _maxRun, (if (_pairGap > 1e8) then {"-"} else {_pairGap toFixed 3})];
        diag_log format ["%1 %2", _tag, _line];
        systemChat ("probe_parkour: " + _line);
    };

    default {systemChat format ["probe_parkour: unknown mode %1 (trace | fence | glide | pushoff | keys)", _mode]};
};
