/*
    AP_fnc_wantedPerson (LooneyBin)  -- return a unit's wanted-list entry, or [] if not wanted.
    Entry shape (see server vars.sqf): [name, uid, [chargeIDs], bounty, jailTime]. Index 3 = bounty.

    Was a reverse-drift no-op stub (`if (true) exitWith {}`), which -- because the mission registers
    AP_fnc_wantedPerson too -- SHADOWED the real AP_server impl on the server. So server callers
    (APS_fnc_handleJail, AP_fnc_jailSys) always got [] -> jailMe's _bounty fell to its 1500 default ->
    every prisoner bailed for a flat $1500. Restore a real lookup so the entry (and its index-3 bounty)
    resolves wherever this copy wins. The list lives in the SERVER's localNamespace (APS_wantedList, so a client
    publicVariable cannot forge it); on a client it does not exist -> [].
*/
params [["_unit", objNull, [objNull]]];
if (isNull _unit) exitWith { [] };
private _wl = localNamespace getVariable ["APS_wantedList", []];
private _uid = getPlayerUID _unit;
if (_uid isEqualTo "") exitWith { [] };
private _i = _wl findIf { (_x isEqualType []) && {(_x param [1, ""]) isEqualTo _uid} };
if (_i isEqualTo -1) exitWith { [] };
_wl select _i
