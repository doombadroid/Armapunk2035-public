// SPDX-License-Identifier: MIT
/*
    server/fn_storeNone.sqf   —   aq_fnc_storeNone

    Purpose: store driver that stores nothing. Quests reset every session.

    WHY THIS EXISTS
    Two reasons, and the second is the important one.
      - Some missions want it: a scenario, a test range, a coop night where
        starting clean is the point.
      - It gives every other part of the system a defined behaviour when
        persistence is unavailable. Without an explicit "no store" driver, the
        no-store case is expressed as a nil driver, and every caller grows a
        different "if we have a store" branch — which is how half of a system
        ends up persisting and the other half not.
    It also succeeds rather than fails: an operation that did exactly what was
    configured is not an error, and logging one per flush would train hosts to
    ignore the log.

    WHAT IT DOES
      "init"  -> true, with one honest line in the log so nobody reports lost
                 progress as a bug.
      "load"  -> "" (every record is absent)
      "save"  -> true (discarded)
      "flush" -> true

    Usage:  set  AQ_Settings >> store = "none";
*/

params [["_verb", "", [""]], ["_args", [], [[]]]];

if (!isServer) exitWith {
    diag_log text "[AQ] storeNone called off the server; refused.";
    false
};

switch (toLower _verb) do {
    case "init": {
        diag_log text "[AQ] storeNone: persistence is disabled by configuration. Quest progress will not survive a mission restart.";
        true
    };
    case "load":  { "" };
    case "save":  { true };
    case "flush": { true };
    default {
        diag_log text format ["[AQ] storeNone: unknown verb '%1'.", _verb];
        false
    };
};
