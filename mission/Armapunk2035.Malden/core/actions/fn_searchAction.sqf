params[["_unit", objNull, [objNull]]];
if (isNull _unit || !(_unit isKindOf "CAManBase")) exitWith {};
["Searching...", "basic"] spawn AP_fnc_handleMessage;
uiSleep 2;
if (player distance _unit > 5 || !alive player || !alive _unit) exitWith {
    ["Cannot search that person.", "basic"] spawn AP_fnc_handleMessage;}; [
    ["-SEARCH-", player, (profileName), format["searched %1 (%2) at POS: %3", name _unit, getPlayerUID _unit, getPosATL player]], "APS_fnc_logIt", 2, false, false] spawn AP_fnc_MP;
[["search", _unit], "APS_fnc_victimSRV", 2, false, false] spawn AP_fnc_MP;   // server re-checks, forwards AP_fnc_searchClient
if ([
    ["illegal_marker_2_0", "illegal_marker_3_0", "illegal_marker_5_0"], 300, player] call AP_fnc_inZone) then {
    ["action", "searchdrugfield", 1] call AP_fnc_handleQuest;};