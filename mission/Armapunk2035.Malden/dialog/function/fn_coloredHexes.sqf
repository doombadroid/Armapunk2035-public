addMissionEventHandler["Draw3D", {if !(AP_hexMode) exitWith {removeMissionEventHandler["Draw3D", _thisEventHandler];};
    private _player =
    if !(isNil "suspectESP_suspectObj") then {suspectESP_suspectObj} else {player};
    private _group = group _player;
    private _leader = leader _group;
    private _allGroupMembers = (units _group) select {
        (alive _x) && (_x in allPlayers) && !(_x isEqualTo _player) && !(_x getVariable["AP_restrained", false])};
    private _allGroupVehicles = (_allGroupMembers apply {vehicle _x}) select {(alive _x) && !(_x isKindOf "CAManBase")};
    private _allGroupVehicles = _allGroupVehicles arrayIntersect _allGroupVehicles;
    private _allGroupMembers = _allGroupMembers select {(vehicle _x) isEqualTo _x};
    private _getHexPicture = {params[["_unit", objNull, [objNull]]];
        _unit =
        if !(_unit isKindOf "CAManBase") then {driver _unit} else {_unit};
        if (_unit distance2D(getMarkerPos "respawn_civilian") <= 1000) exitWith {"\A3\ui_f\data\igui\cfg\cursors\select_ca.paa"};
        if (side _unit isEqualTo civilian) exitWith {
            private _iconPath = (_unit getVariable["AP_coloredHexesData", "\A3\ui_f\data\igui\cfg\cursors\select_ca.paa"]);
            _iconPath};
        if (side _unit isEqualTo west) exitWith {
            private _iconPath = ["", "\A3\Ui_f\data\GUI\Cfg\Ranks\private_gs.paa", "icons\pfc_gs.paa", "\A3\Ui_f\data\GUI\Cfg\Ranks\corporal_gs.paa", "\A3\Ui_f\data\GUI\Cfg\Ranks\sergeant_gs.paa", "\A3\Ui_f\data\GUI\Cfg\Ranks\lieutenant_gs.paa", "\A3\Ui_f\data\GUI\Cfg\Ranks\captain_gs.paa", "\A3\Ui_f\data\GUI\Cfg\Ranks\colonel_gs.paa"] select(_unit getVariable["AP_unitCopLevel", 0]);
            _iconPath};
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
        if !(_unit isEqualTo(vehicle _player)) then {private _selection =
            if (_unit in _allGroupVehicles) then {"zamerny"} else {"spine3"};
            private _position = _unit modelToWorldVisual(_unit selectionPosition[_selection, "Memory"]);
            private _text =
            if (AP_targetTag) then {if (_unit in _allGroupMembers) then {
                    format["%1 - %2m", name _unit, [round(_unit distance2D _player)] call AP_fnc_numberText];} else {
                    if (_unit in _allGroupVehicles) then {
                        format["%1 (%3) - %2m ", [_unit] call _getDriverName, [round(_unit distance2D _player)] call AP_fnc_numberText, count((crew(vehicle _unit)) select {
                            alive _x})];} else {"";};};} else {"";
            }; if (_hexIcon isNotEqualTo "\A3\ui_f\data\igui\cfg\cursors\select_ca.paa") then {
                drawIcon3D[_hexIcon, _color, _position, 0.5, 0.5, 0, "", true];};
            drawIcon3D["\A3\ui_f\data\igui\cfg\cursors\select_ca.paa", _color, _position, 1, 1, 0, _text, 2];};}
    forEach(_allGroupMembers + _allGroupVehicles);}];