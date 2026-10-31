private _doubleClickItem = {params[["_control", controlNull], ["_selectedIndex", -1]];
    if (_selectedIndex isEqualTo - 1) exitWith {};
    if (isNull _control) exitWith {};
    private _plb_display = findDisplay 39500;
    if (isNull _plb_display) exitWith {};
    private _mainListGroup = _plb_display displayCtrl 39503;
    private _mainItemList = _mainListGroup controlsGroupCtrl 1000;
    private _mainItemListEdit = _mainListGroup controlsGroupCtrl 1004;
    private _mainItemListBackground = _mainListGroup controlsGroupCtrl 1003;
    if ((lbCurSel _mainItemList) isEqualTo - 1) exitWith {};
    private _selectedData = [_mainItemList lnbData[_selectedIndex, 0], _mainItemList lnbValue[_selectedIndex, 1], _mainItemList lnbValue[_selectedIndex, 2]];
    _selectedData params["_itemName", "_itemPrice", "_itemInvAmount"];
    private _currentQty = missionNamespace getVariable(format["AP_inv_%1", _itemName]);
    if !(_currentQty isEqualTo _itemInvAmount) exitWith {_mainItemListEdit ctrlSetText "1"};
    _mainItemListEdit ctrlSetText format["%1", _itemInvAmount];};
private _clickSelectedItem = {params[["_control", controlNull], ["_selectedIndex", -1], ["_shopType", ""]];
    if (_selectedIndex isEqualTo - 1) exitWith {};
    if (isNull _control) exitWith {};
    if (_shopType isEqualTo "") exitWith {};
    private _plb_display = findDisplay 39500;
    if (isNull _plb_display) exitWith {};
    private _mainListGroup = _plb_display displayCtrl 39503;
    private _mainItemList = _mainListGroup controlsGroupCtrl 1000;
    private _mainItemListBuyButton = _mainListGroup controlsGroupCtrl 1005;
    private _mainItemListSellButton = _mainListGroup controlsGroupCtrl 1006; {_x ctrlEnable false}
    forEach[_mainItemListBuyButton, _mainItemListSellButton];
    private _shopInfo = [_shopType] call AP_fnc_virt_shops;
    _shopInfo params[["_shopTitle", ""], ["_buyItems", []], ["_sellItems", []]];
    private _selectedData = [_mainItemList lnbData[_selectedIndex, 0], _mainItemList lnbValue[_selectedIndex, 1], _mainItemList lnbValue[_selectedIndex, 2]];
    _selectedData params["_itemName", "_itemPrice", "_itemInvAmount"];
    if ((_control isEqualTo _mainItemList) && !(_selectedIndex isEqualTo - 1)) then {if (_itemName in _buyItems) then {
            _mainItemListBuyButton ctrlEnable true;};
        if ((_itemName in _sellItems) && (_itemInvAmount >= 1)) then {_mainItemListSellButton ctrlEnable true;
            _mainItemListBuyButton ctrlEnable true;};
        if ((ctrlEnabled _mainItemListBuyButton) && !(_itemName in _buyItems)) then {_mainItemListBuyButton ctrlEnable false;};};};
params["_target", "_caller", "_actionID", ["_shopType", "", [""]]];
if (_shopType isEqualTo "") exitWith {};
if !((vehicle player) isEqualTo player) exitWith {
    ["This action cannot be performed from within a vehicle.", "basic"] spawn AP_fnc_handleMessage;};
if ((player distance _target) >= 10) exitWith {["You are too far away.", "basic"] spawn AP_fnc_handleMessage;};
// The machine's own body is not a wall (owner 2026-09-07: "it errors with buying through the wall"). A vending
// carrier (npcs\fn_vendShop.sqf) sits 5.6 cm in front of its cabinet, and from beside the machine the eye->carrier
// line clips the cabinet. lineIntersects can ignore only the player and the target, so take the hit list and
// subtract the carrier's cabinet; for an NPC the body IS the target and nothing changes.
private _wallHits = (lineIntersectsObjs [eyePos player, aimPos _target, player, _target, false]) - [_target getVariable ["AP_vendCabinet", objNull]];
if (_wallHits isNotEqualTo []) exitWith {
    ["It would be hard to buy things through the wall, don't you think?", "basic"] spawn AP_fnc_handleMessage;};
if (player getVariable["AP_restrained", false]) exitWith {};
if (player getVariable["AP_surrendered", false]) exitWith {};
// owner 2026-08-12: the web shop replaces this dialog. Hooked HERE rather than at
// the 51 call sites, because every one of them already funnels through this
// function with a shop type. An early exit leaves the whole native path below
// untouched, so flipping AP_webShop to false brings the old dialog straight back.
if (missionNamespace getVariable ["AP_webShop", true]) exitWith {
    [_shopType] spawn AP_fnc_shopOpen;
};

