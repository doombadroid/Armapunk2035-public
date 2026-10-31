/*
    APS_fnc_ignitionBombSRV  (LooneyBin) -- arm an ignition bomb on a vehicle. Runs on the SERVER.
    2020 client args: [_vehicle, _planterName, _planterUID, _planter]   (fn_ignitionBomb)

    Was a no-op stub, so the bomb "planted" client-side but never detonated -> "ignition bomb isn't
    working". The bomb is meant to blow when the TARGET starts the engine. Engine state is networked, so
    the server just watches isEngineOn on the rigged vehicle and detonates on ignition (no per-client EH
    / no extra whitelisted fn needed). One-shot; cancels cleanly if the vehicle is gone first.
*/
params [["_vehicle", objNull, [objNull]], ["_name", "", [""]], ["_uid", "", [""]], ["_planter", objNull, [objNull]]];
if (isNull _vehicle) exitWith {};
if (_vehicle getVariable ["AP_ignitionBombArmed", false]) exitWith {};   // already rigged
_vehicle setVariable ["AP_ignitionBombArmed", true, true];
_vehicle setVariable ["AP_ignitionBomb", [_name, _uid], true];

[_vehicle, _name, _uid] spawn {params ["_v", "_name", "_uid"];
    // wait for ignition (or the vehicle being destroyed/deleted before then)
    waitUntil { uiSleep 1; isNull _v || {!alive _v} || {isEngineOn _v} };
    if (isNull _v || {!alive _v}) exitWith {
        if (!isNull _v) then { _v setVariable ["AP_ignitionBombArmed", false, true]; _v setVariable ["AP_ignitionBomb", nil, true]; };};
    uiSleep (0.6 + random 1.4);                              // brief, slightly random delay after start
    if (isNull _v || {!alive _v}) exitWith {};
    private _pos = getPosATL _v;
    "Bo_GBU12_LGB" createVehicle _pos;                       // the blast
    _v setDamage 1;
    _v setVariable ["AP_ignitionBomb", nil, true];
    _v setVariable ["AP_ignitionBombArmed", false, true];   // owner 2026-06-23 (#505): bomb is spent -- clear the armed flag so the wreck loses fn_cleanup's idle-reap exemption (it's now dead anyway -> normal dead-vehicle reap).
    [[0, format ["An ignition bomb planted by %1 has detonated!", _name]], "AP_fnc_broadcast", -2, false, false] spawn AP_fnc_MP;
    [["-IGNITIONBOMB-", _v, _name, format ["ignition bomb detonated (planter UID %1) at %2", _uid, _pos]], "APS_fnc_logIt", 2, false, false] spawn AP_fnc_MP;
};

diag_log format ["[LooneyBin][ignitionBombSRV] armed %1 by %2 (%3)", typeOf _vehicle, _name, _uid];
