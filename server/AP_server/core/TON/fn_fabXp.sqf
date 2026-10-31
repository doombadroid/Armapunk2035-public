/*
    APS_fnc_fabXp  (Armapunk -- fabrication progression, server-side only)

        [_player, _count] call APS_fnc_fabXp

    Called ONLY from APS_fnc_fabSRV's collect arm, and only for a recipe that passed the level +/-1
    window. Not in CfgRE.hpp, deliberately: that absence is the whole security model here, the same
    reasoning as APS_fnc_ndDebitSrv. A client that could reach this could grant itself the top of
    the tree in one packet, which is exactly the exploit the system this was ported from shipped --
    there, the CLIENT decided it had levelled and told the server the new number to store.

    The server keeps TWO copies of the progression: AP_fabLevelSrv / AP_fabXpSrv (the authority:
    uid-keyed hashmaps in localNamespace, filled at login by DB_fnc_queryRequest) and AP_fabLevel /
    AP_fabXp (published on the unit, for the UI). Any object variable is client-writable, published or
    not, so the authority is not on the unit at all (audit 2026-09-26, mints2): a forged
    AP_fabLevelSrv = 20 on the unit used to be persisted here by the next collect.
*/
params [["_player", objNull, [objNull]], ["_count", 1, [0]]];
if (!isServer || {isNull _player}) exitWith {};

private _uid = getPlayerUID _player;
if !(_uid regexMatch "\d{17}") exitWith {};

private _lvlMap = localNamespace getVariable ["AP_fabLevelSrv", createHashMap];
private _xpMap  = localNamespace getVariable ["AP_fabXpSrv", createHashMap];
if !(_uid in _lvlMap) exitWith {};   // not loaded this session: writing a default level would reset the DB's
private _lvl = _lvlMap get _uid;
private _xp  = (_xpMap getOrDefault [_uid, 0]) + ((round _count) max 1);

// Roll up as many levels as the batch earned. A 20-unit batch at a low level can legitimately
// cross two thresholds, and stopping at one would silently eat the remainder.
private _levelled = false;
while {_lvl < 20} do {
    private _need = ["xpFor", _lvl] call AP_fnc_fabCfg;
    if (_need <= 0 || {_xp < _need}) exitWith {};
    _xp = _xp - _need;
    _lvl = _lvl + 1;
    _levelled = true;
};
if (_lvl >= 20) then { _xp = 0 };

_lvlMap set [_uid, _lvl];
_xpMap set [_uid, _xp];
_player setVariable ["AP_fabLevel", _lvl, true];
_player setVariable ["AP_fabXp", _xp, true];

[format ["UPDATE players SET fab_level=%1, fab_xp=%2 WHERE playerid='%3'", _lvl, _xp, _uid]] call DB_fnc_asyncQuery;

if (_levelled) then {
    [[format ["<t size='1.2' color='#56d6e2'>FABRICATION LEVEL %1</t>", _lvl], "basic"],
     "AP_fnc_handleMessage", _player, false, false] spawn AP_fnc_MP;
    ["-FAB-", _player, name _player, format ["reached fabrication level %1", _lvl]] call APS_fnc_logIt;
};
