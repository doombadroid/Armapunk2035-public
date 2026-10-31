// SPDX-License-Identifier: MIT
/*
    types/fn_typeZoneHold.sqf

    Objective type "zoneHold" — stand inside a radius, on foot, for N seconds.

    WHY THIS EXISTS
        A haul that ends the moment a vehicle crosses a marker is not gameplay;
        it is a distance check with a payout attached, and nothing about it can
        be contested. This type is what turns the end of a run into a moment:
        the player has to get out, stay put, stay visible and stay committed for
        a known number of seconds, and anyone who wants to stop them has a
        window in which to do it.

        Two consequences follow, and both are the reason this file is longer
        than the other seven:

        1. The countdown has to be *visible*. A timer the player cannot see is
           indistinguishable from a stuck quest, so progress is reported on a
           tick and `progress` computes live between ticks rather than returning
           the last stored value.
        2. An abort is a fact, not a verdict. Leaving the circle, climbing into
           a vehicle and dying are reported as they happen and the server
           decides what they mean — reset the timer for a forgiving cargo run,
           fail the quest outright for a tense one. A client that decided this
           for itself would hard-code one difficulty into the engine.

        Where the design is silent, this file takes the reading that keeps the
        client dumb: on abort the local accumulator drops to zero, because
        crediting time the server has not confirmed is the error that pays out
        for a hold that never happened. If the server's policy is to keep the
        partial progress, its own tally is the one that counts and the client's
        display corrects itself on the next sync.

    WHAT IT DOES
        arm       resolves the marker, subscribes to its own internal
                  completion event, spawns the watcher.
        event     accepts the watcher's completion, consumes `consume[]` and
                  answers "satisfied".
        disarm    clears the run flag, terminates the watcher, unsubscribes.
                  Idempotent — safe to call twice, or before `arm`.
        progress  [secondsHeld, secondsNeeded, "Holding Foundry yard 34/90 s"]
        describe  "Hold the Foundry yard for 90 seconds, on foot"

    CONFIG
        marker      STRING  the zone's marker name.                  required
        radius      NUMBER  metres.                                  default 25
        seconds     NUMBER  how long the hold must last.             default 60
        onFoot      NUMBER  1 = being in a vehicle aborts.           default 1
        consume[]   ARRAY   { {"class", qty}, ... } taken on success. optional
        reportEvery NUMBER  seconds between progress reports.        default 1
        resetOnAbort NUMBER 1 = the local timer restarts on abort.   default 1
        label       STRING  display name for the zone ($STR_ ok).
                            default: the marker's own text, else the marker name.
        text        STRING  overrides the generated describe line.   optional

    EVENTS CONSUMED
        "aq_internal_zonehold", args [ _questId, _objectiveId ] — fired by this
            type's own watcher. Internal events carry the ids because the bus
            routes by name to every subscriber, so a second zoneHold objective
            would otherwise complete on the first one's timer.

    ENGINE API (owned by functions/ — called by name, per DESIGN.md 4, 5, 9)
        [_ctx, _event]       call aq_fnc_subscribe    route _event to this objective
        [_ctx, ""]           call aq_fnc_unsubscribe  "" = every subscription
        [_ctx, _fact, _args] call aq_fnc_report       client->server fact; the
                                                      server re-validates and decides
        [_name, _args]       call aq_fnc_event        the bus itself
        [_key, _args]        call aq_fnc_profile      host mapping (DESIGN.md 9)
        [_string, _subst]    call aq_fnc_text         literal or $STR_, plus %SLOT%

    THE SIXTH VERB
        `events` is optional and returns an ARRAY of event names to route here,
        declared before `arm` runs. This type subscribes during `arm` instead,
        so it answers with an empty array — but it must answer, because a type
        that falls through to its unknown-verb branch writes a line to the RPT
        every time an objective arms.

    WHICH MACHINE TAKES consume[]
        The `event` verb runs twice: on the client, for the watcher's own
        teardown and the local display, and again on the server against the
        authoritative copy of the state. Only the server's run may take the
        listed items. `_ctx get "server"` is how the two are told apart. The
        design's rule is that the server owns anything that pays, and consuming
        a manifest is that operation run backwards; a client that took the items
        itself would also take them twice on a listen server, where both
        invocations happen on one machine.

    UNVERIFIED: a HashMap is a reference type, so the `state` map handed to the
        spawned watcher is the same map `disarm` and `progress` later read. The
        teardown and the live countdown both depend on it. Confirm by arming an
        objective, reading `progress` from the debug console while the watcher
        runs, and checking the number advances.

    Usage:
        ["zoneHold", aq_fnc_typeZoneHold] call aq_fnc_registerType;
        ["arm", _ctx] call aq_fnc_typeZoneHold;
*/

params [
    ["_verb", "", [""]],
    ["_ctx", createHashMap, [createHashMap]]
];

