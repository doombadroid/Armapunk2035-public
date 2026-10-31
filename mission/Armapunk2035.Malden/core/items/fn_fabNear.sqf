/*
    AP_fnc_fabNear  -- the fabricator anchor the player is standing at, or objNull.

        call AP_fnc_fabNear   ->  <anchor object> | objNull

    WHY PROXIMITY AND NOT cursorObject. Every other placed machine here (the mining rig, house
    furniture) targets with cursorObject, which is a raycast -- and a raycast needs geometry to
    hit. The printers ship with NO collision by owner call, so cursorObject slides straight through
    them and would never return one. Distance is the only thing left that can find them.

    The gunsmith bench DOES have collision, so it could be cursor-targeted -- but it uses the same
    path anyway. Two targeting mechanisms for one interaction would mean two sets of edge cases
    (what happens when you look at a bench while standing in a printer?) for no gain, and the
    anchor is what carries the identity in both cases regardless.

    Called from addAction condition strings, i.e. every frame per action. nearestObjects over a 4 m
    radius with a type filter is cheap, and this codebase already runs a 20 m nearestObjects in a
    per-frame condition (the Hack Mining Rig action), so this is not a new class of cost. The
    caller is expected to short-circuit on something cheaper first.
*/
// 4 m, not 3: the bench is a 2 m object and its anchor sits at the CENTRE, so standing at either
// end of the worktop is already ~1 m out before the player has stepped back to read the screen.
private _c = nearestObjects [player, ["Land_HelipadEmpty_F"], 4];
private _i = _c findIf { _x getVariable ["AP_fabPrinter", false] };
if (_i isEqualTo -1) exitWith { objNull };
_c select _i
