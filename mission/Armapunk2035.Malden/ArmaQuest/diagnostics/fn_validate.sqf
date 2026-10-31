// SPDX-License-Identifier: MIT
/*
    diagnostics/fn_validate.sqf  —  aq_fnc_validate

    Purpose: prove that every quest, template, pool, giver and profile entry in
    the loaded catalogue resolves to something real, and refuse to arm the system
    when it does not.

    WHY THIS EXISTS
        A quest catalogue is data, and data fails quietly. A misspelled objective
        type, a giver id that no longer exists, a marker deleted from the map, a
        prerequisite pointing at a renamed quest, a profile slot left empty — none
        of these throw. They produce a quest that is simply never offered, or one
        that is offered and can never be completed, on a live server, for weeks,
        with no log line and no player able to describe the fault. The only moment
        at which the whole catalogue is cheap to check is before it is used, so the
        check ships as part of the library and runs at preInit. Returning a boolean
        is the point: a broken catalogue must be able to stop the system arming
        rather than degrade into a mystery.

    WHAT IT DOES
        Walks AQ_Settings, AQ_Profile, AQ_Givers, AQ_Pools, AQ_Quests and
        AQ_Templates in that order and records every unresolvable reference as a
        problem or a warning, each carrying the exact config path it was found at.
        Problems are faults that make content unusable; warnings are things an
        author almost certainly did not mean but which still function. Prints a
        numbered report under [AQ-VALIDATE] and returns TRUE only when the problem
        list is empty. Read-only: it reads config and the type/trigger registries
        and mutates nothing, so it is safe to run on a live server at any time.

    Usage:
        private _ok = [] call aq_fnc_validate;              // on demand, verbose
        if (!([true] call aq_fnc_validate)) then { ... };   // at preInit, refuse to arm

    Runs synchronously and never suspends, so it must be `call`ed: preInit needs
    the answer before it decides whether to arm, and a spawned copy would return
    its verdict to nobody.
*/

params [
    ["_preInit", false, [false]],   // true = called before the mission world exists
    ["_verbose", true,  [true]]     // false = report the totals only
];

private _tag = "[AQ-VALIDATE]";

// ---------------------------------------------------------------------------
// Local helpers. Deliberately self-contained: a validator that depends on the
// engine it is validating cannot report that the engine failed to load.
// ---------------------------------------------------------------------------

// Root class lookup. Config may be included from description.ext (mission), from
// a campaign description, or from an addon config, so all three are searched in
// the order that lets a mission override an addon.
private _root = {
    params [["_class", "", [""]]];
    private _found = configNull;
    {
        if (isClass (_x >> _class)) exitWith { _found = _x >> _class };
    } forEach [missionConfigFile, campaignConfigFile, configFile];
    _found
};

private _problems = [];   // [path, message]
private _warnings = [];   // [path, message]

private _err  = { params ["_path", "_msg"]; _problems pushBack [_path, _msg]; };
private _warn = { params ["_path", "_msg"]; _warnings pushBack [_path, _msg]; };

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
// Subclasses of a class, in declaration order.
private _subs = {
    params ["_cfg"];
    if (isNull _cfg) exitWith { [] };
    configProperties [_cfg, "isClass _x", true]
};
// Property names of a class (non-class entries), for typo catching.
private _props = {
    params ["_cfg"];
    if (isNull _cfg) exitWith { [] };
    (configProperties [_cfg, "!isClass _x", true]) apply { configName _x }
};

// Text fields may be a literal or a "$STR_" stringtable key. A key that does not
// resolve renders as raw text in front of a player, which is a content bug worth
// one line of report.
// UNVERIFIED: isLocalized takes the key WITHOUT the leading "$". Confirm by
// passing a known-good key from the host stringtable with and without it.
private _chkText = {
    params ["_path", "_s", ["_required", false, [false]]];
    if (_s isEqualTo "") exitWith {
        if (_required) then { [_path, "is empty; players will see a blank line"] call _err };
    };
    if ((_s select [0, 1]) isEqualTo "$") then {
        private _key = _s select [1];
        if (!isLocalized _key) then {
            [_path, format ["stringtable key '%1' does not resolve", _key]] call _warn;
        };
    };
};

// Is this string a signed number literal? item:'s quantity gets away with
// treating "parseNumber result <= 0" as "malformed", because a quantity can
// never legitimately be zero or negative. rep:'s threshold has no such luck —
// FACTION_REP_SPEC.md section 6.1 makes negative thresholds meaningful, and a
// threshold of exactly 0 is a plain, legal "at least neutral" gate — and
// parseNumber("banana") and parseNumber("0") both return 0, so the result
// alone cannot tell a malformed token from a deliberate one. This walks the
// characters instead, the same way fn_scaleReward.sqf validates a slot name.
private _isNumberLiteral = {
    params ["_s"];
    if (_s isEqualTo "") exitWith { false };
    private _digits = 0;
    private _dots   = 0;
    private _ok     = true;
    {
        private _c = _x;
        private _isDigit = (_c >= 48 && {_c <= 57});
        if (_isDigit) then {
            _digits = _digits + 1;
        } else {
            private _isSign = (_forEachIndex == 0) && {(_c == 45) || {_c == 43}};   // - or +, first char only
            private _isDot  = (_c == 46) && {_dots == 0};                           // one . at most
            if (_isDot) then { _dots = _dots + 1; };
            if (!_isSign && {!_isDot}) exitWith { _ok = false };
        };
    } forEach (toArray _s);
    _ok && {_digits > 0}
};

