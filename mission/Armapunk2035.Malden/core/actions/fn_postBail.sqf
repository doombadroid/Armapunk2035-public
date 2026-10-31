params[["_unit", objNull, [objNull]]];
if (AP_bail_paid) exitWith {};
if (isNil {"AP_bail_amount"}) then {AP_bail_amount = 3500;};
if (AP_atmcash < AP_bail_amount) exitWith {
    systemChat format["You do not have $%1 in your bank account to pay bail.", AP_bail_amount];};
private _action = [format["Do you wish to pay $%1 to be release from jail?", [AP_bail_amount] call AP_fnc_numberText], "Pay Bail", "Yes", "No"] call BIS_fnc_guiMessage;
if !(_action) exitWith {};
AP_atmcash = AP_atmcash - AP_bail_amount;
AP_atmcashCacheB = ((AP_atmcash / 4) + 11);
[1] call AP_fnc_ClupdatePartial;
AP_bail_paid = true; [[0, format["%1 has posted bail!", name _unit]], "AP_fnc_broadcast", -2, false, false] spawn AP_fnc_MP;
["moneyspentbail", AP_bail_amount] call AP_fnc_statArrUpdate;