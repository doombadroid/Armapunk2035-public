// SPDX-License-Identifier: MIT
/*
    types/fn_typeCraft.sqf

    Objective type "craft" — craft N of an item.

    WHY THIS EXISTS
        Crafting is the flow that is easiest to confuse with a stock check, and
        the confusion is expensive: a crafted item is usually consumed, sold or
        fitted moments later, so an objective that counted what the player is
        holding would tick back down to zero and un-complete itself. This type
        counts the act, not the outcome, and counts it only from the moment the
        objective was armed — otherwise a stockpile crafted last week finishes
        the job the instant it is accepted.

    WHAT IT DOES
        arm       subscribes to the craft event and zeroes the accumulator.
        event     adds the crafted quantity, reports the craft as a fact,
                  answers whether the running total has reached the target.
        disarm    drops every subscription. Idempotent, no watcher to kill.
        progress  [made, needed, "Lockpick crafted 3/5"]
        describe  "Craft 5 x Lockpick"

    CONFIG
        item      STRING   virtual item class produced.           required
        count     NUMBER   how many must be crafted.              default 1
        station   STRING   only crafts at this bench/station id count. optional
        label     STRING   display name for the item ($STR_ ok).  default: item
        text      STRING   overrides the generated describe line. optional
        events[]  ARRAY    event names carrying a craft. default { "aq_crafted" }

    EVENTS CONSUMED
        "aq_crafted", args [ _item, _qty, _stationId ]
            _qty defaults to 1, _stationId is only needed when `station` is set.
        Host call site:  ["aq_crafted", ["lockpick", 1, "workbench"]] call aq_fnc_event;

    ENGINE API (owned by functions/ — called by name, per DESIGN.md 4, 5, 9)
        [_ctx, _event]       call aq_fnc_subscribe    route _event to this objective
        [_ctx, ""]           call aq_fnc_unsubscribe  "" = every subscription
        [_ctx, _fact, _args] call aq_fnc_report       client->server fact; the
                                                      server re-validates and decides
        [_string, _subst]    call aq_fnc_text         literal or $STR_, plus %SLOT%

    THE SIXTH VERB
        `events` is optional and returns an ARRAY of event names to route here,
        declared before `arm` runs. This type builds its list from config, so it
        answers with an empty array — but it must answer, because a type that
        falls through to its unknown-verb branch writes a line to the RPT every
        time an objective arms.

    Usage:
        ["craft", aq_fnc_typeCraft] call aq_fnc_registerType;
        ["progress", _ctx] call aq_fnc_typeCraft;   // -> [3, 5, "Lockpick crafted 3/5"]
*/

params [
    ["_verb", "", [""]],
    ["_ctx", createHashMap, [createHashMap]]
];

private _qid = _ctx getOrDefault ["quest", "?"];
private _oid = _ctx getOrDefault ["objective", "?"];

private _fail = {
    params ["_msg"];
    diag_log format ["[AQ] typeCraft %1/%2: %3", _qid, _oid, _msg];
    switch (toLower _verb) do {
        case "progress": { [0, 0, ""] };
        case "describe": { "" };
        default { false };
    };
};

private _cfg   = _ctx getOrDefault ["cfg", configNull];
private _state = _ctx getOrDefault ["state", 0];
// Radiant slot fills. Empty for an authored quest, and empty is a no-op.
private _subst = _ctx getOrDefault ["subst", createHashMap];

if !(_state isEqualType createHashMap) exitWith { ["no state HashMap in context"] call _fail };

// `cfg` is a CONFIG for authored quests and a HashMap for generated (radiant)
// ones, and radiant substitution is textual, so "5" has to read back as 5 when
// a number was wanted.
private _cfgGet = {
    params ["_key", "_def"];
    private _v = _def;
    switch (typeName _cfg) do {
        case "HASHMAP": { _v = _cfg getOrDefault [_key, _def]; };
        case "CONFIG": {
            private _e = _cfg >> _key;
            if (isNumber _e) then { _v = getNumber _e }
            else {
                if (isText _e) then {
                    _v = getText _e;
                    // Substitution happens on the way out of config, so a
                    // generated quest read back through its TEMPLATE does not
                    // hand a raw %SLOT% token to the player.
                    if (!isNil "aq_fnc_text") then { _v = [_v, _subst] call aq_fnc_text };
                }
                else { if (isArray _e) then { _v = getArray _e } };
            };
        };
    };
    if (_def isEqualType 0 && {_v isEqualType ""}) then {
        _v = if (_v isEqualTo "") then { _def } else { parseNumber _v };
    };
    _v
};

private _txt = {
    params [["_s", "", [""]]];
    if (_s isEqualTo "") exitWith { "" };
    if (!isNil "aq_fnc_text") exitWith { [_s, _subst] call aq_fnc_text };
    // UNVERIFIED: `localize` takes the stringtable key without the leading '$'.
    if ((_s select [0,1]) isEqualTo "$") then { localize (_s select [1]) } else { _s }
};

private _item    = ["item", ""] call _cfgGet;
private _need    = ["count", 1] call _cfgGet;
private _station = ["station", ""] call _cfgGet;
if (_item isEqualTo "") exitWith { ["config has no `item`"] call _fail };
if (_need < 1) then { _need = 1 };

private _label = ["label", ""] call _cfgGet;
if (_label isEqualTo "") then { _label = _item };
_label = [_label] call _txt;

private _events = ["events", []] call _cfgGet;
if (!(_events isEqualType []) || {_events isEqualTo []}) then { _events = ["aq_crafted"] };

switch (toLower _verb) do {

    case "arm": {
        _state set ["cur", 0];
        {
            [_ctx, _x] call aq_fnc_subscribe;
        } forEach _events;
        // "events" is the engine's spelling: aq_fnc_armObjective indexes what it
        // finds under that key into the bus. A second spelling leaves it empty.
        _state set ["events", _events];
        [_ctx, "craft", [_item, 0, _need]] call aq_fnc_report;
        true
    };

    case "disarm": {
        [_ctx, ""] call aq_fnc_unsubscribe;
        _state set ["events", []];
        true
    };

    // Optional sixth verb: subscriptions come from config, so nothing is
    // declared here — but the verb must be answered rather than fall through.
    case "events": { [] };

    case "event": {
        (_ctx getOrDefault ["event", ["", []]]) params [["_name", "", [""]], ["_args", [], [[]]]];
        if !(_name in _events) exitWith { false };

        private _evItem = _args param [0, "", [""]];
        if !(_evItem isEqualTo _item) exitWith { false };

        private _qty = _args param [1, 1, [0]];
        if (_qty <= 0) exitWith { false };

        if (_station != "") then {
            private _at = _args param [2, "", [""]];
            if !(_at isEqualTo _station) then { _qty = 0 };
        };
        if (_qty <= 0) exitWith { false };

        private _cur = (_state getOrDefault ["cur", 0]) + _qty;
        _state set ["cur", _cur];

        [_ctx, "craft", [_item, _qty, _need]] call aq_fnc_report;
        _cur >= _need
    };

    case "progress": {
        private _cur = _state getOrDefault ["cur", 0];
        [_cur min _need, _need, format ["%1 crafted %2/%3", _label, _cur min _need, _need]]
    };

    case "describe": {
        private _t = ["text", ""] call _cfgGet;
        if (_t != "") exitWith { [_t] call _txt };
        if (_station != "") exitWith { format ["Craft %1 x %2 at %3", _need, _label, [_station] call _txt] };
        format ["Craft %1 x %2", _need, _label]
    };

    default { [format ["unknown verb '%1'", _verb]] call _fail };
};