// Marker existence. Markers placed in the map layer only exist once the mission
// world is up, so at preInit this check is deferred rather than failed — a
// validator that fails every marker at preInit teaches authors to ignore it.
// UNVERIFIED: area markers may carry an empty markerType, so membership of
// allMapMarkers is the primary test and the type/shape tests are fallbacks.
private _markersReady = { (count allMapMarkers) > 0 };
private _markerExists = {
    params ["_m"];
    (_m in allMapMarkers) || { (getMarkerType _m) != "" } || { (markerShape _m) != "" }
};
private _deferredMarkers = 0;
private _chkMarker = {
    params ["_path", "_m"];
    if (_m isEqualTo "") exitWith { [_path, "marker name is empty"] call _err };
    if (!([] call _markersReady)) exitWith { _deferredMarkers = _deferredMarkers + 1 };
    if (!([_m] call _markerExists)) then {
        [_path, format ["marker '%1' does not exist on this map", _m]] call _err;
    };
};

// Named-function resolution. Every escape hatch in this system is a function the
// host registers by name, so "the name is spelled right and something answers to
// it" is the whole of the contract we can check ahead of time.
private _fncDefined = {
    params ["_name"];
    if (_name isEqualTo "") exitWith { false };
    private _v = missionNamespace getVariable [_name, nil];
    !isNil "_v" && { _v isEqualType {} }
};

// Objective-type registration. The registry is a HashMap of type name -> code,
// built by aq_fnc_registerType. When it has not been built yet (validate can run
// before the type files are loaded) the check degrades to probing for the
// conventional function name rather than declaring the whole catalogue broken.
private _typeRegistry = localNamespace getVariable ["aq_types", nil];
private _registryLoaded = !isNil "_typeRegistry" && { _typeRegistry isEqualType createHashMap };
private _typeKnown = {
    params ["_t"];
    if (_t isEqualTo "") exitWith { false };
    if (_registryLoaded) exitWith { _t in (keys _typeRegistry) };
    private _fn = "aq_fnc_type" + (toUpper (_t select [0, 1])) + (_t select [1]);
    [_fn] call _fncDefined
};

// Trigger-driver registration, same shape as the type registry.
private _trigRegistry = localNamespace getVariable ["aq_triggers", nil];
private _trigLoaded = !isNil "_trigRegistry" && { _trigRegistry isEqualType createHashMap };

// World-resolver registration (aq_fnc_registerWorld), same shape again. This is
// the whole reason world: is a registry and not a lookup table: an unregistered
// key is a content bug that produces a quest nobody can ever see, and this is
// where it is caught, named, before anyone goes looking for it in play.
private _worldRegistry = localNamespace getVariable ["aq_worlds", nil];
private _worldLoaded = !isNil "_worldRegistry" && { _worldRegistry isEqualType createHashMap };

// %SLOT% marker scan, shared with the radiant generator's substitution rule:
// a slot marker is any text between a matched pair of percent signs.
private _slotsIn = {
    params ["_s"];
    private _out = [];
    private _cur = "";
    private _open = false;
    {
        private _ch = toString [_x];
        if (_ch isEqualTo "%") then {
            if (_open) then {
                if (_cur != "") then { _out pushBackUnique _cur };
                _cur = ""; _open = false;
            } else {
                _open = true; _cur = "";
            };
        } else {
            if (_open) then { _cur = _cur + _ch };
        };
    } forEach (toArray _s);
    [_out, _open]   // _open true == an unterminated marker was left dangling
};

// ---------------------------------------------------------------------------
// 1. AQ_Settings
// ---------------------------------------------------------------------------
private _settings = ["AQ_Settings"] call _root;
// "extDB3" is the same driver under the name a host is more likely to type; the
// store facade accepts both, so refusing one of them here would fail a
// catalogue that works.
private _knownStores = ["profileNamespace", "extDB", "extDB3", "sql", "none"];
private _knownBoardModes = ["shared", "onDemand"];

if (isNull _settings) then {
    ["AQ_Settings", "class is missing; defaults will be used for store and board mode"] call _warn;
} else {
    private _store = [_settings, "store", "profileNamespace"] call _gTxt;
    if (!(_store in _knownStores)) then {
        ["AQ_Settings >> store",
         format ["'%1' is not a shipped store driver (%2)", _store, _knownStores]] call _err;
    };
    private _bm = [_settings, "boardMode", "shared"] call _gTxt;
    if (!(_bm in _knownBoardModes)) then {
        ["AQ_Settings >> boardMode",
         format ["'%1' is not a board mode (%2)", _bm, _knownBoardModes]] call _err;
    };
};

