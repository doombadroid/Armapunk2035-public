/*
    APS_fnc_setGangTagSRV  (LooneyBin: REPAIRED -- was a passthrough to updateGang)
    Client args: [_gangID, _tag, _group, _global?]   (fn_setGangTag, fn_initGang)

    The gang tag is read off the GROUP object (AP_grpTag, e.g. onPlayerKilled's death messages). Set it
    network-wide so every client sees the tag. Only set a non-empty tag -> fn_initGang passes "" on each
    member's gang init, and we must not let one member relogging wipe the tag for everyone. The old stub
    fed the args into updateGang (which expected [id, inviteRank, kickRank]) -> the group object landed in
    a rank slot -> no-op.
    NOTE: there is no gangs.tag column, so the tag is session-live only; surviving a restart needs a
    schema add (tracked in TODO).
*/
params [["_gangID", -1, [0, -1, ""]], ["_tag", "", [""]], ["_group", grpNull, [grpNull]]];
if (isNull _group || {_tag isEqualTo ""}) exitWith {};
// owner 2026-06-23 SECURITY (security.md §2.2): was ANY client could broadcast a chosen tag onto ANY group
// (spoof another gang's overhead/kill-message tag). No SQL here -> identity only: require the NON-SPOOFABLE
// caller be a MEMBER of _gangID (fn_setGangTag reads the caller's own AP_gang_data[0]). The empty-tag
// join-path calls (fn_gangInvite/fn_initGang) are already short-circuited by the _tag=="" guard above, so
// the just-joined-member DB race never reaches this check.
private _san = { (format ["%1", _this]) splitString "\'""" joinString "" };
private _idStr = (format ["%1", _gangID]) call _san;
private _src = remoteExecutedOwner;   // 0 == server-internal = trusted
private _ok = true;
if (_src != 0) then {private _caller = (allPlayers select { owner _x isEqualTo _src }) param [0, objNull];
    private _callerUID = getPlayerUID _caller;
    private _crow = [format ["SELECT COUNT(*) AS n FROM %3 WHERE playerid='%1' AND gang0='%2'", _callerUID, _idStr, "players"], 2] call DB_fnc_asyncQuery;
    private _isMember = (_crow isEqualType []) && {count _crow >= 1} && {(parseNumber (format ["%1", _crow select 0])) > 0};
    if (!_isMember) then {
        ["-SEC-", _caller, format ["BLOCKED setGangTagSRV gang=%1 tag=%2 by %3", _idStr, (_tag call _san), _callerUID]] call APS_fnc_logIt;
        _ok = false;};};
if (!_ok) exitWith {};   // top-level -> exits the function
_group setVariable ["AP_grpTag", _tag, true];   // global -> all clients see the gang tag
