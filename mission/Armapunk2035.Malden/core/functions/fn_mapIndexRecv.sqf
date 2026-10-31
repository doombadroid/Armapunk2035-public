/*
    File: fn_mapIndexRecv.sqf  (AP_fnc_mapIndexRecv)
    The server's answer to a "index" fetch (self-test): every non-empty cell key, the row count
    it holds, and its rev. Server-origin only (NOT in CfgRE; gated below).
*/
if (isRemoteExecuted && {remoteExecutedOwner != 2}) exitWith {};
params [["_keys", [], [[]]], ["_n", 0, [0]], ["_rev", -1, [0]]];
AP_mapIndex = [_keys, _n, _rev];
