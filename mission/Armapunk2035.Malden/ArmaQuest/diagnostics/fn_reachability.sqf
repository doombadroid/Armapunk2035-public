// SPDX-License-Identifier: MIT
/*
    diagnostics/fn_reachability.sqf  —  aq_fnc_reachability

    Purpose: compute which quests no player can ever be offered, and say why.

    WHY THIS EXISTS
        A quest catalogue gates itself. Prerequisites, chains and givers form a
        graph, and nothing in play distinguishes "unreachable" from "not yet
        reached" — both look like a quest nobody has done. So a prerequisite that
        names a renamed quest, a pair of quests that require each other, or a
        quest whose giver was deleted removes content silently and permanently.
        Authors find out months later, if ever. The graph is tiny and the answer is
        exact, so the only reason this failure survives anywhere is that nobody
        computed it.

    WHAT IT DOES
        Reads AQ_Quests and AQ_Givers, builds the prerequisite and chain graph, and
        solves for the set of quests that can be offered: a quest is reachable when
        something can offer it (a giver that exists, or a chain from a reachable
        quest), every quest it requires is itself reachable, and every world: token
        it carries names a key something has registered. Iterating that to a fixed
        point leaves the unreachable set, and each member is then classified —
        dangling prerequisite, prerequisite cycle, orphan, unregistered world key,
        or blocked behind another unreachable quest. Radiant templates get the same
        treatment through their givers[] list. Read-only and bounded; safe on a
        live server.

        WHY world: PARTICIPATES AND rep:/license:/item: DO NOT. The latter three
        gate a PLAYER against state that changes from one moment to the next — a
        licence earned, an item spent, standing that rose or fell — so none of them
        can make a quest unreachable to EVERYONE, only unreachable to someone right
        now, which is a different question this diagnostic does not answer. A
        world: key is catalogue structure, not player state: it either has a
        registered resolver or it does not, and that fact is as fixed at validation
        time as a giver id or a quest id is. What is NOT fixed, and what this file
        deliberately does not attempt, is what a REGISTERED resolver returns — that
        depends on server state that may not have booted yet (aq_fnc_srvInit can run
        after this diagnostic does) and is allowed by design to flip between true
        and false over the life of the server (a purge ends, a cartel changes
        hands). Evaluating a resolver here would not compute reachability, it would
        compute one instant of it and misreport the rest as permanently broken. So
        the only claim made about world: is the one that is actually true forever:
        an UNREGISTERED key can never be satisfied by any player at any moment, on
        this catalogue, as it stands — which is exactly "unreachable to everyone",
        the thing this diagnostic exists to catch — and is treated as dangling,
        exactly like a quest: token naming an id that does not exist. A registered
        key takes no further part: whether its resolver is ever true is left to the
        server, honestly, rather than guessed at here.

    Usage:
        private _unreachable = [] call aq_fnc_reachability;   // [[id, reason], ...]

    Runs synchronously and never suspends, so `call` it; the work is bounded by
    the size of the catalogue, not by anything happening in the mission.
*/

params [
    ["_verbose", true, [true]]   // false = totals only, still returns the full list
];

private _tag = "[AQ-REACH]";

// Self-contained config lookup: this diagnostic must be able to run and report
// even when the engine that consumes the catalogue never armed.
private _root = {
    params [["_class", "", [""]]];
    private _found = configNull;
    {
        if (isClass (_x >> _class)) exitWith { _found = _x >> _class };
    } forEach [missionConfigFile, campaignConfigFile, configFile];
    _found
};
private _subs = {
    params ["_cfg"];
    if (isNull _cfg) exitWith { [] };
    configProperties [_cfg, "isClass _x", true]
};
private _gTxt = {
    params ["_cfg", "_key", ["_def", ""]];
    if (isText (_cfg >> _key)) then { getText (_cfg >> _key) } else { _def }
};
private _gNum = {
    params ["_cfg", "_key", ["_def", 0]];
    if (isNumber (_cfg >> _key)) then { getNumber (_cfg >> _key) } else { _def }
};
private _gArr = {
    params ["_cfg", "_key"];
    if (isArray (_cfg >> _key)) then { getArray (_cfg >> _key) } else { [] }
};

private _questsCfg = ["AQ_Quests"] call _root;
private _giversCfg = ["AQ_Givers"] call _root;
private _templCfg  = ["AQ_Templates"] call _root;

