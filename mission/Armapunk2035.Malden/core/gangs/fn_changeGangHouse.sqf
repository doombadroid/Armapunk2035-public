params[["_oldHouse", objNull, [objNull]], ["_newHouse", objNull, [objNull]]];
if (isNull _oldHouse || isNull _newHouse) exitWith {};
private _gangID = AP_gang_data param[0, -1];
if !(_gangID isEqualTo - 1) then {AP_gangBuilding = [_newHouse, getPosATL _newHouse];
    AP_gang_data set[3, getPosATL _newHouse];
    if (AP_gang_data param[2, 0] isEqualTo 1) then {[[_oldHouse, _newHouse, _gangID], "APS_fnc_changeGangHouseSRV", 2] spawn AP_fnc_MP;
        ["You have chosen this house as your new gang house.", "basic"] spawn AP_fnc_handleMessage;} else {
        deleteMarkerLocal AP_gangBldgMark;
        private _marker = createMarkerLocal[format["phouse_%1%2", _gangID, _newHouse getVariable["AP_homeOwner", ""]], getPosATL _newHouse];
        _marker setMarkerTextLocal "Gang Building";
        _marker setMarkerColorLocal "ColorGreen";
        _marker setMarkerTypeLocal "mil_end";
        AP_gangBldgMark = _marker;
        ["Your gang leader has changed the gang house.", "basic"] spawn AP_fnc_handleMessage;};};