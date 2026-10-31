/*
    APS_fnc_dutyLookup -- read one player's duty roster entry. The server's own answer to "is this player
    on shift, and as what", with no client input anywhere in it.

        [unit] call APS_fnc_dutyLookup   ->   [factionId, roleId, sinceTime, confirmed]   or   []
        [uid]  call APS_fnc_dutyLookup   ->   same

    SERVER-LOCAL ONLY. There is deliberately NO CfgRE entry for this function or for the two predicates
    built on it: CfgRE runs in whitelist mode (mode = 1), so an unlisted function cannot be remote-executed
    at all, and that -- not an origin assertion -- is what keeps them off the wire. An origin assertion
    would in fact be WRONG here: remoteExecutedOwner reports the owner of the enclosing script context, so
    inside a legitimately remote-executed authority function (APS_fnc_setJail and friends, which is exactly
    where the predicates are used) it reads the CALLING CLIENT's id, not 0. Asserting 0 would refuse every
    real call site. These three functions have no side effects and no state of their own, so being a pure
    read is the whole of their safety story. If a later PR ever needs one of them on the wire, that is a
    design change, not a config line.

    The roster is APS_fnc_dutySRV's `AP_dutyRoster`, keyed by uid:
        uid -> [faction, role, startTime, startPos, confirmed, ownerId]
    Four of six are returned. The return is an ARRAY so it can grow the same way DB_fnc_dutyLoad's does; a
    caller that wants the stash position or the owner id should read the roster directly rather than
    widening this and making every `param [0,""]` in the tree suspect.

    SLOT 3, `confirmed`, IS NOT DECORATION -- read the note in DB_fnc_updatePartial before ignoring it. It is
    false from the moment the grant is written until the client acks that its side actually moved, and during
    that window the player is still, truthfully, a civilian: the clock-on flush of their civilian kit and
    talents happens inside it. Anything that ROUTES a write by faction has to wait for slot 3; only something
    asking "is this uid on the roster at all" (the disconnect handler) may ignore it.

    AP_dutyRoster does not exist until APS_fnc_dutySRV's "init" runs, and "init" is behind AP_dutyEnabled --
    so on a kill-switched (flag-false) server the variable is NIL, not empty. That is the normal state, not an
    error: it returns [] and every caller degrades to its pre-duty behaviour.
*/
params [["_who", objNull, ["", objNull]]];
if (isNil {localNamespace getVariable "AP_dutyRoster"}) exitWith { [] };

private _uid = if (_who isEqualType "") then { _who } else {
    if (isNull _who) then { "" } else { getPlayerUID _who }
};
if (_uid isEqualTo "") exitWith { [] };

private _e = (localNamespace getVariable "AP_dutyRoster") getOrDefault [_uid, []];
if !(_e isEqualType []) exitWith { [] };
if (_e isEqualTo []) exitWith { [] };

[_e param [0, ""], _e param [1, ""], _e param [2, 0], _e param [4, false]]
