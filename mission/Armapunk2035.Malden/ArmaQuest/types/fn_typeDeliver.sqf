// SPDX-License-Identifier: MIT
/*
    types/fn_typeDeliver.sqf

    Objective type "deliver" — carry N of an item to a marker and hand it over.

    WHY THIS EXISTS
        A delivery that completes on arrival alone is a delivery the player can
        finish while the cargo is still sitting in a warehouse: arriving and
        handing over are two different facts, and only the second one costs the
        player anything. So this type checks both, and the hand-over goes
        through the profile's take-item call rather than being written inline.
        Routing it through the profile is what lets a host whose inventory lives
        on the server perform the consumption server-side without editing this
        file — and it means a failed take blocks completion instead of paying
        out for goods that were never removed.

        The watcher exists only because no event can tell you that a player has
        arrived somewhere. It is distance-scaled and it is torn down by
        `disarm`; a watcher that outlives its objective is the failure mode that
        turns a quest system into a frame-rate problem.

    WHAT IT DOES
        arm       resolves the marker, subscribes to the hand-over event and to
                  its own internal completion event, spawns the arrival watcher.
        event     hand-over from the host, or the watcher's own automatic
                  hand-over; consumes the goods and answers "satisfied".
        disarm    clears the run flag, terminates the watcher, unsubscribes.
                  Idempotent — safe to call twice, or before `arm`.
        progress  [carried, needed, "Copper 20/20 - 1.2 km to Foundry"]
        describe  "Deliver 20 x Copper to Foundry"

    CONFIG
        item      STRING   virtual item class.                      required
        count     NUMBER   how many must arrive.                    default 1
        marker    STRING   destination marker name.                 required
        radius    NUMBER   metres from the marker that count as there. default 30
        onFoot    NUMBER   1 = must be out of a vehicle to hand over. default 0
        consume   NUMBER   1 = take the goods on hand-over.          default 1
        auto      NUMBER   1 = hand over automatically on arrival.   default 1
                           0 = wait for the host to fire the event, for hosts
                           that want their own "hand in" prompt.
        label     STRING   display name for the destination ($STR_ ok).
                           default: the marker's own text, else the marker name.
        itemLabel STRING   display name for the item ($STR_ ok).   default: item
        text      STRING   overrides the generated describe line.  optional
        events[]  ARRAY    hand-over event names. default { "aq_delivered" }

    EVENTS CONSUMED
        "aq_delivered", args [ _item, _qty ]  — host-driven hand-over.
        "aq_internal_deliver", args [ _questId, _objectiveId ]  — fired by this
            type's own watcher. Internal events carry the ids because the bus
            routes by name to every subscriber, so a second delivery objective
            would otherwise complete on the first one's arrival.

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

    WHICH MACHINE TAKES THE CARGO
        The `event` verb runs twice: on the client, for the watcher's own
        teardown and the local display, and again on the server against the
        authoritative copy of the state. Only the server's run may take the
        goods. `_ctx get "server"` is how the two are told apart, and the take
        sits behind it — the design's rule is that the server owns anything that
        pays, and consuming a player's cargo is the same operation as paying
        them, run backwards. A client that took the items itself would also take
        them twice on a listen server, where both runs happen on one machine.

    Usage:
        ["deliver", aq_fnc_typeDeliver] call aq_fnc_registerType;
        ["arm", _ctx] call aq_fnc_typeDeliver;
*/

params [
    ["_verb", "", [""]],
    ["_ctx", createHashMap, [createHashMap]]
];

private _qid = _ctx getOrDefault ["quest", "?"];
private _oid = _ctx getOrDefault ["objective", "?"];

