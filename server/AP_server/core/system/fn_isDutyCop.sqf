/*
    APS_fnc_isDutyCop -- "may this unit exercise MaxSec authority right now?", answered server-side.

        [unit] call APS_fnc_isDutyCop   ->   true / false

    This replaces `side _caller isEqualTo west` at every server gate that pays money, clears wanted,
    jails, impounds, or otherwise spends the state's authority. The side test alone stopped being
    sufficient the moment the two duty groups became persistent and PUBLISHED BY netId: a modified client
    can `[player] joinSilent (groupFromNetId AP_dutyGroupCopNet)` and be side west without ever reaching
    APS_fnc_dutySRV -- no whitelist read, no cooldown, no roster entry. The roster is the only authority on
    who is actually on shift, so the gate has to ask it.

    BOTH halves are required, and neither is redundant:
      * the SIDE test still runs, so a rostered player whose grant has not yet landed (the window between
        the roster entry and the client's joinSilent, which the ack watchdog owns) is not yet an officer;
      * the ROSTER test is what a self-joiner fails.
    The faction is checked, not merely membership: a trauma-rostered client that joins the MaxSec group by
    netId is side west holding an "independent" roster entry, and a rostered-at-all test would pass it.

    THE FLAG-FALSE CLAUSE IS THE LOAD-BEARING LINE OF THIS WHOLE FEATURE. It was written as a PRE-FLIP
    compatibility clause: while AP_dutyEnabled was false the roster did not exist (APS_fnc_dutySRV's "init"
    is behind the same flag) and nobody was rostered -- including every real cop, who was still sitting on
    a west mission slot the old way -- so without it, wrapping ~38 authority gates in this predicate would
    have locked every serving officer out of jail, impound, wanted-clear and dispatch on a flag that was
    supposed to change nothing. With it, a flag-false server evaluated exactly `side _unit isEqualTo west`,
    the identical expression the gates used before, and the merge was a no-op by construction.
    SINCE PR7 THE SAME LINE IS THE KILL-SWITCH, and its meaning has changed with the world under it: the
    west slots are gone, so flag-false no longer means "cops the old way", it means an all-civilian server
    with no route onto side west at all and therefore no officers. That is the intended rollback state, not
    a degraded one -- turn the flag off and the mission runs as it did before MaxSec existed. Keep the
    clause: it is what makes the rollback one boolean instead of a revert.
    The clause keys on the FLAG ALONE, never on "the roster is empty". Flag-on-with-an-empty-roster is not
    a compatibility state, it is the exact state a self-joiner creates for themselves on a quiet server,
    and falling back to the bare side test there would hand them everything.
*/
params [["_unit", objNull, [objNull]]];
if (isNull _unit) exitWith { false };
if !(localNamespace getVariable ["AP_dutyEnabled", false]) exitWith { (side _unit) isEqualTo west };   // localNamespace: the network cannot write it (Lsec-0-1)

((side _unit) isEqualTo west) && {((_unit call APS_fnc_dutyLookup) param [0, ""]) isEqualTo "maxsec"}
