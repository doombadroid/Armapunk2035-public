params["_target", "_caller", "_actionID", ["_parameters", "", ["", []]]];
private _shopType =
if !(_parameters isEqualType[]) then {_parameters} else {_parameters select 0};
private _ndShop =
if !(_parameters isEqualType[]) then {false} else {_parameters select 1};
if (_shopType isEqualTo "") exitWith {};
if (isNull _target) exitWith {[[player, [61, _shopType]], "APS_fnc_dongClient", 2] call AP_fnc_MP;};
if (_target isEqualTo _caller) exitWith {[[player, [62, _shopType]], "APS_fnc_dongClient", 2] call AP_fnc_MP;};
if (player getVariable["AP_restrained", false]) exitWith {};
if (player getVariable["AP_surrendered", false]) exitWith {};
if (AP_passiveModeJIP) exitWith {
    ["You cannot buy a gun while in passive mode! You can disable it on your phone (Y).", "basic"] spawn AP_fnc_handleMessage;};
// ui branch: ALL weapon shops run on the NIGHT CITY dialog (core\shops\fn_ncShop.sqf) -- rebel, gun
// store, turf, hunting, bounty/skiptracer, MaxSec/MaxTac/SRT armories, TT equipment. Guards above still
// apply; licence/side gates live inside weaponShopCfg, which ncShop calls too. The stock two-listbox
// path below is kept as dead fallback.
// owner 2026-08-13: the HTML ARMORY replaces the NIGHT CITY dialog. Placed
// HERE, after the addAction params are unpacked and every guard has run -- the
// first version read _this param 0, which from an NPC action is the NPC OBJECT,
// and the object poisoned every catalogue call downstream. AP_webShops false
// falls through to ncShop unchanged.
if (missionNamespace getVariable ["AP_webShops", true]) exitWith {
    uiNamespace setVariable ["AP_armoryShop", _shopType];
    uiNamespace setVariable ["AP_armoryND", _ndShop];
    [] spawn { if (dialog) then { closeDialog 0; uiSleep 0.12; }; createDialog "AP_web_armory"; };
};
if (true) exitWith {["open", _shopType, _ndShop] call AP_fnc_ncShop;};
private _shopType =
_shopType;
["AP_weapon_shop"] call AP_fnc_createDialog;
private _plb_display = findDisplay 39400;
if (isNull _plb_display) exitWith {};
if (_ndShop) then {AP_ndShop = true;};
private _preNd = AP_nd;
if !(_ndShop) then {if (_shopType == "rebelwep") then {
        // owner 2026-06-16 (#272): this used `exitWith {}` when the arms cartel flag is NEUTRAL (flagGangID 0),
        // but exitWith here exits the WHOLE shop function -- AFTER createDialog already opened the window and
        // BEFORE it's populated/held. Result: the rebel weapon shop "opened then closed" any time no gang owned
        // the arms cartel (the normal state). Now we just skip the cartel-owner bonus and keep the shop running.
        AP_armsCartel = [false, 0, -1];
        private _pointData = arms_flag getVariable["AP_capData", [0, "Neutral", -1]];
        _pointData params["_flagGangID", "", "_progress"];
        if !(_flagGangID isEqualTo 0) then {AP_armsCartel set[2, _flagGangID];
            if ((count AP_gang_data) > 0) then {if ((_flagGangID isEqualTo(AP_gang_data select 0)) && (_progress >= 0)) then {
                    AP_armsCartel set[0, true];};};};};};
private _title = _plb_display displayCtrl 39401;
private _filterList = _plb_display displayCtrl 39402;
private _mainListGroup = _plb_display displayCtrl 39404;
private _mainItemList = _mainListGroup controlsGroupCtrl 1000;
private _mainItemListButton = _mainListGroup controlsGroupCtrl 1001;
private _mainItemListBackground = _mainListGroup controlsGroupCtrl 1003;
private _sideListGroup = _plb_display displayCtrl 39405;
private _sideItemList = _sideListGroup controlsGroupCtrl 1000;
private _sideItemListButton = _sideListGroup controlsGroupCtrl 1001;
private _sideItemListBackground = _sideListGroup controlsGroupCtrl 1003;
private _titleText = ([_shopType] call AP_fnc_weaponShopCfg) select 0;
if (_ndShop) then {_titleText = _titleText + (format[" - %1 ND", [AP_ndStr] call AP_fnc_ndText])};
_title ctrlSetText _titleText; {_x lnbAddColumn 0.70}
forEach[_mainItemList, _sideItemList]; {_x params[["_title", ""], ["_type", ""]];
    private _allItems = ([_shopType] call AP_fnc_weaponShopCfg) select 1;
    private _listItems = _allItems select {(toLower _type) isEqualTo(toLower(([_x select 0] call BIS_fnc_itemType) select 0))};
    if ((count _listItems) >= 1) then {private _index = _filterList lbAdd _title;
        _filterList lbSetData[_index, _type];};}
forEach[["Weapons", "weapon"], ["Throwables", "magazine"], ["Items", "item"]];
if ((lbSize _filterList) <= 1) then {_filterList ctrlShow false;
    private _filterListPosition = ctrlPosition _filterList;
    private _controls = ((allControls _plb_display) select {
        ((ctrlParentControlsGroup _x) isEqualTo _mainListGroup) && !((ctrlIDC _x) in [1000, 1002, 1003])});
    _mainListGroup ctrlSetPosition[_filterListPosition select 0, _filterListPosition select 1]; {
        _x ctrlSetPosition[(ctrlPosition _x) select 0, ((ctrlPosition _x) select 1) + (_filterListPosition select 3) + 0.0055]}
    forEach _controls; {
        _x ctrlSetPosition[(ctrlPosition _x) select 0, (ctrlPosition _x) select 1, (ctrlPosition _x) select 2, ((ctrlPosition _x) select 3) + (_filterListPosition select 3) + 0.0055]
    }
    forEach[_mainItemList, _mainItemListBackground]; {_x ctrlCommit 0}
    forEach(allControls _plb_display);};
