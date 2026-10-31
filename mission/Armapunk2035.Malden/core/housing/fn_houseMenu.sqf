disableSerialization;
params[["_house", objNull, [objNull]]];
if (isNull _house) exitWith {closeDialog 0};
if !(SRV_HousesSetup) exitWith {["Please wait a bit while houses are being initalized...", "basic"] spawn AP_fnc_handleMessage;
    closeDialog 0};
if (AP_action_in_use) exitWith {closeDialog 0;};
if !(alive _house) exitWith {closeDialog 0;};
if !((typeOf _house) in AP_houseTypes) exitWith {closeDialog 0};
if !(AP_effSide isEqualTo civilian) exitWith {closeDialog 0};
private _isOwner = (getPlayerUID player) isEqualTo(_house getVariable["AP_homeOwner", ""]);
private _hasKeys = ([_house, getPlayerUID player, "accessHouse"] call AP_fnc_keyHolderStatus);
if (!_isOwner && !_hasKeys) exitWith {closeDialog 0;
    if !(license_civ_home) exitWith {["You don't have a home owners license.", "basic"] spawn AP_fnc_handleMessage;};
    if !(AP_effSide isEqualTo civilian) exitWith {};
    if (_house getVariable["AP_restricted_house", false]) exitWith {
        ["This house cannot be purchased.", "basic"] spawn AP_fnc_handleMessage;};
    [_house] spawn AP_fnc_buyHouse;};
// DECK ROUTE (UI overhaul 2026-08-26): the dashboard opens as a deck app. The
// buy-house branch above is untouched -- a stranger at the door still gets the
// purchase flow, not a phone. Native dialog 2100 is the AP_deckApps=false
// fallback.
if (missionNamespace getVariable ["AP_deckApps", true]) exitWith {
    AP_pInact_curTarget = _house;
    ["House", _house] call AP_fnc_deckOpenApp;
};
["houseMenu"] call AP_fnc_createDialog;
private _display = findDisplay 2100;
private _title = _display displayCtrl 2101;
private _houseInfo = _display displayCtrl 2102;
private _closeButton = _display displayCtrl 2103;
private _lightsColor = _display displayCtrl 2104;
private _lightsButton = _display displayCtrl 2105;
private _viewStorage = _display displayCtrl 2106;
private _storageLock = _display displayCtrl 2107;
private _upgradeVirtual = _display displayCtrl 2108;
private _upgradePhysical = _display displayCtrl 2109;
private _manageKeys = _display displayCtrl 2110;
private _viewKeyholders = _display displayCtrl 2111;
private _sellMarket = _display displayCtrl 2112;
private _listSale = _display displayCtrl 2113;
private _agingBarrel = _display displayCtrl 2114;
private _temp1 = _display displayCtrl 2115;
private _temp2 = _display displayCtrl 2116;
private _temp3 = _display displayCtrl 2117;
private _temp4 = _display displayCtrl 2118;
private _temp5 = _display displayCtrl 2119;
AP_pInact_curTarget = _house;
private _houseID = _house getVariable["AP_houseID", -1];
private _virtualCap = _house getVariable["AP_vcap", 100];
private _physicalCap = _house getVariable["AP_phys_cap", 100];
private _keyCapCount = _house getVariable["AP_keycap", 0];
private _mainButtons = [_lightsButton, _viewStorage, _storageLock, _upgradeVirtual, _upgradePhysical, _manageKeys, _viewKeyholders, _sellMarket, _listSale, _agingBarrel, _temp1, _temp2, _temp3, _temp4, _temp5]; {
    if (ctrlText _x isEqualTo "") then {_x ctrlShow false};
    if !(_isOwner) then {_x ctrlEnable false};}
forEach _mainButtons;
([typeOf _house] call AP_fnc_houseConfig) params["_houseCost", "_sellPrice", "_physicalCaps", "_virtualCaps"];
private _maxedPhysicalUpgrades = _physicalCap isEqualTo((_physicalCaps select(count _physicalCaps - 1)) select 0);
private _maxedVirtualUpgrades = _virtualCap isEqualTo((_virtualCaps select(count _virtualCaps - 1)) select 0);
// helipad sheds measure reach flat (distance2D) so standing on the raised deck still counts --
// same 10m footprint as every other house, the deck height just stops eating the budget.
// HOMESTEADER -- Open House (214): reach extended to 25m (load the truck from the driveway).
private _reachM = if (214 in AP_side_talents) then { 25 } else { 10 };
private _inReach = if (_house getVariable["AP_helipad", false]) then {(player distance2D _house) < _reachM} else {
    (player distance _house) < _reachM};
private _canAccessInventory = (_house isKindOf "House_F" && _inReach) && {
    _house in AP_vehicles || (AP_effSide isEqualTo civilian && (getPlayerUID player in (_house getVariable["AP_house_keys", []])))};
