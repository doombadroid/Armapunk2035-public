params[["_unit", objNull, [objNull]], ["_amount", 0, [0]], ["_full", false, [false]]];
if (AP_copRole isEqualTo "" || isNull _unit || !(AP_effSide isEqualTo west) || isNil "AP_prestige" || isNil "AP_cop_talents" || !(AP_session_completed)) exitWith {};
if (_unit isEqualTo player && !(_full)) exitWith {};
if !(_full) then {private _multiplier =
    switch (call AP_copLevel) do {case 7: {0.15};
        case 6: {0.15};
        case 5: {0.125};
        case 4: {0.075};
        case 3: {0.05};
        default {0};}; _amount = _amount * _multiplier;
    systemChat format["You've earned %1 prestige for the actions of %2.", _amount, name _unit];} else {
    systemChat format["You've earned %1 prestige.", _amount];};
AP_prestige = AP_prestige + _amount;
[16] call AP_fnc_ClupdatePartial;