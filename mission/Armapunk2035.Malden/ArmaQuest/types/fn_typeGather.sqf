// SPDX-License-Identifier: MIT
/*
    types/fn_typeGather.sqf

    Objective type "gather" — hold N of an item.

    WHY THIS EXISTS
        Progress accumulated straight from event payloads drifts away from the
        truth. A quantity gets double-counted at a mis-instrumented call site,
        or the player drops the stack after the counter has already ticked, and
        the objective reads "complete" while the item is not in the inventory.
        So a *hold* objective never trusts a payload quantity: it treats every
        event as nothing more than a hint that the stock may have moved, and
        re-reads the real count through the profile. It re-reads on `arm` too,
        so a player who already had the items when they accepted does not have
        to drop them and pick them up again — which is the single most common
        "the quest is broken" report a naive implementation produces.

    WHAT IT DOES
        arm       subscribes to the stock-changed events, then takes an
                  immediate reading so an already-held stack counts.
        event     re-reads the stock, reports the reading as a fact, answers
                  whether the objective is satisfied.
        disarm    drops every subscription. Idempotent, no watcher to kill.
        progress  [held, needed, "Copper 12/20"]
        describe  "Gather 20 x Copper"

    CONFIG
        item      STRING   virtual item class.                    required
        count     NUMBER   how many must be held.                 default 1
        label     STRING   display name for the item ($STR_ ok).  default: item
        text      STRING   overrides the generated describe line. optional
        events[]  ARRAY    event names that mean "stock may have changed".
                           default { "aq_gathered", "aq_bought", "aq_crafted",
                                     "aq_inventory" }

    EVENTS CONSUMED
        Any of the above, args [ _item, _qty ]. Both args are optional: an event
        with no item filters nothing and simply triggers a re-read.

    ENGINE API (owned by functions/ — called by name, per DESIGN.md 4, 5, 9)
        [_ctx, _event]       call aq_fnc_subscribe    route _event to this objective
        [_ctx, ""]           call aq_fnc_unsubscribe  "" = every subscription
        [_ctx, _fact, _args] call aq_fnc_report       client->server fact; the
                                                      server re-validates and decides
        [_key, _args]        call aq_fnc_profile      host mapping (DESIGN.md 9).
                                                      One argument returns the mapped
                                                      NAME; two calls it.
        [_string, _subst]    call aq_fnc_text         literal or $STR_, plus %SLOT%

    THE SIXTH VERB
        `events` is optional and returns an ARRAY of event names the type wants
        routed to it, declared before `arm` runs. This type builds its list from
        config instead, so it answers with an empty array — but it must answer,
        because a type that falls through to its unknown-verb branch writes a
        line to the RPT every time an objective arms.

    Usage:
        ["gather", aq_fnc_typeGather] call aq_fnc_registerType;
        ["progress", _ctx] call aq_fnc_typeGather;   // -> [12, 20, "Copper 12/20"]
*/

params [
    ["_verb", "", [""]],
    ["_ctx", createHashMap, [createHashMap]]
];

private _qid = _ctx getOrDefault ["quest", "?"];
private _oid = _ctx getOrDefault ["objective", "?"];

// Every early exit has to answer in the shape the verb promised, or the journal
// renderer gets a boolean where it expected [cur, max, text] and dies far away
// from the actual mistake.
private _fail = {
    params ["_msg"];
    diag_log format ["[AQ] typeGather %1/%2: %3", _qid, _oid, _msg];
    switch (toLower _verb) do {
        case "progress": { [0, 0, ""] };
        case "describe": { "" };
        default { false };
    };
};

private _cfg    = _ctx getOrDefault ["cfg", configNull];
private _state  = _ctx getOrDefault ["state", 0];
private _player = _ctx getOrDefault ["player", objNull];
// Radiant slot fills. Empty for an authored quest, and empty is a no-op.
private _subst  = _ctx getOrDefault ["subst", createHashMap];

if !(_state isEqualType createHashMap) exitWith { ["no state HashMap in context"] call _fail };