["AP_virtual_shop"] call AP_fnc_createDialog;
private _plb_display = findDisplay 39500;
if (isNull _plb_display) exitWith {};
// owner 2026-06-21 (#442): only ping cops ("informant spotted X at a drug dealer") if the subject is actually
// WANTED (>$500, the standard threshold used by fn_debitCard etc.). Was firing on EVERY drug-dealer access
// regardless of bounty -> cops spammed for every civ buying at the dealer.
if ((_shopType == "heroin") && ((time - AP_last_wanted) > 240) && (AP_effSide isEqualTo civilian) && ((A_stats_crimes param [0, 0]) > 500)) then {
    AP_last_wanted = time;
    if (23 in AP_infamy_talents && license_civ_rebel && (random 10) < 2) exitWith {};
    private _toSend = allPlayers select {_x distance player <= 4000 && side _x isEqualTo west};
    if !(_toSend isEqualTo[]) then {[
            [8, profileName, str(A_stats_crimes select 0), player], "AP_fnc_clientMessage", _toSend, false, false] spawn AP_fnc_MP;};};
if (_shopType == "wongs") then {
    // owner 2026-07-05: same exitWith footgun as #272 -- opened the Wong shop empty whenever the wong cartel
    // was neutral. Skip the owner-bonus instead of aborting the function.
    private _pointData = wongs_flag getVariable["AP_capData", [0, "Neutral", -1]];
    _pointData params["_flagGangID", "", "_progress"];
    AP_wongsCartel = [false, 0, -1];
    if !(_flagGangID isEqualTo 0) then {AP_wongsCartel set[2, _flagGangID];
        if ((_flagGangID isEqualTo(AP_gang_data param[0, -2])) && (_progress >= 0)) then {AP_wongsCartel set[0, true];};};};
if (_shopType == "rebel") then {
    // owner 2026-07-05: same exitWith footgun as #272 (fn_weaponShopMenu) -- exitWith here aborts the WHOLE
    // shop function after the dialog opened but before it's populated, so the rebel virtual shop opened empty
    // whenever the arms cartel was neutral (the normal state). Skip the owner-bonus instead of aborting.
    private _pointData = arms_flag getVariable["AP_capData", [0, "Neutral", -1]];
    _pointData params["_flagGangID", "", "_progress"];
    AP_armsCartel = [false, 0, -1];
    if !(_flagGangID isEqualTo 0) then {AP_armsCartel set[2, _flagGangID];
        if ((_flagGangID isEqualTo(AP_gang_data param[0, -2])) && (_progress >= 0)) then {AP_armsCartel set[0, true];};};};
private _inTurf = (player inArea "turf_area_rodo_flag" || player inArea "turf_area_panagia_flag" || player inArea "turf_area_zaros_flag");
if (_shopType isEqualTo "heroin" && _inTurf) then {
    // owner 2026-07-05: same exitWith footgun as #272 -- exitWith aborted the WHOLE shop function after the
    // dialog opened, so the heroin shop opened empty inside a turf zone whenever that turf flag was neutral.
    // Skip the turf-tax owner-bonus instead of aborting; also default the gang id so an empty AP_turf_data
    // can't leave _flagGangID nil (nil isEqualTo 0 would throw).
    private _nearestFlag = (nearestObjects[player, ["Flag_Red_F", "FlagPole_F"], 600] select 0);
    (_nearestFlag getVariable["AP_turf_data", []]) params[["_flagGangID", 0]];
    AP_turfTax = [false, 0, -1];
    if !(_flagGangID isEqualTo 0) then {AP_turfTax set[2, _flagGangID];
        if (_flagGangID isEqualTo(AP_gang_data param[0, -2])) then {AP_turfTax set[0, true];};};};
private _topTitle = _plb_display displayCtrl 39501;
private _subTitle = _plb_display displayCtrl 39502;
private _mainListGroup = _plb_display displayCtrl 39503;
private _mainItemList = _mainListGroup controlsGroupCtrl 1000;
private _mainItemListEdit = _mainListGroup controlsGroupCtrl 1004;
private _mainItemListBackground = _mainListGroup controlsGroupCtrl 1003;
private _mainItemListBuyButton = _mainListGroup controlsGroupCtrl 1005;
private _mainItemListSellButton = _mainListGroup controlsGroupCtrl 1006;
private _shopTitle = ([_shopType] call AP_fnc_virt_shops) select 0;
_topTitle ctrlSetText(format["%1", _shopTitle]);
_subTitle ctrlSetText(format["Shop Inventory - Weight: %2/%3", _shopTitle, AP_carryWeight, AP_maxWeight]); {_x lnbAddColumn 0.425;
    _x lnbAddColumn 0.7;}
