/*
    File: fn_suiteRentNotice.sqf  (AP_fnc_suiteRentNotice)
    Luxe Suites 2026-08-06 -- rent toasts. CfgRE allowedTargets = 1.

        [_oid, _kind, _daysLeft] remoteExec     -- _kind: "paid" | "overdue"

    Purely informational; the lease state is already settled server-side. The
    overdue notice is the one that matters -- a tenant who is offline when their
    payment fails needs to find out the moment they next connect, which is why
    the sweep also fires this on the pass after they log in.
*/
if (isRemoteExecuted && {remoteExecutedOwner != 2}) exitWith {};   // server-origin only: CfgRE allowedTargets limits the target, never the sender
params [["_oid", "", [""]], ["_kind", "", [""]], ["_days", 0, [0]]];

switch (_kind) do {
    case "paid": {
        [format ["Luxe Suites: %1 ND rent paid.", AP_suiteRentND], "basic"] spawn AP_fnc_handleMessage;
    };
    case "overdue": {
        [format ["<t color='#ff4444' size='1.05'>SUITE RENT OVERDUE</t><br/><t color='#ff8f6b'>%1 ND could not be taken. You have %2 day(s) to settle at the kiosk before the suite is re-let and everything stored inside is lost.</t>",
            AP_suiteRentND, _days], "hint"] spawn AP_fnc_handleMessage;
    };
};
