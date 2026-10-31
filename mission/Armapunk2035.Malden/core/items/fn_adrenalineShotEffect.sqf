params[["_unit", objNull, [objNull]]];
if (player getVariable["AP_downed", false]) then {player setVariable["AP_adrenaline", true, true]};
[] call AP_fnc_hudUpdate;
if (!isNull _unit) then {titleText[format["%1 has injected you with an Adrenaline Shot", [name _unit] call AP_fnc_cleanName], "PLAIN"]};