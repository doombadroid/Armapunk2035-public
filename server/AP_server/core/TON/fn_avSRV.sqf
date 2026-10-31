/*
    APS_fnc_avSRV  (Armapunk 2035, 2026-09-22) -- LUXE AV (ap_av_lux, addon ap_av): the autonomous air taxi.

    M1 per the owner (2026-09-22): an admin spawns the hull from the admin vehicle list, passengers pick a
    PRESET destination (AP_avDest, server_init.sqf) and the SERVER flies it with the shared kinematic core
    (AP_fnc_hcFly -> AP_fnc_flyStep, the same code the summon HC runs). No pilot seat for players: the
    engine's driver slot exists (the helicopter sim needs one) and is locked here.

    Verbs (client -> server, CfgRE target 2; the caller is remoteExecutedOwner, never the payload):
        ["go",   _veh, _destIdx]   caller sits in the hull's cargo; door shuts, pods tilt, it flies and lands
        ["door", _veh, _open]      caller is aboard or within 8 m; only while landed and not flying

    The flight itself (door, pods, core, pad pin, final settle) is APS_fnc_avFly -- separate so the engine
    smoke (design/av-hovercraft/engine_smoke_av.py) can fly it without a real passenger.

    Why the landing is forced to the pad (fly_land): the dedicated server never streams the designer's map
    objects (AP_fnc_mapTick exits on isDedicated), so AP_fnc_flyLandSpot here cannot see them. Every
    AP_avDest entry is a designer-placed helipad checked clear in map_objects (2026-09-22); the core's
    cruise stays >= 120 m over the start and its descent is vertical, so only the pad column matters.

    Why a final settle: a pilotless hull does not hover-hold (engine smoke 2026-09-22: released at 20 m it
    fell to the ground in 4 s), so any flight that ends in the air (hover / aborted / timeout) is lowered
    here, per frame, to the ground before the doors open.
    Kill switch: SRV_avEnabled (server_init.sqf).
*/
params [["_verb", "", [""]], ["_veh", objNull, [objNull]], ["_arg", 0, [0, true]]];
if !(missionNamespace getVariable ["SRV_avEnabled", true]) exitWith {};
if (isNull _veh || {!alive _veh} || {!(_veh isKindOf "ap_av_lux")}) exitWith {};
private _src = remoteExecutedOwner;
private _caller = if (_src isEqualTo 0) then { objNull } else { (allPlayers select { owner _x isEqualTo _src }) param [0, objNull] };
if (_src isNotEqualTo 0 && {isNull _caller}) exitWith {};
private _tell = { params ["_to", "_msg"]; [[_msg, "basic"], "AP_fnc_handleMessage", _to, false, false] spawn AP_fnc_MP; };
private _inCargo = !isNull _caller && {_caller in crew _veh} && {((assignedVehicleRole _caller) param [0, ""]) isEqualTo "cargo"};

switch (_verb) do {
    case "door": {
        if (!_inCargo && {_caller distance _veh > 8}) exitWith {};
        if (_veh getVariable ["AP_avBusy", false]) exitWith { [_caller, "The doors stay sealed in flight."] call _tell; };
        _veh animateSource ["doors_open", [0, 1] select (_arg isEqualTo true)];
    };
    case "go": {
        if (!_inCargo) exitWith {};
        if (_veh getVariable ["AP_avBusy", false]) exitWith { [_caller, "Already under way."] call _tell; };
        private _list = missionNamespace getVariable ["AP_avDest", []];
        if !(_arg isEqualType 0) exitWith {};
        if (_arg < 0 || {_arg >= count _list}) exitWith {};
        (_list select _arg) params ["_name", "_dest"];
        if (_veh distance2D _dest < 150) exitWith { [_caller, format ["You are already at %1.", _name]] call _tell; };
        if (((getPosATL _veh) select 2) > 3) exitWith {};
        _veh setVariable ["AP_avBusy", true, true];
        ["-AV-", _caller, format ["%1 (%2) sent AV %3 to %4", name _caller, getPlayerUID _caller, netId _veh, _name]] call APS_fnc_logIt;
        [_veh, _dest, _name] spawn APS_fnc_avFly;
    };
};