private _giverIds = ([_giversCfg] call _subs) apply { configName _x };
private _giverBoard = createHashMap;
{
    _giverBoard set [configName _x, [_x, "boardSize", 0] call _gNum];
} forEach ([_giversCfg] call _subs);

// ---------------------------------------------------------------------------
// Build the graph
// ---------------------------------------------------------------------------
private _ids           = [];
private _prereqs       = createHashMap;   // id -> [quest ids it requires]
private _dangling      = createHashMap;   // id -> [required quest ids that do not exist]
private _danglingWorld = createHashMap;   // id -> [world: keys nothing registered]
private _giverOf       = createHashMap;   // id -> giver id ("" = none)
private _chainOf       = createHashMap;   // id -> chained-to quest id ("" = none)
private _chainedBy     = createHashMap;   // id -> [quest ids that chain into it]

// aq_worlds is populated by aq_fnc_registerWorld, on whatever schedule the host's
// own init calls it, so there is no guarantee it has run before this diagnostic
// does. An unloaded (or not-yet-existing) registry degrades to "nothing is
// registered", which reports every world: token as dangling rather than silently
// skipping the check. That is a deliberate asymmetry with aq_fnc_validate, which
// treats the same situation as a warning: validate() GATES whether the system
// arms, so it leans away from failing the whole catalogue over a load-order
// fluke, while this diagnostic gates nothing and exists specifically to
// over-report rather than hide a gap — a false "register this" is one re-run
// away from being corrected; a false "this is fine" is not.
private _worldRegistry = localNamespace getVariable ["aq_worlds", nil];
private _worldKnown = !isNil "_worldRegistry" && { _worldRegistry isEqualType createHashMap };

{
    private _q = _x;
    private _id = configName _q;
    _ids pushBackUnique _id;
    _giverOf set [_id, [_q, "giver", ""] call _gTxt];
    _chainOf set [_id, [_q, "chain", ""] call _gTxt];
    _prereqs set [_id, []];
    _dangling set [_id, []];
    _danglingWorld set [_id, []];
} forEach ([_questsCfg] call _subs);

{
    private _id = _x;
    private _chain = _chainOf getOrDefault [_id, ""];
    if (_chain != "") then {
        private _l = _chainedBy getOrDefault [_chain, []];
        _l pushBackUnique _id;
        _chainedBy set [_chain, _l];
    };
} forEach _ids;

{
    private _q = _x;
    private _id = configName _q;
    {
        private _tok = _x;
        if (_tok isEqualType "") then {
            private _parts = _tok splitString ":";
            if ((count _parts) == 2 && { (_parts select 0) isEqualTo "quest" }) then {
                private _need = _parts select 1;
                if (_need in _ids) then {
                    (_prereqs get _id) pushBackUnique _need;
                } else {
                    (_dangling get _id) pushBackUnique _need;
                };
            };
            // "license:", "item:", "rep:" and "align:" tokens are host state,
            // not catalogue structure. Whether a player holds a licence, has an
            // item, stands well with a faction, or belongs to a crew that has
            // sworn to one can change from one moment to the next, so none of
            // them can make a quest unreachable to
            // EVERYONE, only to a player right now — a different question,
            // fn_srvAccept's to answer, not this one. They take no part in the
            // graph. fn_validate proves each is answerable at all (a mapped
            // profile entry), which is all that can be proved ahead of time.
            //
            // "world:" is different in kind, not degree — see WHY world:
            // PARTICIPATES at the top of this file for the full reasoning.
            // In short: a world: key either has a registered resolver or it
            // does not, and that is fixed at validation time the same way a
            // giver id is, so it is read here rather than joining the list
            // above. What a REGISTERED resolver returns is not read or
            // guessed at; only the registration fact is.
            if ((count _parts) >= 2 && { (_parts select 0) isEqualTo "world" }) then {
                private _key = _parts select 1;
                private _registered = _worldKnown && { _key in (keys _worldRegistry) };
                if (_key != "" && { !_registered }) then {
                    (_danglingWorld get _id) pushBackUnique _key;
                };
            };
        };
    } forEach ([_q, "requires"] call _gArr);
} forEach ([_questsCfg] call _subs);

// ---------------------------------------------------------------------------
// Solve for the reachable set
// ---------------------------------------------------------------------------
// A quest is reachable when something can OFFER it and every quest it requires is
// itself reachable. Offerability through a chain depends on the chaining quest
// being reachable, so the two conditions are solved together, by iterating to a
// fixed point. This is deliberately a pure function of the catalogue: no ordering
// of declarations can change the answer.
private _reachable = createHashMap;
{ _reachable set [_x, false] } forEach _ids;

