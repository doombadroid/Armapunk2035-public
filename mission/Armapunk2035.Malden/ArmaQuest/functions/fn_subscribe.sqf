// SPDX-License-Identifier: MIT
/*
    fn_subscribe.sqf -- route one event name to one armed objective.

    WHY THIS EXISTS
      The bus is what stops the cost of playing growing with the amount of
      content authored: an event that nothing is waiting for costs one HashMap
      miss, because subscription is built when an objective arms rather than
      derived from config when an event fires. That only holds if there is
      exactly one way to subscribe. A type that pushed its own entry into the
      index, and another that recorded the name in its state for the engine to
      pick up, would produce a bus that is half-indexed -- and the symptom of a
      half-indexed bus is one objective type that never advances while the rest
      work, which reads as a bug in that type.

      So both records are written here, together: the objective's own state
      remembers what it subscribed to (which is what `disarm` unwinds, and what
      survives a type whose `arm` failed half way through), and the bus index
      gets the routing entry.

    WHAT IT DOES
      Adds _event to the objective state's "events" list and adds
      [questId, objectiveId, typeName] to aq_subs under that name. Both are
      pushBackUnique, so subscribing twice is one subscription -- an objective
      armed twice must not count one sale as two.

      The type name travels with the subscription so that routing an event never
      touches the config tree.

    Usage:  [_ctx, "aq_sold"] call aq_fnc_subscribe;
*/

params [
    ["_ctx",   createHashMap, [createHashMap]],
    ["_event", "",            [""]]
];

if (_event isEqualTo "") exitWith {
    diag_log "[AQ] subscribe: refused, empty event name";
    false
};

private _state = _ctx getOrDefault ["state", createHashMap];
if !(_state isEqualType createHashMap) exitWith {
    diag_log format ["[AQ] subscribe: '%1' has no state map in its context", _event];
    false
};

private _events = _state getOrDefault ["events", []];
_events pushBackUnique _event;
_state set ["events", _events];

private _questId = _ctx getOrDefault ["quest", ""];
private _objId   = _ctx getOrDefault ["objective", ""];

// A probe context (registerType) carries no real ids, and there is nothing to
// route to. Recording the declaration in state is still correct and harmless.
if (_questId isEqualTo "" || {_objId isEqualTo ""}) exitWith { true };

private _typeName = [_ctx getOrDefault ["cfg", configNull], "type", ""] call aq_fnc_cfgGet;

if (isNil "aq_subs") then { aq_subs = createHashMap; };
private _list = aq_subs getOrDefault [_event, []];
_list pushBackUnique [_questId, _objId, _typeName];
aq_subs set [_event, _list];

true
