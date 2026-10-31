/*
    APS_fnc_adminKickBan  (LooneyBin -- owner request 2026-06-11: admin-menu Kick + Ban)
    Client (core/admin/fn_adminKick / fn_adminBan) sends:
        [_targetUID, _targetName, _isBan, _caller]
    Server verifies the CALLER's admin level from the DB (never trust the client gate alone),
    then: ban -> permanent row in `bans` (enforced at connect by fn_insertRequest);
    both -> client-side botKick (clean quit) + 8s engine fallback (#kick / deleteVehicle)
    so even a script-wedged client drops (same belt-and-braces as the bot 'hardkick').
*/
params [["_uid", "", [""]], ["_name", "", [""]], ["_isBan", false, [false]], ["_caller", objNull, [objNull]]];
if (_uid isEqualTo "") exitWith {};

// owner 2026-06-23 SECURITY (security.md §2.2/2.3 — identity-by-argument + SQLi): the admin gate re-queried
// adminlevel via getPlayerUID of the client-passed _caller OBJECT, so an attacker could pass a real admin's
// object and kick/ban "as" them. Derive the actor from the NON-SPOOFABLE remoteExecutedOwner instead
// (0 = server-internal = trusted). Also escape the target _uid before the ban INSERT (it was concatenated raw).
private _src = remoteExecutedOwner;
_caller = if (_src isEqualTo 0) then { objNull } else { (allPlayers select { owner _x isEqualTo _src }) param [0, objNull] };
private _callerUID = getPlayerUID _caller;
private _need = if (_isBan) then { 4 } else { 3 };
private _lvl = if (_src isEqualTo 0) then { 999 } else {
    private _rows = [format ["SELECT adminlevel FROM players_global WHERE playerid='%1'", _callerUID], 2, true] call DB_fnc_asyncQuery;
    parseNumber format ["%1", (_rows param [0, [0]]) param [0, 0]]};
if (_lvl < _need) exitWith {
    ["-SEC-", _caller, format ["BLOCKED adminKickBan (%1) by %2 on %3", ["kick","ban"] select _isBan, _callerUID, _uid]] call APS_fnc_logIt;
    diag_log format ["[LooneyBin][adminKickBan] DENIED %1 (lvl %2) tried %3 on %4", _callerUID, _lvl, ["kick","ban"] select _isBan, _uid];
};

if (_isBan) then {private _san = { (format ["%1", _this]) splitString "\'""" joinString "" };
    private _uidEsc = _uid call _san;
    [format ["INSERT INTO bans (playerid, reason, banned_by, until) VALUES ('%1', 'Banned in-game by admin', '%2', NULL)", _uidEsc, _callerUID]] call DB_fnc_asyncQuery;
};

private _u = (allPlayers select { (getPlayerUID _x) isEqualTo _uid }) param [0, objNull];
if (!isNull _u) then {
    [[["You have been kicked by an admin.", "You have been BANNED from this server."] select _isBan], "AP_fnc_botKick", _u, false, false] spawn AP_fnc_MP;
    [_u] spawn {params ["_u"];
        uiSleep 8;
        if (!isNull _u) then {serverCommand format ["#kick %1", owner _u];
            uiSleep 4;
            if (!isNull _u) then { deleteVehicle _u; };};};};
[777, _caller, format ["%1 %2 (%3)", ["KICKED","BANNED"] select _isBan, _name, _uid]] call APS_fnc_logIt;
diag_log format ["[LooneyBin][adminKickBan] %1 %2 (%3) by %4", ["kick","ban"] select _isBan, _name, _uid, name _caller];
