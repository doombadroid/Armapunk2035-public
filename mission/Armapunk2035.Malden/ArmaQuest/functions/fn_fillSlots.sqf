// SPDX-License-Identifier: MIT
/*
    functions/fn_fillSlots.sqf

    Purpose: resolve every slot a template declares, in dependency order, then
    substitute the resulting %NAME% tokens textually and totally through a raw
    quest instance.

    WHY THIS EXISTS
    A template is a quest with holes in it, and three things go wrong with holes.

    A hole that stays open: a title reading "Clear %ENEMY% out of %PLACE%"
    reaches a player and the whole system reads as broken. So a token with no
    slot is a hard error that kills the instance rather than a blank.

    A hole that closes wrongly: an objective's count = "%COUNT%" stays the string
    "7" instead of the number 7, and a type comparing progress against a string
    never completes. So a field that is exactly one numeric token becomes an
    actual number.

    A hole that closes with the wrong half: a pool entry has a name a human reads
    and an id the engine uses, and pasting the id into a title gives
    "Courier run to aq_place_quarry" while pasting the name into a marker field
    gives an objective pointing at nothing. So which half a token expands to
    depends on the field it sits in — the entry's label in text a player sees,
    its value everywhere else — and either half can be named explicitly.

    WHAT IT DOES
      1. Orders the slots: those with no distance constraint first, then those
         anchored on the giver or the player, then those anchored on another
         slot, each after the slot it measures from. Declaration order cannot be
         trusted for this, because an author writing the anchored slot first is
         making a reasonable mistake, not an unreasonable one. A cycle between
         two anchored slots is reported by name instead of looping.
      2. Builds a spec per slot and hands it to aq_fnc_pickFromPool.
      3. Walks every string, array and nested map in the instance and rewrites
         its tokens.

    TOKEN GRAMMAR
        %NAME%          the slot's label in a text field (title, summary,
                        description, an objective's text), its value elsewhere;
                        for a numeric slot, the rolled number
        %NAME.label%    always the entry's label
        %NAME.value%    always the entry's value
        %NAME.marker%   always the entry's marker
    A name is letters, digits and underscore — the same characters a config class
    name may use, so every real slot is covered. Anything else between percent
    signs is ordinary prose ("50% off") and is left alone. A near miss with no
    spaces in it, such as a mistyped %some-place%, cannot be a slot and is left
    as text, but it is logged: a typo that quietly disables a token is the same
    class of silence as a typo that quietly disables a constraint.

    A field carrying a token must be inline text. A "$STR_" key is substituted as
    written, so the token would have to be in the key itself — the stringtable is
    read long after this pass. The read path substitutes again from the record's
    flat map, which is what makes a localized line with a token in it work.

    Returns  [true, SLOTS, SLOTPOS, USEDKEYS, FLAT]
               SLOTS     name -> entry HashMap (pool) or NUMBER (numeric)
               SLOTPOS   name -> world position, for slots that have one
               USEDKEYS  [["pool:value", notUsedWithinSeconds], ...] — the entry
                         this instance spent and the window the slot that drew it
                         asked for. The pair travels together because the stamp
                         the caller writes records WHEN, and the window is a
                         property of the slot rather than of the entry: two
                         templates may draw one pool entry with two different
                         windows, and neither may decide for the other
               FLAT      name (and name.label/.value/.marker) -> STRING, for the
                         text read path
             [false, "reason"]   — the instance is discarded by the caller.

    Usage:
        private _r = [_inst, _tpl >> "slots", _ctx] call aq_fnc_fillSlots;
        if !(_r select 0) then { diag_log text ("[AQ] " + (_r select 1)) };
*/

params [
    ["_inst",     createHashMap, [createHashMap]],
    ["_slotsCfg", configNull,    [configNull]],
    ["_ctx",      createHashMap, [createHashMap]]
];

private _slots   = createHashMap;
private _slotPos = createHashMap;
private _used    = [];
private _flat    = createHashMap;
_ctx set ["slots", _slots];
_ctx set ["slotPos", _slotPos];
_ctx set ["poolPicks", createHashMap];   // fresh per generation: the no-duplicate
                                         // rule is about one instance, not the day.

// Members a slot class may declare. Anything else is a typo, and a typo in a
// constraint silently removes the constraint, which is the failure this module
// exists to prevent — so it is named rather than ignored.
private _known = ["pool", "values", "weights", "tags", "excludeTags",
                  "distanceFrom", "min", "max", "step", "notUsedWithin", "allowRepeat"];

// Fields a player reads. A token in one of these expands to an entry's label;
// everywhere else it expands to the entry's value.
private _textFields = ["title", "summary", "description", "text"];

// --------------------------------------------------------------- read slots --
private _names = [];
private _specs = createHashMap;
if (isClass _slotsCfg) then {
    {
        private _name = configName _x;
        private _spec = createHashMap;
        {
            private _k = configName _x;
            if (!(_k in _known)) then {
                diag_log text ("[AQ] fillSlots: slot '" + _name + "' declares unknown member '" + _k + "' (ignored)");
            } else {
                switch (true) do {
                    case (isNumber _x): { _spec set [_k, getNumber _x] };
                    case (isText _x):   { _spec set [_k, getText _x] };
                    case (isArray _x):  { _spec set [_k, getArray _x] };
                };
            };
        } forEach (configProperties [_x, "!isClass _x", false]);
        _names pushBack _name;
        _specs set [_name, _spec];
    } forEach ("true" configClasses _slotsCfg);
};