private _qid = _ctx getOrDefault ["quest", "?"];
private _oid = _ctx getOrDefault ["objective", "?"];

private _fail = {
    params ["_msg"];
    diag_log format ["[AQ] typeZoneHold %1/%2: %3", _qid, _oid, _msg];
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
// True only in the server's own invocation. See WHICH MACHINE TAKES consume[].
private _authoritative = _ctx getOrDefault ["server", false];

if !(_state isEqualType createHashMap) exitWith { ["no state HashMap in context"] call _fail };

// `cfg` is a CONFIG for authored quests and a HashMap for generated (radiant)
// ones, and radiant substitution is textual, so "90" has to read back as 90.
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
                    // hold read back through its TEMPLATE must resolve %PLACE%
                    // to the marker it was filled with, or the zone is the map
                    // origin and `arm` refuses.
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

private _marker  = ["marker", ""] call _cfgGet;
private _radius  = ["radius", 25] call _cfgGet;
private _seconds = ["seconds", 60] call _cfgGet;
private _onFoot  = (["onFoot", 1] call _cfgGet) > 0;
private _every   = ["reportEvery", 1] call _cfgGet;
private _reset   = (["resetOnAbort", 1] call _cfgGet) > 0;
private _consume = ["consume", []] call _cfgGet;

if (_marker isEqualTo "") exitWith { ["config has no `marker`"] call _fail };
if (_radius < 1) then { _radius = 25 };
if (_seconds < 1) then { _seconds = 60 };
if (_every < 0.2) then { _every = 1 };
if !(_consume isEqualType []) then { _consume = [] };

private _pos = getMarkerPos _marker;

private _place = ["label", ""] call _cfgGet;
if (_place isEqualTo "") then { _place = markerText _marker };
if (_place isEqualTo "") then { _place = _marker };
_place = [_place] call _txt;

private _internal = "aq_internal_zonehold";

// Teardown in one place: the flag stops the loop at its next check, and
// `terminate` is the backstop for a loop parked in a sleep. A hold watcher
// ticks every second, so one that outlives its objective is the exact thing
// that makes a quest system a performance complaint.
private _stopWatcher = {
    _state set ["run", false];
    _state set ["inside", false];
    private _h = _state getOrDefault ["h", scriptNull];
    if !(isNull _h) then { terminate _h };
    _state set ["h", scriptNull];
};

switch (toLower _verb) do {

    case "arm": {
        if (_pos isEqualTo [0,0,0]) exitWith {
            [format ["marker '%1' does not exist, so the zone is the map origin", _marker]] call _fail
        };

        call _stopWatcher;
        _state set ["held", 0];
        _state set ["last", time];
        _state set ["inside", false];
        _state set ["done", false];

        [_ctx, _internal] call aq_fnc_subscribe;

        _state set ["run", true];
        private _h = [_ctx, _state, _player, _pos, _radius, _seconds, _onFoot, _every, _reset, _internal, _qid, _oid] spawn {
            params ["_ctx", "_state", "_player", "_pos", "_radius", "_seconds", "_onFoot", "_every", "_reset", "_internal", "_qid", "_oid"];

            private _abort = {
                params ["_reason"];
                private _had = _state getOrDefault ["held", 0];
                _state set ["inside", false];
                if (_reset) then { _state set ["held", 0] };
                _state set ["last", time];
                // The abort goes up as a fact. Whether it costs the player the
                // quest or only the timer is the server's call, per the quest's
                // own config — the client must not encode one answer.
                [_ctx, "zoneHoldAbort", [_reason, _had, _seconds]] call aq_fnc_report;
            };

            while { _state getOrDefault ["run", false] } do {
                private _wasInside = _state getOrDefault ["inside", false];

                if (isNull _player) exitWith {
                    diag_log format ["[AQ] typeZoneHold %1/%2: watcher lost its player object, stopping", _qid, _oid];
                    _state set ["run", false];
                };

                if (!alive _player) then {
                    if (_wasInside) then { ["dead"] call _abort };
                    sleep 2;
                } else {
                    private _d       = _player distance2D _pos;
                    private _inZone  = _d <= _radius;
                    private _mounted = _onFoot && {!(vehicle _player isEqualTo _player)};

                    if (_inZone && {!_mounted}) then {
                        private _now = time;
                        if (!_wasInside) then {
                            // Entering starts the clock now; the approach time
                            // before this instant is not hold time.
                            _state set ["inside", true];
                            _state set ["last", _now];
                            [_ctx, "zoneHoldEnter", [_qid, _oid]] call aq_fnc_report;
                        };

                        // Elapsed real time, not the number of loops: a sleep
                        // under load overshoots, and counting ticks would make
                        // the hold longer on a busy server than an empty one.
                        private _held = (_state getOrDefault ["held", 0]) + (_now - (_state getOrDefault ["last", _now]));
                        _state set ["held", _held];
                        _state set ["last", _now];

                        if (_held >= _seconds) then {
                            _state set ["held", _seconds];
                            // Completion goes back through the bus so the
                            // consume-and-satisfy path lives in one place.
                            [_internal, [_qid, _oid]] call aq_fnc_event;
                            _state set ["run", false];
                        } else {
                            [_ctx, "zoneHoldTick", [floor _held, _seconds]] call aq_fnc_report;
                            sleep _every;
                        };
                    } else {
                        if (_wasInside) then {
                            [if (_mounted) then { "vehicle" } else { "left" }] call _abort;
                        };
                        // Outside the zone the poll rate scales with the
                        // distance left: 120 m/s is a generous ceiling for the
                        // fastest approach, so looking sooner buys nothing.
                        sleep ((((_d - _radius) / 120) max 0.5) min 15);
                    };
                };
            };
        };
        _state set ["h", _h];

        [_ctx, "zoneHoldTick", [0, _seconds]] call aq_fnc_report;
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

        if (_consume isEqualTo []) exitWith {
            _state set ["done", true];
            call _stopWatcher;
            [_ctx, "zoneHoldDone", [_marker, _seconds]] call aq_fnc_report;
            true
        };

        if (isNull _player) exitWith { ["hold completed with no player object"] call _fail };
        private _uid = ["playerUid", [_player]] call aq_fnc_profile;

        // Check the whole list before taking any of it. A partial take cannot
        // be rolled back, so a player one item short would otherwise lose the
        // rest of the manifest and get nothing for it. The check is a READ, so
        // both invocations run it: on the client it is a pre-flight that turns
        // "nothing happened" into a named rejection the player can act on, and
        // on the server it is the one that counts.
        private _short = "";
        {
            _x params [["_class", "", [""]], ["_qty", 1, [0]]];
            if (_class isEqualTo "") then { _short = "malformed_consume_entry" } else {
                private _have = ["countItem", [_uid, _class]] call aq_fnc_profile;
                if (!(_have isEqualType 0)) then { _have = 0 };
                if (_have < _qty) then { _short = _class };
            };
        } forEach _consume;

        if (_short != "") exitWith {
            diag_log format ["[AQ] typeZoneHold %1/%2: hold completed but '%3' is short, nothing taken", _qid, _oid, _short];
            [_ctx, "zoneHoldAbort", ["consume_short", _short, _seconds]] call aq_fnc_report;
            _state set ["held", 0];
            _state set ["last", time];
            false
        };

        // The take itself, and only on the server's invocation. The client has
        // already reported the completed hold as a fact; consuming the manifest
        // from the client would move authority off the server, and on a listen
        // server — where both invocations are the same machine — it would take
        // the manifest twice.
        private _taken = true;
        if (_authoritative) then {
            {
                _x params [["_class", "", [""]], ["_qty", 1, [0]]];
                private _ok = ["takeItem", [_uid, _class, _qty]] call aq_fnc_profile;
                if !(_ok isEqualType true) then { _ok = false };
                if (!_ok) then {
                    _taken = false;
                    diag_log format ["[AQ] typeZoneHold %1/%2: profile takeItem refused %3 x %4", _qid, _oid, _qty, _class];
                };
            } forEach _consume;
        };

        if (!_taken) exitWith {
            [_ctx, "zoneHoldAbort", ["consume_failed", "", _seconds]] call aq_fnc_report;
            false
        };

        _state set ["done", true];
        call _stopWatcher;
        [_ctx, "zoneHoldDone", [_marker, _seconds]] call aq_fnc_report;
        true
    };

    case "progress": {
        if (_state getOrDefault ["done", false]) exitWith {
            [_seconds, _seconds, format ["%1 held", _place]]
        };
        // Computed live rather than read back, so the HUD counts down smoothly
        // between the watcher's reports instead of stepping once a second.
        private _held = _state getOrDefault ["held", 0];
        if (_state getOrDefault ["inside", false]) then {
            _held = _held + (time - (_state getOrDefault ["last", time]));
        };
        _held = (_held max 0) min _seconds;
        private _text = if (_state getOrDefault ["inside", false]) then {
            format ["Holding %1 %2/%3 s", _place, floor _held, _seconds]
        } else {
            format ["Reach %1 and hold for %2 s", _place, _seconds]
        };
        [floor _held, _seconds, _text]
    };

    case "describe": {
        private _t = ["text", ""] call _cfgGet;
        if (_t != "") exitWith { [_t] call _txt };
        private _foot = if (_onFoot) then { ", on foot" } else { "" };
        format ["Hold %1 for %2 seconds%3", _place, _seconds, _foot]
    };

    default { [format ["unknown verb '%1'", _verb]] call _fail };
};
