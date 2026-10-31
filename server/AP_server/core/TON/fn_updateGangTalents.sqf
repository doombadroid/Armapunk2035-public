/*
    APS_fnc_updateGangTalents  (LooneyBin -- implemented 2026-06-09; the passthrough fed
    [[exp,talents], gangID] into 2017 [unit, gang, talents] -> gang XP + gang PERKS never persisted.)
    Client (talentMenu / captureCartel) sends [[AP_gang_exp, AP_gang_talents], gangID].
*/
params [["_data", [], [[]]], ["_gangID", -1, ["", 0]]];
_data params [["_exp", 0, [0]], ["_talents", [], [[]]]];
// owner 2026-06-23 SECURITY (security.md §2.2/§2.3): was ANY client could rewrite ANY gang's exp/talents,
// with _gangID + str(_talents) raw in the UPDATE. Escape the id + the serialised talents array, and require
// the caller be a MEMBER of that gang (talents are spent from your own gang's menu). _exp/_talents VALUE
// bounds (legality of perks) are out of scope here -- this closes identity + SQLi only.
private _san = { (format ["%1", _this]) splitString "\'""" joinString "" };
private _idStr = (format ["%1", _gangID]) call _san;
if (_idStr isEqualTo "" || {_idStr isEqualTo "-1"}) exitWith {};
private _src = remoteExecutedOwner;   // 0 == server-internal = trusted
private _ok = true;
if (_src != 0) then {private _caller = (allPlayers select { owner _x isEqualTo _src }) param [0, objNull];
    private _callerUID = getPlayerUID _caller;
    private _crow = [format ["SELECT COUNT(*) AS n FROM %3 WHERE playerid='%1' AND gang0='%2'", _callerUID, _idStr, "players"], 2] call DB_fnc_asyncQuery;
    private _isMember = (_crow isEqualType []) && {count _crow >= 1} && {(parseNumber (format ["%1", _crow select 0])) > 0};
    if (!_isMember) then {["-SEC-", _caller, format ["BLOCKED updateGangTalents gang=%1 by %2", _idStr, _callerUID]] call APS_fnc_logIt;
        _ok = false;};};
if (!_ok) exitWith {};   // top-level -> exits the function
private _talSafe = (str _talents) call _san;   // SQLi-safe serialised talents
[format ["UPDATE gangs SET experience='%2', talents='%3' WHERE id='%1'", _idStr, _exp max 0, _talSafe]] call DB_fnc_asyncQuery;
// refresh the boot cache row (slots: 7 = exp, 8 = talents) so later ops this session see the change
private _idx = AP_server_gangs findIf { (format ["%1", _x select 0]) isEqualTo _idStr };
if (_idx > -1) then {private _row = AP_server_gangs select _idx;
    _row set [7, _exp]; _row set [8, _talents];
    AP_server_gangs set [_idx, _row];};
diag_log format ["[LooneyBin][gang] talents persisted for gang %1 (exp %2, %3 talent(s))", _idStr, _exp, count _talents];