// ---------------------------------------------------------------------------
// 2. AQ_Profile — the host mapping table
// ---------------------------------------------------------------------------
private _profile = ["AQ_Profile"] call _root;
private _profileKeys = [
    "payMoney", "takeMoney", "giveItem", "takeItem", "countItem",
    "hasLicense", "grantLicense", "playerUid", "awardXp",
    "getRep", "addRep", "factionOf"
];
private _profileMap = createHashMap;   // key -> "" (unavailable) or function name

if (isNull _profile) then {
    ["AQ_Profile", "class is missing; nothing can be paid, taken or identified"] call _err;
    { _profileMap set [_x, ""] } forEach _profileKeys;
} else {
    {
        private _key = _x;
        private _name = [_profile, _key, ""] call _gTxt;
        _profileMap set [_key, _name];
        if (_name isEqualTo "") then {
            // "" is a legal declaration of "this host cannot do that". It only
            // becomes an error where a quest actually needs it, which is reported
            // at that quest's own path further down.
            if (_key isEqualTo "playerUid") then {
                ["AQ_Profile >> playerUid",
                 "is empty; players cannot be identified, so no state can be kept"] call _err;
            } else {
                ["AQ_Profile >> " + _key, "is empty; features needing it are unavailable"] call _warn;
            };
        } else {
            if (!([_name] call _fncDefined)) then {
                ["AQ_Profile >> " + _key,
                 format ["names '%1', which is not a defined function", _name]] call _err;
            };
        };
    } forEach _profileKeys;

    {
        private _p = _x;
        if (!(_p in _profileKeys)) then {
            ["AQ_Profile >> " + _p, "is not a profile key; check the spelling"] call _warn;
        };
    } forEach ([_profile] call _props);
};

private _profileHas = { params ["_key"]; (_profileMap getOrDefault [_key, ""]) != "" };

// ---------------------------------------------------------------------------
// 3. AQ_Givers
// ---------------------------------------------------------------------------
private _givers = ["AQ_Givers"] call _root;
private _giverIds = [];

if (isNull _givers) then {
    ["AQ_Givers", "class is missing; no quest can be offered to anyone"] call _warn;
} else {
    {
        private _g = _x;
        private _id = configName _g;
        private _p = "AQ_Givers >> " + _id;
        _giverIds pushBackUnique _id;

        [_p + " >> name", [_g, "name", ""] call _gTxt, true] call _chkText;

        private _trigger = [_g, "trigger", "addAction"] call _gTxt;
        if (_trigger isEqualTo "") then {
            [_p + " >> trigger", "is empty; nothing will expose this giver"] call _err;
        } else {
            if (_trigLoaded) then {
                if (!(_trigger in (keys _trigRegistry))) then {
                    [_p + " >> trigger",
                     format ["driver '%1' is not registered", _trigger]] call _err;
                };
            } else {
                if (!(_trigger isEqualTo "addAction")) then {
                    [_p + " >> trigger",
                     format ["driver '%1' cannot be checked; trigger registry not loaded", _trigger]]
                     call _warn;
                };
            };
        };

        private _marker = [_g, "marker", ""] call _gTxt;
        private _object = [_g, "object", ""] call _gTxt;
        if (!(_marker isEqualTo "")) then { [_p + " >> marker", _marker] call _chkMarker };
        if (!(_object isEqualTo "")) then {
            if (!isClass (configFile >> "CfgVehicles" >> _object)) then {
                [_p + " >> object",
                 format ["'%1' is not a CfgVehicles class", _object]] call _err;
            };
        } else {
            if (!(_marker isEqualTo "")) then {
                [_p + " >> object",
                 "a marker is set but no object class is given, so nothing will be spawned"]
                 call _warn;
            };
        };

        private _board = [_g, "boardSize", 0] call _gNum;
        if (_board < 0) then {
            [_p + " >> boardSize", format ["is %1; must be zero or greater", _board]] call _err;
        };
    } forEach ([_givers] call _subs);
};

// ---------------------------------------------------------------------------
// 4. AQ_Pools
// ---------------------------------------------------------------------------
// The shape of a pool entry belongs to the radiant generator, so this checks only
// what is true of every pool: it exists, and it is not empty. An empty pool is
// the single most common cause of a template that never generates.
private _pools = ["AQ_Pools"] call _root;
private _poolIds = [];

