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
