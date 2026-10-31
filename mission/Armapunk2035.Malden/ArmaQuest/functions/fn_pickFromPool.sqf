// SPDX-License-Identifier: MIT
/*
    functions/fn_pickFromPool.sqf

    Purpose: draw one value for a radiant slot — a pool entry or a rolled
    integer — subject to declarative constraints, using a seeded generator so
    the same seed always yields the same draw.

    WHY THIS EXISTS
    A radiant quest is only as good as the values poured into it. Left
    unconstrained, a generator will happily send a player to the settlement they
    are standing in, or to the same settlement three times in one evening, and
    every such quest teaches the player that generated content is noise. The
    constraint pass is therefore not a nicety layered on top of the draw: it is
    the draw. Candidates that violate a constraint are removed *before* the
    random pick, so an impossible slot reports "0 of 7 entries survive: 4 too
    close, 3 used too recently" instead of silently returning something wrong.

    The generator is seeded and self-contained — it never touches the engine's
    global random state — so a dry run can replay a generation exactly, and one
    generation cannot perturb unrelated random behaviour elsewhere in a mission.

    WHAT IT DOES
      Pool slot (`pool` names a class under AQ_Pools):
        1. Reads the pool's entries. Each entry class carries
             label   what a human reads      (default: the class name)
             value   what the engine uses    (default: the class name)
             marker  the entry's position    (optional)
             position[] a literal position, when no marker exists
             tags[]  free-form filter labels
             weight  relative likelihood     (default 1)
        2. Filters entries, in order:
             tags / excludeTags   entry must carry all / none of them
             distanceFrom         "giver" | "player" | "slot:<NAME>", min/max
                                  metres; max = 0 means no upper bound
             notUsedWithin        seconds, against a caller-supplied history
             allowRepeat = 0   an entry already taken by another slot of the
                                  same pool in this instance is not eligible
        3. Draws from the survivors, weighted.
      Numeric slot (no `pool`): rolls an integer in [min, max], on `step`.

    Returns  [true, VALUE, POSITION, HISTORYKEY]
               VALUE      HASHMAP for a pool slot: "label" "value" "marker"
                          "tags" "pos"; NUMBER for a numeric slot
               POSITION   [] when the entry has none
               HISTORYKEY "" when the slot declares no notUsedWithin
             [false, "reason"]   constraint or config failure, written for a
                                 human reading the RPT.

    Usage:
        private _spec = createHashMapFromArray [
            ["pool", "settlements"], ["distanceFrom", "giver"],
            ["min", 800], ["max", 5000], ["notUsedWithin", 3600]
        ];
        private _r = ["PLACE", _spec, _ctx] call aq_fnc_pickFromPool;
        if (_r select 0) then { private _entry = _r select 1; };
*/

params [
    ["_slot", "", [""]],
    ["_spec", createHashMap, [createHashMap]],
    ["_ctx",  createHashMap, [createHashMap]]
];

if (_slot isEqualTo "") exitWith {
    diag_log text "[AQ] pickFromPool: called with an empty slot name";
    [false, "empty slot name"]
};

// ---------------------------------------------------------------- generator --
// Wichmann-Hill. Chosen deliberately over a classic 32-bit LCG: SQF scalars are
// 32-bit floats, so any generator whose intermediate products exceed 2^24 loses
// its low bits and degenerates. Every product here stays under 5.3 million, so
// the arithmetic is exact in single precision and the sequence is reproducible
// on any machine that runs the mission.
private _rng = _ctx getOrDefault ["rng", []];
if (count _rng != 3) then {
    private _seed = _ctx getOrDefault ["seed", -1];
    if (!(_seed isEqualType 0) || {_seed < 0}) then {
        // No seed supplied: take one from the engine and record it, so even an
        // unseeded generation can be replayed afterwards from the log.
        _seed = floor (random 1000000);
        _ctx set ["seed", _seed];
    };
    // Fold the seed into six digits before mixing, so the mixing products stay
    // inside the range a 32-bit float counts exactly. Otherwise two callers
    // passing the same large seed could drift apart on rounding.
    _seed = (floor (abs _seed)) mod 1000000;
    _rng = [
        1 + (_seed mod 30268),
        1 + ((_seed * 3 + 7) mod 30306),
        1 + ((_seed * 11 + 13) mod 30322)
    ];
    _ctx set ["rng", _rng];
};

