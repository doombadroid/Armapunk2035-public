/*
    File: fn_factionTerritory.sqf  (AP_fnc_factionTerritory)

    "Whose ground am I standing on?"

        [_pos]  call AP_fnc_factionTerritory   -> "f_neon" | ... | ""
        []      call AP_fnc_factionTerritory   -> the same, for the local player
        ["flush"] call AP_fnc_factionTerritory -> drop the cache (config reload only)

    "" is NEUTRAL and is the answer for most of the map: La Trinite, the northern
    cartel belt, and every road between them. Neutrality is the absence of an owner
    rather than an owner of its own -- the same discipline the standing blobs use
    for zero, and it means adding or removing a territory never needs a "neutral"
    entry maintained alongside it.

    WHY THIS EXISTS WHEN fn_factionCfg ALREADY HAS "territoryOf". Because of who
    calls it. The name-tag ladder asks this question for every rendered unit, and
    the territory banner asks it on a timer; routing that through the config
    function would rebuild a four-row array of eight-point polygons, with its
    blurbs and display names, on every single call. This caches the ONLY part that
    matters -- id and polygon -- once, and answers out of that.

    The cache is built from fn_factionCfg and is therefore not a second source of
    truth: it cannot disagree about where a border is, only about WHEN it noticed a
    change. Config is compiled into the mission and cannot change at runtime, so
    the only thing that invalidates it is a developer reloading functions, which is
    what "flush" is for. It is deliberately not time-based -- a periodic rebuild
    would spend work forever to catch an event that never happens in a live game.

    A faction with an EMPTY polygon (f_maxsec, reserved) is skipped at cache-build
    time rather than tested and rejected per call. An empty polygon must never be
    read as "matches everywhere", which is what `inPolygon []` returning false
    saves us from -- but relying on that would be relying on an engine edge case,
    so it is filtered out here where the intent is visible.

    inPolygon WANTS Position3D ON BOTH SIDES. The engine ignores Z in VALUE, not in
    ARITY: a two-element position or a two-element vertex throws "2 elements
    provided, 3 expected" -- once per polygon, every 3 s, on every client (the
    2026-09-01 RPT had 738 of them). fn_factionCfg stores the polygons as [x,y]
    pairs on purpose (that is what tools/bake_territory.py writes and what the web
    map draws), so the lift to [x,y,0] happens HERE, once, when the cache is built,
    and the query point is lifted the same way below.
*/
params [["_pos", [], [[], ""]]];

if (_pos isEqualType "") exitWith {
    if (toLower _pos isEqualTo "flush") then {
        missionNamespace setVariable ["AP_territoryCache", nil];
    };
    ""
};

private _cache = missionNamespace getVariable ["AP_territoryCache", []];
if (_cache isEqualTo []) then {
    {
        private _id   = _x select 0;
        private _poly = _x param [5, []];
        if (_poly isNotEqualTo []) then {
            _cache pushBack [_id, _poly apply { [_x select 0, _x select 1, 0] }];
        };
    } forEach (["all"] call AP_fnc_factionCfg);
    missionNamespace setVariable ["AP_territoryCache", _cache];
};

// No argument means "where I am". Resolved here rather than defaulted in params
// because getPosATL on a null player during early init is not something a caller
// should have to think about.
if (_pos isEqualTo []) then {
    _pos = if (isNull player) then { [] } else { getPosATL player };
};
if (count _pos < 2) exitWith { "" };

private _p = [_pos select 0, _pos select 1, 0];   // Position3D, see header
private _hit = "";
{
    if (_p inPolygon (_x select 1)) exitWith { _hit = _x select 0; };
} forEach _cache;
_hit