if (!isNull _pools) then {
    {
        private _pool = _x;
        private _id = configName _pool;
        private _p = "AQ_Pools >> " + _id;
        _poolIds pushBackUnique _id;

        // A pool is one class per entry, each carrying `value`, `label` and
        // optionally `marker` / `position[]` / `tags[]` / `weight`. There is no
        // array form: the generator reads subclasses and nothing else, so an
        // `entries[]` or `values[]` array here would validate clean and then
        // never produce a candidate.
        private _entries = [_pool] call _subs;

        if ((count _entries) == 0) then {
            [_p, "pool declares no entry classes; every template slot using it will fail to fill"] call _err;
        };
        {
            private _stray = _x;
            if (_stray in ["entries", "items", "values", "weights", "kind"]) then {
                [_p + " >> " + _stray,
                 "is not read by the generator; a pool is one class per entry, each with value / label / marker"]
                 call _err;
            };
        } forEach ([_pool] call _props);

        {
            private _entry = _x;
            private _m = [_entry, "marker", ""] call _gTxt;
            if (!(_m isEqualTo "")) then {
                [_p + " >> " + (configName _entry) + " >> marker", _m] call _chkMarker;
            };
        } forEach _entries;
    } forEach ([_pools] call _subs);
};

// ---------------------------------------------------------------------------
// 5. AQ_Quests
// ---------------------------------------------------------------------------
private _quests = ["AQ_Quests"] call _root;
private _questIds = [];
if (!isNull _quests) then {
    { _questIds pushBackUnique (configName _x) } forEach ([_quests] call _subs);
};

// Shared by quests and templates: an objectives class and its rewards class.
private _chkObjectives = {
    params [["_path", "", [""]], "_objsCfg", ["_isTemplate", false, [false]]];
    private _list = [_objsCfg] call _subs;
    if (_list isEqualTo []) then {
        [_path, "declares no objectives; it can never be completed"] call _err;
    };
    {
        private _o = _x;
        private _op = _path + " >> " + (configName _o);

        private _type = [_o, "type", ""] call _gTxt;
        if (_type isEqualTo "") then {
            [_op + " >> type", "is missing"] call _err;
        } else {
            if (!([_type] call _typeKnown)) then {
                [_op + " >> type",
                 format ["'%1' is not a registered objective type", _type]] call _err;
            };
        };

        // Generic data checks. These read config keys only; what a key MEANS is
        // the type plugin's business and is deliberately not second-guessed here.
        private _mk = [_o, "marker", ""] call _gTxt;
        if (!(_mk isEqualTo "")) then {
            if (_isTemplate && { ((([_mk] call _slotsIn) select 0) isNotEqualTo []) }) then {
                // a substituted marker is checked after generation, not here
            } else {
                [_op + " >> marker", _mk] call _chkMarker;
            };
        };

        if (isNumber (_o >> "count")) then {
            private _c = getNumber (_o >> "count");
            if (_c <= 0) then {
                [_op + " >> count", format ["is %1; must be greater than zero", _c]] call _err;
            };
        };
        if (isNumber (_o >> "radius")) then {
            private _r = getNumber (_o >> "radius");
            if (_r <= 0) then {
                [_op + " >> radius", format ["is %1; must be greater than zero", _r]] call _err;
            };
        };
        if (isText (_o >> "item") && { (getText (_o >> "item")) isEqualTo "" }) then {
            [_op + " >> item", "is empty"] call _err;
        };
    } forEach _list;
};

private _chkRewards = {
    params [["_path", "", [""]], "_rw"];
    if (isNull _rw) exitWith {};

    private _money = [_rw, "money", 0] call _gNum;
    if (_money < 0) then {
        [_path + " >> money", format ["is %1; a reward cannot be negative", _money]] call _err;
    };
    if (_money > 0 && { !(["payMoney"] call _profileHas) }) then {
        [_path + " >> money",
         "pays money but AQ_Profile >> payMoney is empty, so it can never be paid"] call _err;
    };

    private _xp = [_rw, "xp", 0] call _gNum;
    if (_xp > 0 && { !(["awardXp"] call _profileHas) }) then {
        [_path + " >> xp", "awards xp but AQ_Profile >> awardXp is empty; xp will be ignored"]
        call _warn;
    };

    private _items = [_rw, "items"] call _gArr;
    if (!(_items isEqualTo []) && { !(["giveItem"] call _profileHas) }) then {
        [_path + " >> items",
         "gives items but AQ_Profile >> giveItem is empty, so they can never be given"] call _err;
    };
    {
        private _pair = _x;
        if (!(_pair isEqualType []) || { (count _pair) != 2 }) then {
            [_path + " >> items", format ["entry %1 is not a {class, quantity} pair", _forEachIndex]]
            call _err;
        } else {
            if (!((_pair select 0) isEqualType "")) then {
                [_path + " >> items",
                 format ["entry %1 has a non-string class", _forEachIndex]] call _err;
            };
            if (!((_pair select 1) isEqualType 0) || { (_pair select 1) <= 0 }) then {
                [_path + " >> items",
                 format ["entry %1 has a quantity that is not a positive number", _forEachIndex]]
                 call _err;
            };
        };
    } forEach _items;

    private _lic = [_rw, "licenses"] call _gArr;
    if (!(_lic isEqualTo []) && { !(["grantLicense"] call _profileHas) }) then {
        [_path + " >> licenses",
         "grants licences but AQ_Profile >> grantLicense is empty"] call _err;
    };
    {
        if (!(_x isEqualType "") || { _x isEqualTo "" }) then {
            [_path + " >> licenses",
             format ["entry %1 is not a non-empty licence name", _forEachIndex]] call _err;
        };
    } forEach _lic;

    private _reps = [_rw, "rep"] call _gArr;
    if (!(_reps isEqualTo []) && { !(["addRep"] call _profileHas) }) then {
        [_path + " >> rep",
         "pays reputation but AQ_Profile >> addRep is empty, so it can never be paid"] call _err;
    };
    {
        private _pair = _x;
        if (!(_pair isEqualType []) || { (count _pair) != 2 }) then {
            [_path + " >> rep", format ["entry %1 is not a {factionId, delta} pair", _forEachIndex]]
            call _err;
        } else {
            if (!((_pair select 0) isEqualType "") || { (_pair select 0) isEqualTo "" }) then {
                [_path + " >> rep",
                 format ["entry %1 names no faction id", _forEachIndex]] call _err;
            };
            if (!((_pair select 1) isEqualType 0)) then {
                [_path + " >> rep",
                 format ["entry %1 has a non-numeric delta", _forEachIndex]] call _err;
            };
            // Deliberately no "delta > 0" check: FACTION_REP_SPEC.md section 6.3
            // is explicit that a reward may move a faction DOWN — "helping the
            // docks at the neon faction's expense" — so a negative delta here is
            // authored content, not a mistake, unlike an items[] quantity.
        };
    } forEach _reps;
};