private _canAccessInventoryAsAdmin = (_house isKindOf "House_F" && _inReach) && {
    (call AP_adminLevel >= 3) && (AP_effSide isEqualTo civilian) && !(_house in AP_vehicles) && !(getPlayerUID player in (_house getVariable["AP_house_keys", []])) && !(_houseID isEqualTo -1)
};
private _isGarage = (typeOf _house) in ["Land_i_Garage_V1_F", "Land_i_Garage_V2_F", "Land_i_Garage_V1_dam_F", "Land_i_Garage_V2_dam_F"]; {
    _x params["_button", "_condition", "_trueText", "_falseText", "_action", ["_enable", true, [true]]];
    if (isNull _button) then {_button = _mainButtons param[_mainButtons findIf {!ctrlShown _x}, controlNull]};
    if (call _condition) then {_button ctrlEnable _enable};
    if (call _condition && !(ctrlShown _button)) then {_button ctrlShow true};
    private _text =
    if (call _condition) then {_trueText} else {[_falseText, ctrlText _button] select(_falseText isEqualTo "")};
    _button ctrlSetText _text;
    _button buttonSetAction _action;}
forEach[[_storageLock, {_house getVariable["AP_buildingLocked", false]
}, "Unlock All doors", "Lock All doors", "[AP_pInact_curTarget] call AP_fnc_lockHouse; closeDialog 0;"], [_upgradePhysical, {
    _maxedPhysicalUpgrades
}, "Fully Upgraded", "", "[AP_pInact_curTarget, 'pstorage'] spawn AP_fnc_upgradeProperty; closeDialog 0;", false], [_upgradeVirtual, {
    _maxedVirtualUpgrades
}, "Fully Upgraded", "", "[AP_pInact_curTarget, 'vstorage'] spawn AP_fnc_upgradeProperty; closeDialog 0;", false], [_viewKeyholders, {
    true}, "View Key Holders", "", "[] call AP_fnc_listKeyHolders;"], [_manageKeys, {true
}, "Manage Keys", "", "['propertyKeys'] call AP_fnc_createDialog;"], [_temp1, {true
}, "Homegoods Store", "", "closeDialog 0; [player, player, -1, ""homegoods""] spawn AP_fnc_virtualShopMenu;"], [_viewStorage, {
    _canAccessInventory || _canAccessInventoryAsAdmin
}, "View Storage", "", ["closeDialog 0; [AP_pInact_curTarget, false] spawn AP_fnc_storageOpen;", "closeDialog 0; [AP_pInact_curTarget, true] spawn AP_fnc_storageOpen;"] select _canAccessInventoryAsAdmin], [_listSale, {
    _house getVariable["AP_house_price", -1] isEqualTo - 1
}, "List for Sale", "Remove Listing", "closeDialog 0; [AP_pInact_curTarget] spawn AP_fnc_marketSellHouse;"], [_sellMarket, {true
}, "Sell to Bank", "", "closeDialog 0; [AP_pInact_curTarget] spawn AP_fnc_sellHouse;"], [_lightsButton, {
    isNull(_house getVariable["AP_lightSource", objNull])}, "Turn Lights On", "Turn Lights Off", ""], [controlNull, {
    _house getVariable["AP_barrel_unaged", false] && !(_isGarage)
}, "Barrel Installed", "Add Aging Barrel", "[AP_pInact_curTarget,'aging'] spawn AP_fnc_upgradeProperty; closeDialog 0;", false], [controlNull, {
    !(_house getVariable["AP_barrel_unaged", false]) && !(_isGarage)
}, "Add Aging Barrel", "Fully Upgraded", "[AP_pInact_curTarget,'aging'] spawn AP_fnc_upgradeProperty; closeDialog 0;"], [controlNull, {
    _house getVariable["AP_greenhouse_unaged", false] && !(_isGarage)
}, "Greenhouse Installed", "Add Greenhouse", "[AP_pInact_curTarget,'greenhouse'] spawn AP_fnc_upgradeProperty; closeDialog 0;", false], [controlNull, {
    !(_house getVariable["AP_greenhouse_unaged", false]) && !(_isGarage)
}, "Add Greenhouse", "Fully Upgraded", "[AP_pInact_curTarget,'greenhouse'] spawn AP_fnc_upgradeProperty; closeDialog 0;"], [controlNull, {
    _house getVariable["AP_leadcontainer_unaged", false] && !(_isGarage)
}, "Lead Container Installed", "Add Lead Container", "[AP_pInact_curTarget,'leadcontainer'] spawn AP_fnc_upgradeProperty; closeDialog 0;", false], [controlNull, {
    !(_house getVariable["AP_leadcontainer_unaged", false]) && !(_isGarage)
}, "Add Lead Container", "Lead Container Installed", "[AP_pInact_curTarget,'leadcontainer'] spawn AP_fnc_upgradeProperty; closeDialog 0;"], [controlNull, {
    (AP_gang_data param[2, 0] isEqualTo 1) && (AP_gang_data param[3, [0, 0, 0]] isEqualTo[0, 0, 0])
}, "Set Gang House", "", "closeDialog 0; [AP_pInact_curTarget] spawn AP_fnc_setGangHouse;"], [controlNull, {_isGarage
}, "Access Garage", "", "['Car', AP_pInact_curTarget] call AP_fnc_handleVehicles;"], [controlNull, {_isGarage
}, "Store Vehicle", "", "closeDialog 0; [AP_pInact_curTarget, player] spawn AP_fnc_storeVehicle;"], [controlNull, {
    (AP_gang_data param[2, 0] isEqualTo 1) && (_house getVariable["AP_house_gang", -1] isEqualTo(AP_gang_data param[0, -5]))
}, "Remove Gang House", "", format["closeDialog 0; [] spawn{ if (['Are you sure you no longer want this house as your gang house?', 'Remove Gang House', 'Yes', 'No'] call BIS_fnc_guiMessage) then {[[AP_pInact_curTarget, %1], 'AP_fnc_removeGangHouse', [%1] call AP_fnc_getOnlineMembers] spawn AP_fnc_MP; [[AP_pInact_curTarget, %1], 'APS_fnc_removeGangHouseSRV', 2] spawn AP_fnc_MP}; };", AP_gang_data param[0, -1]]], [controlNull, {
    (AP_gang_data param[2, 0] isEqualTo 1) && _house getVariable["AP_house_gang", -1] != (AP_gangBuilding param[0, objNull] getVariable["AP_house_gang", -2]) && !(isNull(AP_gangBuilding select 0))
}, "Change Gang House", "", format["closeDialog 0; [] spawn{ if (['Are you sure you want to change your gang house to this house?', 'Change Gang House', 'Yes', 'No'] call BIS_fnc_guiMessage) then {[[AP_gangBuilding param [0, objNull], AP_pInact_curTarget], 'AP_fnc_changeGangHouse', [%1] call AP_fnc_getOnlineMembers] spawn AP_fnc_MP}; };", AP_gang_data param[0, -1]]]]; {
    if !(_isOwner) then {_x ctrlEnable false};}
