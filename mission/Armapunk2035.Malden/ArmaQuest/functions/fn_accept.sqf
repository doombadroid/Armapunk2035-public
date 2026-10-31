// SPDX-License-Identifier: MIT
/*
    fn_accept.sqf -- ask the server to accept a quest. Nothing changes here
    until it says yes.

    WHY THIS EXISTS
      The tempting version of this function marks the quest active locally,
      arms its watchers and then tells the server, because that makes the UI
      feel instant. It also makes the UI lie. On a shared board the offer may
      already be gone; the player may be one prerequisite short; a repeatable
      quest may still be on cooldown; the server may be holding a limit on
      concurrent quests. Every one of those ends with a client showing an
      active quest the server has never heard of -- objectives that never
      complete, and a player who is certain the system is broken because from
      where they are sitting it is.

      One authority, one direction. The client asks; the server answers by
      pushing the new state, and the client's view changes only then. The
      round trip is a few dozen milliseconds and it buys a UI that cannot
      disagree with the server.

    WHAT IT DOES
      Validates the id, throttles double-clicks, and sends the request. It
      does not touch aq_quests, does not arm anything and does not create a
      task. The server's state push does all three.

      Server reply contract: the server answers on this client with
          ["offerResult", [ok, "reason", _questId]] remoteExec ["aq_fnc_sync", _own]
      and, on success, with a "state" push carrying the newly active quest.
      aq_fnc_sync turns both into the journal's own verbs.

      The player object is the first argument on the wire because the server
      re-derives the caller from remoteExecutedOwner and refuses to act for a
      unit the calling machine does not own — sending it is what gives the
      server something to check the ownership of, not a claim it trusts.

    Usage:  ["copper_run"] call aq_fnc_accept;
*/

params [
    ["_questId", "", [""]],
    ["_giverId", "", [""]]     // optional: which board the offer came from
];

if (_questId isEqualTo "") exitWith {
    diag_log "[AQ] accept: refused, empty quest id";
    false
};
if (!hasInterface) exitWith {
    diag_log "[AQ] accept: called with no interface -- this is a client-side entry point";
    false
};
if (isNil "aq_ready" || {!aq_ready}) exitWith {
    diag_log format ["[AQ] accept: refused '%1', system not armed", _questId];
    false
};

// A double-click is one accept. The server would reject the second anyway,
// but a request that exists only to be rejected is still a request.
if (isNil "aq_lastRequest") then { aq_lastRequest = createHashMap; };
private _now = diag_tickTime;
private _key = format ["accept|%1", _questId];
if (_now - (aq_lastRequest getOrDefault [_key, -1e6]) < 1) exitWith { false };
aq_lastRequest set [_key, _now];

[player, _giverId, _questId] remoteExec ["aq_fnc_srvAccept", 2];
true