private _headerInfo = [["Name", false], ["Price", true]]; {private _itemListGroup = _x;
    private _itemList = _x controlsGroupCtrl 1000;
    private _itemListWidth = (ctrlPosition _itemList) select 2;
    private _columnPositions = lnbGetColumnsPosition _itemList; {private _currentColumnPosition = _x * _itemListWidth;
        (_headerInfo select _forEachIndex) params[["_headerText", ""], ["_sortByValue", false]];
        private _nextColumnPosition =
        if !(_forEachIndex isEqualTo((count _columnPositions) - 1)) then {_columnPositions select(_forEachIndex + 1)} else {1};
        _nextColumnPosition = _nextColumnPosition * _itemListWidth;
        private _control = _plb_display ctrlCreate["AP_RscListNBoxHeaderButton", 1002, _itemListGroup];
        _control ctrlSetPosition[_currentColumnPosition, 0, (_nextColumnPosition - _currentColumnPosition) + 0.0002, 0.05];
        _control ctrlSetStructuredText parseText format["<t size='0.8'>%1</t><t align='right' size='0.6'><img image='%2'/></t>", _headerText, "icons\arrows.paa"];
        _control ctrlCommit 0;
        _control ctrlAddEventHandler["ButtonClick", format["[%1, %2, %3, false, _this select 0] call AP_fnc_listNBoxSort;", format["((findDisplay 39400) displayCtrl %1) controlsGroupCtrl 1000", ctrlIDC _itemListGroup], _forEachIndex, _sortByValue]];
        if (_forEachIndex isEqualTo 0) then {[_itemList, _forEachIndex, _sortByValue, false, _control] call AP_fnc_listNBoxSort};}
    forEach _columnPositions;}
forEach[_mainListGroup, _sideListGroup]; {_x ctrlEnable false}
forEach[_mainItemListButton, _sideItemListButton];
_mainItemList ctrlAddEventHandler["LBSelChanged", format["['%1', _this] call AP_fnc_weaponShopSelection;", _shopType]];
_sideItemList ctrlAddEventHandler["LBSelChanged", format["['%1', _this] call AP_fnc_weaponShopSelection;", _shopType]];
_filterList ctrlAddEventHandler["LBSelChanged", format["['%1', _this] call AP_fnc_weaponShopFilter;", _shopType]]; {
    _x ctrlAddEventHandler["ButtonClick", format["['%1', _this select 0] spawn AP_fnc_weaponShopBuy;", _shopType]]}
forEach[_mainItemListButton, _sideItemListButton];
_filterList lbSetCurSel 0;
private _allControls = allControls _plb_display;
if ((lbSize _filterList) <= 1) then {_allControls = _allControls - [_filterList]}; {waitUntil {ctrlCommitted _x};
    _x ctrlSetFade 0;
    _x ctrlCommit 0.05}
forEach _allControls;
ctrlSetFocus _mainItemList;
waitUntil {isNull(findDisplay 39400)};
AP_ndShop = false;
[false] call AP_fnc_saveGear;
if (AP_lastSynced_gear != str(AP_gear)) then {[3] call AP_fnc_ClupdatePartial;
    [6] call AP_fnc_ClupdatePartial;};
if !(_ndShop) then {if (!((AP_armsCartel select 2) isEqualTo - 1) && !((AP_armsCartel select 1) isEqualTo 0)) then {[
            [0, 0, AP_armsCartel select 1], "APS_fnc_cartelSRV", false, false] spawn AP_fnc_MP;
        AP_armsCartel = [false, 0, -1];};};
if (AP_purchasedGear isEqualTo[]) exitWith {};
private _gear = "";
private _totalPrice = 0;
private _armsTax = 0; {_x params["_item", "_amount", "_tax", "_itemName", "_price"];
    _gear = _gear + format["%1 - %2<br/>", _amount, _itemName];
    _totalPrice = _totalPrice + _price;
    _armsTax = _armsTax + _tax;}
forEach AP_purchasedGear;
private _extra =
switch ((AP_purchasedGear param[0, []]) param[5, "Woops"]) do {case ("Arms"): {
            format[", with <t color='#7FFF00'>$%1</t> going to the %2", [_armsTax] call AP_fnc_numberText, "Arms Dealer"]}; case ("Tax"):
            {format[", including a tax of <t color='#7FFF00'>$%1</t>", [_armsTax] call AP_fnc_numberText]};
        default {""};}; if (_ndShop) then {_armsTax = 0;};
private _extra =
if !(_armsTax isEqualTo 0) then {_extra} else {""};
private _formatText =
if !(_ndShop) then {
    format["<t align='center'>You bought:<br/>%1for <t color='#7FFF00'>$%2</t>%3", _gear, [_totalPrice] call AP_fnc_numberText, _extra];
} else {
    format["<t align='center'>You bought:<br/>%1for <t color='#7FFF00'>%2 ND</t>%3", _gear, [[_totalPrice] call AP_fnc_ndFromLegacy] call AP_fnc_ndText, _extra]
};
private _rebelOutposts = ["Rebelop_1", "Rebelop_2", "Rebelop_3", "Rebelop_4", "Rebelop_5", "Rebelop_6"];
if !(({player distance(getMarkerPos _x) <= 200}
count _rebelOutposts) isEqualTo 0) then {["moneyspentrebel", _totalPrice] call AP_fnc_statArrUpdate;};
[_formatText, "weppurchase"] spawn AP_fnc_handleMessage;
AP_purchasedGear = [];