// ------------------------------------------------------------ order slots ----
// A stable three-way partition rather than a sort: there are exactly three
// classes of slot and a template has a handful of them.
private _plain    = [];   // no distance constraint
private _anchored = [];   // measured from the giver or the player
private _later    = [];   // measured from another slot
{
    private _d = (_specs get _x) getOrDefault ["distanceFrom", ""];
    switch (true) do {
        case (_d isEqualTo ""): { _plain pushBack _x };
        case ((_d select [0, 5]) == "slot:"): { _later pushBack _x };
        default { _anchored pushBack _x };
    };
} forEach _names;
private _order = _plain + _anchored;

// Slot-anchored slots resolve once the slot they name is resolved. Repeated
// sweeps rather than a graph walk: a template has a handful of slots, and a
// sweep that makes no progress is exactly the cycle we need to report.
private _guard = 0;
while {count _later > 0 && {_guard < 64}} do {
    _guard = _guard + 1;
    private _progress = false;
    private _still = [];
    {
        private _d = (_specs get _x) getOrDefault ["distanceFrom", ""];
        private _other = _d select [5];
        if (_other in _order) then {
            _order pushBack _x;
            _progress = true;
        } else {
            _still pushBack _x;
        };
    } forEach _later;
    _later = _still;
    if (!_progress) exitWith {};
};
if (count _later > 0) exitWith {
    private _why = "slots " + str _later + " anchor on a slot that never resolves - a cycle, or a name that is not a slot";
    diag_log text ("[AQ] fillSlots: " + _why);
    [false, _why]
};

// ----------------------------------------------------------- resolve slots ---
private _failSlot = "";
private _failWhy  = "";
{
    private _name = _x;
    private _r = [_name, _specs get _name, _ctx] call aq_fnc_pickFromPool;
    if !(_r select 0) exitWith {
        _failSlot = _name;
        _failWhy  = _r select 1;
    };

    private _val     = _r select 1;
    private _pos     = _r select 2;
    private _histKey = _r select 3;

    _slots set [_name, _val];
    if (count _pos >= 2) then { _slotPos set [_name, _pos] };
    if (_histKey != "") then {
        _used pushBackUnique [_histKey, (_specs get _name) getOrDefault ["notUsedWithin", 0]];
    };

    // The flat map is what the text read path uses when it resolves a field
    // straight from the template config. It holds strings only.
    if (_val isEqualType 0) then {
        _flat set [_name, str _val];
    } else {
        _flat set [_name, _val get "label"];
        _flat set [_name + ".label",  _val get "label"];
        _flat set [_name + ".value",  _val get "value"];
        _flat set [_name + ".marker", _val get "marker"];
    };
} forEach _order;

if (_failSlot != "") exitWith {
    [false, "slot '" + _failSlot + "': " + _failWhy]
};

// ------------------------------------------------------------- substitution --
private _slotNames = keys _slots;
private _failure = "";

