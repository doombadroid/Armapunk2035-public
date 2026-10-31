/*
    AP_fnc_atmSkimOwner  (LooneyBin, owner 2026-07-16) -- owner UID of the skimmer on an ATM object, or ""
    if it's clean / not an ATM. Reads the server-synced AP_atmSkim HashMap by the ATM's rounded world position
    (the same key the server writes). Used by the withdraw/deposit skim + the cop's "Remove Skimmer" action.
*/
params [["_atm", objNull, [objNull]]];
if (isNull _atm) exitWith { "" };
private _p = getPosATL _atm;
private _key = format ["%1_%2", round (_p select 0), round (_p select 1)];
(missionNamespace getVariable ["AP_atmSkim", createHashMap]) getOrDefault [_key, ""]