forEach _mainButtons;
// owner 2026-07-10: RENAME field (2120) + button (2121). Owner-only; prefill with the current custom name.
// Click reads the field, hands it to AP_fnc_renameHouse (client-sanitize -> owner-gated server persist).
private _renameEdit = _display displayCtrl 2120;
private _renameButton = _display displayCtrl 2121;
// owner 2026-07-10: SHED HELIPAD upgrade button (2122). Sheds only, owner only, once.
private _heliBtn = _display displayCtrl 2122;
if ((typeOf _house isEqualTo "Land_i_Shed_Ind_F") && {(_house getVariable ["AP_homeOwner", ""]) isEqualTo (getPlayerUID player)} && {!(_house getVariable ["AP_helipad", false])}) then {
    _heliBtn ctrlShow true;
    // grid slot [0.5598,0.522] is ALSO poolable (a gang-house row can claim 2119 there) -- if that happened,
    // drop the helipad button below the rename block instead of overlapping.
    if (ctrlShown (_display displayCtrl 2119)) then {
        _heliBtn ctrlSetPosition [0.45875 * safezoneW + safezoneX, 0.6175 * safezoneH + safezoneY, 0.196 * safezoneW, 0.0249999 * safezoneH];
        _heliBtn ctrlCommit 0;};
    _heliBtn ctrlAddEventHandler ["ButtonClick", {[AP_pInact_curTarget] spawn AP_fnc_buyHelipad;}];} else {_heliBtn ctrlShow false;};
// owner 2026-07-11: MALDEN MAKEOVER skin picker (2123). Eligible types only (AP_fnc_maldenMap -- houses
// with real Argo variant models), owner only. Label shows the current look; the swap runs server-side.
private _maldenBtn = _display displayCtrl 2123;
if ((["eligible", typeOf _house] call AP_fnc_maldenMap) && {(_house getVariable ["AP_homeOwner", ""]) isEqualTo (getPlayerUID player)}) then {
    private _cur = ["colorOf", typeOf _house] call AP_fnc_maldenMap;
    _maldenBtn ctrlSetText (["Malden Makeover", format ["Malden Makeover: %1", _cur]] select (_cur isNotEqualTo ""));
    _maldenBtn ctrlShow true;
    _maldenBtn ctrlAddEventHandler ["ButtonClick", {["open", AP_pInact_curTarget] spawn AP_fnc_maldenPicker;}];} else {
    _maldenBtn ctrlShow false;};
