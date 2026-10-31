/*
    File: fn_copSplitReceive.sqf  (LooneyBin)
    Receiver half of APS_fnc_copSplit. Runs on EACH active officer's client when the
    server distributes a cop payout (ticket / money seizure / vehicle+inventory seizure /
    impound / illegal tent / arrest bounty). Credits this officer's bank with their share.
    Server-initiated only (not in CfgRemoteExec whitelist -- server is exempt from mode=1).
    Args: [_share]
*/
params [["_share", 0, [0]]];
// Server-origin guard: APS_fnc_copSplit (server, owner 2) is the only legit caller; this credits bank
// cash, so a local call must not self-award a cop split.
if (remoteExecutedOwner != 2) exitWith {};
if (_share <= 0 || {AP_effSide isNotEqualTo west}) exitWith {};

AP_atmcash = AP_atmcash + _share;
AP_atmcashCacheB = ((AP_atmcash / 4) + 11);
[1] call AP_fnc_ClupdatePartial;
systemChat format ["Police payout: +$%1", [_share] call AP_fnc_numberText];
