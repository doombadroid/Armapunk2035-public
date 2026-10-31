// SPDX-License-Identifier: MIT
/*
    diagnostics/fn_dryRun.sqf  —  aq_fnc_dryRun

    Purpose: roll N instances of a radiant template through the real generator
    and print each one fully substituted — title, summary, every objective,
    every reward — without touching game state.

    WHY THIS EXISTS
        A template is a sentence with holes in it, and the only way to know
        whether the holes produce sense is to read the finished sentences.
        Without this the loop for tuning a template is: edit config, restart the
        server, log in, walk to a giver, hope the roll picks the slot you were
        testing, read one offer, repeat. Authors do not do that, so templates
        ship with slots that read fine in config and produce nonsense in play —
        a bounty for three of a faction forty kilometres away, a reward that
        scaled by a place name. Printing twenty instances in one call turns that
        into a two-second read.

        THE SECOND REASON IS WHY THIS FILE IS SHORT. An earlier version carried
        its own generator: its own random source, its own pool reader, its own
        substituter. It could therefore disagree with the thing it was there to
        predict, and it did — a different pool shape, no label/value split, no
        weights. A dry run that answers a different question from the live board
        is worse than no dry run, because its output is believed. So this drives
        aq_fnc_genOffer. Whatever the board would produce is what prints here,
        including the failures.

    WHAT IT DOES
        Builds a generator context forcing one template and a seed, calls
        aq_fnc_genOffer N times, and prints each returned instance. Reuses one
        context across the run, so the sequence varies exactly as a board's
        would while remaining reproducible from the seed.

        It records nothing: no history is passed in, no offer is consumed, no
        slot usage is stamped, and the engine's own random state is untouched
        because the generator carries its own. The cost of that isolation is
        stated in the output rather than hidden — `notUsedWithin` cannot be
        applied without a player's persisted history, and it is listed as
        NOT APPLIED. `distanceFrom` IS applied whenever a giver position can be
        resolved, because the giver's marker is on the map and measuring against
        it is the whole point of the constraint; when it cannot be resolved, the
        generator's own rejection line says so.

    Usage:
        ["courier_contract", 10] call aq_fnc_dryRun;             // ten rolls
        ["courier_contract", 10, 1234] call aq_fnc_dryRun;       // the same ten
        ["courier_contract", 10, 1234, "depot_clerk"] call aq_fnc_dryRun;

    Runs synchronously and never suspends, so `call` it; the instance count is
    capped so a dry run cannot outlast the frame it was asked for.
*/

params [
    ["_templateId", "", [""]],
    ["_count",       5, [0]],
    ["_seed",       -1, [0]],     // < 0 = let the generator pick and record one
    ["_giverId",    "", [""]]     // "" = the template's first declared giver
];

private _tag = "[AQ-DRYRUN]";
private _maxInstances = 25;       // bounded output

if (_templateId isEqualTo "") exitWith {
    diag_log format ["%1 ERROR: no template id given. Usage: [""<template>"", 10] call aq_fnc_dryRun", _tag];
    if (hasInterface) then { systemChat format ["%1 no template id given.", _tag] };
    false
};

if (isNil "aq_fnc_genOffer") exitWith {
    diag_log format ["%1 ERROR: aq_fnc_genOffer is not defined, so there is no generator to dry-run. Check CfgFunctions.", _tag];
    if (hasInterface) then { systemChat format ["%1 the generator is not loaded.", _tag] };
    false
};

private _asked = round _count;
_count = _asked max 1 min _maxInstances;
if (_asked > _maxInstances) then {
    diag_log format ["%1 NOTE: %2 instances requested, capped to %3 so a dry run cannot flood the log.",
                     _tag, _asked, _maxInstances];
};

// Self-contained config lookup, as with the other diagnostics: this must work
// whether or not the radiant engine ever armed.
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

private _templates = ["AQ_Templates"] call _root;
private _template = configNull;
{
    if ((configName _x) isEqualTo _templateId) exitWith { _template = _x };
} forEach ([_templates] call _subs);

if (isNull _template) exitWith {
    private _avail = ([_templates] call _subs) apply { configName _x };
    diag_log format ["%1 ERROR: '%2' is not a class in AQ_Templates. Available: %3",
                     _tag, _templateId, _avail];
    if (hasInterface) then {
        systemChat format ["%1 no template '%2'. Available: %3", _tag, _templateId, _avail];
    };
    false
};

// A template is offered BY a giver, and half its constraints are measured from
// that giver's position, so rolling one without naming a giver measures nothing.
// Taking the template's own first entry is the answer that needs no argument and
// is right almost every time.
private _givers = [_template, "givers"] call _gArr;
if (_giverId isEqualTo "") then {
    { if (_x isEqualType "" && {_x != ""}) exitWith { _giverId = _x }; } forEach _givers;
};

