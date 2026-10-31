/*
    APS_fnc_transferGangOwnerSRV  (LooneyBin: REPAIRED -- was a passthrough to setOwnerID)
    Client args: [_oldOwnerUID, _newOwnerUID]   (only the current owner -- gangrank0=1 -- can call it)

    Gang ownership = gangrank0 = 1 (fn_gangTransferOwner gates the caller on rank 1; populateGangInfo
    flags rank 1 as the owner). Transfer = promote the new owner to rank 1 and demote the old owner to
    rank 2. Persisted to the players table, so getGangInfo (which reads gangrank0 from the DB) reflects
    the new ranks the next time the gang menu opens. The old stub just set an ownerID netvar on the
    arg array -> did nothing.
*/
params [["_oldOwnerUID", "", [""]], ["_newOwnerUID", "", [""]]];
// owner 2026-06-23 SECURITY (security.md §2.2/§2.3): was [victimLeaderUID,myUID] -> STEAL LEADERSHIP of any
// gang (it just set whoever-you-named to gangrank0=1). Two fixes: (1) the "old owner" is WHOEVER IS CALLING
// -- derive it from the NON-SPOOFABLE caller, never the client-supplied _oldOwnerUID; (2) verify the caller is
// actually the rank-1 leader, and the new owner is a MEMBER OF THE SAME GANG (client gate = AP_gang_data[2]==1
// + target chosen from the gang roster). Escape both UIDs for the format[] UPDATEs.
private _san = { (format ["%1", _this]) splitString "\'""" joinString "" };
private _src = remoteExecutedOwner;   // 0 == server-internal = trusted
private _newSafe = _newOwnerUID call _san;
if (_newSafe isEqualTo "") exitWith {};
private _oldSafe = "";   // the ACTING leader; for a client call we OVERRIDE the client's _oldOwnerUID with the real caller
if (_src isEqualTo 0) then {_oldSafe = _oldOwnerUID call _san;   // server-internal -> trust the passed value
} else {private _caller = (allPlayers select { owner _x isEqualTo _src }) param [0, objNull];
    private _callerUID = getPlayerUID _caller;
    _oldSafe = _callerUID call _san;   // NON-SPOOFABLE actor identity
    private _gid = "";
    private _rank = 99;
    private _row = [format ["SELECT gang0, gangrank0 FROM %2 WHERE playerid='%1'", _callerUID, "players"], 2] call DB_fnc_asyncQuery;
    if ((_row isEqualType []) && {count _row >= 2}) then { _gid = (format ["%1", _row select 0]) call _san; _rank = parseNumber (format ["%1", _row select 1]); };
    // new owner must be in the SAME gang as the caller (and the gang must be real, not '0')
    private _memOK = false;
    if (_gid isNotEqualTo "" && {_gid isNotEqualTo "0"}) then {
        private _mrow = [format ["SELECT COUNT(*) AS n FROM %3 WHERE playerid='%1' AND gang0='%2'", _newSafe, _gid, "players"], 2] call DB_fnc_asyncQuery;
        _memOK = (_mrow isEqualType []) && {count _mrow >= 1} && {(parseNumber (format ["%1", _mrow select 0])) > 0};};
    if (_rank != 1 || {!_memOK} || {_oldSafe isEqualTo _newSafe}) then {
        ["-SEC-", _caller, format ["BLOCKED transferGangOwner -> %1 by %2 (rank %3, gang %4, memberOK %5)", _newSafe, _callerUID, _rank, _gid, _memOK]] call APS_fnc_logIt;
        _oldSafe = "";   // flag failure -> the top-level guard below exits the FUNCTION
    };};
if (_oldSafe isEqualTo "" || {_oldSafe isEqualTo _newSafe}) exitWith {};

[format ["UPDATE players SET gangrank0='1' WHERE playerid='%1'", _newSafe]] call DB_fnc_asyncQuery;   // promote new owner
[format ["UPDATE players SET gangrank0='2' WHERE playerid='%1'", _oldSafe]] call DB_fnc_asyncQuery;   // demote old owner

[[991, objNull, format ["Gang ownership transferred %1 -> %2. Srv %3", _oldSafe, _newSafe, AP_server_instance]], "APS_fnc_logIt", false, false] spawn AP_fnc_MP;