private _fail = {
    params ["_msg"];
    diag_log format ["[AQ] typeDeliver %1/%2: %3", _qid, _oid, _msg];
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
// True only in the server's own invocation. See WHICH MACHINE TAKES THE CARGO.
private _authoritative = _ctx getOrDefault ["server", false];

if !(_state isEqualType createHashMap) exitWith { ["no state HashMap in context"] call _fail };

// `cfg` is a CONFIG for authored quests and a HashMap for generated (radiant)
// ones, and radiant substitution is textual, so "20" has to read back as 20.
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
                    // courier run read back through its TEMPLATE must resolve
                    // %CARGO% and %PLACE%, or it asks for an item nobody has and
                    // points at the map origin.
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

private _item   = ["item", ""] call _cfgGet;
private _need   = ["count", 1] call _cfgGet;
private _marker = ["marker", ""] call _cfgGet;
private _radius = ["radius", 30] call _cfgGet;
private _onFoot = (["onFoot", 0] call _cfgGet) > 0;
private _take   = (["consume", 1] call _cfgGet) > 0;
private _auto   = (["auto", 1] call _cfgGet) > 0;

if (_item isEqualTo "") exitWith { ["config has no `item`"] call _fail };
if (_marker isEqualTo "") exitWith { ["config has no `marker`"] call _fail };
if (_need < 1) then { _need = 1 };
if (_radius < 1) then { _radius = 30 };

private _pos = getMarkerPos _marker;

private _itemLabel = ["itemLabel", ""] call _cfgGet;
if (_itemLabel isEqualTo "") then { _itemLabel = _item };
_itemLabel = [_itemLabel] call _txt;

private _place = ["label", ""] call _cfgGet;
if (_place isEqualTo "") then { _place = markerText _marker };
if (_place isEqualTo "") then { _place = _marker };
_place = [_place] call _txt;

private _events = ["events", []] call _cfgGet;
if (!(_events isEqualType []) || {_events isEqualTo []}) then { _events = ["aq_delivered"] };
private _internal = "aq_internal_deliver";

// Teardown in one place: the flag stops the loop at its next check, and
// `terminate` is the backstop for a loop parked in a sleep.
private _stopWatcher = {
    _state set ["run", false];
    private _h = _state getOrDefault ["h", scriptNull];
    if !(isNull _h) then { terminate _h };
    _state set ["h", scriptNull];
};

private _carried = {
    if (isNull _player) exitWith { 0 };
    private _uid = ["playerUid", [_player]] call aq_fnc_profile;
    private _n   = ["countItem", [_uid, _item]] call aq_fnc_profile;
    if !(_n isEqualType 0) exitWith { 0 };
    _n
};

switch (toLower _verb) do {

    case "arm": {
        if (_pos isEqualTo [0,0,0]) exitWith {
            [format ["marker '%1' does not exist, so the destination is the map origin", _marker]] call _fail
        };

        // Re-arming must never leave the previous watcher running.
        call _stopWatcher;
        _state set ["done", false];
        _state set ["arrived", false];

        {
            [_ctx, _x] call aq_fnc_subscribe;
        } forEach _events;
        [_ctx, _internal] call aq_fnc_subscribe;

        if (_auto) then {
            _state set ["run", true];
            private _h = [_ctx, _state, _player, _pos, _radius, _onFoot, _item, _need, _internal, _qid, _oid] spawn {
                params ["_ctx", "_state", "_player", "_pos", "_radius", "_onFoot", "_item", "_need", "_internal", "_qid", "_oid"];

                while { _state getOrDefault ["run", false] } do {
                    if (isNull _player) exitWith {
                        diag_log format ["[AQ] typeDeliver %1/%2: watcher lost its player object, stopping", _qid, _oid];
                        _state set ["run", false];
                    };
                    if (!alive _player) then { sleep 5 };

                    private _d = _player distance2D _pos;
                    if (alive _player && {_d <= _radius} && {!_onFoot || {vehicle _player isEqualTo _player}}) then {
                        private _uid = ["playerUid", [_player]] call aq_fnc_profile;
                        private _have = ["countItem", [_uid, _item]] call aq_fnc_profile;
                        if (!(_have isEqualType 0)) then { _have = 0 };
                        if (_have >= _need) then {
                            _state set ["arrived", true];
                            // Completion goes back through the bus rather than
                            // being decided here, so the automatic hand-over and
                            // the host-fired one take exactly the same path.
                            [_internal, [_qid, _oid]] call aq_fnc_event;
                            _state set ["run", false];
                        } else {
                            _state set ["arrived", true];
                        };
                    } else {
                        _state set ["arrived", false];
                    };

                    // Poll rate scales with the distance left: nothing on this
                    // map closes 3 km inside a second, so looking every second
                    // from 3 km away buys nothing and costs every client.
                    // 120 m/s is a generous ceiling for the fastest approach.
                    sleep ((((_d - _radius) / 120) max 0.5) min 15);
                };
            };
            _state set ["h", _h];
        };

        [_ctx, "deliver", [_item, call _carried, _need]] call aq_fnc_report;
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

        private _mine = if (_name isEqualTo _internal) then {
            // The bus routes by name to every subscriber, so an internal event
            // has to prove it is ours before it is allowed to finish anything.
            ((_args param [0, "", [""]]) isEqualTo _qid) && {(_args param [1, "", [""]]) isEqualTo _oid}
        } else {
            (_name in _events) && {(_args param [0, "", [""]]) isEqualTo _item}
        };
        if (!_mine) exitWith { false };

        if (_state getOrDefault ["done", false]) exitWith { true };

        // Standing in the right place is a precondition of the hand-over even
        // when the host drives it, because a host prompt can be fired from
        // anywhere and this type's whole point is that the goods arrived.
        if (isNull _player) exitWith { ["hand-over with no player object"] call _fail };
        if (_player distance2D _pos > _radius) exitWith {
            [_ctx, "deliverRejected", [_item, "out_of_range"]] call aq_fnc_report;
            false
        };
        if (_onFoot && {!(vehicle _player isEqualTo _player)}) exitWith {
            [_ctx, "deliverRejected", [_item, "in_vehicle"]] call aq_fnc_report;
            false
        };

        private _uid  = ["playerUid", [_player]] call aq_fnc_profile;
        private _have = call _carried;
        if (_have < _need) exitWith {
            [_ctx, "deliverRejected", [_item, "short", _have, _need]] call aq_fnc_report;
            false
        };

        // The hand-over itself. Only the server's invocation performs it: the
        // client's run has already reported the arrival as a fact, and taking
        // the cargo from the client would both move authority off the server and
        // take it twice on a listen server, where both invocations are one
        // machine.
        private _ok = true;
        if (_take && _authoritative) then {
            _ok = ["takeItem", [_uid, _item, _need]] call aq_fnc_profile;
            if !(_ok isEqualType true) then { _ok = false };
        };
        if (!_ok) exitWith {
            // Counted-but-not-taken is how a delivery quest becomes an infinite
            // money printer, so a refused take fails loudly and completes nothing.
            diag_log format ["[AQ] typeDeliver %1/%2: profile takeItem refused %3 x %4 for %5", _qid, _oid, _need, _item, _uid];
            [_ctx, "deliverRejected", [_item, "take_failed"]] call aq_fnc_report;
            false
        };

        _state set ["done", true];
        _state set ["cur", _need];
        call _stopWatcher;
        [_ctx, "deliver", [_item, _need, _need, _marker]] call aq_fnc_report;
        true
    };

    case "progress": {
        if (_state getOrDefault ["done", false]) exitWith {
            [_need, _need, format ["%1 delivered to %2", _itemLabel, _place]]
        };
        private _have = (call _carried) min _need;
        private _dist = if (isNull _player) then { -1 } else { _player distance2D _pos };
        private _tail = if (_dist < 0) then { "" } else {
            if (_dist <= _radius) then { format [" - at %1", _place] }
            else {
                if (_dist >= 1000) then { format [" - %1 km to %2", (_dist / 1000) toFixed 1, _place] }
                else { format [" - %1 m to %2", round _dist, _place] };
            };
        };
        [_have, _need, format ["%1 %2/%3%4", _itemLabel, _have, _need, _tail]]
    };

    case "describe": {
        private _t = ["text", ""] call _cfgGet;
        if (_t != "") exitWith { [_t] call _txt };
        format ["Deliver %1 x %2 to %3", _need, _itemLabel, _place]
    };

    default { [format ["unknown verb '%1'", _verb]] call _fail };
};
