/*
    AP_fnc_deathMedics -- WHO CAN COME FOR YOU, as one number and one distance.

        ([] call AP_fnc_deathMedics) params ["_online", "_nearest"];
        // _online  : eligible responders connected, whether or not they are near
        // _nearest : metres to the closest eligible LIVE responder, or 99999 = none

    THE ELIGIBLE-RESPONDER RULE LIVES HERE AND NOWHERE ELSE. It was inline in
    fn_deathScreen.sqf, which writes it into the native death dialog's two text
    controls; the web death screen needs the same two numbers for its own panel, and
    a second copy of "who counts as a medic" is exactly the drift that turns one
    rule into two that disagree after somebody edits one of them. fn_deathScreen.sqf
    now calls this and formats the answer; nothing about what it displays changed.

    THE TWO COUNTS ARE DELIBERATELY DIFFERENT QUESTIONS, and both are preserved
    verbatim from fn_deathScreen.sqf rather than tidied:

      _online counts over allPlayers with NO alive test and NO self-exclusion, and
      it adds the two groups (independent, plus cops whose role is medic/all)
      SEPARATELY -- so a cop-medic on the independent side would count twice. That
      cannot happen today (a unit has one side) and the sum is what the screen has
      always shown; it is written down here so the next reader does not "fix" a
      double-count that is really two disjoint sets.

      _nearest tests alive AND excludes the dead player themself, and measures from
      AP_corpse, not from the player -- the body is what a medic has to reach.

    99999 IS "NONE", NOT A DISTANCE, and that distinction is the point: a zero would
    read as "a medic is standing on you". Callers must test the sentinel and say
    None rather than print a number. Distance is also NOT an ETA and must never be
    presented as one.

    AP_corpse can still be objNull for a frame or two at the very start of a death
    (fn_deathCamera sets it AFTER fn_onPlayerKilled spawns the screen thread), so the
    position read is guarded: with no corpse there is no distance to anything, which
    is the None case, not a distance to [0,0,0] out at the map origin.
*/
private _online = ({side _x isEqualTo independent} count allPlayers)
                + ({(_x getVariable ["AP_unitCopRole", ""]) in ["medic", "all"]} count allPlayers);

private _nearest = 99999;
if (!isNull AP_corpse) then {
    private _from = getPosATL AP_corpse;
    {
        if ((side _x isEqualTo independent || ((_x getVariable ["AP_unitCopRole", ""]) in ["medic", "all"]))
            && alive _x && !(_x isEqualTo player)) then {
            private _d = _from distance _x;
            if (_d < _nearest) then { _nearest = _d; };
        };
    } forEach allPlayers;
};

[_online, _nearest]