if (isNull _quests) then {
    ["AQ_Quests", "class is missing; the catalogue is empty"] call _warn;
} else {
    {
        private _q = _x;
        private _id = configName _q;
        private _p = "AQ_Quests >> " + _id;

        [_p + " >> title",   [_q, "title", ""] call _gTxt, true] call _chkText;
        [_p + " >> summary", [_q, "summary", ""] call _gTxt] call _chkText;
        [_p + " >> description", [_q, "description", ""] call _gTxt] call _chkText;

        private _giver = [_q, "giver", ""] call _gTxt;
        private _chain = [_q, "chain", ""] call _gTxt;
        if (_giver isEqualTo "") then {
            // Legal: a chained quest is handed out by its predecessor. It is only
            // a fault when nothing chains to it, which fn_reachability reports.
            [_p + " >> giver",
             "is empty; this quest can only be reached by being chained into"] call _warn;
        } else {
            if (!(_giver in _giverIds)) then {
                [_p + " >> giver",
                 format ["'%1' is not a class in AQ_Givers", _giver]] call _err;
            };
        };

        if (!(_chain isEqualTo "") && { !(_chain in _questIds) }) then {
            [_p + " >> chain",
             format ["chains to '%1', which is not a quest", _chain]] call _err;
        };

        private _side = [_q, "side", ""] call _gTxt;
        // Side names are host vocabulary, so only emptiness is a fault here.
        if (isText (_q >> "side") && { _side isEqualTo "" }) then {
            [_p + " >> side", "is declared but empty; remove it or name a side"] call _warn;
        };

        private _rep = [_q, "repeatable", 0] call _gNum;
        if (_rep < -1) then {
            [_p + " >> repeatable",
             format ["is %1; use 0 for once, -1 for always, or a positive cooldown", _rep]] call _err;
        };
        private _tl = [_q, "timeLimit", 0] call _gNum;
        if (_tl < 0) then {
            [_p + " >> timeLimit", format ["is %1; must be zero or greater", _tl]] call _err;
        };

        // requires[] tokens. Six kinds, and the grammar is two OR three
        // colon-separated parts:
        //     quest:<id>              license:<name>
        //     item:<class>            item:<class>:<qty>
        //     world:<key>             world:<key>:<value>
        //     rep:<factionId>:<n>     align:<factionId>
        // item:'s quantity and world:'s value are optional and, when present,
        // last. rep:'s threshold is NOT optional -- rep: is always three parts,
        // because there is no sane default for a standing gate the way "1" is a
        // sane default for a quantity of items.
        {
            private _tok = _x;
            private _tp = _p + format [" >> requires[%1]", _forEachIndex];
            if (!(_tok isEqualType "")) then {
                [_tp, "is not a string"] call _err;
            } else {
                private _parts = _tok splitString ":";
                if ((count _parts) < 2 || { (count _parts) > 3 }) then {
                    [_tp, format ["'%1' is malformed; expected 'quest:<id>', 'license:<name>', 'item:<class>[:<qty>]', 'rep:<factionId>:<n>', 'align:<factionId>' or 'world:<key>[:<value>]'",
                                  _tok]] call _err;
                } else {
                    private _kind = _parts select 0;
                    private _name = _parts select 1;
                    if ((count _parts) == 3 && { !(_kind in ["item", "rep", "world"]) }) then {
                        [_tp, format ["'%1' has a third part; only 'item:', 'rep:' and 'world:' take one", _tok]] call _err;
                    };
                    switch (_kind) do {
                        case "quest": {
                            if (!(_name in _questIds)) then {
                                [_tp, format ["requires quest '%1', which does not exist", _name]]
                                call _err;
                            };
                            if (_name isEqualTo _id) then {
                                [_tp, "requires itself"] call _err;
                            };
                        };
                        case "license": {
                            // A licence name belongs to the host, and the design
                            // deliberately defines no licence registry to check it
                            // against. What can be proved is that the requirement
                            // is answerable at all.
                            if (!(["hasLicense"] call _profileHas)) then {
                                [_tp,
                                 "requires a licence but AQ_Profile >> hasLicense is empty, so the requirement can never pass"]
                                 call _err;
                            };
                        };
                        case "item": {
                            // Same reasoning: item classes are the host's
                            // vocabulary, so only answerability can be proved.
                            if (!(["countItem"] call _profileHas)) then {
                                [_tp,
                                 "requires an item but AQ_Profile >> countItem is empty, so the requirement can never pass"]
                                 call _err;
                            };
                            if ((count _parts) == 3) then {
                                private _qty = parseNumber (_parts select 2);
                                if (_qty <= 0) then {
                                    [_tp, format ["quantity '%1' is not a positive number", _parts select 2]] call _err;
                                };
                            };
                            if (_name isEqualTo "") then {
                                [_tp, "names no item class"] call _err;
                            };
                        };
                        case "rep": {
                            // A faction id is the host's vocabulary too -- this
                            // library has no faction catalogue and must not grow
                            // one (FACTION_REP_SPEC.md section 6), so, exactly as
                            // for license: and item:, only answerability can be
                            // proved, not that the faction itself exists.
                            if ((count _parts) != 3) then {
                                [_tp, format ["'%1' is malformed; expected 'rep:<factionId>:<n>'", _tok]] call _err;
                            } else {
                                if (_name isEqualTo "") then {
                                    [_tp, "names no faction id"] call _err;
                                };
                                private _nStr = _parts select 2;
                                if (!([_nStr] call _isNumberLiteral)) then {
                                    [_tp, format ["threshold '%1' is not a number", _nStr]] call _err;
                                };
                            };
                            if (!(["getRep"] call _profileHas)) then {
                                [_tp,
                                 "requires reputation but AQ_Profile >> getRep is empty, so the requirement can never pass"]
                                 call _err;
                            };
                        };
                        case "align": {
                            // Two parts only. align: has nothing optional to carry:
                            // it is a membership test, not a threshold, so a third
                            // part is a quest author writing rep: from memory and
                            // is worth saying out loud rather than ignoring.
                            if ((count _parts) != 2) then {
                                [_tp, format ["'%1' is malformed; expected 'align:<factionId>' or 'align:any'", _tok]] call _err;
                            } else {
                                if (_name isEqualTo "") then {
                                    [_tp, "names no faction id"] call _err;
                                };
                            };
                            // As for license:, item: and rep:, the faction id is the
                            // host's vocabulary and this library has no catalogue to
                            // check it against. Only answerability can be proved.
                            if (!(["factionOf"] call _profileHas)) then {
                                [_tp,
                                 "requires an alignment but AQ_Profile >> factionOf is empty, so the requirement can never pass"]
                                 call _err;
                            };
                        };
                        case "world": {
                            // This is the whole reason world: is a registry: an
                            // unregistered key is a quest that can never appear,
                            // caught here by name instead of by a player who never
                            // sees it and has no way to know it exists
                            // (WORLD_STATE_SPEC.md section 4).
                            if (_name isEqualTo "") then {
                                [_tp, "names no key"] call _err;
                            } else {
                                if (_worldLoaded) then {
                                    if (!(_name in (keys _worldRegistry))) then {
                                        [_tp, format ["names world key '%1', which nothing has registered with aq_fnc_registerWorld", _name]]
                                        call _err;
                                    };
                                } else {
                                    [_tp, format ["names world key '%1', which cannot be checked; the world registry is not loaded", _name]]
                                    call _warn;
                                };
                            };
                        };
                        default {
                            [_tp, format ["'%1' is not a known requirement kind", _kind]] call _err;
                        };
                    };
                };
            };
        } forEach ([_q, "requires"] call _gArr);

        private _objs = _q >> "objectives";
        if (isNull _objs) then {
            [_p + " >> objectives", "class is missing"] call _err;
        } else {
            [_p + " >> objectives", _objs, false] call _chkObjectives;
        };

        [_p + " >> rewards", _q >> "rewards"] call _chkRewards;
    } forEach ([_quests] call _subs);
};