// Returns a uniform in [0,1). Mutates _rng in place; `call` shares this scope.
private _uniform = {
    _rng params ["_s1", "_s2", "_s3"];
    _s1 = (171 * _s1) mod 30269;
    _s2 = (172 * _s2) mod 30307;
    _s3 = (170 * _s3) mod 30323;
    _rng set [0, _s1];
    _rng set [1, _s2];
    _rng set [2, _s3];
    private _v = (_s1 / 30269) + (_s2 / 30307) + (_s3 / 30323);
    _v - (floor _v)
};

private _specKeys = keys _spec;
private _poolName = _spec getOrDefault ["pool", ""];
// An inline candidate list is the seam that keeps every random choice in the
// generator inside this one function: the caller choosing among templates has a
// weighted pick to make and no pool to make it from. Entries are plain strings
// and become minimal entry records.
private _inline   = _spec getOrDefault ["values", []];

// ------------------------------------------------------------ numeric slot --
if (_poolName isEqualTo "" && {_inline isEqualTo []}) exitWith {
    // No pool: min/max are the value range. Integers only — a slot feeding an
    // objective count or a reward multiplier is never fractional.
    if (!("min" in _specKeys) || {!("max" in _specKeys)}) exitWith {
        diag_log text ("[AQ] pickFromPool: slot '" + _slot + "' declares neither a pool nor a numeric min/max");
        [false, "declares neither a pool nor a numeric min/max"]
    };
    private _min = _spec get "min";
    private _max = _spec get "max";
    if (!(_min isEqualType 0) || {!(_max isEqualType 0)}) exitWith {
        diag_log text ("[AQ] pickFromPool: slot '" + _slot + "' has a non-numeric min/max");
        [false, "non-numeric min/max"]
    };
    if (_max < _min) exitWith {
        diag_log text ("[AQ] pickFromPool: slot '" + _slot + "' has max below min");
        [false, "max is below min"]
    };
    private _step = _spec getOrDefault ["step", 1];
    if (!(_step isEqualType 0) || {_step < 1}) then { _step = 1 };
    _step = floor _step;

    private _lo = floor _min;
    private _hi = floor _max;
    // Roll in units of step, then scale back, so the result is always a
    // multiple of step above min and never exceeds max.
    private _units = floor ((_hi - _lo) / _step);
    private _v = _lo + (_step * (floor ((call _uniform) * (_units + 1))));
    if (_v > _hi) then { _v = _hi };   // float guard; the draw is [0,1)
    [true, _v, [], ""]
};

// --------------------------------------------------------------- pool entries --
// Where a duplicate is remembered, and what a history stamp is filed under.
private _nsKey = if (_poolName != "") then { _poolName } else { _slot };
private _entries = [];
private _poolMissing = false;

if (_poolName isEqualTo "") then {
    private _iw = _spec getOrDefault ["weights", []];
    {
        private _e = createHashMap;
        private _v = if (_x isEqualType "") then { _x } else { str _x };
        _e set ["id", _v];
        _e set ["label", _v];
        _e set ["value", _v];
        _e set ["marker", ""];
        _e set ["tags", []];
        _e set ["position", []];
        _e set ["weight", if (_forEachIndex < count _iw) then { _iw select _forEachIndex } else { 1 }];
        _entries pushBack _e;
    } forEach _inline;
} else {
    // The index built at preInit is the fast path. The config walk behind it is
    // for a caller running before preInit — a validator, or a dry run in a test
    // harness. Entries are read at generation time, which is a board refill and
    // not a hot path; nothing here runs per frame or per event.
    private _pool = configNull;
    if (!isNil "aq_idxPool") then {
        _pool = aq_idxPool getOrDefault [_poolName, configNull];
    };
    if (isNull _pool) then {
        _pool = missionConfigFile >> "AQ_Pools" >> _poolName;
        if (!isClass _pool) then { _pool = configFile >> "AQ_Pools" >> _poolName };
    };
    if (!isClass _pool) then {
        _poolMissing = true;
    } else {
        {
            private _e = createHashMap;
            private _cn = configName _x;
            // label and value both default to the class name, so a pool of bare
            // classes is legal and reads sensibly in both halves of a token.
            _e set ["id", _cn];
            _e set ["label",  if (isText (_x >> "label"))  then { getText (_x >> "label") }  else { _cn }];
            _e set ["value",  if (isText (_x >> "value"))  then { getText (_x >> "value") }  else { _cn }];
            _e set ["marker", if (isText (_x >> "marker")) then { getText (_x >> "marker") } else { "" }];
            _e set ["tags",   if (isArray (_x >> "tags"))  then { getArray (_x >> "tags") }  else { [] }];
            _e set ["weight", if (isNumber (_x >> "weight")) then { getNumber (_x >> "weight") } else { 1 }];
            _e set ["position", if (isArray (_x >> "position")) then { getArray (_x >> "position") } else { [] }];
            _entries pushBack _e;
        } forEach ("true" configClasses _pool);
    };
};

