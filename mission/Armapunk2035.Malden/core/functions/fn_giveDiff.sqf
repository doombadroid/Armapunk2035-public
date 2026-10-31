params[["_unit", objNull, [objNull]], ["_item", "", [""]], ["_val", 0, [0]], ["_from", objNull, [objNull]]];
if (isNull _unit || isNull _from) exitWith {};
if !(_unit isEqualTo player) exitWith {};
private _bool = count _this > 4;
private _type = ["getName", _item] call AP_fnc_virtItemCfg;
if (_bool) then {if ([true, _item, _val] call AP_fnc_handleInv) then {
        [format["You tried to give %1 %2 %3 but they couldn't hold that so it was returned.", [name _from] call AP_fnc_cleanName, _val, _type], "basic"] spawn AP_fnc_handleMessage;
    };} else {if ([true, _item, _val] call AP_fnc_handleInv) then {
        [format["%1 returned %2 %3 because they couldn't hold that amount.", [name _from] call AP_fnc_cleanName, _val, _type], "basic"] spawn AP_fnc_handleMessage;
    };};