if (_isOwner) then {_renameEdit ctrlSetText (_house getVariable ["AP_houseName", ""]);
    _renameButton ctrlAddEventHandler ["ButtonClick", {private _d = ctrlParent (_this select 0);
        private _nm = ctrlText (_d displayCtrl 2120);
        [AP_pInact_curTarget, _nm] spawn AP_fnc_renameHouse;
        closeDialog 0;}];} else {{ _x ctrlShow false; _x ctrlEnable false; } forEach [_renameEdit, _renameButton];};
if (_hasKeys) then {_viewStorage ctrlEnable true};
if (_isGarage) then {_lightsButton ctrlEnable false};
if (_hasKeys && _isGarage) then {{_x ctrlEnable true}
    forEach(_mainButtons select {ctrlText _x == "Access Garage" || ctrlText _x == "Store Vehicle"})}; {_x params["_color", "_rgb"];
    private _index = _lightsColor lbAdd _color;
    _lightsColor lbSetData[_index, str _rgb];}
forEach[["Regular", [250, 150, 50]], ["Red", [40, 0, 0]], ["Blue", [0, 0, 40]], ["Aqua", [0, 40, 40]], ["Green", [0, 40, 0]], ["Orange", [80, 40, 0]], ["Yellow", [80, 80, 0]], ["Pink", [40, 0, 40]]];
_lightsColor lbSetCurSel 0;
_lightsButton ctrlAddEventHandler["ButtonClick", {params["_control"];
    private _display = ctrlParent _control;
    private _list = _display displayCtrl 2104;
    private _rgb =
    if ((_list lbData(lbCurSel _list)) isEqualType[]) then {_list lbData(lbCurSel _list)} else {
        parseSimpleArray(_list lbData(lbCurSel _list))};
    [AP_pInact_curTarget, _rgb] call AP_fnc_lightHouseAction;
    closeDialog 0;}];
private _houseName = getText(configFile >> "CfgVehicles" >> typeOf _house >> "displayName");
private _agingInfo =
if (_isGarage) then {"Incompatible"} else {["Not Active", "Active"] select(_house getVariable["AP_barrel_unaged", false])};
private _greenhouseInfo =
if (_isGarage) then {"Incompatible"} else {["Not Active", "Active"] select(_house getVariable["AP_greenhouse_unaged", false])};
private _leadContainerInfo =
if (_isGarage) then {"Incompatible"} else {["Not Active", "Active"] select(_house getVariable["AP_leadcontainer_unaged", false])};
private _listPriceInfo =
if (_house getVariable["AP_house_price", -1] isEqualTo - 1) then {
    "No"} else {"$" + ([_house getVariable["AP_house_price", -1]] call AP_fnc_numberText)};
private _agingBarrelCost =
if (_house getVariable["AP_barrel_unaged", false]) then {20000} else {0};
private _greenhouseCost =
if (_house getVariable["AP_greenhouse_unaged", false]) then {20000} else {0};
private _leadContainerCost =
if (_house getVariable["AP_leadcontainer_unaged", false]) then {350000} else {0};
private _physicalStorageCost = 0;
private _virtualStorageCost = 0; {_x params["_storageCap", "_cost"];
    if (_physicalCap < _storageCap) exitWith {};
    _physicalStorageCost = _physicalStorageCost + _cost;}
forEach _physicalCaps; {_x params["_storageCap", "_cost"];
    if (_virtualCap < _storageCap) exitWith {};
    _virtualStorageCost = _virtualStorageCost + _cost;}
forEach _virtualCaps;
private _houseValue = "$" + ([_houseCost + _physicalStorageCost + _virtualStorageCost + _agingBarrelCost + _greenhouseCost + _leadContainerCost] call AP_fnc_numberText);
private _houseInfoText = parseText(format["<t size='0.85' align='center'>
	House:<br/>
	%1<br/>
	<br/>
	Storage Capacity:<br/>
	Virtual: %2<br/>
	Physical: %3<br/>
	<br/>
	Aging Barrel: %4 <br/>
	Greenhouse: %7 <br/>
	Lead Container: %8 <br/>
	Max Keys: %9<br/>
	<br/>
	Listed on Market: %5 <br/>
	<br/>
	House Value: %6<br/>
	</t>", _houseName, _virtualCap, _physicalCap, _agingInfo, _listPriceInfo, _houseValue, _greenhouseInfo, _leadContainerInfo, _keyCapCount]);
_title ctrlSetText format["House Management - %1", _houseID];
_houseInfo ctrlSetStructuredText _houseInfoText;