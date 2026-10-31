/*
    APS_fnc_handleDispatch  (LooneyBin -- implemented 2026-06-09; the passthrough fed
    [mode, unit, copLevel, message] into 2017 createDispatch [id, desc, value, chance, maxCops, pos, uid]
    -> cop BACKUP / SUPERIOR requests never reached anyone.)
      [0, player, copLevel, msg]  request BACKUP  -> all cops: alert banner + map ping at the requester
      [1, player, copLevel, msg]  request SUPERIOR -> Lieutenants+ (copLevel >= 5) only
*/
params [["_mode", 0, [0]], ["_unit", objNull, [objNull]], ["_lvl", 0, [0]], ["_msg", "", [""]]];
// owner 2026-06-23 SECURITY (security.md §2.2): cop-only. Callers = fn_requestBackup / fn_requestSuperior.
// Recipients were already filtered to west, but the CALLER was never checked -> any civ could remoteExec a fake
// BACKUP/SUPERIOR banner + map ping to every cop (spam/confusion). Derive the real caller (remoteExecutedOwner,
// non-spoofable) and require side==west; server-internal passes.
private _src = remoteExecutedOwner;
private _caller = if (_src isEqualTo 0) then { objNull } else { (allPlayers select { owner _x isEqualTo _src }) param [0, objNull] };
if (_src isNotEqualTo 0 && {!(_caller call APS_fnc_isDutyCop)}) exitWith { ["-SEC-", _caller, format ["BLOCKED handleDispatch by %1", getPlayerUID _caller]] call APS_fnc_logIt; };
if (isNull _unit) exitWith {};
private _pos = getPosATL _unit;
private _bar = format ["<t size='1.25' color='#4aa3ff'>%1</t><br/><t size='1.0'>%2 (%3)</t>",
    ["BACKUP REQUESTED", "SUPERIOR REQUESTED"] select (_mode min 1), _msg, name _unit];
private _cops = allPlayers select { (_x call APS_fnc_isDutyCop) && {!(_x isEqualTo _unit)} }; {
    [[_bar, "copalert"], "AP_fnc_handleMessage", _x, false, false] spawn AP_fnc_MP;
    [[_pos, format ["%1: %2", ["BACKUP", "SUPERIOR"] select (_mode min 1), name _unit]], "AP_fnc_tacticalPing", _x, false, false] spawn AP_fnc_MP;
} forEach _cops;
