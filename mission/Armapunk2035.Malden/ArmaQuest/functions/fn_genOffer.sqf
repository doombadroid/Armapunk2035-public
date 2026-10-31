// SPDX-License-Identifier: MIT
/*
    functions/fn_genOffer.sqf

    Purpose: generate one concrete radiant quest instance for a giver — pick a
    template by weight, fill its slots, scale its rewards, and emit a HashMap
    shaped exactly like a parsed authored quest.

    WHY THIS EXISTS
    Radiant content earns its place only if the rest of the system cannot tell it
    from hand-authored content. The moment the state machine, the journal or a
    payout needs to know "is this one of the generated ones", every later feature
    grows a second code path and the two drift. So the product of this function
    is not a special object: it is a quest, with a synthetic id of the form
    "template#nonce". The "#" cannot appear in a config class name, so a
    generated id can never collide with an authored one, and any code holding
    the id can still tell where it came from without asking.

    The second reason is quality control. A template whose slots cannot all be
    satisfied — every settlement too close, every one of them visited an hour ago
    — must produce nothing at all. Half a quest, or a quest pointing at a place
    the constraints rejected, is worse than an empty board: the board recovers on
    the next roll, the bad quest is remembered. So a failed template is logged
    with the slot that failed and why, dropped from the candidate set, and the
    next template is tried.

    WHAT IT DOES
      1. Collects templates offered by this giver (givers[] empty = any giver)
         with weight > 0.
      2. Draws one, weighted, from the seeded generator.
      3. Copies the template into a raw instance: every scalar/array member
         except the generator's own directives, plus objectives (in declaration
         order) and rewards.
      4. aq_fnc_fillSlots resolves the slots and substitutes the tokens.
      5. aq_fnc_scaleReward applies scaleWith, if present.
      6. Stamps id, giver, template, seed, slots and the history keys the caller
         must persist, and returns.
      Failure at 3-5 drops that template and returns to 2.

    THE INSTANCE
        "id"        STRING   "bounty#481207"
        "radiant"   BOOL     true
        "template"  STRING   template class name
        "seed"      NUMBER   reproduces this exact generation
        "giver"     STRING   giver id it was generated for
        "slots"     HASHMAP  slot name -> the pool entry drawn (label, value,
                             marker, tags, pos) or the rolled number
        "subst"     HASHMAP  slot name -> STRING, plus the dotted forms, under
                             the name the text read path expects: a field
                             resolved straight from the template config then
                             substitutes to exactly what is already in the
                             instance
        "slotPos"   HASHMAP  slot name -> world position, where it has one
        "used"      ARRAY    [["pool:value", notUsedWithinSeconds], ...] — what
                             this instance spent and the window each slot asked
                             for. Stamped into the taker's history on accept, not
                             on generation: an offer nobody took must not burn
                             anybody's history
        "title" "summary" "description" "side" "chain" "icon"   STRING
        "requires"  ARRAY of STRING
        "repeatable" "timeLimit"  NUMBER
        "objectives" ARRAY of HASHMAP, declaration order, each with "id","type"
                     and the type's own members
        "rewards"   HASHMAP  "money" "xp" "items" "licenses"

    DESIGN NOTE (§4 ambiguity). The objective-type contract passes "cfg" as a
    CONFIG. A generated objective has no config class to point at — substitution
    produced new values that exist only in memory — so its parameters travel in
    the objective HashMap above, whose keys are the config member names one for
    one. The reading chosen is the one that keeps the authority in one place: the
    server hands a type its parameters, rather than a type reaching back into
    config and finding the unsubstituted template.

    THE CONTEXT  (one HashMap, passed down to every part of the generator)
        "giverPos"  ARRAY    position of the giver, for distanceFrom = "giver"
        "player"    OBJECT   requesting player, if there is one
        "playerPos" ARRAY    overrides the player's own position
        "now"       NUMBER   seconds, on the same clock the history was written
                             with; required only when a slot uses notUsedWithin
        "history"   HASHMAP  "pool:value" -> the epoch it was LAST USED, on the
                             same clock as "now". Whose history
                             it is, is the caller's decision: a player's for an
                             on-demand offer, the board's for a shared one. The
                             generator only needs it to be the right one.
        "seed"      NUMBER   optional; recorded on the instance either way
        "template"  STRING   optional; force one template
        "nonce"     STRING   optional; force the id suffix
      The generator also writes "rng", "slots", "slotPos" and "poolPicks" into
      the context as working state.

    Returns  the instance HashMap, or an EMPTY HashMap when nothing could be
             generated. Empty rather than nil or a pair, so a caller can write
             `if (count _inst > 0)` and nothing downstream has to unwrap a
             success flag before it can look at a quest. Every failure is
             already in the log by then, with the slot and the reason.

    The second argument may be the context below, or simply the player the offer
    is for (objNull for a shared board offer that belongs to nobody yet), which
    is the shortest call a board needs to make.

    Usage:
        private _ctx = createHashMapFromArray [
            ["giverPos", getMarkerPos "aq_giver_market"],
            ["now", _serverEpochSeconds],
            ["history", _playerHistory],
            ["seed", 481516]
        ];
        private _quest = ["market_trader", _ctx] call aq_fnc_genOffer;
        if (count _quest > 0) then { ... };
*/