forEach[_mainItemList]; {private _headerInfo = [["Name", false], ["Price", true], ["Inv Amount", false]];
    private _idx = _forEachIndex;
    private _itemListGroup = _x;
    private _itemList = _x controlsGroupCtrl 1000;
    private _itemListWidth = (ctrlPosition _itemList) select 2;
    private _columnPositions = lnbGetColumnsPosition _itemList; {private _currentColumnPosition = _x * _itemListWidth;
        (_headerInfo select _forEachIndex) params[["_headerText", ""], ["_sortByValue", false]];
        private _nextColumnPosition =
        if !(_forEachIndex isEqualTo((count _columnPositions) - 1)) then {_columnPositions select(_forEachIndex + 1)} else {1};
        _nextColumnPosition = _nextColumnPosition * _itemListWidth;
        private _control = _plb_display ctrlCreate["AP_RscListNBoxHeaderButton", 1002, _itemListGroup];
        _control ctrlSetPosition[_currentColumnPosition, 0, (_nextColumnPosition - _currentColumnPosition) + 0.0002, 0.05];
        private _arrows =
        if (_idx in [0, 1, 2]) then {"<img image='icons\arrows.paa'/></t>"} else {""};
        _control ctrlSetStructuredText parseText format["<t size='0.8'>%1</t><t align='right' size='0.6'>%2", _headerText, _arrows];
        _control ctrlCommit 0;
        if (_idx isEqualTo 0) then {
            _control ctrlAddEventHandler["ButtonClick", format["[%1, %2, %3, false, _this select 0] call AP_fnc_listNBoxSort;", format["((findDisplay 39500) displayCtrl %1) controlsGroupCtrl 1000", ctrlIDC _itemListGroup], _forEachIndex, _sortByValue]];
            if (_forEachIndex isEqualTo 0) then {[_itemList, _forEachIndex, _sortByValue, false, _control] call AP_fnc_listNBoxSort};};}
    forEach _columnPositions;}
forEach[_mainListGroup]; {_x ctrlEnable false;}
forEach[_mainItemListBuyButton, _mainItemListSellButton]; {_x ctrlSetText "1"}
forEach[_mainItemListEdit];
_mainItemListBuyButton ctrlAddEventHandler["ButtonClick", format["['%1', _this select 0, '%2'] spawn AP_fnc_virtualShopManage;", _shopType, "buyItem"]];
_mainItemListSellButton ctrlAddEventHandler["ButtonClick", format["['%1', _this select 0, '%2'] spawn AP_fnc_virtualShopManage;", _shopType, "sellItem"]];
_mainItemList ctrlSetEventHandler["LBSelChanged", format["[_this select 0, _this select 1, '%1'] call %2", _shopType, _clickSelectedItem]];
_mainItemList ctrlSetEventHandler["LBDblClick", format["_this call %1", _doubleClickItem]];
private _allControls = allControls _plb_display; {waitUntil {ctrlCommitted _x};
    _x ctrlSetFade 0;
    _x ctrlCommit 0.05;}
forEach _allControls;
ctrlSetFocus _mainItemList;
private _nearMedSupply = nearestObjects[player, ["C_IDAP_supplyCrate_F"], 6];
private _medCrate = _nearMedSupply param[_nearMedSupply findIf {_x getVariable["AP_medSupply", false]}, objNull];
if !(isNull _medCrate) then {[[_medCrate, 900], "APS_fnc_setCleanTime", 2] spawn AP_fnc_MP;};
[_shopType] call AP_fnc_virtualShopPopulate;
waitUntil {isNull(findDisplay 39500)};
[false] call AP_fnc_saveGear;
if (AP_lastSynced_gear != str(AP_gear)) then {[3] call AP_fnc_ClupdatePartial;};
if (_shopType == "wongs") then {if (!((AP_wongsCartel select 2) isEqualTo - 1) && !((AP_wongsCartel select 1) isEqualTo 0)) then {[
            [0, 3, AP_wongsCartel select 1], "APS_fnc_cartelSRV", false, false] spawn AP_fnc_MP;
        AP_wongsCartel = [false, 0, -1];};};
