// SPDX-License-Identifier: MIT
/*
    types/fn_typeAction.sqf

    Objective type "action" — count N occurrences of a named host event.

    WHY THIS EXISTS
        The other seven types each know something concrete about the fact they
        count: gather re-reads a stock, sell and craft accumulate a flow, kill
        filters a corpse, deliver and zoneHold watch a place, talk matches a
        giver id. A host's own instrumentation produces plenty of facts that
        fit none of those shapes — a terminal hacked, a door breached, a bribe
        paid, a scan completed — and none of them deserves its own type file
        and its own registration just to be counted. This type is "do X, N
        times" for whatever X the host is prepared to name: it counts
        occurrences of exactly one event, chosen entirely by config, and
        leaves what the event means and when it fires to the host's own call
        site.

    WHAT IT DOES
        arm       subscribes to the configured verb and zeroes the accumulator.
        event     adds the reported quantity, clamped by AQ_Settings >>
                  factMaxCount, reports the action as a fact, answers whether
                  the running total has reached the target.
        disarm    drops every subscription. Idempotent, no watcher to kill.
        progress  [done, needed, "door_breached 3/5"]
        describe  "Do door_breached x5"

    CONFIG
        verb      STRING   the event verb to count.                required
        count     NUMBER   how many occurrences are needed.         default 1
        label     STRING   display name for the verb ($STR_ ok).    default: verb
        text      STRING   overrides the generated describe line.   optional

        Unlike its siblings, there is no `events[]` override here. `verb` is
        not a filter applied to a shared bus name, it IS the bus name: the
        host names the fact by calling [_verb, [...]] call aq_fnc_event
        directly, so letting a quest redirect the subscription would mean
        letting it redirect what it counts.

    EVENTS CONSUMED
        `verb`, args [ _qty ]
            _qty defaults to 1. There is no fixed event name like "aq_sold" or
            "aq_crafted" to filter on here — the configured verb IS that name.
        Host call site:  ["door_breached", [1]] call aq_fnc_event;

    ENGINE API (owned by functions/ — called by name, per DESIGN.md 4, 5, 9)
        [_ctx, _event]       call aq_fnc_subscribe    route _event to this objective
        [_ctx, ""]           call aq_fnc_unsubscribe  "" = every subscription
        [_ctx, _fact, _args] call aq_fnc_report       client->server fact; the
                                                      server re-validates and decides
        [_key, _default]     call aq_fnc_setting      one AQ_Settings key, typed
        [_string, _subst]    call aq_fnc_text         literal or $STR_, plus %SLOT%

    THE SIXTH VERB
        `events` is optional and returns an ARRAY of event names the type wants
        routed to it, declared before `arm` runs. This type subscribes to its
        one configured verb during `arm`, so it answers with an empty array —
        but it must answer, because a type that falls through to its
        unknown-verb branch writes a line to the RPT every time an objective
        arms.

    Usage:
        ["action", aq_fnc_typeAction] call aq_fnc_registerType;
        ["progress", _ctx] call aq_fnc_typeAction;   // -> [3, 5, "door_breached 3/5"]
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
    diag_log format ["[AQ] typeAction %1/%2: %3", _qid, _oid, _msg];
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
// ones, and radiant substitution is textual — so "5" has to read back as 5
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
    // Confirm by putting a $STR_ key in `label` and reading the journal line.
    if ((_s select [0,1]) isEqualTo "$") then { localize (_s select [1]) } else { _s }
};

// Named "_actionVerb" rather than "_verb" because "_verb" is already the
// dispatch parameter above (arm/event/progress/...) — the two are unrelated
// namespaces that happen to share a word.
private _actionVerb = ["verb", ""] call _cfgGet;
private _need       = ["count", 1] call _cfgGet;
if (_actionVerb isEqualTo "") exitWith { ["config has no `verb`"] call _fail };
if (_need < 1) then { _need = 1 };

private _label = ["label", ""] call _cfgGet;
if (_label isEqualTo "") then { _label = _actionVerb };
_label = [_label] call _txt;

// The ceiling on a single reported fact (AQ_Settings >> factMaxCount): a
// ceiling on the absurd, not on the plausible. server/fn_srvFact.sqf applies
// the same setting to every fact crossing the trust boundary; this type
// applies it too so its own running total cannot be inflated by one bad
// report before the server's authoritative copy catches up.
private _maxCount = ["factMaxCount", 10000] call aq_fnc_setting;
if (!(_maxCount isEqualType 0) || {_maxCount <= 0}) then { _maxCount = 10000; };

switch (toLower _verb) do {

    case "arm": {
        // Re-arming after an abandon-and-retake must start from zero, or the
        // second attempt completes on the first attempt's occurrences.
        _state set ["cur", 0];
        [_ctx, _actionVerb] call aq_fnc_subscribe;
        // "events" is the engine's spelling: aq_fnc_armObjective indexes what it
        // finds under that key into the bus, and aq_fnc_disarmObjective unwinds
        // it. A second spelling here would leave the bus half-built.
        _state set ["events", [_actionVerb]];
        [_ctx, "action", [_actionVerb, 0, _need]] call aq_fnc_report;
        true
    };

    case "disarm": {
        // Nothing spawned, so teardown is subscriptions only. Unsubscribing
        // with "" clears the lot, which keeps this idempotent even if `arm`
        // never ran.
        [_ctx, ""] call aq_fnc_unsubscribe;
        _state set ["events", []];
        true
    };

    // Optional sixth verb: the one event this type wants is subscribed
    // directly during `arm`, so it declares nothing here — but it must
    // answer, because a type that falls through to its unknown-verb branch
    // writes a line to the RPT every time an objective arms.
    case "events": { [] };

    case "event": {
        (_ctx getOrDefault ["event", ["", []]]) params [["_name", "", [""]], ["_args", [], [[]]]];
        if !(_name isEqualTo _actionVerb) exitWith { false };

        private _qty = _args param [0, 1, [0]];
        if (_qty <= 0) exitWith { false };
        // A ceiling on the absurd, not on the plausible: one inflated report
        // can push the running total, never past what the ceiling allows.
        _qty = _qty min _maxCount;

        private _cur = (_state getOrDefault ["cur", 0]) + _qty;
        _state set ["cur", _cur];

        // The raw occurrence goes up as a fact, not as "I am finished". The
        // server keeps its own tally and decides; the boolean below is only
        // the client's read of its own objective, used to stop watching early.
        [_ctx, "action", [_actionVerb, _cur, _need]] call aq_fnc_report;
        _cur >= _need
    };

    case "progress": {
        private _cur = _state getOrDefault ["cur", 0];
        [_cur min _need, _need, format ["%1 %2/%3", _label, _cur min _need, _need]]
    };

    case "describe": {
        private _t = ["text", ""] call _cfgGet;
        if (_t != "") exitWith { [_t] call _txt };
        format ["Do %1 x%2", _label, _need]
    };

    default { [format ["unknown verb '%1'", _verb]] call _fail };
};
