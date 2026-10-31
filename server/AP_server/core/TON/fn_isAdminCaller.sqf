/*
    APS_fnc_isAdminCaller  (Armapunk 2026-09-26 security remediation -- one-line admin gate)

        if !([3, "eventBRSRV START"] call APS_fnc_isAdminCaller) exitWith {};

    True when the machine that remoteExec'd the CURRENT script is a player whose
    players_global.adminlevel >= _need. Server-internal calls (not remote-executed, or sent by the
    server itself) are trusted. Identity is remoteExecutedOwner -- never anything in the payload --
    and a refusal gets a -SEC- row attributed to that sender. Same gate as fn_eventGunGameSRV /
    fn_fabDebugSRV, factored so every admin-only SRV entry point is one flat line.

    `call` it from the remoteExec'd function body: a spawned script has no remoteExecutedOwner.
    The DB read needs a scheduled caller; an unscheduled one reads no rows and is refused.
*/
params [["_need", 3, [0]], ["_what", "", [""]]];
private _src = remoteExecutedOwner;
if (_src in [0, 2]) exitWith { true };
private _caller = (allPlayers select { owner _x isEqualTo _src }) param [0, objNull];
private _uid = getPlayerUID _caller;
private _lvl = 0;
if (_uid isNotEqualTo "") then {
    private _rows = ["SELECT adminlevel FROM players_global WHERE playerid = %s", 2, true, [_uid]] call DB_fnc_asyncQuery;
    _lvl = parseNumber format ["%1", (_rows param [0, [0]]) param [0, 0]];
};
if (_lvl >= _need) exitWith { true };
["-SEC-", _caller, format ["BLOCKED %1 by %2 (owner %3, admin %4 < %5)", _what, _uid, _src, _lvl, _need]] call APS_fnc_logIt;
false
