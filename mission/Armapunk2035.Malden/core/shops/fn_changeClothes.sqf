params["_basic", ["_type", ""], ["_oldLoadout", ""]];
if (_type isEqualTo "") exitWith {};
disableSerialization;
private _display = findDisplay 3100;
if (isNull _display) exitWith {};
_basic params["_list", "_selection"];
private _filter = _display displayCtrl 3102;
private _totalText = _display displayCtrl 3106;
private _priceText = _display displayCtrl 3107;
private _purchase = _display displayCtrl 1001;
if (_selection isEqualTo - 1) exitWith {};
if (isNull _display) exitWith {};
private _boxSelection = parseSimpleArray format["%1", _list lbData _selection];
_boxSelection params["_data", "_customTexture"];
private _price = _list lbValue _selection;
private _filterSelection = _filter lbValue(lbCurSel _filter);
private _oldLoadout = parseSimpleArray format["%1", _oldLoadout];
if !(_oldLoadout isEqualType[]) exitWith {};
private _oldItem = _oldLoadout select _filterSelection;
if !(_type isEqualTo "faces") then {[_data, true, nil, nil, nil, nil, nil, true] call AP_fnc_handleItem;} else {player setFace _data;};
private _isPack = getNumber(configFile >> "CfgVehicles" >> _data >> "isBackpack");
private _itemType = getNumber(configFile >> "CfgWeapons" >> _data >> "ItemInfo" >> "type");
if !(_customTexture isEqualTo "") then {if (_itemType isEqualTo 801) then {player setObjectTexture[0, _customTexture];
        AP_clothingShop_skins set[0, _customTexture];
        private _idx = [uniform player, "getID", _customTexture] call AP_fnc_clothingTextures;
        private _textureRow = [uniform player, "getRowByID", _idx] call AP_fnc_clothingTextures;
        if !(_textureRow param[11, ""] isEqualTo "") then {player setObjectTexture[1, _textureRow select 11];};};
    if (_isPack isEqualTo 1) then {if (_customTexture isEqualTo "AP_INVIS_BAG") then {
            // invisible backpack: EMPTY texture ("") on the backpackContainer = invisible + robust (a transparent
            // .paa doesn't blend; hideObject gets un-done on respawn/vehicle/reconnect). Local for the preview.
            [false] call AP_fnc_invisBag;} else {(unitBackpack player) setObjectTexture[0, _customTexture];};
        AP_clothingShop_skins set[1, _customTexture];};} else {if (_itemType isEqualTo 801) then {AP_clothingShop_skins set[0, ""];};
    if (_isPack isEqualTo 1) then {AP_clothingShop_skins set[1, ""];};};
private _currentLoadout = [uniform player, headgear player, goggles player, vest player, backpack player];
private _currentItem = _currentLoadout select _filterSelection;
private _price =
if (_currentItem isEqualTo _oldItem) then {0} else {_price};
AP_clothing_purchase set[_filterSelection, _price];
private _totalPrice = 0; {if !(_x isEqualTo 0) then {_totalPrice = _totalPrice + _x}}
forEach AP_clothing_purchase;
private _formatTextTotal =
if !(AP_ndShop) then {format["$%1", [_totalPrice] call AP_fnc_numberText]} else {
    format["%1 ND", [[_totalPrice] call AP_fnc_ndFromLegacy] call AP_fnc_ndText]   // NEW DRACHMA: bundle 6000:1
};
private _formatTextPrice =
if !(AP_ndShop) then {format["$%1", [_price] call AP_fnc_numberText]} else {
    format["%1 ND", [[_price] call AP_fnc_ndFromLegacy] call AP_fnc_ndText]};
_totalText ctrlSetText _formatTextTotal;
_priceText ctrlSetText _formatTextPrice;
if (_data isEqualTo "remove") exitWith {if !(_currentItem isEqualTo _oldItem) then {switch (_filterSelection) do {case 0: {
                    removeUniform player;
                    if !(_oldItem isEqualTo "") then {player forceAddUniform _oldItem}};
            case 1: {removeHeadgear player;
                    if !(_oldItem isEqualTo "") then {player addHeadgear _oldItem}};
            case 2: {removeGoggles player;
                    if !(_oldItem isEqualTo "") then {player addGoggles _oldItem}};
            case 3: {removeVest player;
                    if !(_oldItem isEqualTo "") then {player addVest _oldItem}};
            case 4: {removeBackpack player;
                    if !(_oldItem isEqualTo "") then {player addBackpack _oldItem}};};};};
if (!ctrlEnabled _purchase) then {_purchase ctrlEnable true};