params [
    ["_giver", "", [""]],
    ["_arg",   createHashMap, [createHashMap, objNull]]
];

// A player instead of a context is the board's short form: build the context
// around them so there is one code path from here down.
private _ctx = createHashMap;
if (_arg isEqualType createHashMap) then {
    _ctx = _arg;
} else {
    _ctx set ["player", _arg];
    if (!isNull _arg) then { _ctx set ["playerPos", getPosWorld _arg] };
};

if (_giver isEqualTo "") exitWith {
    diag_log text "[AQ] genOffer: called with an empty giver id";
    createHashMap
};

// Mission config first so a host can add templates without touching the addon.
private _root = missionConfigFile >> "AQ_Templates";
if (!isClass _root) then { _root = configFile >> "AQ_Templates" };
if (!isClass _root) exitWith {
    diag_log text "[AQ] genOffer: no AQ_Templates class in mission config or config file";
    createHashMap
};

// The giver's own position, when the caller did not supply one. A distance
// constraint anchored on the giver is the commonest of them all, so making the
// caller look this up would mean every caller looking it up the same way, and
// one of them eventually not doing it.
if (!("giverPos" in (keys _ctx))) then {
    private _gc = configNull;
    if (!isNil "aq_idxGiver") then { _gc = aq_idxGiver getOrDefault [_giver, configNull] };
    if (isNull _gc) then {
        _gc = missionConfigFile >> "AQ_Givers" >> _giver;
        if (!isClass _gc) then { _gc = configFile >> "AQ_Givers" >> _giver };
    };
    if (isClass _gc && {isText (_gc >> "marker")}) then {
        private _mk = getText (_gc >> "marker");
        if (_mk != "") then {
            private _mp = getMarkerPos _mk;
            if (!(_mp isEqualTo [0,0,0])) then { _ctx set ["giverPos", _mp] };
        };
    };
};

// A caller may force one template — aq_fnc_dryRun does, to print N instances of
// the same thing.
private _force = _ctx getOrDefault ["template", ""];

private _cands = [];
private _wts   = [];
{
    private _name = configName _x;
    private _wanted = (_force isEqualTo "") || {_name == _force};
    if (_wanted) then {
        private _givers = if (isArray (_x >> "givers")) then { getArray (_x >> "givers") } else { [] };
        // No givers[] means "any giver": a single-giver mission should not have
        // to repeat the giver id in every template.
        if (_givers isEqualTo [] || {_giver in _givers}) then {
            private _w = if (isNumber (_x >> "weight")) then { getNumber (_x >> "weight") } else { 1 };
            if (_w > 0) then {
                _cands pushBack _name;
                _wts pushBack _w;
            };
        };
    };
} forEach ("true" configClasses _root);

