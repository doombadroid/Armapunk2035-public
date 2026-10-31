params[["_mode", -1, [0]]];
if (_mode isEqualTo - 1) exitWith {};

disableSerialization;
switch (_mode) do {case 0: {waitUntil {!isNull(findDisplay 2900)};
            private _display = findDisplay 2900;
            private _dropDownMemberCombo = (_display displayCtrl 2901) controlsGroupCtrl 1100;
            private _dropDownColor = (_display displayCtrl 2901) controlsGroupCtrl 1101;
            private _hexConfig = ["getCfg"] call AP_fnc_hexIconCfg; {_x params["_xIDX", "_xName", "_xPath", "_xUnlocked"];
                if (_xUnlocked) then {private _index = _dropDownMemberCombo lbAdd format["%1", _xName];
                    _dropDownMemberCombo lbSetData[_index, str _x];
                    _dropDownMemberCombo lbSetPicture[_index, _xPath];
                    _dropDownMemberCombo lbSetPictureColor[_index, [1, 1, 1, 1]];
                    if (_xIDX isEqualTo((profileNameSpace getVariable["AP_coloredHexesData", []] param[0, []]) param[0, -1])) then {
                        _dropDownMemberCombo lbSetCurSel _index;};};}
            forEach _hexConfig; {_x params["_colorName", "_colorRGB"];
                private _index = _dropDownColor lbAdd format["%1", _colorName];
                _dropDownColor lbSetData[_index, str _x];
                _dropDownColor lbSetColor[_index, _colorRGB];
                if (_colorRGB isEqualTo(profileNameSpace getVariable["AP_coloredHexesData", []] param[1, []])) then {
                    _dropDownColor lbSetCurSel _index;};}
            forEach[["Active Elements", [profileNamespace getVariable["IGUI_TEXT_RGB_R", 1], profileNamespace getVariable["IGUI_TEXT_RGB_G", 1], profileNamespace getVariable["IGUI_TEXT_RGB_B", 1], profileNamespace getVariable["IGUI_TEXT_RGB_A", 0.5]]], ["Red", [1, 0, 0, 1]], ["Orange", [1, 0.647, 0, 1]], ["Yellow", [1, 1, 0, 1]], ["Chartreuse Green", [0.498, 1, 0, 1]], ["Green", [0, 0.501, 0, 1]], ["Spring Green", [0, 1, 0.498, 1]], ["Cyan", [0, 1, 1, 1]], ["Azure", [0, 0.498, 1, 1]], ["Blue", [0, 0, 1, 1]], ["Violet", [0.93, 0.509, 0.93, 1]], ["Magenta", [1, 0, 1, 1]], ["Rose", [1, 0.894, 0.882, 1]], ["Black", [0, 0, 0, 1]], ["White", [1, 1, 1, 1]]];
        };
    case 1: {waitUntil {!isNull(findDisplay 2900)};
            private _display = findDisplay 2900;
            private _dropDownColor = (_display displayCtrl 2901) controlsGroupCtrl 1101;
            private _hexConfig = ["getCfg"] call AP_fnc_hexIconCfg;
            private _chosenHexColor = parseSimpleArray(_dropDownColor lbData(lbCurSel _dropDownColor));
            if (_chosenHexColor isEqualTo[]) exitWith {};
            _chosenHexColor params["_colorName", "_colorRGB"];
            profileNamespace setVariable["AP_coloredHexesData", [((profileNamespace getVariable["AP_coloredHexesData", [[-1, ""],
                [0, 0, 0, 1]]]) param[0, [-1, ""]]), _colorRGB]];};
    case 2: {waitUntil {!isNull(findDisplay 2900)};
            private _display = findDisplay 2900;
            private _dropDownMemberCombo = (_display displayCtrl 2901) controlsGroupCtrl 1100;
            private _hexConfig = ["getCfg"] call AP_fnc_hexIconCfg;
            private _chosenMemberPic = parseSimpleArray(_dropDownMemberCombo lbData(lbCurSel _dropDownMemberCombo));
            if (_chosenMemberPic isEqualTo[]) exitWith {};
            _chosenMemberPic params["_memberIDX", "_memberHexName", "_memberPath", "_memberUnlocked"];
            if !(_memberUnlocked) exitWith {};
            if !((time - 10) > AP_lastHexChange) exitWith {
                ["You can only set your hex icon every 10 seconds!"] spawn AP_fnc_handleMessage};
            private _dialogQuestion = [format["Do you want to set your public group hex icon as %1? This only shows on civilian and can only be changed every 10 seconds.", _memberHexName], "Group Hex Icon", "Yes", "No"] call BIS_fnc_guiMessage;
            if !(_dialogQuestion) exitWith {};
            AP_lastHexChange = time;
            profileNamespace setVariable["AP_coloredHexesData", [
                [_memberIDX, _memberPath], ((profileNamespace getVariable["AP_coloredHexesData", [[-1, ""], [0, 0, 0, 1]
                ]]) param[1, [0, 0, 0, 1]])]];
            if (AP_effSide isEqualTo civilian) then {player setVariable["AP_coloredHexesData", _memberPath, true];};
            [format["Group hex icon saved!"], "basic"] spawn AP_fnc_handleMessage;};};