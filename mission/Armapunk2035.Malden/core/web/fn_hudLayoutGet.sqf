/*
    AP_fnc_hudLayoutGet -- ask the server for this account's saved HUD layout.

        [] call AP_fnc_hudLayoutGet;

    Fire and forget. The answer arrives later at AP_fnc_hudLayoutRecv, which caches it and
    applies it to whichever HUD pages are up.

    ---- WHY THIS IS NOT PART OF THE LOGIN LOAD ----------------------------------------------

    DB_fnc_queryRequest builds "the exact 32-element side-array" that fn_requestReceived reads
    BY INDEX. That index map is the same class of structure that produced the stat/title
    corruption -- a value in the wrong slot turns up as an unrelated setting changing by itself,
    and it looks like data corruption rather than a bug. A cosmetic layout is nowhere near worth
    touching it.

    So the layout is fetched separately, once, by the HUD keeper on its first successful bridge:
    one extra query per login, off the login critical path, zero index-map churn. The HUD draws
    at the designer's defaults for the fraction of a second before the answer lands, and keeps
    drawing at them for the whole session if the query fails. That is the correct direction to
    fail in -- the shipped layout, never a broken one.

    THE THROTTLE IS NOT POLITENESS, IT IS A LOOP GUARD. The caller is a `while {true}` keeper
    that re-bridges whenever the layer is re-cut -- on every death and respawn, on the toggle,
    and on any frame where something else cut the layer down. Without a floor, a client stuck in
    a re-cut cycle would issue a database query per second for as long as it lasted.
*/

if (!hasInterface) exitWith { false };

private _last = missionNamespace getVariable ["AP_hudLayoutAsked", -1e9];
if ((diag_tickTime - _last) < 10) exitWith { false };
AP_hudLayoutAsked = diag_tickTime;

["get"] remoteExec ["APS_fnc_hudLayoutSRV", 2];
true
