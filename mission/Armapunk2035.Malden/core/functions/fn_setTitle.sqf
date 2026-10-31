params[["_value", "No Title", [""]], ["_variable", "", [""]]];
if (_variable isEqualTo "") exitWith {};
if (_value isEqualTo "") then {player setVariable[_variable, nil, true];} else {private _value =
    if (_variable isEqualTo "AP_title") then {[_value, (profileNameSpace getVariable["AP_titleColor", "#B6B6B6"])]} else {_value};
    player setVariable[_variable, _value, true];};