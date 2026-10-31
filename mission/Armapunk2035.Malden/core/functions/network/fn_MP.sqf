with missionNamespace do {params[["_params", [], [[]]
    ], ["_functionName", "", [""]], ["_target", false, [objnull, false, 0, [], sideUnknown, grpNull, ""]], ["_isPersistent", false, [false, ""]], ["_isCall", false, [false]]];
    // --- LooneyBin universal call audit (owner 2026-06-15 "log every function we can") ---------------
    // fn_MP is the single chokepoint every cross-machine call flows through, so logging here = logging
    // every remote function a client invokes (the entire exploit surface) without touching 1000s of files.
    // Client-only (hasInterface) so the dedicated server's broadcast spam never floods the table.
    // Recursion-safe (never logs the logger). Live toggles via debug console -- NO reboot:
    //   AP_logCalls     master on/off               (default true)
    //   AP_logCallsAll  firehose: log EVERY fn name  (default false -> use the watch list; BURST ONLY)
    //   AP_logCallList  lowercase name-substrings to log when not in All mode
    if (hasInterface && {missionNamespace getVariable ["AP_logCalls", true]}) then {private _fnl = toLower _functionName;
        // Exact-name DENY set: these fire on the save/login hot path (updatePartial fires on every
        // field save and dominates this volume) -- skip the audit entirely so it never doubles DB
        // write traffic. Exact equality only, so DB_fnc_updateGang/updateWar/updateHouse (substring
        // "update") are unaffected, and the "query" substring tripwire that logs raw DB_fnc_asyncQuery
        // (CLANKR's RCE watch) stays intact.
        // ALL ENTRIES MUST BE LOWERCASE: _fnl is toLower'd and `in` compares strings
        // CASE-SENSITIVELY (unlike ==/!=). The AP_ rename re-cased this list's third entry
        // to canonical spelling and silently killed it; keep them lowercase.
        private _denyAudit = ["db_fnc_updatepartial", "db_fnc_updaterequest", "aps_fnc_stattableupdate", "db_fnc_queryrequest"];
        if (_fnl != "APS_fnc_logIt" && {!(_fnl in _denyAudit)}) then {
            private _watch = missionNamespace getVariable ["AP_logCallList", []];
            if ((missionNamespace getVariable ["AP_logCallsAll", false]) || {(_watch findIf { _fnl find _x > -1 }) > -1}) then {
                private _as = format ["%1", _params];
                if (count _as > 300) then { _as = (_as select [0, 300]) + "..(trunc)"; };
                private _tgt = switch (true) do {
                    case (_target isEqualType objNull): { if (isNull _target) then { "null" } else { netId _target } };
                    default { format ["%1", _target] };};
                [["-FNCALL-", player, name player, format ["MP call %1 (call=%2) -> tgt %3 | args: %4", _functionName, _isCall, _tgt, _as]],
                    "APS_fnc_logIt", 2, false, false] spawn AP_fnc_MP;};};};
    if (_target isEqualType 0) then {if (isServer && !isDedicated) then {if (_target isEqualTo - 2) then {_target = 0;};};};
    if (_target isEqualType true) then {_target = [2, 0] select _target;};
    if (_target isEqualType[] && {(count _target) isEqualTo 0}) exitWith {};
    if (_isCall) then {_params remoteExecCall[_functionName, _target, _isPersistent];} else {
        _params remoteExec[_functionName, _target, _isPersistent];};};