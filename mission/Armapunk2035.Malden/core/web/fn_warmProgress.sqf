/*
    AP_fnc_warmProgress -- the connect-time cache worker's progress, from ui\html\warm.html.

        [_pct, _done, _total] call AP_fnc_warmProgress;      // registered on control 930451

    Stores the figure and re-pushes the landing payload if that screen is still up. Nothing else
    reads it and nothing waits on it: PLAY is deliberately NOT gated on the cache, because every
    consumer already handles a cold asset and a login that waits on the icon directory to save a
    first-open stutter is a bad trade. ui\html\landing.html enforces that on its side -- its
    welcome->faction step used to require loadPct >= 100 and no longer does.

    THE PAGE IS NOT TRUSTED WITH THE NUMBER, only with the fact that it moved. _pct is clamped to
    0..100 and rounded here rather than taken as sent; _done and _total are read for the log and
    for nothing else. There is no path from this value to money, authority or the world -- it
    picks a bar width on the client that produced it -- but a page value that goes straight into a
    global without a clamp is the habit this tree does not want.

    AP_warmGaveUp IS A LATCH, NOT A GATE. AP_fnc_warmBridge's watchdog sets it after 30 s of
    silence and fills the bar to 100, so a page that finally finds its voice at 40% cannot pull the
    bar backwards from 100. Monotonic is the only thing a loading bar owes anybody.

    Returns [] -- the page discards it. The handler must return SOMETHING: webui's CALL path
    encodes the return value and replies with it, and a suspended handler that never returns leaves
    the page's promise to time out.
*/
params [["_pct", 0, [0]], ["_done", 0, [0]], ["_total", 0, [0]]];
disableSerialization;

if (missionNamespace getVariable ["AP_warmGaveUp", false]) exitWith { [] };

AP_warmReported = true;                                  // read by fn_warmBridge's watchdog
AP_warmPct = 0 max (round _pct) min 100;

// Once, at the ends, so a slow connect leaves a trace of how far the cache actually got without
// putting a hundred lines in the RPT.
if (AP_warmPct isEqualTo 100 || { AP_warmPct isEqualTo 0 }) then {
    diag_log format ["[WARM] %1%% (%2/%3) t=%4", AP_warmPct, _done, _total, diag_tickTime toFixed 1];
};

[] call AP_fnc_warmRepush;
[]