// ---------------------------------------------------------------------------
// 6. AQ_Templates
// ---------------------------------------------------------------------------
private _templates = ["AQ_Templates"] call _root;

if (!isNull _templates) then {
    {
        private _t = _x;
        private _id = configName _t;
        private _p = "AQ_Templates >> " + _id;

        private _weight = [_t, "weight", 0] call _gNum;
        if (_weight <= 0) then {
            [_p + " >> weight",
             format ["is %1; a template with no weight is never rolled", _weight]] call _warn;
        };

        {
            private _gid = _x;
            if (!(_gid isEqualType "") || { !(_gid in _giverIds) }) then {
                [_p + format [" >> givers[%1]", _forEachIndex],
                 format ["'%1' is not a class in AQ_Givers", _gid]] call _err;
            };
        } forEach ([_t, "givers"] call _gArr);

        // --- slots ---------------------------------------------------------
        private _slotsCfg = _t >> "slots";
        private _slotNames = [];
        private _numericSlots = [];

        if (isNull _slotsCfg) then {
            [_p + " >> slots", "class is missing; a template with no slots is just a quest"]
            call _warn;
        } else {
            {
                private _s = _x;
                private _sn = configName _s;
                private _sp = _p + " >> slots >> " + _sn;
                _slotNames pushBackUnique _sn;

                private _pool = [_s, "pool", ""] call _gTxt;
                private _hasRange = (isNumber (_s >> "min")) || (isNumber (_s >> "max"));

                if (_pool isEqualTo "" && { !_hasRange }) then {
                    // The design gives a slot exactly two shapes: filled from a
                    // pool, or a numeric range. Neither means the slot can never
                    // be filled, and substitution is total, so generation dies.
                    [_sp, "declares neither a pool nor a numeric range, so it can never be filled"]
                    call _err;
                };

                if (!(_pool isEqualTo "")) then {
                    if (isNull _pools) then {
                        [_sp + " >> pool",
                         format ["names pool '%1' but AQ_Pools does not exist", _pool]] call _err;
                    } else {
                        if (!(_pool in _poolIds)) then {
                            [_sp + " >> pool",
                             format ["'%1' is not a class in AQ_Pools", _pool]] call _err;
                        };
                    };
                    if (_hasRange) then {
                        [_sp, "declares both a pool and a numeric range; one of them is ignored"]
                        call _warn;
                    };
                } else {
                    if (_hasRange) then { _numericSlots pushBackUnique _sn };
                };

                if (_hasRange) then {
                    private _min = [_s, "min", 0] call _gNum;
                    private _max = [_s, "max", 0] call _gNum;
                    if (_max < _min) then {
                        [_sp, format ["max (%1) is below min (%2)", _max, _min]] call _err;
                    };
                };

                private _nuw = [_s, "notUsedWithin", 0] call _gNum;
                if (_nuw < 0) then {
                    [_sp + " >> notUsedWithin",
                     format ["is %1; must be zero or greater", _nuw]] call _err;
                };
            } forEach ([_slotsCfg] call _subs);

            // distanceFrom is checked in a second pass so that it can reference a
            // slot declared after it.
            {
                private _s = _x;
                private _sn = configName _s;
                private _sp = _p + " >> slots >> " + _sn;
                private _df = [_s, "distanceFrom", ""] call _gTxt;
                if (!(_df isEqualTo "") && { !(_df in ["giver", "player"]) }) then {
                    if (!((_df select [0, 5]) isEqualTo "slot:")) then {
                        [_sp + " >> distanceFrom",
                         format ["'%1' is not 'giver', 'player' or 'slot:<NAME>'", _df]] call _err;
                    } else {
                        private _ref = _df select [5];
                        if (!(_ref in _slotNames)) then {
                            [_sp + " >> distanceFrom",
                             format ["references slot '%1', which is not declared", _ref]] call _err;
                        } else {
                            if (_ref in _numericSlots) then {
                                [_sp + " >> distanceFrom",
                                 format ["references numeric slot '%1', which has no position", _ref]]
                                 call _err;
                            };
                            if (_ref isEqualTo _sn) then {
                                [_sp + " >> distanceFrom", "references itself"] call _err;
                            };
                        };
                    };
                };
            } forEach ([_slotsCfg] call _subs);
        };

        // --- substitution markers -------------------------------------------
        private _used = [];
        private _scan = {
            params ["_path", "_s"];
            if (!(_s isEqualType "")) exitWith {};
            ([_s] call _slotsIn) params ["_found", "_dangling"];
            if (_dangling) then {
                // Percent signs are kept out of format strings on purpose: format
                // has no escape for one, so a report about a marker must not be
                // written with a marker in it.
                [_path, "has an unterminated slot marker (odd number of percent signs) in: " + _s]
                call _err;
            };
            {
                private _n = _x;
                _used pushBackUnique _n;
                if (!(_n in _slotNames)) then {
                    [_path, format ["uses slot marker '%1', which is not a declared slot", _n]]
                    call _err;
                };
            } forEach _found;
        };

        [_p + " >> title",   [_t, "title", ""] call _gTxt, true] call _chkText;
        [_p + " >> title",   [_t, "title", ""] call _gTxt] call _scan;
        [_p + " >> summary", [_t, "summary", ""] call _gTxt] call _chkText;
        [_p + " >> summary", [_t, "summary", ""] call _gTxt] call _scan;
        [_p + " >> description", [_t, "description", ""] call _gTxt] call _scan;

        private _tObjs = _t >> "objectives";
        if (isNull _tObjs) then {
            [_p + " >> objectives", "class is missing"] call _err;
        } else {
            [_p + " >> objectives", _tObjs, true] call _chkObjectives;
            {
                private _o = _x;
                private _op = _p + " >> objectives >> " + (configName _o);
                {
                    private _prop = _x;
                    if (isText _prop) then {
                        [_op + " >> " + (configName _prop), getText _prop] call _scan;
                    };
                } forEach (configProperties [_o, "!isClass _x", true]);
            } forEach ([_tObjs] call _subs);
        };

        private _tRw = _t >> "rewards";
        [_p + " >> rewards", _tRw] call _chkRewards;
        if (!isNull _tRw) then {
            private _scaleWith = [_tRw, "scaleWith", ""] call _gTxt;
            if (!(_scaleWith isEqualTo "")) then {
                _used pushBackUnique _scaleWith;
                if (!(_scaleWith in _slotNames)) then {
                    [_p + " >> rewards >> scaleWith",
                     format ["names '%1', which is not a declared slot", _scaleWith]] call _err;
                } else {
                    if (!(_scaleWith in _numericSlots)) then {
                        // scaleWith multiplies. Multiplying by a place name is the
                        // exact failure this check exists to catch.
                        [_p + " >> rewards >> scaleWith",
                         format ["names '%1', which is not a numeric slot", _scaleWith]] call _err;
                    };
                };
            };
            {
                private _prop = _x;
                if (isText _prop) then {
                    [_p + " >> rewards >> " + (configName _prop), getText _prop] call _scan;
                };
            } forEach (configProperties [_tRw, "!isClass _x", true]);
        };

        {
            private _sn = _x;
            if (!(_sn in _used)) then {
                [_p + " >> slots >> " + _sn, "is declared but never used"] call _warn;
            };
        } forEach _slotNames;
    } forEach ([_templates] call _subs);
};

