/*
    File: fn_spawnScatterCheck.sqf  (AP_fnc_spawnScatterCheck)
    Boot invariant, server side: every town spawn scatter marker still puts a player on open ground.

        [] call AP_fnc_spawnScatterCheck;      // logs [AP-SPAWN] ...

    The five <town>_cspawn_* markers behind each civ_spawn_N live in the map layer, which means a
    designer can drag one in Eden Live, or delete it, and nothing would say so until a player
    spawned inside a wall. This says so at boot, in one line when all is well and one line per bad
    marker when it is not.

    IT ASKS A NARROWER QUESTION THAN THE PROBE THAT PLACED THEM, on purpose. debug\probe_townspawn.sqf
    is choosing fifteen points out of seven hundred, so it can afford to reject anything doubtful:
    a roof overhead, a building within 3 m, a wall within 1.2 m in any direction. Those are not
    faults. A shop doorway has a roof over it and a wall beside it, and three of the designer's own
    Larche and La Trinite spawn points -- live and working for weeks -- are exactly that; the first
    version of this check called all three BAD. What actually strands a player is being sealed
    inside geometry, in water, or on a cliff, so that is what is asked here: a marker that is
    missing, wet, steep, or boxed in on all eight sides. isFlatEmpty is asked only about gradient
    and water -- its proximity test counts a whole bounding sphere and rejects every town position.
*/
private _sets = [
    ["civ_spawn_1", ["lt_cspawn_1", "lt_cspawn_2", "lt_cspawn_3", "lt_cspawn_4", "lt_cspawn_5"]],
    ["civ_spawn_2", ["lh_civspawn_1", "lh_civspawn_2", "lh_civspawn_3", "lh_civspawn_4", "lh_civspawn_5"]],
    ["civ_spawn_3", ["lp_cspawn_1", "lp_cspawn_2", "lp_cspawn_3", "lp_cspawn_4", "lp_cspawn_5"]],
    ["civ_spawn_4", ["ch_cspawn_1", "ch_cspawn_2", "ch_cspawn_3", "ch_cspawn_4", "ch_cspawn_5"]],
    ["civ_spawn_5", ["ps_cspawn_1", "ps_cspawn_2", "ps_cspawn_3", "ps_cspawn_4", "ps_cspawn_5"]]
];
private _ok = 0;
private _bad = 0;
{
    _x params ["_town", "_markers"];
    if ((markerType _town) isEqualTo "") then {
        _bad = _bad + 1;
        diag_log format ["[AP-SPAWN] WARN the town marker %1 is missing -- it is listed in AP_fnc_spawnPointCfg and would drop a player at [0,0,0]", _town];
    };
    {
        private _p = getMarkerPos _x;
        private _why = "";
        if ((markerType _x) isEqualTo "" || {_p isEqualTo [0,0,0]}) then { _why = "missing"; } else {
            _p set [2, 0];
            private _g = getTerrainHeightASL _p;
            private _chest = [_p select 0, _p select 1, _g + 1];
            if (surfaceIsWater _p) then { _why = "in water"; };
            if (_why isEqualTo "" && {(_p isFlatEmpty [-1, -1, 0.6, 6, 0, false, objNull]) isEqualTo []}) then { _why = "on a slope"; };
            if (_why isEqualTo "") then {
                private _open = 0;
                {
                    private _r = _x * 45;
                    if ((count (lineIntersectsSurfaces [_chest, [(_chest select 0) + 1.2 * sin _r, (_chest select 1) + 1.2 * cos _r, _chest select 2], objNull, objNull, true, 1, "GEOM", "NONE"])) isEqualTo 0) then { _open = _open + 1; };
                } forEach [0, 1, 2, 3, 4, 5, 6, 7];
                if (_open isEqualTo 0) then { _why = "sealed inside geometry"; };
            };
        };
        if (_why isEqualTo "") then { _ok = _ok + 1; } else {
            _bad = _bad + 1;
            diag_log format ["[AP-SPAWN] WARN %1 (%2) is %3 at %4 -- a player spawning there is stuck; move it in Eden or drop it from fn_spawnConfirm", _x, _town, _why, _p];
        };
    } forEach _markers;
} forEach _sets;
diag_log format ["[AP-SPAWN] town scatter: %1 of %2 spawn points standable%3", _ok, _ok + _bad, if (_bad isEqualTo 0) then { "" } else { format [" -- %1 BAD", _bad] }];
// The same markers are the town list behind AP_fnc_nearTown ("no tree / tent / campfire / execution
// / care package in town"). Six hand-written copies of that list had rotted to one town between
// them, each one silently, so the rule is asked here whether it can still see all five.
private _seen = 0;
{
    private _ctr = getMarkerPos (_x select 0);
    if (!(_ctr isEqualTo [0,0,0]) && {[120, _ctr] call AP_fnc_nearTown}) then { _seen = _seen + 1; } else {
        diag_log format ["[AP-SPAWN] WARN AP_fnc_nearTown cannot see %1 -- every 'not in town' rule has stopped applying there", _x select 0];
    };
} forEach _sets;
diag_log format ["[AP-SPAWN] town-proximity rule sees %1 of %2 towns", _seen, count _sets];
