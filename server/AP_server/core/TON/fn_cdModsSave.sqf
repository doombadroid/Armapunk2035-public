// Altis Life game mechanic — fictional in-game "quickhack" ability, game logic only
/*
    File: fn_cdModsSave.sqf  (APS_fnc_cdModsSave) -- the ONE writer of players.cyberdeck_modules.
    Server-only: deliberately NOT in CfgRE.

        [_unit, _addIds, _removeIds] spawn APS_fnc_cdModsSave

    AP_cdMods is a PUBLIC object var, so any client can setVariable it to anything, and the five sites that
    persisted it (installHack, buyModule, the ICE Firewall shatter in qhSRV and talSRV, Dead Man's Clutch) wrote
    `str` of that var straight into the UPDATE -- a quote in a forged element was SQL injection on every row of
    players (audit TONc-0-0). The list persisted here is the SERVER's own copy instead: it lives in localNamespace,
    which nothing on the network can write, is seeded from the DB the first time a UID is touched this run, and
    changes only by the ids the calling server fn passes. Numbers only, bound as a parameter. The object var is
    re-published from it, so a forged list is overwritten the next time the deck changes.
    Scheduled only (the seed is a DB read): callers spawn it. Its absence from CfgRE is what keeps it server-only
    (like APS_fnc_ndCreditSrv); every caller runs inside a client-remoteExec'd fn, so no isRemoteExecuted guard here.
*/
params [["_unit", objNull, [objNull]], ["_add", [], [[]]], ["_remove", [], [[]]]];
private _uid = getPlayerUID _unit;
if (_uid isEqualTo "") exitWith {};
private _ids = { _this select { _x isEqualType 0 && {_x >= 0} && {_x < 10000} && {_x isEqualTo floor _x} } };   // ids are small ints; keeps str() plain digits
private _k = "APS_cdMods_" + _uid;

if (isNil {localNamespace getVariable _k}) then {
    private _row = ["SELECT COALESCE(cyberdeck_modules::text, '[]') FROM players WHERE playerid = %s", 2, false, [_uid]] call DB_fnc_asyncQuery;
    // no row / DB error: leave it unseeded -- persisting only this change would wipe the rest of the deck
    if (_row isEqualTo []) exitWith { diag_log format ["[cdMods] seed read failed for %1 -- change %2/%3 not persisted", _uid, _add, _remove]; };
    private _seed = parseSimpleArray format ["%1", _row param [0, "[]"]];
    if (isNil "_seed" || {!(_seed isEqualType [])}) then { _seed = []; };
    if (isNil {localNamespace getVariable _k}) then { localNamespace setVariable [_k, _seed call _ids]; };   // a parallel seed may have won
};
if (isNil {localNamespace getVariable _k}) exitWith {};

// read-modify-write in one unscheduled step so two changes for the same UID cannot interleave
private _mods = [];
isNil {
    private _cur = localNamespace getVariable [_k, []];
    _mods = (_cur - _remove) + ((_add call _ids) - _cur);
    localNamespace setVariable [_k, _mods];
};
if ((_unit getVariable ["AP_cdMods", []]) isNotEqualTo _mods) then { _unit setVariable ["AP_cdMods", +_mods, true]; };   // a copy: server fns pushBack into the object var
// ponytail: two changes for one UID inside one DB round trip may land out of order; queue per UID if that ever shows.
["UPDATE players SET cyberdeck_modules = %s WHERE playerid = %s", 1, false, [str _mods, _uid]] call DB_fnc_asyncQuery;
_mods
