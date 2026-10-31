// Registration, not a loop -- no handle, no exit condition, so it outlives whatever added it. The body
// already drives off AP_effSide (below), but "whatever AP_effSide happens to be" is wrong once duty can
// move it: a clocked-off medic would draw a TT hex over every civilian in view, every frame. Gate the whole
// draw on being on the TT side. No-op for a real medic slot; no-op for everyone else, who never had it.
addMissionEventHandler["Draw3D", {if !(AP_effSide isEqualTo independent) exitWith {};
    private _group = group player;
    private _leader = leader _group;
    private _sideUnits = allPlayers select {(side _x) isEqualTo AP_effSide};
    private _allSideMembers = _sideUnits select {
        (alive _x) && (_x in allPlayers) && !(_x isEqualTo player) && !(_x getVariable["AP_restrained", false])};
    private _allSideVehicles = (_allSideMembers apply {vehicle _x}) select {(alive _x) && !(_x isKindOf "CAManBase")};
    private _allSideVehicles = _allSideVehicles arrayIntersect _allSideVehicles;
    private _allSideMembers = _allSideMembers select {(vehicle _x) isEqualTo _x};
    private _getHexPicture = {params[["_unit", objNull, [objNull]]];
        if (_unit distance2D(getMarkerPos "respawn_civilian") <= 1000) exitWith {"\A3\ui_f\data\igui\cfg\cursors\select_ca.paa"};
        if (side _unit isEqualTo independent) exitWith {"icons\med_hex.paa"};};
    private _getDriverName = {params["_vehicle"];
        private _crew = crew _vehicle;
        private _driver = driver _vehicle;
        private _return =
        if (isNull _driver) then {name(_crew param[_crew findIf {alive _x}, objNull])} else {name _driver};
        _return}; {private _unit = _x;
        private _hexIcon =
        if (AP_isCustomHexesEnabled) then {[_unit] call _getHexPicture} else {"\A3\ui_f\data\igui\cfg\cursors\select_ca.paa"};
        private _color =
        
            ((profileNamespace getVariable["AP_coloredHexesData", [[-1, ""], [1, 1, 1, 1]]]) param[1, [1, 1, 1, 1]]);
        if (((toLower _hexIcon) find "a3") isEqualTo - 1) then {
            _hexIcon = format["mpmissions\__cur_mp.%1\%2", toLower worldName, _hexIcon];};
        if !(_unit isEqualTo(vehicle player)) then {private _selection =
            if (_unit in _allSideVehicles) then {"zamerny"} else {"spine3"};
            private _position = _unit modelToWorldVisual(_unit selectionPosition[_selection, "Memory"]);
            private _text =
            if (AP_targetTag) then {if (_unit in _allSideMembers) then {
                    format["%1 - %2m", name _unit, [round(_unit distance2D player)] call AP_fnc_numberText];} else {
                    if (_unit in _allSideVehicles) then {
                        format["%1 (%3) - %2m ", [_unit] call _getDriverName, [round(_unit distance2D player)] call AP_fnc_numberText, count((crew(vehicle _unit)) select {
                            alive _x})];} else {"";};};} else {"";
            }; if (_hexIcon isNotEqualTo "\A3\ui_f\data\igui\cfg\cursors\select_ca.paa") then {
                drawIcon3D[_hexIcon, _color, _position, 0.5, 0.5, 0, "", true];};
            drawIcon3D["\A3\ui_f\data\igui\cfg\cursors\select_ca.paa", _color, _position, 1, 1, 0, _text, 2];};}
    forEach(_allSideMembers + _allSideVehicles);}];