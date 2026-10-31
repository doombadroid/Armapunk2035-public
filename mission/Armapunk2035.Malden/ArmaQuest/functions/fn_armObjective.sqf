// SPDX-License-Identifier: MIT
/*
    fn_armObjective.sqf -- bring one objective to life on this client.

    WHY THIS EXISTS
      Arming is where two kinds of leak start. The first is a watcher whose
      handle nobody kept: the loop keeps running after the quest ends, burning
      a scheduled slot for the rest of the session and, worse, still reporting
      facts. The second is a double-arm: the same objective armed twice
      subscribes twice, so one sale counts as two.

      So every handle a type creates is recorded in the objective's own state
      map, every subscription is recorded in the bus index, and arming an
      objective that is already armed is a no-op rather than a second set of
      watchers.

    WHAT IT DOES
      - Refuses to arm anything while the catalogue has not validated.
      - Builds the type context, resolves the type, calls `arm`.
      - Collects the event names the type subscribed to, by two routes:
          the optional `events` verb (a pure declaration, preferred), and
          state "events" written during `arm`,
        then indexes them into the bus with the type name attached, so the bus
        never reads config while routing.
      - Rolls back with a full disarm if `arm` reports failure, so a
        half-armed objective never survives.

    Usage:  ["copper_run", "have"] call aq_fnc_armObjective;
*/

params [
    ["_questId", "", [""]],
    ["_objId",   "", [""]]
];

if (_questId isEqualTo "" || {_objId isEqualTo ""}) exitWith {
    diag_log format ["[AQ] armObjective: refused, empty id (quest '%1', objective '%2')", _questId, _objId];
    false
};

// Validation failed, or preInit never ran. Arming here would put watchers on
// a catalogue nobody has checked; the disarmed state is the safe one.
if (isNil "aq_ready" || {!aq_ready}) exitWith {
    diag_log format ["[AQ] armObjective: refused %1/%2, system not armed (validation failed or preInit did not run)", _questId, _objId];
    false
};

private _key = format ["%1|%2", _questId, _objId];
if (aq_armedObj getOrDefault [_key, false]) exitWith { true };   // already live

private _ctx = [_questId, _objId] call aq_fnc_ctx;
if (count _ctx isEqualTo 0) exitWith { false };   // aq_fnc_ctx already logged

private _cfg      = _ctx get "cfg";
private _typeName = getText (_cfg >> "type");
private _type     = (localNamespace getVariable "aq_types") getOrDefault [_typeName, {}];

if (_type isEqualTo {}) exitWith {
    diag_log format ["[AQ] armObjective: %1/%2 wants type '%3', which is not registered. Registered types: %4", _questId, _objId, _typeName, keys (localNamespace getVariable "aq_types")];
    false
};

private _state = _ctx get "state";
// Seeded before `arm` so a type can push into them without checking first.
if (isNil { _state get "handles" }) then { _state set ["handles", []]; };
if (isNil { _state get "events"  }) then { _state set ["events",  []]; };

private _ok = ["arm", _ctx] call _type;
if (isNil "_ok") then { _ok = true; };   // a type that returns nothing is taken at its word
if (!(_ok isEqualType true) || {!_ok}) exitWith {
    diag_log format ["[AQ] armObjective: type '%1' refused to arm %2/%3", _typeName, _questId, _objId];
    [_questId, _objId] call aq_fnc_disarmObjective;   // no half-armed objectives
    false
};

// ------------------------------------------------------------ subscriptions
/*
    Two routes into the bus, because neither alone covers every type:

      1. The optional `events` verb: a type may answer an ARRAY of event names
         it wants. Pure, declarative, and available before arming.
      2. state "events": names recorded by aq_fnc_subscribe during `arm`, which
         is what a type does when its subscriptions depend on its config.

    Both are honoured and the union is indexed. A watcher-only type declares
    neither and receives no events, which is correct, not an error.

    The `events` verb is OPTIONAL IN WHAT IT DECLARES AND NOT IN BEING ANSWERED.
    It is probed on every arm, so a type that lets it fall through to an
    unknown-verb branch writes a line to the RPT every time an objective arms —
    which is why the shipped types all answer it with an empty array. A type
    that answers something other than an ARRAY is simply ignored here; only the
    noise is the problem.
*/
private _wanted = [];

private _declared = ["events", _ctx] call _type;
if (!isNil "_declared" && {_declared isEqualType []}) then {
    { if (_x isEqualType "" && {_x != ""}) then { _wanted pushBackUnique _x; }; } forEach _declared;
};

{ if (_x isEqualType "" && {_x != ""}) then { _wanted pushBackUnique _x; }; }
    forEach (_state getOrDefault ["events", []]);

{
    private _list = aq_subs getOrDefault [_x, []];
    // The type name travels with the subscription so routing an event never
    // touches the config tree.
    _list pushBackUnique [_questId, _objId, _typeName];
    aq_subs set [_x, _list];
} forEach _wanted;

_state set ["events", _wanted];
aq_armedObj set [_key, true];

true
