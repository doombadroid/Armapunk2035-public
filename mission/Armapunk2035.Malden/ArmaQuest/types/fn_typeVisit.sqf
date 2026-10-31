// SPDX-License-Identifier: MIT
/*
    types/fn_typeVisit.sqf

    Objective type "visit" — reach a marker within a radius.

    WHY THIS EXISTS
        "Go there" is the cheapest objective to author and the easiest one to
        make expensive at runtime: it is the type a catalogue ends up with
        dozens of, and a naive version runs a per-frame or per-second distance
        check for every one of them on every client. So this watcher asks how
        long the player *could not possibly* have arrived for, and sleeps that
        long. A player three kilometres away cannot cross the line in the next
        second no matter what they are flying, so looking is wasted work; as
        they close, the poll tightens by itself. The cost of a visit objective
        therefore scales with how close the player is to caring about it, not
        with how many exist.

    WHAT IT DOES
        arm       resolves the marker, subscribes to its own internal arrival
                  event, spawns the distance-scaled watcher.
        event     accepts the watcher's arrival and answers "satisfied".
        disarm    clears the run flag, terminates the watcher, unsubscribes.
                  Idempotent — safe to call twice, or before `arm`.
        progress  [0 or 1, 1, "Reach Foundry - 1.2 km"]
        describe  "Travel to Foundry"

    CONFIG
        marker    STRING  destination marker name.                   required
        radius    NUMBER  metres from the marker that count as there. default 30
        onFoot    NUMBER  1 = arriving in a vehicle does not count.  default 0
        label     STRING  display name for the place ($STR_ ok).
                          default: the marker's own text, else the marker name.
        text      STRING  overrides the generated describe line.     optional

    EVENTS CONSUMED
        "aq_internal_visit", args [ _questId, _objectiveId ] — fired by this
            type's own watcher. Internal events carry the ids because the bus
            routes by name to every subscriber, so a second visit objective
            would otherwise complete on the first one's arrival.

    ENGINE API (owned by functions/ — called by name, per DESIGN.md 4, 5)
        [_ctx, _event]       call aq_fnc_subscribe    route _event to this objective
        [_ctx, ""]           call aq_fnc_unsubscribe  "" = every subscription
        [_ctx, _fact, _args] call aq_fnc_report       client->server fact; the
                                                      server re-validates and decides
        [_name, _args]       call aq_fnc_event        the bus itself
        [_string, _subst]    call aq_fnc_text         literal or $STR_, plus %SLOT%

    THE SIXTH VERB
        `events` is optional and returns an ARRAY of event names to route here,
        declared before `arm` runs. This type subscribes during `arm` instead,
        so it answers with an empty array — but it must answer, because a type
        that falls through to its unknown-verb branch writes a line to the RPT
        every time an objective arms.

    Usage:
        ["visit", aq_fnc_typeVisit] call aq_fnc_registerType;
        ["arm", _ctx] call aq_fnc_typeVisit;
*/

params [
    ["_verb", "", [""]],
    ["_ctx", createHashMap, [createHashMap]]
];

private _qid = _ctx getOrDefault ["quest", "?"];
private _oid = _ctx getOrDefault ["objective", "?"];

