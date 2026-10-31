// SPDX-License-Identifier: MIT
/*
    types/fn_typeTalk.sqf

    Objective type "talk" — interact with a named giver.

    WHY THIS EXISTS
        Almost every chain needs a "go back and report in" beat, and without a
        type for it that beat gets faked: with a visit objective standing on the
        giver's marker, which completes while the player drives past, or with a
        bespoke script per quest, which is content that cannot be authored in
        config. This type makes the report-in a first-class objective that
        completes on the interaction itself and on nothing else.

        It deliberately does not converse. A giver offers and accepts; anything
        richer is a dialogue system, and a dialogue system pretending to be an
        objective type is how a quest engine grows a second, worse engine inside
        it. What this type knows is that the player interacted with giver X.

    WHAT IT DOES
        arm       subscribes to the interaction event and zeroes the counter.
        event     matches the giver id, counts the interaction, reports it as a
                  fact, answers whether the objective is satisfied.
        disarm    drops every subscription. Idempotent, no watcher to kill.
        progress  [0 or 1, 1, "Report to the Market Trader"]
        describe  "Speak to the Market Trader"

    CONFIG
        giver     STRING  giver id, as declared in AQ_Givers. "" = any giver
                          counts, which is what a "check in with anyone" beat
                          wants.                                    optional
        count     NUMBER  interactions needed. Above 1 only makes sense with a
                          host that fires the event per exchange.   default 1
        label     STRING  display name ($STR_ ok). default: the giver's `name`
                          from AQ_Givers, else the giver id.
        text      STRING  overrides the generated describe line.    optional
        events[]  ARRAY   interaction event names. default { "aq_talked" }

    EVENTS CONSUMED
        "aq_talked", args [ _giverId, _giverObject ]
            _giverObject is optional and unused by the match; the id is the
            identity, because the same giver may be respawned as a new object.
        Host call site:  ["aq_talked", ["market_trader"]] call aq_fnc_event;

    ENGINE API (owned by functions/ — called by name, per DESIGN.md 4, 5)
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

    WHO FIRES aq_talked
        The giver's trigger driver, when the player interacts. Nothing else in
        the library fires it, and a custom driver that forgets to produces
        quests that can be accepted and never finished — see
        aq_fnc_registerTrigger.

    Usage:
        ["talk", aq_fnc_typeTalk] call aq_fnc_registerType;
        ["describe", _ctx] call aq_fnc_typeTalk;   // -> "Speak to the Market Trader"
*/

params [
    ["_verb", "", [""]],
    ["_ctx", createHashMap, [createHashMap]]
];

private _qid = _ctx getOrDefault ["quest", "?"];
private _oid = _ctx getOrDefault ["objective", "?"];

private _fail = {
    params ["_msg"];
    diag_log format ["[AQ] typeTalk %1/%2: %3", _qid, _oid, _msg];
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
// ones, and radiant substitution is textual, so "1" has to read back as 1.
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

private _giver = ["giver", ""] call _cfgGet;
private _need  = ["count", 1] call _cfgGet;
if (_need < 1) then { _need = 1 };

// The display name comes from the giver's own declaration so an objective does
// not have to repeat it, and renaming a giver in one place renames it in every
// quest that points at them.
private _label = ["label", ""] call _cfgGet;
if (_label isEqualTo "" && {_giver != ""}) then {
    private _gc = missionConfigFile >> "AQ_Givers" >> _giver >> "name";
    if !(isText _gc) then { _gc = configFile >> "AQ_Givers" >> _giver >> "name" };
    if (isText _gc) then { _label = getText _gc };
};
if (_label isEqualTo "") then { _label = if (_giver != "") then { _giver } else { "your contact" } };
_label = [_label] call _txt;

private _events = ["events", []] call _cfgGet;
if (!(_events isEqualType []) || {_events isEqualTo []}) then { _events = ["aq_talked"] };

switch (toLower _verb) do {

    case "arm": {
        _state set ["cur", 0];
        {
            [_ctx, _x] call aq_fnc_subscribe;
        } forEach _events;
        // "events" is the engine's spelling: aq_fnc_armObjective indexes what it
        // finds under that key into the bus. A second spelling leaves it empty.
        _state set ["events", _events];
        [_ctx, "talk", [_giver, 0, _need]] call aq_fnc_report;
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

        private _who = _args param [0, "", [""]];
        // An empty `giver` means any contact will do; otherwise the id must
        // match. Ids are compared case-insensitively because they are written
        // by hand in two places — the giver class and the objective.
        if (_giver != "" && {!((toLower _who) isEqualTo (toLower _giver))}) exitWith { false };

        private _cur = (_state getOrDefault ["cur", 0]) + 1;
        _state set ["cur", _cur];
        [_ctx, "talk", [_who, _cur, _need]] call aq_fnc_report;
        _cur >= _need
    };

    case "progress": {
        private _cur = (_state getOrDefault ["cur", 0]) min _need;
        private _text = if (_cur >= _need) then {
            format ["Spoke to %1", _label]
        } else {
            if (_need > 1) then { format ["Speak to %1 %2/%3", _label, _cur, _need] }
            else { format ["Speak to %1", _label] };
        };
        [_cur, _need, _text]
    };

    case "describe": {
        private _t = ["text", ""] call _cfgGet;
        if (_t != "") exitWith { [_t] call _txt };
        format ["Speak to %1", _label]
    };

    default { [format ["unknown verb '%1'", _verb]] call _fail };
};