if (_cands isEqualTo []) exitWith {
    private _why = if (_force != "") then {
        "template '" + _force + "' does not exist, or is not offered by giver '" + _giver + "'"
    } else {
        "no template with weight > 0 is offered by giver '" + _giver + "'"
    };
    diag_log text ("[AQ] genOffer: " + _why);
    createHashMap
};

// One seed per offer, recorded on the instance. A board rolling K offers reuses
// one context, so the generator state carries from call to call: this call takes
// its own seed from that running state and then re-seeds from it. The sequence
// therefore keeps varying, while any single offer can still be reproduced on its
// own — hand aq_fnc_dryRun a fresh context carrying that seed and no "rng" key.
// What a seed cannot reproduce is the world: constraint filtering also depends
// on marker positions and on the history and clock the caller supplies, so a
// replay matches only when those match too.
private _seed = _ctx getOrDefault ["seed", -1];
if ("rng" in (keys _ctx)) then {
    private _sp = ["__offerSeed", createHashMapFromArray [["min", 0], ["max", 999999]], _ctx] call aq_fnc_pickFromPool;
    if (_sp select 0) then { _seed = _sp select 1 };
};
if (!(_seed isEqualType 0) || {_seed < 0}) then { _seed = floor (random 1000000) };
_ctx set ["seed", _seed];
_ctx deleteAt "rng";

// Members the generator consumes itself; everything else on a template is quest
// data and is copied through, so a field added to the quest schema later needs
// no change here.
private _directives = ["weight", "givers"];

private _result = createHashMap;
private _done = false;

