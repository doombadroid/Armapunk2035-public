if (AP_effSide isEqualTo civilian && (AP_serverId isEqualTo 1)) exitWith {};
[] call AP_fnc_calWeight;
private _num = missionNamespace getVariable(format["AP_inv_%1", "firstAidKit"]);
private _amount =
switch (true) do {case (_num >= 4): {0};
    case (_num isEqualTo 3): {1};
    case (_num isEqualTo 2): {2};
    case (_num isEqualTo 1): {3};
    case (_num isEqualTo 0): {4};}; if ((AP_maxWeight - AP_carryWeight) < _amount) exitWith {};
if (_amount in [1, 2, 3, 4]) then {[true, "firstAidKit", _amount] call AP_fnc_handleInv;};