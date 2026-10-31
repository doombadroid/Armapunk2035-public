params[["_mode", 0, [0]]];
if !(_mode in [1, 2]) exitWith {};
private _val = parseNumber(ctrlText 12918);
if ((call AP_adminLevel) < 3) exitWith {["Insufficient permissions", "basic"] spawn AP_fnc_handleMessage;};
if !([str _val] call AP_fnc_isNumber) exitWith {["You didn't enter a positive integer.", "basic"] spawn AP_fnc_handleMessage;};
if (_val < 100) exitWith {["You must send a minimum of $100.", "basic"] spawn AP_fnc_handleMessage;};
if (_val > 9999999) exitWith {["You must enter a number less than $9,999,999.", "basic"] spawn AP_fnc_handleMessage;};
switch (_mode) do {case 1: {if ((lbCurSel 12901) isEqualTo - 1) exitWith {
                ["You did not select a player.", "basic"] spawn AP_fnc_handleMessage;};
            private _unit = lbData[12901, lbCurSel 12901];
            _unit = missionNamespace getVariable _unit;
            if (isNil "_unit" || {isNull _unit}) exitWith {["Player does not exist.", "basic"] spawn AP_fnc_handleMessage;};
            private _action = [format["Are you sure you want to give $%1 to %2?", [_val] call AP_fnc_numberText, (name _unit)], "Admin Add Money", "Yes", "No"] call BIS_fnc_guiMessage;
            if !(_action) exitWith {};
            if (_val > 0) then {[[_val, player, _unit, _val, [1]], "APS_fnc_handleWireTransfer", 2, false, false] spawn AP_fnc_MP; [
                    ["-ADMINACTION-", player, profileName, format["added $%1 to %2's bank account.", _val, name _unit]], "APS_fnc_logIt", 2] spawn AP_fnc_MP;
                [format["You added $%1 to %2's bank account.", [_val] call AP_fnc_numberText, name _unit]] spawn AP_fnc_handleMessage;
            };};
    case 2: {AP_atmcash = (round(AP_atmcash + _val)) max 0;
            AP_atmcashCacheB = ((AP_atmcash / 4) + 11); [
                ["-ADMINACTION-", player, profileName, format["added $%1 to their bank account.", _val]], "APS_fnc_logIt", 2] spawn AP_fnc_MP;
            [format["You added $%1 to your bank account.", [_val] call AP_fnc_numberText]] spawn AP_fnc_handleMessage;};
    default {};};