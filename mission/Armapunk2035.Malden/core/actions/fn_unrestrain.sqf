params[["_unit", objNull, [objNull]], ["_playerActivated", false, [false]]];
if (isNull _unit || !(_unit getVariable["AP_restrained", false])) exitWith {};
if (player distance _unit > 8 && (call AP_adminLevel <= 1)) exitWith {};
private _exit = false;
if (_playerActivated) then {
    private _action = [format["<t align='center'>Do you want to unrestrain %1?</t>", name _unit], "Unrestrain Player", "Yes", "No"] call BIS_fnc_guiMessage;
    if !(_action) exitWith {_exit = true};};
if (_exit) exitWith {};
_unit setVariable["AP_restrained", nil, true]; [
    ["-UNRESTRAIN-", player, (profileName), format["(%1) unrestrained %2 (%3) (%4) at %5", AP_effSide, name _unit, getPlayerUID _unit, side _unit, getPosATL player]], "APS_fnc_logIt", 2, false, false] spawn AP_fnc_MP;