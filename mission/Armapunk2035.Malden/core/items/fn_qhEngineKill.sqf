// Altis Life game mechanic — fictional in-game "quickhack" ability, game logic only.
/*
    File: fn_qhEngineKill.sqf  (AP_fnc_qhEngineKill)
    LooneyBin 2026-07-21: set an engine hitpoint on a vehicle. Exists because `setHit` only takes effect where
    the vehicle is LOCAL -- and an OCCUPIED car is local to its DRIVER, not the server. Killswitch and Safe Stop
    ran setHit straight on the server, so they worked on empty cars (server-local) but did NOTHING to a car with
    a driver in it. This runs via AP_fnc_MP targeted at the VEHICLE object, so it executes on whichever machine
    owns the car (driver's client if occupied, server if empty) -- exactly how AP_fnc_setFuel is used.

      [_veh, _hitPointName, _value]
*/
if (isRemoteExecuted && {remoteExecutedOwner != 2}) exitWith {};   // server-origin only: CfgRE allowedTargets limits the target, never the sender
params [["_veh", objNull, [objNull]], ["_hp", "HitEngine", [""]], ["_val", 1, [0]]];
if (isNull _veh) exitWith {};
_veh setHit [_hp, _val];