private _fail = {
    params ["_msg"];
    diag_log format ["[AQ] typeVisit %1/%2: %3", _qid, _oid, _msg];
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
// ones, and radiant substitution is textual, so "30" has to read back as 30.
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
                    // Substitution happens on the way out of config: a generated
                    // quest read back through its TEMPLATE must resolve %PLACE%
                    // to the marker it was filled with, or the destination is
                    // the map origin and `arm` refuses.
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

private _marker = ["marker", ""] call _cfgGet;
private _radius = ["radius", 30] call _cfgGet;
private _onFoot = (["onFoot", 0] call _cfgGet) > 0;

if (_marker isEqualTo "") exitWith { ["config has no `marker`"] call _fail };
if (_radius < 1) then { _radius = 30 };

private _pos = getMarkerPos _marker;

private _place = ["label", ""] call _cfgGet;
if (_place isEqualTo "") then { _place = markerText _marker };
if (_place isEqualTo "") then { _place = _marker };
_place = [_place] call _txt;

private _internal = "aq_internal_visit";

// Teardown in one place: the flag stops the loop at its next check, and
// `terminate` is the backstop for a loop parked in a sleep.
private _stopWatcher = {
    _state set ["run", false];
    private _h = _state getOrDefault ["h", scriptNull];
    if !(isNull _h) then { terminate _h };
    _state set ["h", scriptNull];
};

switch (toLower _verb) do {

    case "arm": {
        if (_pos isEqualTo [0,0,0]) exitWith {
            [format ["marker '%1' does not exist, so the destination is the map origin", _marker]] call _fail
        };

        call _stopWatcher;
        _state set ["done", false];

        [_ctx, _internal] call aq_fnc_subscribe;

        _state set ["run", true];
        private _h = [_ctx, _state, _player, _pos, _radius, _onFoot, _internal, _qid, _oid] spawn {
            params ["_ctx", "_state", "_player", "_pos", "_radius", "_onFoot", "_internal", "_qid", "_oid"];

            while { _state getOrDefault ["run", false] } do {
                if (isNull _player) exitWith {
                    diag_log format ["[AQ] typeVisit %1/%2: watcher lost its player object, stopping", _qid, _oid];
                    _state set ["run", false];
                };

                private _d = _player distance2D _pos;
                _state set ["dist", _d];

                if (alive _player
                    && {_d <= _radius}
                    && {!_onFoot || {vehicle _player isEqualTo _player}}) then {
                    [_internal, [_qid, _oid]] call aq_fnc_event;
                    _state set ["run", false];
                } else {
                    // The whole point of this type: sleep for as long as
                    // arrival is physically impossible. 120 m/s is a generous
                    // ceiling for the fastest approach on any Arma map, and the
                    // clamp keeps a very distant objective from going to sleep
                    // for so long that arrival feels laggy.
                    sleep ((((_d - _radius) / 120) max 0.5) min 15);
                };
            };
        };
        _state set ["h", _h];
        true
    };

    case "disarm": {
        call _stopWatcher;
        [_ctx, ""] call aq_fnc_unsubscribe;
        true
    };

    // Optional sixth verb: this type subscribes during `arm`, so nothing is
    // declared here — but the verb must be answered rather than fall through.
    case "events": { [] };

    case "event": {
        (_ctx getOrDefault ["event", ["", []]]) params [["_name", "", [""]], ["_args", [], [[]]]];
        if !(_name isEqualTo _internal) exitWith { false };

        // The bus routes by name to every subscriber, so an internal event has
        // to prove it is ours before it is allowed to finish anything.
        if !((_args param [0, "", [""]]) isEqualTo _qid) exitWith { false };
        if !((_args param [1, "", [""]]) isEqualTo _oid) exitWith { false };
        if (_state getOrDefault ["done", false]) exitWith { true };

        // Re-checked here rather than trusted from the watcher, so the same
        // guard covers a host that fires the arrival itself.
        if (isNull _player) exitWith { ["arrival with no player object"] call _fail };
        if (_player distance2D _pos > _radius) exitWith { false };
        if (_onFoot && {!(vehicle _player isEqualTo _player)}) exitWith { false };

        _state set ["done", true];
        call _stopWatcher;
        [_ctx, "visit", [_marker]] call aq_fnc_report;
        true
    };

    case "progress": {
        if (_state getOrDefault ["done", false]) exitWith {
            [1, 1, format ["Reached %1", _place]]
        };
        private _d = if (isNull _player) then { _state getOrDefault ["dist", -1] } else { _player distance2D _pos };
        private _tail = if (_d < 0) then { "" } else {
            if (_d >= 1000) then { format [" - %1 km", (_d / 1000) toFixed 1] }
            else { format [" - %1 m", round _d] };
        };
        [0, 1, format ["Reach %1%2", _place, _tail]]
    };

    case "describe": {
        private _t = ["text", ""] call _cfgGet;
        if (_t != "") exitWith { [_t] call _txt };
        if (_onFoot) exitWith { format ["Travel to %1 and arrive on foot", _place] };
        format ["Travel to %1", _place]
    };

    default { [format ["unknown verb '%1'", _verb]] call _fail };
};
