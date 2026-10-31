/*
    File: fn_medicEarn.sqf  (LooneyBin)
    TT prestige earn helper. Call:  <amount> call AP_fnc_medicEarn;
    Adds prestige points (AP_medic_exp) for TT actions (revive / bloodbag / FAK / clearing
    wreckage / repairing houses / putting out fires) and saves via ClupdatePartial case 23.
    Independent-only so non-medics using a FAK/bloodbag don't earn TT prestige.
*/
params [["_amount", 0, [0]]];
if ((AP_effSide isEqualTo independent) && {!isNil "AP_medic_exp"} && {_amount > 0}) then {AP_medic_exp = AP_medic_exp + _amount;
    // owner 2026-06-13 (#158): notify -- the grant was silent, so medics thought revives/narcan/bloodbag
    // gave no prestige. Spend it in the TT prestige tree (AEMT+).
    systemChat format["You've earned %1 TT prestige.", _amount];
    [23] call AP_fnc_ClupdatePartial;};