private _hasGiver = {
    params ["_id"];
    private _g = _giverOf getOrDefault [_id, ""];
    (_g != "") && { _g in _giverIds }
};

private _guard = (count _ids) + 1;   // a fixed point is reached in at most N passes
private _changed = true;
private _pass = 0;
while { _changed && { _pass < _guard } } do {
    _changed = false;
    _pass = _pass + 1;
    {
        private _id = _x;
        if (!(_reachable get _id)) then {
            private _offerable = [_id] call _hasGiver;
            if (!_offerable) then {
                {
                    if (_reachable getOrDefault [_x, false]) exitWith { _offerable = true };
                } forEach (_chainedBy getOrDefault [_id, []]);
            };
            if (_offerable) then {
                private _blocked = false;
                if (!((_dangling get _id) isEqualTo [])) then { _blocked = true };
                if (!_blocked && {!((_danglingWorld get _id) isEqualTo [])}) then { _blocked = true };
                if (!_blocked) then {
                    {
                        if (!(_reachable getOrDefault [_x, false])) exitWith { _blocked = true };
                    } forEach (_prereqs get _id);
                };
                if (!_blocked) then {
                    _reachable set [_id, true];
                    _changed = true;
                };
            };
        };
    } forEach _ids;
};

// ---------------------------------------------------------------------------
// Classify what is left
// ---------------------------------------------------------------------------
// Prerequisite closure, computed iteratively. A quest that appears in its own
// closure sits in a cycle; that is the difference between "this needs work" and
// "this is mathematically impossible", and it is worth stating separately.
private _closure = {
    params ["_start"];
    private _seen = [];
    private _stack = +(_prereqs getOrDefault [_start, []]);
    while { (count _stack) > 0 } do {
        private _n = _stack deleteAt 0;
        if (!(_n in _seen)) then {
            _seen pushBack _n;
            { _stack pushBack _x } forEach (_prereqs getOrDefault [_n, []]);
        };
    };
    _seen
};

// One concrete cycle path back to the start, for a report an author can act on.
private _cyclePath = {
    params ["_start"];
    private _parent = createHashMap;
    private _queue = [];
    {
        _parent set [_x, _start];
        _queue pushBack _x;
    } forEach (_prereqs getOrDefault [_start, []]);
    private _hit = "";
    while { (count _queue) > 0 && { _hit isEqualTo "" } } do {
        private _n = _queue deleteAt 0;
        {
            if (_x isEqualTo _start) exitWith { _hit = _n };
            if (!(_x in (keys _parent))) then {
                _parent set [_x, _n];
                _queue pushBack _x;
            };
        } forEach (_prereqs getOrDefault [_n, []]);
    };
    if (_hit isEqualTo "") exitWith { [] };
    // Walk the parent links back to the start, then close the loop. The step cap
    // is a guarantee that a malformed parent map cannot hang the server.
    private _path = [];
    private _cur = _hit;
    private _steps = 0;
    while { _steps < 64 } do {
        _path pushBack _cur;
        if (_cur isEqualTo _start) exitWith {};
        _cur = _parent getOrDefault [_cur, _start];
        _steps = _steps + 1;
    };
    reverse _path;              // [_start, ..., _hit]
    _path pushBack _start;      // ... -> _start
    _path
};

