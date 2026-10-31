params[["_unit", objNull, [objNull]], ["_type", "", [""]], ["_typeItems", "", [""]]];
private _message =
if (_unit isKindOf "CAManBase") then {name _unit} else {"this vehicle"};
private _actionMessage =
if (_typeItems isEqualTo "ALL") then {"Do you wish to seize all weapons and illegal items from"} else {
    "Do you wish to seize all illegal items from"};
private _action = [format["%1 %2", _actionMessage, _message], "Seize", "Yes", "No"] call BIS_fnc_guiMessage;
if !(_action) exitWith {};
if (_type isEqualTo "HQ") then {private _exit = true;
    if ((({(position player) inPolygon(AP_police_hq_polys select _x)}
    count[0, 1, 2, 3, 4, 5, 6] > 0) || (((SRV_mobileHQ param[1, objNull]) != objNull) && ((SRV_mobileHQ param[1, objNull]) getVariable["AP_mobileHeadQuartersTruckLocked", false]) && (((SRV_mobileHQ param[1, objNull]) distance2D player) < 20)))) then {
        _exit = false;};
    if (_exit) exitWith {["You cannot seize items into evidence while not near a police HQ!", "basic"] spawn AP_fnc_handleMessage;};
    if (_unit isKindOf "CAManBase") then {[["seizeHQ", _unit, [_typeItems]], "APS_fnc_victimSRV", 2] spawn AP_fnc_MP;
        titleText[format["You have seized %1's illegal items", name _unit], "PLAIN"];};
    if (_unit isKindOf "Car" || _unit isKindOf "Air" || _unit isKindOf "Tank") then {[cursorObject] spawn AP_fnc_vehBaseSeize;};};
if (_type isEqualTo "Field") then {private _near = nearestObjects[_unit, ["Car", "Air", "Ship"], 30];
    private _nearVehicle = _near param[_near findIf {_x getVariable["AP_side", ""] isEqualTo "cop"}, objNull];
    if (isNull _nearVehicle) exitWith {
        ["There aren't any nearby Police vehicles to seize this player's gear into!", "basic"] spawn AP_fnc_handleMessage;};
    if !(alive _nearVehicle) exitWith {
        ["You cannot store items in a vehicle which has been destroyed!", "basic"] spawn AP_fnc_handleMessage;};
    if (isPlayer _unit) then {[["seizeField", _unit, [_nearVehicle, _typeItems]], "APS_fnc_victimSRV", 2] spawn AP_fnc_MP;
        titleText[format["You have seized %1's illegal items into the nearest vehicle. The items can be placed into evidence from any Police HQ.", name _unit], "PLAIN"];
    } else {titleText["Unable to seize illegal items. Please try again.", "PLAIN"];};};