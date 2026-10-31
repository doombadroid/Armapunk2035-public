params[["_mode", -1, [0]]];
if (_mode isEqualTo - 1) exitWith {};

disableSerialization;
switch (_mode) do {case 0: {waitUntil {!isNull(findDisplay 2900)};
            private _display = findDisplay 2900;
            private _ownedSprays = _display displayCtrl 1102;
            private _sprayCfg = ["getCfg"] call AP_fnc_sprayCanCfg; {_x params["_xIDX", "_xName", "_xPath", "_xUnlocked"];
                if (_xUnlocked) then {private _index = _ownedSprays lbAdd format["%1", _xName];
                    _ownedSprays lbSetData[_index, str _x];
                    _ownedSprays lbSetPicture[_index, _xPath];
                    _ownedSprays lbSetPictureColor[_index, [1, 1, 1, 1]];
                    _ownedSprays lbSetSelectColor[_index, [1, 1, 1, 1]];
                    if (_xIDX isEqualTo(profileNameSpace getVariable["AP_savedSprayImage", []] param[0, 0])) then {
                        _ownedSprays lbSetCurSel _index;};};}
            forEach _sprayCfg;};
    case 1: {private _display = findDisplay 2900;
            private _ownedSprays = (_display displayCtrl 2901) controlsGroupCtrl 1102;
            private _chosenSpray = parseSimpleArray(_ownedSprays lbData(lbCurSel _ownedSprays));
            if (_chosenSpray isEqualTo[]) exitWith {};
            _chosenSpray params["_IDX", "_Name", "_Path", "_Unlocked"];
            if !(_Unlocked) exitWith {};
            profileNameSpace setVariable["AP_savedSprayImage", _chosenSpray];};
    case 2: {waitUntil {!isNull(findDisplay 360000)};
            private _display = findDisplay 360000;
            private _ownedSprays = _display displayCtrl 360001;
            private _sprayCfg = ["getCfg"] call AP_fnc_sprayCanCfg; {_x params["_xIDX", "_xName", "_xPath", "_xUnlocked"];
                if (_xUnlocked) then {private _index = _ownedSprays lbAdd format["%1", _xName];
                    _ownedSprays lbSetData[_index, str _x];
                    _ownedSprays lbSetPicture[_index, _xPath];
                    _ownedSprays lbSetPictureColor[_index, [1, 1, 1, 1]];
                    _ownedSprays lbSetSelectColor[_index, [1, 1, 1, 1]];
                    if (_xIDX isEqualTo(profileNameSpace getVariable["AP_savedSprayImage", []] param[0, 0])) then {
                        _ownedSprays lbSetCurSel _index;};};}
            forEach _sprayCfg;};
    case 3: {private _dialog = findDisplay 360000;
            private _ownedSprays = _dialog displayCtrl 360001;
            private _chosenSpray = parseSimpleArray(_ownedSprays lbData(lbCurSel _ownedSprays));
            if (_chosenSpray isEqualTo[]) exitWith {};
            _chosenSpray params["_IDX", "_Name", "_Path", "_Unlocked"];
            if !(_Unlocked) exitWith {};
            [format["You have chosen %1 as your custom spray!", _Name], "basic"] spawn AP_fnc_handleMessage;
            profileNameSpace setVariable["AP_savedSprayImage", _chosenSpray];};};