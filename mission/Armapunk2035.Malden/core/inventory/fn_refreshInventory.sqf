params[["_veh", objNull, [objNull]], ["_isVirtual", true, [true]]];
// WEB ROUTES: no dialog 4500 to repaint -- push the open page's channel instead, chosen by
// which web display is up. Ordered BEFORE the dead-vehicle close so a despawn cannot shut the
// whole phone.
//
// 938000 (STORAGE) was added 2026-09-05 with physical moves. Without it, control fell through
// to `(findDisplay 4500) displayCtrl 4502` -> controlNull, and the lbClear / ctrlSetText[4504]
// that follow threw -- once per move, since fn_takeInventory / fn_storeInventory both call this
// as their last act.
if (isNull (findDisplay 4500)) exitWith {
    private _c = uiNamespace getVariable ["WEBUI_ctrl", controlNull];
    if (isNull _c) exitWith {};
    if !(isNull (findDisplay 937500)) exitWith { [_c, "trunk", (["data"] call AP_fnc_deckTrunk)] call webui_fnc_push; };
    // the bridge parks its own snapshot builder here on open; calling it is exactly what
    // fn_storageBridge's own verbs do after a mutation.
    if !(isNull (findDisplay 938000)) exitWith {
        private _b = uiNamespace getVariable ["AP_storageData", {}];
        if (_b isEqualType {}) then { [_c, "storage", (call _b)] call webui_fnc_push; };
    };
};
if (isNull _veh || !alive _veh) exitWith {closeDialog 0;};
if (!_isVirtual && (_veh isKindOf "Car" || _veh isKindOf "Air" || _veh isKindOf "Ship")) exitWith {closeDialog 0;
    ["Physical inventory via this method is not allowed on vehicles! Please use the Arma 3 inventory method.", "basic"] spawn AP_fnc_handleMessage;
};
if (isNil {(_veh getVariable["AP_vinv", [[], 0]]) select 1}) exitWith {closeDialog 0;
    ["The virtual inventory has corrupted. The inventory has been wiped and reset. This has been logged.", "basic"] spawn AP_fnc_handleMessage;
    [
        ["-WIPEDVEH-", player, (profileName), format["had their vehicle wiped due to potential weight and item exploit. Old Inventory: %1", _veh getVariable["AP_vinv", [
            [], 0]]]], "APS_fnc_logIt", 2] spawn AP_fnc_MP;
    _veh setVariable["AP_vinv", [[], 0], true];};