// ---------------------------------------------------------------------------
// 7. Report
// ---------------------------------------------------------------------------
private _maxPrint = 200;   // bounded output: a broken catalogue must not flood the RPT
private _ok = _problems isEqualTo [];

diag_log format ["%1 --- catalogue validation (%2) ---", _tag,
                 if (_preInit) then { "preInit" } else { "on demand" }];
diag_log format ["%1 quests: %2   givers: %3   pools: %4   templates: %5",
                 _tag, count _questIds, count _giverIds, count _poolIds,
                 count ([_templates] call _subs)];

if (!_registryLoaded) then {
    diag_log format ["%1 NOTE: the objective-type registry is not loaded; type checks fell back to probing for aq_fnc_type<Name>.", _tag];
};
if (_deferredMarkers > 0) then {
    diag_log format ["%1 NOTE: %2 marker reference(s) were not checked because the map layer is not up yet. Re-run on demand after mission start.", _tag, _deferredMarkers];
};

if (_verbose) then {
    private _n = 0;
    {
        _x params ["_path", "_msg"];
        _n = _n + 1;
        if (_n <= _maxPrint) then {
            diag_log format ["%1 %2. PROBLEM  %3 — %4", _tag, _n, _path, _msg];
        };
    } forEach _problems;
    if ((count _problems) > _maxPrint) then {
        diag_log format ["%1 ... %2 further problems suppressed", _tag,
                         (count _problems) - _maxPrint];
    };

    private _w = 0;
    {
        _x params ["_path", "_msg"];
        _w = _w + 1;
        if (_w <= _maxPrint) then {
            diag_log format ["%1 %2. warning  %3 — %4", _tag, _w, _path, _msg];
        };
    } forEach _warnings;
    if ((count _warnings) > _maxPrint) then {
        diag_log format ["%1 ... %2 further warnings suppressed", _tag,
                         (count _warnings) - _maxPrint];
    };
};

diag_log format ["%1 result: %2 — %3 problem(s), %4 warning(s)",
                 _tag, if (_ok) then { "PASS" } else { "FAIL" },
                 count _problems, count _warnings];

// The operator only sees the RPT if they go looking, so an on-demand run says the
// headline out loud on the machine that asked for it.
if (!_preInit && { hasInterface }) then {
    systemChat format ["%1 %2 — %3 problem(s), %4 warning(s). Details in the RPT.",
                       _tag, if (_ok) then { "PASS" } else { "FAIL" },
                       count _problems, count _warnings];
};

// The full lists are left where another diagnostic (or a test harness) can read
// them without re-running the walk. Read-only for everyone else.
aq_validate_problems = _problems;
aq_validate_warnings = _warnings;

_ok
