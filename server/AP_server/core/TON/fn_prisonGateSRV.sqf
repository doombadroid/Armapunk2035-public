/*
    APS_fnc_prisonGateSRV -- the Malden prison's sally-port gates, the escape window's physical half, and
    the cop disarm latch.

    Modes:
      ["boot"]      server-internal. Seal the OUTER gate, clear the disarm latch.
      ["gatehack"]  civ, from AP_fnc_prisonGate after a successful Sequence Breach. Validates the caller,
                    hands the event to APS_fnc_handlePrisonBreak mode 1, opens both gates if it took.
      ["disarm"]    cop, from AP_fnc_stopPrisonBreak's hold. Validates the caller, sets the latch,
                    re-locks the OUTER gate.
      ["relock"]    server-internal. Re-locks the OUTER gate (reset paths).

    WHICH GATE IS SEALED, AND WHY ONLY ONE. fn_maldenJewelSRV.sqf:43-50 writes the rule down: a gate sealed
    with no reachable opener is welded for the life of the server, because sealing runs at boot AND at every
    window close while ["open"] is the only release. So only the OUTER gate is ever sealed. The INNER gate
    is never locked, so cops can always walk prisoners in even with the hack on cooldown, refused by the
    cop-count gate, or blocked by another federal event. The Fed leaves two pedestrian gates unsealed for
    exactly this reason (fn_maldenFedSRV.sqf:279-290).

    THE CALLER IS DERIVED FROM remoteExecutedOwner, NEVER FROM THE PAYLOAD. The payload is precisely what a
    forged call would use to name an innocent player in a -SEC- row.

    The animation set of both gate classes was read off the running server rather than assumed:
    Land_ConcreteWall_01_l_gate_F has doors=1 and anims ["door_1_move","door_1_locked_move"], so the
    "locked" filter below is load-bearing -- driving door_1_locked_move would fight the lock it represents.
*/
params [["_mode", "", [""]]];

// --- gate primitives, the shape fn_maldenJewelSRV.sqf:110-131 uses ------------------------------------
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

// Phase 0 = shut and locked (doors DISABLED), phase 1 = open and free (doors ENABLED). The disable flag is
// the INVERSE of the phase and that is the only asymmetry. The ORDER is the bank's and it is load-bearing:
// write bis_disabled_Door_N FIRST so no fresh hand-open can begin while the rest runs, THEN drive the
// animations and their sources, which is what un-does an open a player performed by hand earlier.
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

// --- caller validation, the shape fn_maldenFedSRV.sqf:189-205 uses ------------------------------------
// _side is a parameter because one validator serves both the civ mode and the cop mode.
private _fnc_caller = {
    params ["_anchor", "_maxDist", "_side"];
    private _src = remoteExecutedOwner;
    if (_src isEqualTo 0) exitWith { [true, objNull] };               // server-internal: no check, no caller
    private _c = (allPlayers select { owner _x isEqualTo _src }) param [0, objNull];
    if (isNull _c
        || {!alive _c}
        // The west branch goes through APS_fnc_isDutyCop instead of the bare side test: the "disarm" mode
        // is a MaxSec authority action and side west alone is satisfiable by joining the published duty
        // group. The civilian branch (the "hack" mode) keeps the literal test -- civilian is not a
        // credential, it is the absence of one, and there is no roster of civilians to consult.
        || {if (_side isEqualTo west) then { !(_c call APS_fnc_isDutyCop) } else { side _c isNotEqualTo _side }}
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
        // 8 m is the looser OUTER bound on purpose: AP_fnc_prisonGate refuses at 6 m and the scroll
        // action offers at 6 m, so a player who can see the option can never be refused for the reason it
        // was offered, and this stays the backstop rather than the UX bound.
        ([_gIn, 8, civilian] call _fnc_caller) params ["_ok", "_c"];
        if (!_ok) exitWith {};

        // Every gate on the EVENT stays in APS_fnc_handlePrisonBreak mode 1, which owns the active check,
        // the fed-event exclusivity, the tenured-cop requirement, the 30-minute re-run cooldown and the
        // 15-minute cross-heist lockout -- and refuses ABOVE its own SRV_prisonData stamp, so a refusal
        // leaves no state and no open gate.
        if (SRV_prisonData param [1, false]) exitWith {
            [[2, "There is already a prison break in progress!"], "AP_fnc_broadcast", _c, false, false] spawn AP_fnc_MP;
        };

        AP_prisonDisarmed = false;
        publicVariable "AP_prisonDisarmed";

        [1, _c, getPlayerUID _c, group _c] call APS_fnc_handlePrisonBreak;

        // Open both gates ONLY if the event actually started. handlePrisonBreak stamps slot 1 below all
        // five of its guards, so this reads its verdict instead of assuming one.
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