if (isNil {(_veh getVariable["AP_pinv", [[], 0]]) select 1}) exitWith {closeDialog 0;
    ["The physical inventory has corrupted. The inventory has been wiped and reset. This has been logged.", "basic"] spawn AP_fnc_handleMessage;
    [
        ["-WIPEDVEH-", player, (profileName), format["had their house wiped due to potential weight and item exploits. Old Inventory: %1", _veh getVariable["AP_pinv", [
            [], 0]]]], "APS_fnc_logIt", 2] spawn AP_fnc_MP;
    _veh setVariable["AP_pinv", [[], 0], true];};
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
        _value = missionNameSpace getVariable [_x, 0];   // owner 2026-06-26 (house storage vanish/dupe -- nolovenova #): no default -> a never-set item var returned nil -> `nil > 0` THREW here, aborting the refresh BEFORE the trunk/house list (line ~64) populated, so house storage showed empty and takes corrupted the saved state. Missed in the _val mega-sweep.
        if (_value > 0) then {_itemName = ["getName", _x] call AP_fnc_virtItemCfg;
            _itemShort = ["getShortName", _x] call AP_fnc_virtItemCfg;
            _itemPic = ["getIcon", _itemShort] call AP_fnc_virtItemCfg;
            _index = _pInv lbAdd(format["[%1] - %2", _value, _itemName]);
            _pInv lbSetData[_index, _itemShort];
            _pInv lbSetPicture[_index, _itemPic];};}
    forEach([1] call AP_fnc_virtItemCfg); {_x params["_varName", "_value"];
        if (_value > 0) then {_itemName = ["getName", _varName] call AP_fnc_virtItemCfg;
            _index = _tInv lbAdd(format["[%1] - %2", _value, _itemName]);
            _tInv lbSetData[_index, _varName];
            _tInv lbSetPicture[_index, ["getIcon", _varName] call AP_fnc_virtItemCfg];};}
    forEach _inventory;} else {_pDropBtn ctrlEnable true;
    _tDropBtn ctrlEnable true;
    _data = _veh getVariable["AP_pinv", [[], 0]];
    private _inventory = _data select 0;
    private _weight = _data select 1;
    ctrlSetText[4504, format["Weight: %1/%2", _weight, (_veh getVariable["AP_phys_cap", 100])]];
    private _pCache = [];
    private _index = -1;
    private _tempItem = "";
    private _headgear = headgear player;
    if !(_headgear IsEqualTo "") then {_index = -1; {if !(_index isEqualTo - 1) exitWith {};
            if (_headgear isEqualTo(_x select 0)) exitWith {_index = _forEachIndex;};}
        forEach _pCache;
        if (_index isEqualTo - 1) then {_pCache pushBack[_headgear, 1];} else {
            _pCache set[_index, [_headgear, ((_pCache select _index) select 1) + 1]];};};
    private _goggles = goggles player;
    if !(_goggles IsEqualTo "") then {_index = -1; {if !(_index isEqualTo - 1) exitWith {};
            if (_goggles isEqualTo(_x select 0)) exitWith {_index = _forEachIndex;};}
        forEach _pCache;
        if (_index isEqualTo - 1) then {_pCache pushBack[_goggles, 1];} else {
            _pCache set[_index, [_goggles, ((_pCache select _index) select 1) + 1]];};};
    private _uniform = uniform player;
    if !(_uniform IsEqualTo "") then {_index = -1; {if !(_index isEqualTo - 1) exitWith {};
            if (_uniform isEqualTo(_x select 0)) exitWith {_index = _forEachIndex;};}
        forEach _pCache;
        if (_index isEqualTo - 1) then {_pCache pushBack[_uniform, 1];} else {
            _pCache set[_index, [_uniform, ((_pCache select _index) select 1) + 1]];};};
    private _vest = vest player;
    if !(_vest IsEqualTo "") then {_index = -1; {if !(_index isEqualTo - 1) exitWith {};
            if (_vest isEqualTo(_x select 0)) exitWith {_index = _forEachIndex;};}
        forEach _pCache;
        if (_index isEqualTo - 1) then {_pCache pushBack[_vest, 1];} else {
            _pCache set[_index, [_vest, ((_pCache select _index) select 1) + 1]];};};
    private _bag = backpack player;
    if (count(backpackItems player) > 0) then {{_tempItem = _x;
            _index = -1; {if !(_index isEqualTo - 1) exitWith {};
                if (_tempItem isEqualTo(_x select 0)) exitWith {_index = _forEachIndex;};}
            forEach _pCache;
            if (_index isEqualTo - 1) then {_pCache pushBack[_tempItem, 1];} else {
                _pCache set[_index, [_tempItem, ((_pCache select _index) select 1) + 1]];};}
        forEach(backpackItems player);};
    if !(_bag IsEqualTo "") then {_index = -1; {if !(_index isEqualTo - 1) exitWith {};
            if (_bag isEqualTo(_x select 0)) exitWith {_index = _forEachIndex;};}
        forEach _pCache;
        if (_index isEqualTo - 1) then {_pCache pushBack[_bag, 1];} else {
            _pCache set[_index, [_bag, ((_pCache select _index) select 1) + 1]];};};
    private _primaryWeapon = primaryWeapon player;
    private _secondaryWeapon = secondaryWeapon player;
    private _handgunWeapon = handgunWeapon player;
    if !(_primaryWeapon isEqualTo "") then {{if (_x != "") then {_tempItem = _x;
                _index = -1; {if !(_index isEqualTo - 1) exitWith {};
                    if (_tempItem isEqualTo(_x select 0)) exitWith {_index = _forEachIndex;};}
                forEach _pCache;
                if (_index isEqualTo - 1) then {_pCache pushBack[_tempItem, 1];} else {
                    _pCache set[_index, [_tempItem, ((_pCache select _index) select 1) + 1]];};};}
        forEach(primaryWeaponItems player); {_tempItem = _x;
            _index = -1; {if !(_index isEqualTo - 1) exitWith {};
                if (_tempItem isEqualTo(_x select 0)) exitWith {_index = _forEachIndex;};}
            forEach _pCache;
            if (_index isEqualTo - 1) then {_pCache pushBack[_tempItem, 1];} else {
                _pCache set[_index, [_tempItem, ((_pCache select _index) select 1) + 1]];};}
        forEach(primaryWeaponMagazine player);
        _index = -1; {if !(_index isEqualTo - 1) exitWith {};
            if (_primaryWeapon isEqualTo(_x select 0)) exitWith {_index = _forEachIndex;};}
        forEach _pCache;
        if (_index isEqualTo - 1) then {_pCache pushBack[_primaryWeapon, 1];} else {
            _pCache set[_index, [_primaryWeapon, ((_pCache select _index) select 1) + 1]];};};
    if !(_secondaryWeapon isEqualTo "") then {{if (_x != "") then {_tempItem = _x;
                _index = -1; {if !(_index isEqualTo - 1) exitWith {};
                    if (_tempItem isEqualTo(_x select 0)) exitWith {_index = _forEachIndex;};}
                forEach _pCache;
                if (_index isEqualTo - 1) then {_pCache pushBack[_tempItem, 1];} else {
                    _pCache set[_index, [_tempItem, ((_pCache select _index) select 1) + 1]];};};}
        forEach(secondaryWeaponItems player); {_tempItem = _x;
            _index = -1; {if !(_index isEqualTo - 1) exitWith {};
                if (_tempItem isEqualTo(_x select 0)) exitWith {_index = _forEachIndex;};}
            forEach _pCache;
            if (_index isEqualTo - 1) then {_pCache pushBack[_tempItem, 1];} else {
                _pCache set[_index, [_tempItem, ((_pCache select _index) select 1) + 1]];};}
        forEach(secondaryWeaponMagazine player);
        _index = -1; {if !(_index isEqualTo - 1) exitWith {};
            if (_secondaryWeapon isEqualTo(_x select 0)) exitWith {_index = _forEachIndex;};}
        forEach _pCache;
        if (_index isEqualTo - 1) then {_pCache pushBack[_secondaryWeapon, 1];} else {
            _pCache set[_index, [_secondaryWeapon, ((_pCache select _index) select 1) + 1]];};};
    if !(_handgunWeapon isEqualTo "") then {{if (_x != "") then {_tempItem = _x;
                _index = -1; {if !(_index isEqualTo - 1) exitWith {};
                    if (_tempItem isEqualTo(_x select 0)) exitWith {_index = _forEachIndex;};}
                forEach _pCache;
                if (_index isEqualTo - 1) then {_pCache pushBack[_tempItem, 1];} else {
                    _pCache set[_index, [_tempItem, ((_pCache select _index) select 1) + 1]];};};}
        forEach(handgunItems player); {_tempItem = _x;
            _index = -1; {if !(_index isEqualTo - 1) exitWith {};
                if (_tempItem isEqualTo(_x select 0)) exitWith {_index = _forEachIndex;};}
            forEach _pCache;
            if (_index isEqualTo - 1) then {_pCache pushBack[_tempItem, 1];} else {
                _pCache set[_index, [_tempItem, ((_pCache select _index) select 1) + 1]];};}
        forEach(handgunMagazine player);
        _index = -1; {if !(_index isEqualTo - 1) exitWith {};
            if (_handgunWeapon isEqualTo(_x select 0)) exitWith {_index = _forEachIndex;};}
        forEach _pCache;
        if (_index isEqualTo - 1) then {_pCache pushBack[_handgunWeapon, 1];} else {
            _pCache set[_index, [_handgunWeapon, ((_pCache select _index) select 1) + 1]];};};
    if (count(uniformItems player) > 0) then {{_tempItem = _x;
            _index = -1; {if !(_index isEqualTo - 1) exitWith {};
                if (_tempItem isEqualTo(_x select 0)) exitWith {_index = _forEachIndex;};}
            forEach _pCache;
            if (_index isEqualTo - 1) then {_pCache pushBack[_tempItem, 1];} else {
                _pCache set[_index, [_tempItem, ((_pCache select _index) select 1) + 1]];};}
        forEach(uniformItems player);};
    if (count(vestItems player) > 0) then {{_tempItem = _x;
            _index = -1; {if !(_index isEqualTo - 1) exitWith {};
                if (_tempItem isEqualTo(_x select 0)) exitWith {_index = _forEachIndex;};}
            forEach _pCache;
            if (_index isEqualTo - 1) then {_pCache pushBack[_tempItem, 1];} else {
                _pCache set[_index, [_tempItem, ((_pCache select _index) select 1) + 1]];};}
        forEach(vestItems player);};
    private _assignedItems = assignedItems player;
    if !(count _assignedItems IsEqualTo 0) then {{_tempItem = _x;
            _index = -1; {if !(_index isEqualTo - 1) exitWith {};
                if (_tempItem isEqualTo(_x select 0)) exitWith {_index = _forEachIndex;};}
            forEach _pCache;
            if (_index isEqualTo - 1) then {_pCache pushBack[_tempItem, 1];} else {
                _pCache set[_index, [_tempItem, ((_pCache select _index) select 1) + 1]];};}
        forEach _assignedItems;}; {private _details = [_x select 0] call AP_fnc_fetchCfgDetails;
        _str = format["%1", (getText(configFile >> (_details select 6) >> _x select 0 >> "DisplayName"))];
        _shrt = _x select 0;
        private _icon = getText(configFile >> (_details select 6) >> _x select 0 >> "picture");
        _pInv lbAdd format["[%1] - %2", _x select 1, _str];
        _pInv lbSetData[(lbSize _pInv) - 1, _shrt];
        _pInv lbSetValue[(lbSize _pInv) - 1, _x select 1];
        _pInv lbSetPicture[(lbSize _pInv) - 1, _icon];}
    forEach _pCache; {private _details = [_x select 0] call AP_fnc_fetchCfgDetails;
        _str = format["%1", (getText(configFile >> (_details select 6) >> _x select 0 >> "DisplayName"))];
        _shrt = _x select 0;
        private _icon = getText(configFile >> (_details select 6) >> _x select 0 >> "picture");
        _tInv lbAdd format["[%1] - %2", _x select 1, _str];
        _tInv lbSetData[(lbSize _tInv) - 1, _shrt];
        _tInv lbSetValue[(lbSize _tInv) - 1, _x select 1];
        _tInv lbSetPicture[(lbSize _tInv) - 1, _icon];}
    forEach _inventory;};