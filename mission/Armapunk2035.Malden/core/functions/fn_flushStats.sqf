/*
    AP_fnc_flushStats  (singleevh.md Phase 3a) — flush the client stat-delta buffer to the server.

    DOUBLE-BUFFER (the "two hashmap" model): atomically swap AP_stats_dirty -> AP_stats_inflight and install a
    fresh empty AP_stats_dirty, so any stat mutations that land while this flush is in flight accumulate in the
    fresh buffer and are NOT lost (the legacy path reset APV_tempStats to zero right after spawning the send —
    a mutation in that window was dropped). Serialize the swapped-out buffer to [[idx, delta], ...] — the SAME
    wire shape the legacy fn_ClupdateRequest flush sent — and hand it to the server RMW (APS_fnc_statTableUpdate),
    which read-modify-writes players_global.lifetime_stats. => NO schema / data / server-protocol change.

    No-op when the flag is off or nothing is dirty. Called by the 120s durability PFH (fn_initStats) AND by the
    existing event triggers (respawn / manual sync / T-55 restart / quit / server force-flush via ClupdateRequest).
*/
if (isNil "AP_useStatBuffer" || {!AP_useStatBuffer}) exitWith {};

// singleevh.md Phase 3b: unified A_stats flush -- dirty-tracked whole-array (mode 9 -> players_global.stats),
// INDEPENDENT of the lifetime delta buffer below (must fire even when the lifetime buffer is empty). Replaces
// the standalone 300s [9] PFH; gives A_stats the same ~120s durability + one flush path. Named A_stats_* globals
// + the mode-9 pack (fn_ClupdatePartial) are untouched.
if (!isNil "AP_astats_dirty" && {AP_astats_dirty}) then { AP_astats_dirty = false; [9] call AP_fnc_ClupdatePartial; };

if (isNil "AP_stats_dirty" || {count AP_stats_dirty == 0}) exitWith {};

AP_stats_inflight = AP_stats_dirty;   // swap out the accumulated deltas
AP_stats_dirty = createHashMap;        // fresh buffer -> concurrent mutations during the send are preserved

private _updateArray = [];
{ if (_y isNotEqualTo 0) then { _updateArray pushBack [_x, _y]; }; } forEach AP_stats_inflight;
AP_stats_inflight = createHashMap;     // consumed

if !(_updateArray isEqualTo []) then {[[getPlayerUID player, _updateArray], "APS_fnc_statTableUpdate", 2] spawn AP_fnc_MP;};
