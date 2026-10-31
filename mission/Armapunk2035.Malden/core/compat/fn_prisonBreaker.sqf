/*
    AP_fnc_prisonBreaker  (LooneyBin -- IMPLEMENTED 2026-06-18; was a no-op stub, which meant a COMPLETED
    prison break NEVER let anyone out: the breaker held the full timer, fn_startPrisonBreak called this on every
    civ within 100m of the prison, but it did nothing -> AP_breakout stayed false -> fn_jailMe's escape gate
    `(SRV_prisonData select 1) && AP_breakout` (line ~98) never fired -> prisoners just kept serving time while
    the HUD bar sailed past the real completion point ("stuck ~87%, nobody breaks out").

    Runs on each nearby client (remoteExec'd from the server's fn_startPrisonBreak success path). Flip
    AP_breakout on the ones actually in jail -> their jail loop exits this tick and releases them out the gate
    (with the "+escaping prison" charge fn_jailMe adds). Non-prisoners are skipped (their jail loop isn't running).
*/
if !((AP_is_arrested param [0, 0]) isEqualTo 1) exitWith {};   // only actual prisoners escape
AP_breakout = true;
["The prison security has been breached -- you're breaking out! Get to the gate.", "basic"] spawn AP_fnc_handleMessage;
