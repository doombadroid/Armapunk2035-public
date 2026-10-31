/*
    File: fn_suiteStorageRecv.sqf  (AP_fnc_suiteStorageRecv)
    Luxe Suites 2026-08-07 -- server -> client storage payload. CfgRE allowedTargets = 1.

        ["ok"|"denied", _vinv, _pinv, _vcap, _pcap] remoteExec

    Deliberately dumb: it only parks the payload where AP_fnc_suiteStorage is
    waiting for it. Everything about what may be stored, and how much, is decided
    server-side -- this never makes that call.
*/
if (isRemoteExecuted && {remoteExecutedOwner != 2}) exitWith {};   // server-origin only: CfgRE allowedTargets limits the target, never the sender
params [["_status", "ok", [""]], ["_vinv", [[], 0], [[]]], ["_pinv", [[], 0], [[]]],
        ["_vcap", 900, [0]], ["_pcap", 3000, [0]]];
AP_suiteStoreLoaded = [_status, _vinv, _pinv, _vcap, _pcap];