while {!_done && {count _cands > 0}} do {
    // The template choice is a weighted draw like any other, so it goes through
    // the same seeded generator: one place owns randomness, and a recorded seed
    // therefore reproduces the choice of template as well as the slot fills.
    private _pick = ["__template", createHashMapFromArray [["values", _cands], ["weights", _wts], ["allowRepeat", 1]], _ctx] call aq_fnc_pickFromPool;
    if !(_pick select 0) then {
        diag_log text ("[AQ] genOffer: could not draw a template for giver '" + _giver + "': " + (_pick select 1));
        _done = true;
    } else {
        private _name = (_pick select 1) get "value";
        private _tpl = _root >> _name;
        private _fail = "";

        // ------------------------------------------------ raw instance ------
        private _inst = createHashMap;
        {
            private _k = configName _x;
            if (!(_k in _directives)) then {
                switch (true) do {
                    case (isNumber _x): { _inst set [_k, getNumber _x] };
                    case (isText _x):   { _inst set [_k, getText _x] };
                    case (isArray _x):  { _inst set [_k, getArray _x] };
                };
            };
        } forEach (configProperties [_tpl, "!isClass _x", false]);

        private _objs = [];
        private _objsCfg = _tpl >> "objectives";
        if (isClass _objsCfg) then {
        {
            private _o = createHashMap;
            _o set ["id", configName _x];
            {
                private _k = configName _x;
                switch (true) do {
                    case (isNumber _x): { _o set [_k, getNumber _x] };
                    case (isText _x):   { _o set [_k, getText _x] };
                    case (isArray _x):  { _o set [_k, getArray _x] };
                };
            } forEach (configProperties [_x, "!isClass _x", false]);
            _objs pushBack _o;
        } forEach ("true" configClasses _objsCfg);
        };

        private _rew = createHashMap;
        private _rewCfg = _tpl >> "rewards";
        if (isClass _rewCfg) then {
        {
            private _k = configName _x;
            switch (true) do {
                case (isNumber _x): { _rew set [_k, getNumber _x] };
                case (isText _x):   { _rew set [_k, getText _x] };
                case (isArray _x):  { _rew set [_k, getArray _x] };
            };
        } forEach (configProperties [_rewCfg, "!isClass _x", false]);
        };

        // Defaults, so nothing downstream has to guess whether a key is missing
        // or meaningfully absent. They match the schema's documented defaults.
        if (!("title"       in (keys _inst))) then { _inst set ["title", _name] };
        if (!("summary"     in (keys _inst))) then { _inst set ["summary", ""] };
        if (!("description" in (keys _inst))) then { _inst set ["description", ""] };
        if (!("side"        in (keys _inst))) then { _inst set ["side", ""] };
        if (!("chain"       in (keys _inst))) then { _inst set ["chain", ""] };
        if (!("icon"        in (keys _inst))) then { _inst set ["icon", ""] };
        if (!("requires"    in (keys _inst))) then { _inst set ["requires", []] };
        if (!("repeatable"  in (keys _inst))) then { _inst set ["repeatable", 0] };
        if (!("timeLimit"   in (keys _inst))) then { _inst set ["timeLimit", 0] };
        _inst set ["objectives", _objs];
        _inst set ["rewards", _rew];

        if (_objs isEqualTo []) then {
            _fail = "template declares no objectives";
        };

        // ------------------------------------------------ slots -------------
        private _slots   = createHashMap;
        private _slotPos = createHashMap;
        private _used    = [];
        private _flat    = createHashMap;
        if (_fail isEqualTo "") then {
            private _fr = [_inst, _tpl >> "slots", _ctx] call aq_fnc_fillSlots;
            if (_fr select 0) then {
                _slots   = _fr select 1;
                _slotPos = _fr select 2;
                _used    = _fr select 3;
                _flat    = _fr select 4;
            } else {
                _fail = _fr select 1;
            };
        };

        // ------------------------------------------------ rewards -----------
        if (_fail isEqualTo "") then {
            private _sw = _rew getOrDefault ["scaleWith", ""];
            if (!(_sw isEqualTo "")) then {
                private _sr = [_rew, _sw, _slots] call aq_fnc_scaleReward;
                if !(_sr select 0) then { _fail = _sr select 1 };
            };
        };

        // ------------------------------------------------ emit or skip ------
        if (_fail isEqualTo "") then {
            // Nonce from the same seeded generator, so an id is reproducible
            // too — a dry run and the live board print the same string.
            private _np = ["__nonce", createHashMapFromArray [["min", 100000], ["max", 999999]], _ctx] call aq_fnc_pickFromPool;
            private _nonce = if (_np select 0) then { str (_np select 1) } else { str (floor (random 999999)) };
            _nonce = _ctx getOrDefault ["nonce", _nonce];

            _inst set ["id", _name + "#" + _nonce];
            _inst set ["radiant", true];
            _inst set ["template", _name];
            _inst set ["seed", _seed];
            _inst set ["giver", _giver];
            _inst set ["slots", _slots];
            // The flat string map under the name the read path expects. A caller
            // that resolves a field straight from the template config gets
            // exactly what is already in the instance, so the offer screen and
            // the journal can never disagree about where the player is going.
            _inst set ["subst", _flat];
            _inst set ["slotPos", _slotPos];
            _inst set ["used", _used];

            _result = _inst;
            _done = true;
        } else {
            diag_log text ("[AQ] genOffer: template '" + _name + "' skipped for giver '" + _giver + "' - " + _fail);
            private _idx = _cands find _name;
            if (_idx >= 0) then {
                _cands deleteAt _idx;
                _wts deleteAt _idx;
            } else {
                // Cannot happen unless the draw returned something it was not
                // given; bail rather than spin.
                _done = true;
            };
        };
    };
};

if (count _result == 0) then {
    diag_log text ("[AQ] genOffer: no template could be generated for giver '" + _giver + "' (seed " + str _seed + "). The reason for each one is above.");
};

_result
