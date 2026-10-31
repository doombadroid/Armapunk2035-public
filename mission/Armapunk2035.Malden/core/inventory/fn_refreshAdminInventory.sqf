params[["_veh", objNull, [objNull]], ["_isVirtual", true, [true]]];
if (isNull _veh || !alive _veh) exitWith {closeDialog 0;};
disableSerialization;
private _tInv = (findDisplay 4500) displayCtrl 4502;
private _pInv = (findDisplay 4500) displayCtrl 4503;
private _storeBtn = (findDisplay 4500) displayCtrl 4508;
private _takeBtn = (findDisplay 4500) displayCtrl 4507;
private _pEdit = (findDisplay 4500) displayCtrl 4506;
private _tEdit = (findDisplay 4500) displayCtrl 4505;
private _pDropBtn = (findDisplay 4500) displayCtrl 4522;
private _tDropBtn = (findDisplay 4500) displayCtrl 4521;
lbClear _tInv;
lbClear _pInv;
private _data = [[], 0];
_pDropBtn ctrlEnable!AP_is_virtual;
_tDropBtn ctrlEnable!AP_is_virtual;
if (_isVirtual) then {_data = _veh getVariable["AP_vinv", [[], 0]];
    private _inventory = _data select 0;
    private _weight = _data select 1;
    ctrlSetText[4504, format["Weight: %1/%2", _weight, (_veh getVariable["AP_vcap", 100])]]; {
        _itemName = ["getName", _x] call AP_fnc_virtItemCfg;
        _itemShort = ["getShortName", _x] call AP_fnc_virtItemCfg;
        _itemPic = ["getIcon", _itemShort] call AP_fnc_virtItemCfg;
        _index = _pInv lbAdd(format["%1", _itemName]);
        _pInv lbSetData[_index, _itemShort];
        _pInv lbSetPicture[_index, _itemPic];}
    forEach([1] call AP_fnc_virtItemCfg); {_x params["_varName", "_value"];
        if (_value > 0) then {_itemName = ["getName", _varName] call AP_fnc_virtItemCfg;
            _index = _tInv lbAdd(format["[%1] - %2", _value, _itemName]);
            _tInv lbSetData[_index, _varName];
            _tInv lbSetPicture[_index, ["getIcon", _varName] call AP_fnc_virtItemCfg];};}
    forEach _inventory;} else {_data = _veh getVariable["AP_pinv", [[], 0]];
    private _inventory = _data select 0;
    private _weight = _data select 1;
    ctrlSetText[4504, format["Weight: %1/%2", _weight, (_veh getVariable["AP_phys_cap", 100])]];
    private _pCache = [];
    private _index = -1;
    private _tempItem = "";
    for "_i"
    from 0 to(count(missionConfigFile >> "CfgWeights") - 1) do {
        private _className = (configName((missionConfigFile >> "CfgWeights") select _i));
        private _details = [_className] call AP_fnc_fetchCfgDetails;
        if !(count _details isEqualTo 0) then {
            private _str = format["%1", (getText(configFile >> (_details select 6) >> _className >> "DisplayName"))];
            private _icon = getText(configFile >> (_details select 6) >> _className >> "picture");
            _pInv lbAdd format["%1", _str];
            _pInv lbSetData[(lbSize _pInv) - 1, _className];
            _pInv lbSetValue[(lbSize _pInv) - 1, 200];
            _pInv lbSetPicture[(lbSize _pInv) - 1, _icon];};}; { private _details = [_x select 0] call AP_fnc_fetchCfgDetails;
        _str = format["%1", (getText(configFile >> (_details select 6) >> _x select 0 >> "DisplayName"))];
        _shrt = _x select 0;
        private _icon = getText(configFile >> (_details select 6) >> _x select 0 >> "picture");
        _tInv lbAdd format["[%1] - %2", _x select 1, _str];
        _tInv lbSetData[(lbSize _tInv) - 1, _shrt];
        _tInv lbSetValue[(lbSize _tInv) - 1, _x select 1];
        _tInv lbSetPicture[(lbSize _tInv) - 1, _icon];}
    forEach _inventory;};