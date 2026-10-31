// SPDX-License-Identifier: MIT
/*
    fn_abandon.sqf -- ask the server to drop a quest. Nothing changes here
    until it says yes.

    WHY THIS EXISTS
      Abandonment is a state transition with consequences: it may start a
      cooldown, it may burn a limited-attempt quest, it may return a shared
      offer to the board. A client that tore its own watchers down and called
      it abandoned would leave the server holding an active quest with nobody
      reporting facts against it -- a quest that can never complete and never
      expire, occupying a slot forever.

      Same rule as accepting, for the same reason: the client asks, the server
      transitions, and the state push disarms the watchers and clears the task
      on the way back.

    WHAT IT DOES
      Validates the id, refuses when the quest is not actually active for this
      player, throttles repeats, and sends the request. It does not disarm
      anything locally -- the server's state push does.

      The local "is it active" check is a courtesy to keep pointless traffic
      off the wire, never a permission check: the server re-checks everything.

      Abandonment is one of the three terminal transitions, so it goes to the
      same server function the timer sweep uses (aq_fnc_srvFail) with the reason
      named. A remote caller may only ask for "abandoned"; the server forces
      that reason for anything arriving from a client, because letting a client
      pick between "failed", "expired" and "abandoned" lets it pick the cheapest
      cooldown.

    Usage:  ["copper_run"] call aq_fnc_abandon;
*/

params [["_questId", "", [""]]];

if (_questId isEqualTo "") exitWith {
    diag_log "[AQ] abandon: refused, empty quest id";
    false
};
if (!hasInterface) exitWith {
    diag_log "[AQ] abandon: called with no interface -- this is a client-side entry point";
    false
};
if (isNil "aq_ready" || {!aq_ready}) exitWith {
    diag_log format ["[AQ] abandon: refused '%1', system not armed", _questId];
    false
};

private _rec = (localNamespace getVariable "aq_quests") getOrDefault [_questId, createHashMap];
if !((_rec getOrDefault ["state", ""]) isEqualTo "active") exitWith {
    diag_log format ["[AQ] abandon: '%1' is not active for this player (state '%2')", _questId, _rec getOrDefault ["state", "unknown"]];
    false
};

if (isNil "aq_lastRequest") then { aq_lastRequest = createHashMap; };
private _now = diag_tickTime;
private _key = format ["abandon|%1", _questId];
if (_now - (aq_lastRequest getOrDefault [_key, -1e6]) < 1) exitWith { false };
aq_lastRequest set [_key, _now];

[player, _questId, "abandoned"] remoteExec ["aq_fnc_srvFail", 2];
true