// `cfg` is a CONFIG for authored quests and a HashMap for generated (radiant)
// ones, and radiant substitution is textual — so "20" has to read back as 20
// when a number was wanted. One reader handles both cases rather than eight
// type files each inventing their own guess.
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
                    // Substitution happens on the way out of config. A generated
                    // quest whose objective is resolved back through its TEMPLATE
                    // still holds raw %SLOT% tokens, and a type that reads them
                    // literally is how `item = "%CARGO%"` reaches a player.
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
    // Confirm by putting a $STR_ key in `label` and reading the journal line.
    if ((_s select [0,1]) isEqualTo "$") then { localize (_s select [1]) } else { _s }
};

private _item = ["item", ""] call _cfgGet;
private _need = ["count", 1] call _cfgGet;
if (_item isEqualTo "") exitWith { ["config has no `item`"] call _fail };
if (_need < 1) then { _need = 1 };

private _label = ["label", ""] call _cfgGet;
if (_label isEqualTo "") then { _label = _item };
_label = [_label] call _txt;

private _events = ["events", []] call _cfgGet;
if (!(_events isEqualType []) || {_events isEqualTo []}) then {
    _events = ["aq_gathered", "aq_bought", "aq_crafted", "aq_inventory"];
};

// The one reading that counts. Anything else is a rumour.
private _recount = {
    if (isNull _player) exitWith { _state getOrDefault ["cur", 0] };
    private _uid = ["playerUid", [_player]] call aq_fnc_profile;
    private _n   = ["countItem", [_uid, _item]] call aq_fnc_profile;
    if !(_n isEqualType 0) then {
        diag_log format ["[AQ] typeGather %1/%2: profile countItem returned %3 for '%4', reading 0", _qid, _oid, _n, _item];
        _n = 0;
    };
    _state set ["cur", _n];
    _n
};

switch (toLower _verb) do {

    case "arm": {
        _state set ["cur", _state getOrDefault ["cur", 0]];
        {
            [_ctx, _x] call aq_fnc_subscribe;
        } forEach _events;
        // "events" is the engine's spelling: aq_fnc_armObjective indexes what it
        // finds under that key into the bus, and aq_fnc_disarmObjective unwinds
        // it. A second spelling here would leave the bus half-built.
        _state set ["events", _events];

        private _n = call _recount;
        [_ctx, "gather", [_item, _n, _need]] call aq_fnc_report;
        true
    };

    case "disarm": {
        // Nothing spawned, so teardown is subscriptions only. Unsubscribing
        // with "" clears the lot, which keeps this idempotent even if `arm`
        // failed halfway through its subscribe loop.
        [_ctx, ""] call aq_fnc_unsubscribe;
        _state set ["events", []];
        true
    };

    // Optional sixth verb: this type's subscriptions come from config, so it
    // declares nothing here and answers with an empty array rather than falling
    // through to the unknown-verb branch.
    case "events": { [] };

    case "event": {
        (_ctx getOrDefault ["event", ["", []]]) params [["_name", "", [""]], ["_args", [], [[]]]];
        if !(_name in _events) exitWith { false };

        // A payload item that names something else is not our business. A
        // payload with no item at all is a generic "inventory moved" nudge and
        // does trigger the re-read.
        private _evItem = _args param [0, "", [""]];
        if (_evItem != "" && {!(_evItem isEqualTo _item)}) exitWith { false };

        private _n = call _recount;
        [_ctx, "gather", [_item, _n, _need]] call aq_fnc_report;
        _n >= _need
    };

    case "progress": {
        private _n = _state getOrDefault ["cur", 0];
        [_n min _need, _need, format ["%1 %2/%3", _label, _n min _need, _need]]
    };

    case "describe": {
        private _t = ["text", ""] call _cfgGet;
        if (_t != "") exitWith { [_t] call _txt };
        format ["Gather %1 x %2", _need, _label]
    };

    default { [format ["unknown verb '%1'", _verb]] call _fail };
};