private _unreachable = [];
{
    private _id = _x;
    if (!(_reachable get _id)) then {
        private _reason = "";
        private _dang  = _dangling get _id;
        private _dangW = _danglingWorld get _id;

        if (!(_dang isEqualTo [])) then {
            _reason = format ["requires quest(s) %1, which do not exist", _dang];
        };

        if (_reason isEqualTo "" && { !(_dangW isEqualTo []) }) then {
            _reason = format ["requires world key(s) %1, which nothing has registered with aq_fnc_registerWorld", _dangW];
        };

        if (_reason isEqualTo "" && { _id in ([_id] call _closure) }) then {
            private _path = [_id] call _cyclePath;
            _reason = if (_path isEqualTo []) then {
                "sits in a prerequisite cycle"
            } else {
                format ["sits in a prerequisite cycle: %1", _path joinString " -> "]
            };
        };

        if (_reason isEqualTo "") then {
            private _g = _giverOf getOrDefault [_id, ""];
            private _inbound = _chainedBy getOrDefault [_id, []];
            if (_g isEqualTo "" && { _inbound isEqualTo [] }) then {
                _reason = "has no giver and no quest chains into it, so nothing can offer it";
            } else {
                if (_g != "" && { !(_g in _giverIds) }) then {
                    _reason = format ["names giver '%1', which is not in AQ_Givers", _g];
                };
            };
        };

        if (_reason isEqualTo "") then {
            private _blockers = [];
            {
                if (!(_reachable getOrDefault [_x, false])) then { _blockers pushBackUnique _x };
            } forEach (_prereqs get _id);
            if (!(_blockers isEqualTo [])) then {
                _reason = format ["is blocked behind unreachable quest(s) %1", _blockers];
            };
        };

        if (_reason isEqualTo "") then {
            private _inbound = _chainedBy getOrDefault [_id, []];
            private _live = [];
            {
                if (_reachable getOrDefault [_x, false]) then { _live pushBackUnique _x };
            } forEach _inbound;
            if (_live isEqualTo []) then {
                _reason = format ["is only chained into by unreachable quest(s) %1", _inbound];
            } else {
                // Every stated condition is satisfied yet the fixed point never
                // marked it. That means the classifier and the solver disagree,
                // which is a bug in this file, not in the catalogue — say so
                // rather than blame the author.
                _reason = "unreachable for a reason this diagnostic could not name (report this)";
            };
        };

        _unreachable pushBack [_id, _reason];
    };
} forEach _ids;

// ---------------------------------------------------------------------------
// Radiant templates
// ---------------------------------------------------------------------------
// A template is offered through its givers[] list, so the same question has a
// simpler answer: no giver that exists, or no board space on any of them.
private _deadTemplates = [];
private _boardMode = "shared";
private _settings = ["AQ_Settings"] call _root;
if (!isNull _settings) then { _boardMode = [_settings, "boardMode", "shared"] call _gTxt };

{
    private _t = _x;
    private _id = configName _t;
    private _tg = [_t, "givers"] call _gArr;
    private _valid = [];
    { if ((_x isEqualType "") && { _x in _giverIds }) then { _valid pushBackUnique _x } } forEach _tg;

    if (_tg isEqualTo []) then {
        _deadTemplates pushBack [_id, "declares no givers, so it is never offered anywhere"];
    } else {
        if (_valid isEqualTo []) then {
            _deadTemplates pushBack [_id,
                format ["names giver(s) %1, none of which are in AQ_Givers", _tg]];
        } else {
            if (_boardMode isEqualTo "shared") then {
                private _space = false;
                {
                    if ((_giverBoard getOrDefault [_x, 0]) > 0) exitWith { _space = true };
                } forEach _valid;
                if (!_space) then {
                    _deadTemplates pushBack [_id,
                        "every giver that could offer it holds a board of zero offers"];
                };
            };
        };
    };
    if (([_t, "weight", 0] call _gNum) <= 0) then {
        _deadTemplates pushBack [_id, "has no weight, so it is never rolled"];
    };
} forEach ([_templCfg] call _subs);

// ---------------------------------------------------------------------------
// Report
// ---------------------------------------------------------------------------
private _maxPrint = 200;
private _reach = ((count _ids) - (count _unreachable));

diag_log format ["%1 --- reachability ---", _tag];
diag_log format ["%1 quests: %2 total, %3 reachable, %4 unreachable (fixed point in %5 pass(es))",
                 _tag, count _ids, _reach, count _unreachable, _pass];

if (_verbose) then {
    private _n = 0;
    {
        _x params ["_id", "_why"];
        _n = _n + 1;
        if (_n <= _maxPrint) then {
            diag_log format ["%1 %2. UNREACHABLE  AQ_Quests >> %3 — %4", _tag, _n, _id, _why];
        };
    } forEach _unreachable;
    if ((count _unreachable) > _maxPrint) then {
        diag_log format ["%1 ... %2 further entries suppressed", _tag,
                         (count _unreachable) - _maxPrint];
    };

    {
        _x params ["_id", "_why"];
        diag_log format ["%1 UNREACHABLE  AQ_Templates >> %2 — %3", _tag, _id, _why];
    } forEach _deadTemplates;
};

if (hasInterface) then {
    systemChat format ["%1 %2/%3 quests reachable, %4 template(s) never offered. Details in the RPT.",
                       _tag, _reach, count _ids, count _deadTemplates];
};

// Left where a follow-up call or a test harness can read the result without
// re-walking the graph. These two variables are the only thing this file writes,
// and nothing in the quest system reads them.
aq_reach_unreachable = _unreachable;
aq_reach_deadTemplates = _deadTemplates;

_unreachable
