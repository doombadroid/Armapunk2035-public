private _unit = cursorObject;
if (isNull _unit) exitWith {};
if !(_unit isKindOf "CAManBase") exitWith {};
if !(isNull objectParent player) exitWith {
    ["This action cannot be performed from within a vehicle.", "basic"] spawn AP_fnc_handleMessage;};
if ((player distance _unit) > 10) exitWith {["You are too far away.", "basic"] spawn AP_fnc_handleMessage;};
if (serverRestartLock) exitWith {
    ["You cannot access this menu right now. Try again after the restart!", "basic"] spawn AP_fnc_handleMessage;};
if (player getVariable["AP_restrained", false]) exitWith {};
if (player getVariable["AP_surrendered", false]) exitWith {};
disableSerialization;
// DECK ROUTE (UI overhaul 2026-08-26): Pay 'n' Spray opens as a deck app.
if (missionNamespace getVariable ["AP_deckApps", true]) exitWith {
    ["SkinShop"] call AP_fnc_deckOpenApp;
};
["AP_vehicle_skin_shop"] call AP_fnc_createDialog;
private _config = call AP_fnc_vehicleSkinShopCfg;
if (_config isEqualType "") exitWith {closeDialog 0;};
_config params["_shopTitle", "_itemArray"];
ctrlSetText[39401, _shopTitle];
private _itemList = ((findDisplay 39400) displayCtrl 39403);
private _buyBtn = ((findDisplay 39400) displayCtrl 39405);
lbClear _itemList;
private _itemInfo = "";
private _itemName = "";
private _index = 0;
private["_vehInfo"]; {_x params["_className", "_customName", "_skinCrateRewardID", "_price"];
    _vehInfo = [_className] call AP_fnc_fetchVehInfo;
    _itemName = _customName;
    _index = _itemList lbAdd _itemName;
    _itemList lbSetData[_index, str _skinCrateRewardID];
    _itemList lbSetPicture[(lbSize _itemList) - 1, (_vehInfo select 2)];
    _itemList lbSetValue[_index, _price];}
forEach _itemArray;
((findDisplay 39400) displayCtrl 39405) ctrlSetText "Buy";
_itemList ctrlSetEventHandler["LBSelChanged", format["[_this, '%1'] call AP_fnc_vehicleSkinShopSelection"]];
_buyBtn ctrlSetEventHandler["ButtonClick", format["[((findDisplay 39400) displayCtrl 39403), lbCurSel 39403, '%1'] call AP_fnc_vehicleSkinShopBuy"]];