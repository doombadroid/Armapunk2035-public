// SPDX-License-Identifier: MIT
/*
    fn_event.sqf -- the event bus. One line at each instrumented host site.

    WHY THIS EXISTS
      The obvious implementation of "did that sale advance any quest?" walks
      the player's active quests, and for each one walks its objectives, and
      for each of those reads the config to find out what it wants. That is a
      config tree walk on every sale, every kill, every craft, for every
      player -- and it gets slower with every quest an author adds. The system
      would penalise content, which is the opposite of its purpose.

      Instead, subscription is built once when an objective arms: the bus
      holds eventName -> the objectives that asked for it, and an event that
      nothing subscribed to costs one HashMap miss. Cost tracks what is
      actually active, not what exists in config, and it does not grow over a
      session because `disarm` removes the entries again.

    WHAT IT DOES
      Routes ["name", [args]] to the objectives subscribed to that name on
      quests active for this player, lets each one's type update whatever it
      keeps locally -- a watcher to stop, a counter the journal is about to
      draw -- and forwards the event itself to the server, once.

      WHERE THE EVENT IS EVALUATED. The type's `event` verb runs twice, on two
      machines, against two copies of the objective's state: here, for the
      client's own display and teardown, and again inside aq_fnc_srvFact
      against the server's authoritative copy. Only the server's answer moves
      the state machine. The design leaves this open; the reading taken is the
      one that keeps the client dumb -- so the fact is forwarded whether or not
      the client's copy thought the event satisfied anything, and the client's
      opinion is never sent. A client that decided which of its facts were worth
      reporting would be a client deciding what it is paid for.

      The consequence for a type author is one rule, and it is the rule the
      shipped types follow: the `event` verb must not change anything outside
      the objective's own state map unless the context says it is the
      authoritative copy (`_ctx get "server"`). Anything that consumes an item
      or pays belongs behind that check.

      Returns the number of objectives the event was routed to.

    Usage:  ["aq_sold", ["copper", 10]] call aq_fnc_event;
*/

params [
    ["_name", "", [""]],
    ["_args", [],  [[]]]
];

if (_name isEqualTo "") exitWith {
    diag_log "[AQ] event: refused, empty event name";
    0
};
if (isNil "aq_ready" || {!aq_ready}) exitWith { 0 };
if (isNil "aq_subs") exitWith { 0 };

// One HashMap miss is the entire cost of an event nothing cares about.
private _subs = aq_subs getOrDefault [_name, []];
if (_subs isEqualTo []) exitWith { 0 };

// Copy: a type's `event` handler may arm or disarm something, and mutating
// the list being walked is a bug that only shows up on the quest that chains.
_subs = +_subs;

private _routed = 0;
{
    _x params [["_questId", "", [""]], ["_objId", "", [""]], ["_typeName", "", [""]]];

    private _type = (localNamespace getVariable "aq_types") getOrDefault [_typeName, {}];
    if (_type isEqualTo {}) then {
        diag_log format ["[AQ] event: '%1' subscribed by unregistered type '%2' on %3/%4", _name, _typeName, _questId, _objId];
    } else {
        // Only quests the server currently holds as active for this player
        // may consume events. A stale subscription is dropped rather than
        // trusted -- a subscription outliving its quest is a leak, and a leak
        // that still fires facts is a way to be paid for a quest you no
        // longer have.
        private _rec = (localNamespace getVariable "aq_quests") getOrDefault [_questId, createHashMap];
        if ((_rec getOrDefault ["state", ""]) isEqualTo "active") then {
            private _ctx = [_questId, _objId] call aq_fnc_ctx;
            if !(count _ctx isEqualTo 0) then {
                _ctx set ["event", [_name, _args]];
                _routed = _routed + 1;

                // The return value is deliberately discarded: it is the
                // client's opinion, and the client has no vote.
                ["event", _ctx] call _type;
            };
        } else {
            [_questId, _objId] call aq_fnc_disarmObjective;
        };
    };
} forEach _subs;

// One event, one fact, whatever it reached. Reporting per objective would send
// the same sale twice for a player holding two quests that want it, and the
// server routes by its own state anyway.
if (_routed > 0) then {
    [_name, _args] call aq_fnc_fact;
};

_routed