// ---------------------------------------------------------------------------
// What this run cannot check
// ---------------------------------------------------------------------------
private _unapplied = [];
{
    private _s = _x;
    private _sn = configName _s;
    if (([_s, "notUsedWithin", 0] call _gNum) > 0) then {
        _unapplied pushBack format
            ["%1: notUsedWithin = %2 — needs a player's persisted slot history, which a dry run deliberately does not read or write",
             _sn, [_s, "notUsedWithin", 0] call _gNum];
    };
    private _df = [_s, "distanceFrom", ""] call _gTxt;
    if (_df isEqualTo "player") then {
        _unapplied pushBack format
            ["%1: distanceFrom = ""player"" — no player is asking, so the generator measures from the giver instead, exactly as it does for a shared board offer",
             _sn];
    };
} forEach ([_template >> "slots"] call _subs);

diag_log format ["%1 --- template '%2', %3 instance(s), seed %4, giver '%5' ---",
                 _tag, _templateId, _count,
                 if (_seed < 0) then { "none given (the generator picks one and records it)" } else { str _seed },
                 _giverId];
diag_log format ["%1 weight %2, givers %3", _tag, [_template, "weight", 0] call _gNum, _givers];
if (_giverId isEqualTo "") then {
    diag_log format ["%1 NOTE: no giver to measure from. Any slot with distanceFrom will fail to fill, and the generator will say so below. Pass one as the fourth argument.", _tag];
};
{
    diag_log format ["%1 NOT APPLIED  %2", _tag, _x];
} forEach _unapplied;

// ---------------------------------------------------------------------------
// Roll
// ---------------------------------------------------------------------------
/*
    One context for the whole run. The generator draws this call's seed from the
    running state and re-seeds from it, so the sequence keeps varying while the
    run as a whole is reproducible from the seed given here — which is what makes
    "the same ten, every time" true.

    No "history" key and no "now": with no history there is nothing for
    notUsedWithin to reject, and the generator refuses to guess a clock it was
    not given rather than filtering against one.
*/
private _ctx = createHashMap;
_ctx set ["template", _templateId];
_ctx set ["player", objNull];
if (_seed >= 0) then { _ctx set ["seed", round _seed]; };

private _failed = 0;

for "_i" from 1 to _count do {
    private _inst = [_giverId, _ctx] call aq_fnc_genOffer;

    if (!(_inst isEqualType createHashMap) || {count _inst == 0}) then {
        _failed = _failed + 1;
        diag_log format ["%1 [%2/%3] GENERATION FAILED — the reason is in the [AQ] genOffer / pickFromPool lines above.", _tag, _i, _count];
    } else {
        private _slots = _inst getOrDefault ["slots", createHashMap];
        diag_log format ["%1 [%2/%3] ------------------------------------------", _tag, _i, _count];
        diag_log format ["%1   id        %2  (seed %3)", _tag, _inst getOrDefault ["id", "?"], _inst getOrDefault ["seed", -1]];
        diag_log format ["%1   slots     %2", _tag,
            (keys _slots) apply {
                private _v = _slots get _x;
                if (_v isEqualType createHashMap) then {
                    format ["%1=%2 (%3)", _x, _v getOrDefault ["value", "?"], _v getOrDefault ["label", ""]]
                } else {
                    format ["%1=%2", _x, _v]
                }
            }];
        diag_log format ["%1   title     %2", _tag, _inst getOrDefault ["title", ""]];
        diag_log format ["%1   summary   %2", _tag, _inst getOrDefault ["summary", ""]];
        private _desc = _inst getOrDefault ["description", ""];
        if !(_desc isEqualTo "") then {
            diag_log format ["%1   descr     %2", _tag, _desc];
        };

        private _objs = _inst getOrDefault ["objectives", []];
        if (_objs isEqualTo []) then {
            diag_log format ["%1   objective (none — this instance can never complete)", _tag];
        } else {
            {
                private _o = _x;
                private _line = "";
                { _line = _line + format ["%1=%2  ", _x, _o get _x]; } forEach (keys _o);
                diag_log format ["%1   objective %2", _tag, _line];
            } forEach _objs;
        };

        // Rewards print as they will be PAID. scaleWith is applied by the
        // generator and removed from the instance, so a figure here that
        // disagrees with the offer screen would mean the two scale in different
        // places — which is the bug this printing is positioned to catch.
        private _rw = _inst getOrDefault ["rewards", createHashMap];
        if (count _rw == 0) then {
            diag_log format ["%1   reward    (no rewards class)", _tag];
        } else {
            private _line = "";
            { _line = _line + format ["%1=%2  ", _x, _rw get _x]; } forEach (keys _rw);
            diag_log format ["%1   reward    %2", _tag, _line];
        };

        private _used = _inst getOrDefault ["used", []];
        if !(_used isEqualTo []) then {
            diag_log format ["%1   history   would stamp %2 on accept (not written by a dry run)", _tag, _used];
        };
    };
};

diag_log format ["%1 --- %2 instance(s), %3 rejected ---", _tag, _count, _failed];
if (hasInterface) then {
    systemChat format ["%1 '%2': %3 rolled, %4 rejected. Details in the RPT.",
                       _tag, _templateId, _count, _failed];
};

(_failed == 0)
