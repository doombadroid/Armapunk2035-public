private _cost = call(AP_respec_fee) * (count AP_side_talents);
private _action = [format["<t align='center'>If you proceed you will unlearn %1 talent(s) for a total cost of $%2!</t>", count AP_side_talents, [_cost] call AP_fnc_numberText], "Unlearn Talents", "Yes", "No"] call BIS_fnc_guiMessage;
if !(_action) exitWith {};
if !([_cost] call AP_fnc_debitCard) exitWith {};
AP_side_talents = [];
["You have forgotten everything you knew.", "basic"] spawn AP_fnc_handleMessage;
[4] call AP_fnc_ClupdatePartial;