if (_shopType == "rebel") then {
    // owner 2026-07-05: was reading the DEAD AP_drugCartel/capIndex 1 (copy-paste from the drug block);
    // AP_drugCartel is never accumulated, so the rebel virtual shop's 8% arms cut was NEVER paid.
    // Swap to AP_armsCartel/capIndex 0 to mirror the working weapon/clothing/loadout flushes.
    if (!((AP_armsCartel select 2) isEqualTo - 1) && !((AP_armsCartel select 1) isEqualTo 0)) then {[
            [0, 0, AP_armsCartel select 1], "APS_fnc_cartelSRV", false, false] spawn AP_fnc_MP;
        AP_armsCartel = [false, 0, -1];};};
if (_shopType isEqualTo "heroin") then {if (!((AP_turfTax select 2) isEqualTo - 1) && !((AP_turfTax select 1) isEqualTo 0)) then {[
            [2, (AP_turfTax select 2), player, (AP_turfTax select 1)], "APS_fnc_gangBank", false, false] spawn AP_fnc_MP;
        AP_turfTax = [false, 0, -1];};};
if (_shopType in ["market", "gas", "turf", "redburger", "hospital", "oil", "fishmarket", "diamond", "salt", "cop", "commod", "home", "vig", "delivery", "meditemshop", "medicaldispensary"]) then {
    if (!((AP_govTax select 2) isEqualTo - 1) && !((AP_govTax select 1) isEqualTo 0)) then {
        ["payGovernor", [(AP_govTax param[1, 0])]] spawn AP_fnc_govSystem;
        AP_govTax set[1, 0];};};
if ((AP_purchasedVItems isNotEqualTo[]) || (AP_soldVItems isNotEqualTo[])) then {playSound "purchase";};
if (AP_purchasedVItems isNotEqualTo[]) then {private _boughtItems = "";
    private _totalPrice = 0;
    private _armsTax = 0; {_x params["_itemName", "_vAmount", "_tax", "_price"];
        _boughtItems = _boughtItems + format["%1 - %2<br/>", _vAmount, _itemName];
        _totalPrice = _totalPrice + _price;
        _armsTax = _armsTax + _tax;}
    forEach AP_purchasedVItems;
    private _extra =
    switch ((AP_purchasedVItems param[0, []]) param[4, "Woops"]) do {case ("Arms"): {
                format[", with <t color='#7FFF00'>$%1</t> going to the %2", [_armsTax] call AP_fnc_numberText, "Arms Dealer"]
            }; case ("Tax"): {format[", including a tax of <t color='#7FFF00'>$%1</t>", [_armsTax] call AP_fnc_numberText]};
            default {""};}; private _extra =
    if !(_armsTax isEqualTo 0) then {_extra} else {""};
    private _formatText = format["<t align='center'>You bought:<br/>%1for <t color='#7FFF00'>$%2</t>%3", _boughtItems, [_totalPrice] call AP_fnc_numberText, _extra];
    [_formatText, "weppurchase"] spawn AP_fnc_handleMessage;
    AP_purchasedVItems = [];};
if (AP_soldVItems isNotEqualTo[]) then {private _soldItems = "";
    private _totalPrice = 0;
    private _wongsTax = 0; {_x params["_itemName", "_vAmount", "_tax", "_price", "_cfgName"];
        _soldItems = _soldItems + format["%1 - %2<br/>", _vAmount, _itemName];
        _totalPrice = _totalPrice + _price;
        if !(toLower(_cfgName) in ["rum_0", "scotch_0", "scotch_3", "whiskeyc_0", "whiskeyr_0"]) then {_wongsTax = _wongsTax + _tax;};}
    forEach AP_soldVItems;
    private _ownerName = "";
    private _inTurf = (player inArea "turf_area_rodo_flag" || player inArea "turf_area_panagia_flag" || player inArea "turf_area_zaros_flag");
    if !(_wongsTax isEqualTo 0) then {if (_inTurf) then {
            private _nearestFlag = (nearestObjects[player, ["Flag_Red_F", "FlagPole_F"], 600] select 0);
            private _flagName = ["Rodopoli", "Zaros", "Panagia"] param[[rodo_flag, zaros_flag, panagia_flag] find _nearestFlag, "Capture Point"];
            _ownerName = format["the %1 Turf", _flagName];} else {_ownerName = "Wongs Triad";};};
    private _extra =
    if !(_wongsTax isEqualTo 0) then {
        format[", with <t color='#7FFF00'>$%1</t> going to the owner of %2", [_wongsTax] call AP_fnc_numberText, _ownerName]} else {""};
    private _formatText = format["<t align='center'>You sold:<br/>%1for <t color='#7FFF00'>$%2</t>%3", _soldItems, [_totalPrice] call AP_fnc_numberText, _extra];
    [_formatText, "weppurchase"] spawn AP_fnc_handleMessage;
    AP_soldVItems = [];};