/*
    AP_fnc_hcFly  (Armapunk 2035, 2026-09-02) -- HEADLESS ROTORCRAFT AUTOPILOT.
    Sibling of AP_fnc_hcDrive for helicopters and VTOLs: flies a LOCAL, empty
    aircraft to a destination with AP_fnc_flyStep, one step per rendered frame,
    and lands it. Runs where the aircraft is local (the HC, or the server).

    In:  [_veh, _dest]        Out: true if it started, false if not local / wrong class.
    Sets on the vehicle (public): hc_ap_driving while en route, hc_ap_done at the end:
        "landed" | "hover" | "wrecked" | "timeout" | "lostlocality" | "aborted" | "vanished"
*/
params [["_veh", objNull, [objNull]], ["_dest", [0, 0, 0], [[]]], ["_budget", 300, [0]]];
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
// Probe-only witnesses (the summon self-test sets hc_ap_probe): the kill and a deletion, with their source.
// Damage calls are logged inside AP_fnc_hcShield -- a second HandleDamage handler would override the shield.
if (_veh getVariable ["hc_ap_probe", false]) then {
    private _kEH = _veh addEventHandler ["Killed", {
        params ["_v", "_killer", "_inst"];
        diag_log format ["[HCFLY-PROBE] KILLED by %1 (inst %2) at %3 dmg=%4", typeOf _killer, typeOf _inst, (getPosATL _v) apply { round _x }, damage _v];
    }];
    private _dEH = _veh addEventHandler ["Deleted", { diag_log format ["[HCFLY-PROBE] DELETED at %1", (getPosATL (_this select 0)) apply { round _x }]; }];
    _veh setVariable ["hc_ap_probeEH", [_kEH, _dEH]];
};

[_veh, _budget] spawn {
    params ["_veh", "_budget"];
    private _end = time + _budget;
    private _fno = diag_frameNo - 1;
    private _lastT = time;
    private _reason = "";
    private _probeT = 0;   // [HCFLY-PROBE] cadence when the aircraft carries hc_ap_probe (the summon self-test sets it)
    diag_log format ["HCFLY start: veh=%1 dest=%2 local=%3 bbox=%4 gear=%5", _veh, _veh getVariable ["fly_dest", []], local _veh, ((boundingBoxReal _veh) select [0, 2]) apply { _x apply { round (_x * 100) / 100 } }, _veh animationSourcePhase "gear"];
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
        if ((_veh getVariable ["hc_ap_probe", false]) && {time >= _probeT}) then {
            _probeT = time + 2;
            diag_log format ["[HCFLY-PROBE] phase=%1 alt=%2 engine=%3 ground=%4 vel=%5 posATL=%6 dest2D=%7 dmg=%8 drv=%9",
                _phase, _veh getVariable ["fly_alt", -1], isEngineOn _veh, isTouchingGround _veh,
                (velocity _veh) apply { round (_x * 10) / 10 }, (getPosATL _veh) apply { round (_x * 10) / 10 },
                round (_veh distance2D (_veh getVariable ["fly_dest", [0, 0, 0]])), round ((damage _veh) * 100) / 100, typeOf (driver _veh)];
        };
        if (_phase in ["landed", "aborted"]) exitWith { _reason = _phase; };
        // "hover" is a phase the core keeps flying (it sinks to ~2 m over the destination); the run ends
        // once it is down there -- ending on the first hover frame left the aircraft 94 m up (b0842).
        // Unmanned with the engine on, the helicopter model holds the hover by itself afterwards.
        // "down there" is measured at the BELLY: the height is the hull centre's, and a Blackfish's belly hangs
        // ~6 m under it (b0863: hovered correctly at 8 m centre height and never "finished")
        private _belly = ((-(((boundingBoxReal _veh) select 0) select 2)) max 0) min 10;
        if (_phase isEqualTo "hover" && {(((getPosASL _veh) select 2) - (getTerrainHeightASL (getPosASL _veh)) - _belly) < 3.5}) exitWith { _reason = "hover"; };
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
    diag_log format ["HCFLY end: veh=%1 reason=%2 local=%3 alive=%4 z=%5 ground=%6 gear=%7 dmg=%8 hits=%9", _veh, _reason, (!isNull _veh && {local _veh}), alive _veh,
        (if (isNull _veh) then { -1 } else { round (((getPosATL _veh) select 2) * 10) / 10 }), (!isNull _veh && {isTouchingGround _veh}),
        (if (isNull _veh) then { -1 } else { _veh animationSourcePhase "gear" }), (if (isNull _veh) then { -1 } else { round ((damage _veh) * 100) / 100 }),
        (if (isNull _veh) then { [] } else { private _h = getAllHitPointsDamage _veh; private _o = []; { if (_x > 0.05) then { _o pushBack [(_h select 0) select _forEachIndex, round (_x * 100) / 100]; }; } forEach (_h select 2); _o })];
    if (!isNull _veh) then {
        private _eh = _veh getVariable ["hc_ap_dmgEH", -1];
        if (_eh >= 0) then { _veh removeEventHandler ["HandleDamage", _eh]; _veh setVariable ["hc_ap_dmgEH", nil]; };
        (_veh getVariable ["hc_ap_probeEH", []]) params [["_kEH", -1], ["_dEH", -1]];
        if (_kEH >= 0) then { _veh removeEventHandler ["Killed", _kEH]; };
        if (_dEH >= 0) then { _veh removeEventHandler ["Deleted", _dEH]; };
        _veh setVariable ["hc_ap_probeEH", nil];
        _veh setVariable ["fly_altCap", nil];
        _veh setVariable ["fly_forceKinematic", nil];
        if (local _veh && {alive _veh} && {_reason isNotEqualTo "hover"}) then { _veh setVelocity [0, 0, 0]; };
        _veh setVariable ["hc_ap_driving", false, true];
        _veh setVariable ["hc_ap_want", false, true];
        _veh setVariable ["hc_ap_done", _reason, true];
    };
};
true
