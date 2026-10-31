/*
    File: fn_suiteEvicted.sqf  (AP_fnc_suiteEvicted)
    Luxe Suites 2026-08-06 -- "your lease ended" notice. CfgRE allowedTargets = 1.

        [_oid, _why] remoteExec   -- _why: "tenant" | "arrears"

    Purely informational. The suite is already gone server-side by the time this
    arrives; this exists so a player who was mid-session when the sweep evicted
    them finds out immediately rather than discovering a locked door later.
*/
if (isRemoteExecuted && {remoteExecutedOwner != 2}) exitWith {};   // server-origin only: CfgRE allowedTargets limits the target, never the sender
params [["_oid", "", [""]], ["_why", "tenant", [""]]];
if (isNil "AP_suiteRows") then { AP_suiteRows = createHashMap; };
AP_suiteRows deleteAt _oid;

if (_why isEqualTo "arrears") then {
    ["<t color='#ff4444' size='1.05'>SUITE REPOSSESSED</t><br/><t color='#ff8f6b'>Your Luxe Suites lease lapsed. The floor has been re-let and its contents are gone.</t>", "hint"] spawn AP_fnc_handleMessage;
} else {
    ["Lease ended. The suite has been handed back.", "basic"] spawn AP_fnc_handleMessage;
};
if (!isNull (findDisplay 941600)) then { [] call AP_fnc_suiteKioskRefresh; };
