/*
    debug\probe_spawnlist.sqf -- does the spawn payload contain EVERY wake point?

        [] execVM "debug\probe_spawnlist.sqf";      // then read [AP-PROBE] in the client RPT

    WHY THIS EXISTS. AP_fnc_spawnPointList builds its rows in a forEach, and an SQF error inside a
    forEach aborts the whole loop -- so a throw on ONE row silently truncates the payload to the rows
    built before it and returns a shorter list that looks perfectly valid. That is exactly what shipped
    on 2026-09-11: a one-argument `missionNamespace getVariable` answered nil for every id that is only
    a marker, the next line threw, and every player's spawn screen showed exactly one wake point. The
    page was fine, the harness was green, and nothing in the payload said it was incomplete.

    THE INVARIANT IS A COUNT, because a count is the one thing a truncating loop cannot fake:
    spawnPointList must return exactly as many rows as spawnPointCfg gave it. Anything less means a row
    threw. The per-row dump is secondary -- it tells you WHICH row, once the count says there is a
    problem.

    Run it on a client, at any time, in or out of the spawn screen; it reads state and writes nothing.
*/
private _cfg  = [AP_effSide, false, true] call AP_fnc_spawnPointCfg;
private _rows = [false] call AP_fnc_spawnPointList;

diag_log format ["[AP-PROBE] spawnlist: cfg=%1 rows=%2 %3",
    count _cfg, count _rows,
    if (count _cfg isEqualTo count _rows) then { "OK" } else { "*** TRUNCATED -- a row threw ***" }];

{
    diag_log format ["[AP-PROBE] spawnlist row %1: id=%2 label=%3 kind=%4 pos=[%5,%6] near=%7 reason=%8",
        _forEachIndex,
        (_cfg param [_forEachIndex, []]) param [0, "?"],
        _x getOrDefault ["label", "?"],
        _x getOrDefault ["kind", "?"],
        (_x getOrDefault ["x", 0]) toFixed 0,
        (_x getOrDefault ["y", 0]) toFixed 0,
        _x getOrDefault ["near", -1],
        _x getOrDefault ["reason", ""]];
} forEach _rows;

// Name the rows that fell off the end, so the log says WHICH id threw rather than only that one did.
if (count _rows < count _cfg) then {
    for "_i" from (count _rows) to ((count _cfg) - 1) do {
        diag_log format ["[AP-PROBE] spawnlist MISSING row %1: id=%2 label=%3",
            _i, (_cfg select _i) param [0, "?"], (_cfg select _i) param [1, "?"]];
    };
};