if (_poolMissing) exitWith {
    diag_log text ("[AQ] pickFromPool: slot '" + _slot + "' names pool '" + _poolName + "', which does not exist");
    [false, "pool '" + _poolName + "' does not exist"]
};
if (_entries isEqualTo []) exitWith {
    diag_log text ("[AQ] pickFromPool: slot '" + _slot + "' draws from '" + _nsKey + "', which has no entries");
    [false, "'" + _nsKey + "' has no entries to draw from"]
};

// --------------------------------------------------------------- constraints --
private _distFrom      = _spec getOrDefault ["distanceFrom", ""];
private _notUsedWithin = _spec getOrDefault ["notUsedWithin", 0];
private _allowDup      = (_spec getOrDefault ["allowRepeat", 0]) > 0;
private _tags          = _spec getOrDefault ["tags", []];
private _excludeTags   = _spec getOrDefault ["excludeTags", []];
private _minD          = _spec getOrDefault ["min", 0];
private _maxD          = _spec getOrDefault ["max", 0];
if (_maxD <= 0) then { _maxD = 1e9 };   // 0 on a pool slot means no upper bound

if (_distFrom isEqualTo "" && {("min" in _specKeys) || {"max" in _specKeys}}) exitWith {
    // min/max on a pool slot can only mean a distance band, and a distance band
    // with nothing to measure from is an authoring mistake that would otherwise
    // be ignored completely.
    diag_log text ("[AQ] pickFromPool: slot '" + _slot + "' sets min/max but no distanceFrom");
    [false, "min/max on a pool slot requires distanceFrom"]
};

// Anchor for the distance constraint.
private _anchor = [];
private _anchorNote = "";
if (_distFrom != "") then {
    switch (true) do {
        case (_distFrom == "giver"): {
            _anchor = _ctx getOrDefault ["giverPos", []];
        };
        case (_distFrom == "player"): {
            _anchor = _ctx getOrDefault ["playerPos", []];
            if (count _anchor < 2) then {
                private _p = _ctx getOrDefault ["player", objNull];
                if (!isNull _p) then { _anchor = getPosWorld _p };
            };
            if (count _anchor < 2) then {
                // A shared board rolls offers that belong to nobody yet, so
                // there is no player to measure from. The giver is the honest
                // substitute: it is a real place, the offer comes from it, and
                // the distance band still means what it was written to mean.
                // Dropping the constraint instead would put a "far away" job
                // next door, which is the outcome the band exists to prevent.
                _anchor = _ctx getOrDefault ["giverPos", []];
                if (count _anchor >= 2) then {
                    _anchorNote = "no player to measure from; measured from the giver instead";
                };
            };
        };
        case ((_distFrom select [0, 5]) == "slot:"): {
            private _other = _distFrom select [5];
            private _slotPos = _ctx getOrDefault ["slotPos", createHashMap];
            _anchor = _slotPos getOrDefault [_other, []];
            if (count _anchor < 2) then {
                diag_log text ("[AQ] pickFromPool: slot '" + _slot + "' anchors on slot '" + _other + "', which has no position - either it does not exist, it has no marker, or it was resolved after this slot");
            };
        };
        default {
            diag_log text ("[AQ] pickFromPool: slot '" + _slot + "' has unknown distanceFrom '" + _distFrom + "'");
        };
    };
};
if (_distFrom != "" && {count _anchor < 2}) exitWith {
    [false, "distanceFrom '" + _distFrom + "' has no position to measure from"]
};
if (_anchorNote != "") then {
    diag_log text ("[AQ] pickFromPool: slot '" + _slot + "' - " + _anchorNote);
};

// Key presence, not a nil default: "no clock supplied" and "the clock reads 0"
// must not look the same.
private _hasNow  = "now" in (keys _ctx);
private _now     = _ctx getOrDefault ["now", 0];
private _history = _ctx getOrDefault ["history", createHashMap];
// An empty history excludes nothing, whatever the clock reads, so a first-run
// board is not blocked by a constraint that has nothing to compare against. A
// history that exists with no clock to read it against is different: that is a
// caller bug, and honouring it by guessing would send a player somewhere the
// history says not to.
if (_notUsedWithin > 0 && {count _history > 0} && {!_hasNow}) exitWith {
    diag_log text ("[AQ] pickFromPool: slot '" + _slot + "' uses notUsedWithin and a history was supplied, but the context carries no 'now' to measure it against");
    [false, "notUsedWithin needs a 'now' in the context, on the same clock as the stored history"]
};

