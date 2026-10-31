if (isRemoteExecuted && {remoteExecutedOwner != 2}) exitWith {};   // server hop only: APS_fnc_victimSRV checks actor/range/state
params[["_vehicle", objNull, [objNull]]];
if (isNull _vehicle || !(isNull objectParent player)) exitWith {};
if (_vehicle distance player > 15) exitWith {};
player moveInCargo _vehicle;