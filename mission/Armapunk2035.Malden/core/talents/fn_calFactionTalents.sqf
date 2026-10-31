/*
    File: fn_calFactionTalents.sqf  (AP_fnc_calFactionTalents)

    How many faction perk points the player currently has, from their standing
    with their PRIMARY faction. See FACTION_REP_SPEC.md section 5.

    Mirrors fn_calTalents.sqf and fn_calGangTalents.sqf exactly -- a descending
    switch of thresholds -- so it reads like the two progression curves already in
    this mission rather than a third idea about how progression works.

    WHY THE PRIMARY FACTION AND NOT A SUM. Standing is tracked independently per
    faction, but points come only from the one the player stands highest with. A
    player who spreads effort across all four therefore unlocks nothing, which is
    what makes allegiance a commitment rather than a checklist -- and it is why
    the values can stay independent and easy to reason about without needing a
    rivalry matrix to make choosing matter.

    A TIE means no primary (AP_fnc_isPrimaryFaction), and therefore zero points.
    A tie means the player has not chosen; picking for them silently is how a perk
    appears to flicker on and off as standing drifts.

    Curve: deliberately shallower than the side-talent curve. Standing accrues from
    quest work rather than from every gameplay action, so the same numbers would
    make faction perks unreachable.

    Sets AP_currentFactionTalents. Call after AP_faction_rep changes.
*/

private _primary = "";
private _standing = 0;

{
    private _fid = _x select 0;
    if ([_fid] call AP_fnc_isPrimaryFaction) exitWith {
        _primary  = _fid;
        _standing = [(player getVariable ["AP_faction_rep", []]), _fid] call AP_fnc_aqRepFind;
    };
} forEach (["all"] call AP_fnc_factionCfg);

AP_primaryFaction = _primary;

AP_currentFactionTalents =
if (_primary isEqualTo "") then { 0 } else {
    switch (true) do {
        case (_standing >= 6000): {12};
        case (_standing >= 4800): {11};
        case (_standing >= 3800): {10};
        case (_standing >= 3000): {9};
        case (_standing >= 2400): {8};
        case (_standing >= 1900): {7};
        case (_standing >= 1450): {6};
        case (_standing >= 1050): {5};
        case (_standing >= 750):  {4};
        case (_standing >= 500):  {3};
        case (_standing >= 300):  {2};
        case (_standing >= 150):  {1};
        default {0};
    };
};

AP_currentFactionTalents