private _poolPicks = _ctx getOrDefault ["poolPicks", createHashMap];
private _taken = _poolPicks getOrDefault [_nsKey, []];

// ------------------------------------------------------------------ filter ---
private _keep  = [];
private _keepW = [];
private _rejTag   = 0;
private _rejNoPos = 0;
private _rejNear  = 0;
private _rejFar   = 0;
private _rejUsed  = 0;
private _rejDup   = 0;
private _rejZeroW = 0;

{
    private _e = _x;
    private _val = _e get "value";
    private _pos = [];
    private _drop = false;

    // tags: must carry all of tags[], none of excludeTags[]
    if (count _tags > 0 || {count _excludeTags > 0}) then {
        private _et = _e get "tags";
        {
            if (!(_x in _et)) exitWith { _drop = true };
        } forEach _tags;
        if (!_drop) then {
            {
                if (_x in _et) exitWith { _drop = true };
            } forEach _excludeTags;
        };
        if (_drop) then { _rejTag = _rejTag + 1 };
    };

    if (!_drop && {!_allowDup} && {_val in _taken}) then { _drop = true; _rejDup = _rejDup + 1 };

    // Position, if the entry has one. Wanted even without a distance
    // constraint: a later slot may anchor on this one.
    if (!_drop) then {
        private _mk = _e get "marker";
        if (_mk != "") then {
            private _mp = getMarkerPos _mk;
            // UNVERIFIED: getMarkerPos answers [0,0,0] for a marker that does not
            // exist here, which is indistinguishable from a marker placed at the
            // map origin. aq_fnc_validate reports pool markers it cannot find;
            // confirm there rather than trusting this.
            if (!(_mp isEqualTo [0,0,0])) then { _pos = _mp };
        };
        if (count _pos < 2) then {
            private _lp = _e get "position";
            if (count _lp >= 2) then { _pos = _lp };
        };
        _e set ["pos", _pos];
    };

    if (!_drop && {_distFrom != ""}) then {
        if (count _pos < 2) then {
            _drop = true;
            _rejNoPos = _rejNoPos + 1;
        } else {
            // Ground distance: markers, world positions and unit positions all
            // agree on x and y, and a hill between two points is not a quest
            // constraint.
            private _dx = (_pos select 0) - (_anchor select 0);
            private _dy = (_pos select 1) - (_anchor select 1);
            private _d = sqrt ((_dx * _dx) + (_dy * _dy));
            if (_d < _minD) then { _drop = true; _rejNear = _rejNear + 1 };
            if (!_drop && {_d > _maxD}) then { _drop = true; _rejFar = _rejFar + 1 };
        };
    };

    if (!_drop && {_notUsedWithin > 0}) then {
        private _last = _history getOrDefault [_nsKey + ":" + _val, -1e12];
        if ((_now - _last) < _notUsedWithin) then { _drop = true; _rejUsed = _rejUsed + 1 };
    };

    if (!_drop) then {
        private _w = _e get "weight";
        if (!(_w isEqualType 0)) then { _w = 1 };
        if (_w > 0) then {
            _keep pushBack _e;
            _keepW pushBack _w;
        } else {
            _rejZeroW = _rejZeroW + 1;
        };
    };
} forEach _entries;

if (_keep isEqualTo []) exitWith {
    // Every tally is named, because "generation failed" without the numbers
    // sends an author back to guess which constraint to loosen.
    private _why = "0 of " + str (count _entries) + " entries in '" + _nsKey + "' survive: "
        + str _rejTag + " filtered by tags, "
        + str _rejNear + " nearer than " + str _minD + "m, "
        + str _rejFar + " further than " + str _maxD + "m, "
        + str _rejNoPos + " with no position to measure, "
        + str _rejUsed + " used within " + str _notUsedWithin + "s, "
        + str _rejDup + " already taken by another slot, "
        + str _rejZeroW + " with zero weight";
    [false, _why]
};

// -------------------------------------------------------------------- draw ---
private _total = 0;
{ _total = _total + _x } forEach _keepW;
private _roll = (call _uniform) * _total;
private _idx = (count _keep) - 1;
private _acc = 0;
{
    _acc = _acc + _x;
    if (_roll < _acc) exitWith { _idx = _forEachIndex };
} forEach _keepW;

private _entry = _keep select _idx;
private _pos   = _entry getOrDefault ["pos", []];

_taken pushBack (_entry get "value");
_poolPicks set [_nsKey, _taken];
_ctx set ["poolPicks", _poolPicks];

private _histKey = if (_notUsedWithin > 0) then { _nsKey + ":" + (_entry get "value") } else { "" };

[true, _entry, _pos, _histKey]
