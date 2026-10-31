/*
    APS_fnc_wantedSyncList  (LooneyBin) -- runs on the SERVER.
    The OFFENDER's client (AP_fnc_wantedListAdd) is the single source of truth for wanted level:
    A_stats_crimes = [totalBounty, count_of_crime_1, count_of_crime_2, ...]. It pushes that state here on
    every change + on load; we rebuild the cop-facing wanted-list entry (APS_wantedList) from it so the Wanted menu AND
    the payout (APS_fnc_wantedBounty reads entry index 3) match the REAL wanted amount. Args: [uid,name,crimes].
*/
params [["_uid", "", [""]], ["_name", "", [""]], ["_crimes", [], [[]]]];
if (_uid isEqualTo "") exitWith {};
// owner 2026-07-24 SECURITY (audit): CfgRE allowedTargets=2 with no caller derivation, so the uid/name/
// crimes were whatever the caller claimed. That made this the unlocked back door around the hardened
// APS_fnc_wantedAdd: any client could rebuild ANY player's wanted-list entry -- zero out its own
// bounty to clear its wanted level, or fabricate a huge bounty on someone else. Entry index 3 is the cash
// the arrest payout reads (APS_fnc_wantedBounty), so a forged entry is also a payout exploit.
// The DESIGN is that the offender's own client is the source of truth for its wanted state (see header),
// so the fix keeps that exactly and only removes the impersonation: for a remote call the identity is
// forced to the calling machine, never the claimed one. server-internal (_src == 0) is unchanged.
private _src = remoteExecutedOwner;   // 0 == server-internal = trusted
if (_src isNotEqualTo 0) then {private _caller = (allPlayers select { owner _x isEqualTo _src }) param [0, objNull];
    if (isNull _caller) then {
        _uid = "";   // unattributable -> the top-level guard below drops it (nested exitWith would only leave this block)
    } else {private _realUid = getPlayerUID _caller;
        if (_realUid isNotEqualTo _uid) then {
            ["-SEC-", _caller, format ["BLOCKED wantedSyncList impersonation: claimed %1, really %2", _uid, _realUid]] call APS_fnc_logIt;
        };
        _uid  = _realUid;
        _name = name _caller;};};
if (_uid isEqualTo "") exitWith {};
// localNamespace, not a missionNamespace global: a client publicVariable would overwrite the whole list (payouts included)
private _wl = localNamespace getVariable "APS_wantedList";
// TONa-0-7: slot 0 (the client's running total) is NOT read -- a client could claim a $1e9 bounty and have
// APS_fnc_wantedBounty pay it out. The bounty is rebuilt here as count x charge value, from the same mission
// charge table the client's own slot 0 is summed from (the APS_ copy lacks 82-109). Each count is clamped
// to 0..25 and ids stop at 150 (APS_fnc_wantedAdd's range): a raw count drove the pushBack loop below, so
// 1e8 was a server stall. APS_fnc_bulkAdd rebuilds through this too.
private _bounty = 0;
private _flat = [];
private _jail = 0;
for "_i" from 1 to (((count _crimes) - 1) min 150) do {private _cnt = _crimes param [_i, 0];
    _cnt = if (_cnt isEqualType 0) then { ((round _cnt) max 0) min 25 } else { 0 };
    private _row = if (_cnt > 0) then { ["getRow", _i] call AP_fnc_wantedChargesConfig } else { [] };
    if (_row isNotEqualTo []) then {for "_j" from 1 to _cnt do { _flat pushBack _i; };
        _bounty = _bounty + ((_row param [2, 0]) * _cnt);
        _jail = _jail + ((_row param [3, 0]) * _cnt);};};
private _idx = _wl findIf { (_x param [1, ""]) isEqualTo _uid };
if (_bounty <= 0) then {if (_idx != -1) then { _wl deleteAt _idx; };} else {
    private _entry = [_name, _uid, _flat, _bounty, _jail];
    if (_idx != -1) then { _wl set [_idx, _entry]; } else { _wl pushBack _entry; };};
