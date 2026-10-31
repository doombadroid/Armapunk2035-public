params["_unit1", "_unit2", "_vehicle"];
if !(AP_effSide isEqualTo civilian) exitWith {};
if (_vehicle getVariable["AP_side", ""] isEqualTo "med") then {
    if (_unit1 isEqualTo(driver _vehicle) || ([player] call AP_fnc_isUnitCopilot)) then {moveOut player;
        ["Only trained Medical and Fire personnel are able to operate this vehicle!", "basic"] spawn AP_fnc_handleMessage;};};