// SPDX-License-Identifier: MIT
/*
    fn_report.sqf -- an objective type's way of telling the server what just
    happened to it. A fact, never a verdict.

    WHY THIS EXISTS
      An objective type runs on the client, because only the client knows where
      the player is standing and what is in their inventory. It therefore has
      exactly one thing it is allowed to say: "this happened". Giving a type a
      direct line to the state machine would put the decision to advance -- and
      so, eventually, the decision to pay -- inside eight plugin files instead
      of one server function.

      This is one line rather than a call to aq_fnc_fact so that the ids a type
      would otherwise have to remember to include are not its problem, and so
      that there is one place to change if the wire ever grows a field.

    WHAT IT DOES
      Sends [_fact, _args] to the server through aq_fnc_fact, which rate-limits
      and attaches the caller's own identity.

      The quest and objective ids are deliberately NOT sent. The server routes a
      fact to the current objective of each of that player's active quests, from
      its own state, so a client naming an objective could only ever name one it
      was not on -- which is a claim the server would refuse anyway. Leaving the
      ids out means there is no such claim to refuse.

      A fact the receiving type does not recognise is a no-op on the server, so
      progress telemetry (a hold's tick, a gather's re-read) costs a message and
      changes nothing. Facts that are meant to SATISFY an objective are named
      with the event name that type's `event` verb tests for, so the server's
      re-run of that verb is the thing that decides.

    Usage:  [_ctx, "aq_internal_visit", [_questId, _objectiveId]] call aq_fnc_report;
*/

params [
    ["_ctx",  createHashMap, [createHashMap]],
    ["_fact", "",            [""]],
    ["_args", [],            [[]]]
];

if (_fact isEqualTo "") exitWith {
    diag_log format ["[AQ] report: %1/%2 tried to report an unnamed fact",
        _ctx getOrDefault ["quest", "?"], _ctx getOrDefault ["objective", "?"]];
    false
};

[_fact, _args] call aq_fnc_fact
