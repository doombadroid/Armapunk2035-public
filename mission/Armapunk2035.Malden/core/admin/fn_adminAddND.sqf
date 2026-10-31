/*
    AP_fnc_adminAddND -- classic admin dialog: grant New Drachma.
    [1] = to the selected player (list 12901), [2] = to self.
    Mirrors fn_adminAddMoney's resolution; amount from field 12918. The server
    (APS_fnc_adminNdSRV) re-checks the level and owns the credit.
*/
params [["_mode", 0, [0]]];
if !(_mode in [1, 2]) exitWith {};
private _val = parseNumber (ctrlText 12918);
if ((call AP_adminLevel) < 3) exitWith {["Insufficient permissions", "basic"] spawn AP_fnc_handleMessage;};
if !([str _val] call AP_fnc_isNumber) exitWith {["You didn't enter a positive integer.", "basic"] spawn AP_fnc_handleMessage;};
if (_val < 1) exitWith {["Minimum is 1 ND.", "basic"] spawn AP_fnc_handleMessage;};
if (_val > 1000000) exitWith {["Maximum is 1,000,000 ND.", "basic"] spawn AP_fnc_handleMessage;};
switch (_mode) do {
    case 1: {
        if ((lbCurSel 12901) isEqualTo -1) exitWith {["You did not select a player.", "basic"] spawn AP_fnc_handleMessage;};
        private _unit = lbData [12901, lbCurSel 12901];
        _unit = missionNamespace getVariable _unit;
        if (isNil "_unit" || {isNull _unit}) exitWith {["Player does not exist.", "basic"] spawn AP_fnc_handleMessage;};
        private _action = [format ["Grant %1 ND to %2?", _val, name _unit], "Admin Grant ND", "Yes", "No"] call BIS_fnc_guiMessage;
        if !(_action) exitWith {};
        [[_unit, str _val], "APS_fnc_adminNdSRV", 2, false, false] spawn AP_fnc_MP;
    };
    case 2: {
        [[objNull, str _val], "APS_fnc_adminNdSRV", 2, false, false] spawn AP_fnc_MP;
    };
};