// Rewrites one string. _isText selects which half of a pool entry an unqualified
// token expands to. Returns [ok, value]; value is a NUMBER when the whole field
// was a single unqualified numeric token, and a STRING otherwise. `call` shares
// this scope, so it reads _slots and _slotNames directly.
private _subst = {
    params ["_s", "_isText"];
    private _codes = toArray _s;
    // UNVERIFIED: toArray/toString round-trips non-ASCII text losslessly on
    // Arma 3 2.18. Confirm with a description containing accented characters;
    // if it does not, only literal text is affected, never a token.
    private _n = count _codes;
    private _out = [];
    private _i = 0;
    // Holder array rather than a bare variable: "no number yet" has no safe
    // initial value of its own, and a variable that starts undefined is not
    // reliably visible to an assignment made inside a nested block.
    private _wholeNumber = [];
    private _bad = "";

    while {_i < _n} do {
        private _c = _codes select _i;
        if (_c != 37) then {                       // 37 = '%'
            _out pushBack _c;
            _i = _i + 1;
        } else {
            private _j = _i + 1;
            private _tok = [];
            private _closed = false;
            private _scan = true;
            while {_scan && {_j < _n}} do {
                private _cc = _codes select _j;
                if (_cc == 37) then {
                    _closed = true;
                    _scan = false;
                } else {
                    // 46 = '.', the qualifier separator
                    if ((_cc >= 65 && {_cc <= 90}) || {(_cc >= 97 && {_cc <= 122})} || {(_cc >= 48 && {_cc <= 57})} || {_cc == 95} || {_cc == 46}) then {
                        _tok pushBack _cc;
                        _j = _j + 1;
                    } else {
                        _scan = false;
                    };
                };
            };

            if (_closed && {count _tok > 0}) then {
                private _whole = toString _tok;
                private _parts = _whole splitString ".";
                private _key = _parts select 0;
                private _qual = if (count _parts > 1) then { toLower (_parts select 1) } else { "" };

                // "NAME." and "NAME.a.b" are malformed, not lenient shorthand.
                if (count _parts > 2 || {_key isEqualTo ""} || {count _parts < 2 && {_whole != _key}}) then {
                    if (_bad isEqualTo "") then { _bad = _whole };
                } else {
                    if (_key in _slotNames) then {
                        private _v = _slots get _key;
                        private _txt = "";
                        private _numeric = _v isEqualType 0;

                        if (_numeric) then {
                            if (_qual != "") then {
                                // A rolled number has no label, value or marker,
                                // and quietly ignoring the qualifier would hide
                                // the author's misunderstanding.
                                if (_bad isEqualTo "") then { _bad = _whole };
                            } else {
                                if (_i == 0 && {_j == (_n - 1)}) then {
                                    _wholeNumber pushBack _v;   // the field IS the slot
                                };
                                _txt = str _v;
                            };
                        } else {
                            _txt = switch (_qual) do {
                                case "":       { if (_isText) then { _v get "label" } else { _v get "value" } };
                                case "label":  { _v get "label" };
                                case "value":  { _v get "value" };
                                case "marker": { _v get "marker" };
                                default        { "" };
                            };
                            if (_qual != "" && {!(_qual in ["label", "value", "marker"])}) then {
                                if (_bad isEqualTo "") then { _bad = _whole };
                            };
                        };

                        { _out pushBack _x } forEach (toArray _txt);
                    } else {
                        // A token naming no slot is the failure this function
                        // exists to catch. Report the name, not a shrug.
                        if (_bad isEqualTo "") then { _bad = _whole };
                    };
                };
                _i = _j + 1;
            } else {
                // Not a token by the strict grammar. Left as written — but a
                // near miss is almost certainly a mistyped slot, and silence
                // there is what this module refuses to allow.
                private _k = _i + 1;
                private _mid = [];
                private _hasAlpha = false;
                private _hasSpace = false;
                private _lim = ((_i + 33) min _n) - 1;
                private _found = false;
                while {_k <= _lim && {!_found}} do {
                    private _cc = _codes select _k;
                    if (_cc == 37) then {
                        _found = true;
                    } else {
                        if ((_cc >= 65 && {_cc <= 90}) || {(_cc >= 97 && {_cc <= 122})}) then { _hasAlpha = true };
                        if (_cc == 32 || {_cc == 9}) then { _hasSpace = true };
                        _mid pushBack _cc;
                        _k = _k + 1;
                    };
                };
                if (_found && {_hasAlpha} && {!_hasSpace} && {count _mid > 0}) then {
                    diag_log text ("[AQ] fillSlots: '" + _s + "' contains '" + (toString _mid) + "' between percent signs; a slot name may only use letters, digits, underscore and one dotted qualifier, so this was left as literal text");
                };
                _out pushBack _c;
                _i = _i + 1;
            };
        };
    };

    if (_bad != "") exitWith { [false, _bad] };
    if (count _wholeNumber > 0) exitWith { [true, _wholeNumber select 0] };
    [true, toString _out]
};

// Iterative walk over the instance. A stack rather than a recursive helper: SQF
// has no clean way to declare a private recursive function inside a file, and a
// quest instance is only ever a few levels deep. Each entry carries whether the
// container sits inside a player-facing field, which is what decides label
// against value for the tokens inside it.
private _stack = [[_inst, false]];
while {count _stack > 0 && {_failure isEqualTo ""}} do {
    private _item = _stack deleteAt 0;
    private _node = _item select 0;
    private _nodeIsText = _item select 1;

    if (_node isEqualType createHashMap) then {
        {
            private _k = _x;
            private _v = _node get _k;
            private _isText = _nodeIsText || {(toLower _k) in _textFields};
            switch (true) do {
                case (_v isEqualType ""): {
                    private _r = [_v, _isText] call _subst;
                    if (_r select 0) then {
                        _node set [_k, _r select 1];
                    } else {
                        _failure = "token '" + (_r select 1) + "' in field '" + _k + "' fills no slot";
                    };
                };
                case (_v isEqualType createHashMap): { _stack pushBack [_v, _isText] };
                case (_v isEqualType []):            { _stack pushBack [_v, _isText] };
            };
        } forEach (keys _node);
    } else {
        {
            private _idx = _forEachIndex;
            private _v = _x;
            switch (true) do {
                case (_v isEqualType ""): {
                    private _r = [_v, _nodeIsText] call _subst;
                    if (_r select 0) then {
                        _node set [_idx, _r select 1];
                    } else {
                        _failure = "token '" + (_r select 1) + "' in an array element fills no slot";
                    };
                };
                case (_v isEqualType createHashMap): { _stack pushBack [_v, _nodeIsText] };
                case (_v isEqualType []):            { _stack pushBack [_v, _nodeIsText] };
            };
        } forEach _node;
    };
};

if (_failure != "") exitWith { [false, _failure] };

[true, _slots, _slotPos, _used, _flat]
