/*
    APS_fnc_enableCoPilot  (LooneyBin: IMPLEMENTED -- was a logging no-op stub)
    Client args: [_vehicle]   (fired from fn_onPlayerKilled / fn_handleDowned when a heli's PILOT dies)

    Promote a living player passenger into the controls so the heli doesn't auto-crash everyone aboard.
    moveInDriver ejects the (dead) pilot from the seat; the #41 corpse handling still applies (an ejected
    corpse is free, not wreck-trapped). No-op if there's already a live pilot or no living passenger.
*/
params [["_veh", objNull, [objNull]]];
if (isNull _veh || {!alive _veh}) exitWith {};
if (!isNull (driver _veh) && {alive (driver _veh)}) exitWith {};   // already has a live pilot

private _cargo = (crew _veh) select { (_x != driver _veh) && {alive _x} && {isPlayer _x} };
if (_cargo isEqualTo []) exitWith {};

private _newPilot = _cargo select 0;
_newPilot moveInDriver _veh;
[["The pilot is down -- you've got the controls! Land it!", "basic"], "AP_fnc_handleMessage", _newPilot, false] spawn AP_fnc_MP;
