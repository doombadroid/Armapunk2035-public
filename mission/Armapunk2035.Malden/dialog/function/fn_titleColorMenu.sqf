params[["_mode", -1, [0]]];
if (_mode isEqualTo - 1) exitWith {};

disableSerialization;
switch (_mode) do {case 0: {waitUntil {!isNull(findDisplay 2900)};
            private _display = findDisplay 2900;
            private _dropDownColorCombo = (_display displayCtrl 2901) controlsGroupCtrl 1103; {
                _x params["_colorName", "_hexColor", "_rgba"];
                private _index = _dropDownColorCombo lbAdd format["%1", _colorName];
                _dropDownColorCombo lbSetData[_index, str _x];
                _dropDownColorCombo lbSetColor[_index, _rgba];
                if (_hexColor isEqualTo(profileNameSpace getVariable["AP_titleColor", "#B6B6B6"])) then {
                    _dropDownColorCombo lbSetCurSel _index;};}
            forEach[["Red", "#FF0000", [1, 0, 0, 1]], ["Orange", "#FFA500", [1, 0.647, 0, 1]], ["Yellow", "#FFFF00", [1, 1, 0, 1]], ["Chartreuse Green", "#7FFF00", [0.498, 1, 0, 1]], ["Green", "#008000", [0, 0.501, 0, 1]], ["Spring Green", "#00FF7F", [0, 1, 0.498, 1]], ["Cyan", "#00FFFF", [0, 1, 1, 1]], ["Azure", "#007fff", [0, 0.498, 1, 1]], ["Blue", "#0000FF", [0, 0, 1, 1]], ["Violet", "#EE82EE", [0.93, 0.509, 0.93, 1]], ["Magenta", "#FF00FF", [1, 0, 1, 1]], ["Rose", "#F33A6A", [1, 0.894, 0.882, 1]], ["Black", "#000000", [0, 0, 0, 1]], ["White", "#FFFFFF", [1, 1, 1, 1]]];
        };
    case 1: {waitUntil {!isNull(findDisplay 2900)};
            private _display = findDisplay 2900;
            private _dropDownColorCombo = (_display displayCtrl 2901) controlsGroupCtrl 1103;
            private _chosenHexColor = parseSimpleArray(_dropDownColorCombo lbData(lbCurSel _dropDownColorCombo));
            private _preTitle = ((player getVariable["AP_title", ["", "#B6B6B6"]]) param[0, ""]);
            if (_chosenHexColor isEqualTo[]) exitWith {};
            _chosenHexColor params["_colorName", "_hexColor"];
            profileNamespace setVariable["AP_titleColor", _hexColor];
            player setVariable["AP_title", [_preTitle, _hexColor], true];};};