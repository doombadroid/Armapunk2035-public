params[["_shopType", "", [""]], ["_controlData", [], [[]]]];
if (_shopType isEqualTo "") exitWith {};
_controlData params["_control", "_selectedIndex"];
private _display = findDisplay 39400;
if (isNull _display) exitWith {};
private _itemPreview = _display displayCtrl 39403;
private _mainListGroup = _display displayCtrl 39404;
private _mainItemList = _mainListGroup controlsGroupCtrl 1000;
private _mainItemListButton = _mainListGroup controlsGroupCtrl 1001;
private _sideListGroup = _display displayCtrl 39405;
private _sideItemList = _sideListGroup controlsGroupCtrl 1000;
private _sideItemListButton = _sideListGroup controlsGroupCtrl 1001;
if ((_control isEqualTo _sideItemList) && !(_selectedIndex isEqualTo - 1)) then {
    _sideItemListButton ctrlEnable(((_sideItemList lnbColor[_selectedIndex, 0]) select 3) isEqualTo 1)};
if ((_control isEqualTo _sideItemList) && (_selectedIndex isEqualTo - 1)) exitWith {_sideItemListButton ctrlEnable false};
private _class = _control lnbData[_selectedIndex, 0];
if (_class isEqualTo "") exitWith {_itemPreview ctrlSetText ""};
([_class] call AP_fnc_fetchCfgDetails) params["_class", "_displayName", "_picture"];
private _compatibleItems = [];
private _magazines = [_class] call AP_fnc_fetchWeaponMagazines;
private _addons = [_shopType] call AP_fnc_weaponAddons;
private _discount = [_shopType, true] call AP_fnc_getDiscount;
_itemPreview ctrlSetText _picture;
if (_control isEqualTo _sideItemList) exitWith {}; {private _cfgCompatibleItems = _x >> "compatibleItems";
    if (isArray _cfgCompatibleItems) then {{if !(_x in _compatibleItems) then {_compatibleItems pushBack(toLower _x)};}
        forEach getArray _cfgCompatibleItems;};
    if (isClass _cfgCompatibleItems) then {{if (((getNumber _x) >= 1) && !((configName _x) in _compatibleItems)) then {
                _compatibleItems pushBack(toLower(configName _x))};}
        forEach(configProperties[_cfgCompatibleItems, "isNumber _x"]);};}
forEach(configProperties[configFile >> "CfgWeapons" >> _class >> "WeaponSlotsInfo", "isClass _x"]);
_sideItemList ctrlSetFade 1.00;
_sideItemList ctrlCommit 0.00;
_sideItemList lbSetCurSel - 1;
lbClear _sideItemList; {_x params[["_class", ""], ["_name", ""], ["_price", 0]];
    if !(_class isEqualTo "") then {
        if (((toLower _class) find "box" >= 0 && {(toLower _class) find "tracer" >= 0}) || (_shopType in ["rebelwep", "turf"] && {(toLower _class) find "tracer" >= 0})) exitWith {};   // owner 2026-06-16 (#267/#297): hide LMG belt/box tracer mags EVERYWHERE (cheap stun ammo) + ALL tracers in rebel/turf. BH 30Rnd "rubber" + cop 9mm tracer (no "box") stay.
        if !((_class in _magazines) || (toLower _class in _compatibleItems)) exitWith {};
        ([_class] call AP_fnc_fetchCfgDetails) params["_class", "_displayName", "_picture"];
        _displayName =
        if !(_name isEqualTo "") then {_name} else {_displayName};
        if (_displayName isEqualTo "") exitWith {};
        private _color = [1, 1, 1, 0.5];
        _price =
        if (AP_ndShop) then {_price} else {_price * _discount};
        _price =
        if (!AP_ndShop && !(_shopType in ["rebelwep", "turf"])) then {_price} else {_price};
        _price =
        _price;
        // NEW DRACHMA: in the wallet shop, show the INDEPENDENT ND price (fn_ndPriceCfg) and gate the
        // afford-colour on the exact ND balance -- never the float mirror.
        private _ndRow = "";
        if (AP_ndShop) then {_ndRow = [_class] call AP_fnc_ndPriceCfg;
            if (_ndRow isEqualTo "") then { _ndRow = [_price] call AP_fnc_ndFromLegacy; };};
        private _formatText =
        if !(AP_ndShop) then {format["$%1", [round _price] call AP_fnc_numberText]} else {format["%1 ND", [_ndRow] call AP_fnc_ndText]
        };
        private _rowIndex = _sideItemList lnbAddRow[_displayName, _formatText];
        _sideItemList lnbSetPicture[[_rowIndex, 0], _picture];
        _sideItemList lnbSetValue[[_rowIndex, 1], round _price];
        _sideItemList lnbSetData[[_rowIndex, 0], _class];
                    if (_shopType in ["rebelwep", "turf"]) then {if !(AP_ndShop) then {if (AP_cash >= _price) then {_color set[3, 1]};
                } else {if ([_ndRow] call AP_fnc_ndAfford) then {_color set[3, 1]};};};
            if (((AP_cash >= _price) || (AP_atmcash >= _price)) && !(_shopType in ["rebelwep", "turf"])) then {
                _color set[3, 1]};
        _sideItemList lnbSetColor[[_rowIndex, 0], _color];
        _sideItemList lnbSetColor[[_rowIndex, 1], [0.361, 0.722, 0.467, _color select 3]];};}
forEach _addons;
[_sideItemList, 0, false, false, controlNull, false] call AP_fnc_listNBoxSort;
_sideItemList ctrlSetFade 0.00;
_sideItemList ctrlCommit 0.00;
private _headerButtons = (allControls(ctrlParent _sideListGroup)) select {
    ((ctrlClassName _x) isEqualTo "AP_RscListNBoxHeaderButton") && ((ctrlParentControlsGroup _x) isEqualTo _sideListGroup)}; {
    _x ctrlEnable((lbSize _sideItemList) >= 1)}
forEach _headerButtons;
if ((_control isEqualTo _mainItemList) && !(_selectedIndex isEqualTo - 1)) then {
    _mainItemListButton ctrlEnable(((_mainItemList lnbColor[_selectedIndex, 0]) select 3) isEqualTo 1)};
if ((_control isEqualTo _mainItemList) && (_selectedIndex isEqualTo - 1)) then {_mainItemListButton ctrlEnable false};