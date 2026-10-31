disableSerialization;
if !(params[["_obj", objNull, [objNull]]]) exitWith {};
// owner 2026-08-13: the LOOT CARD replaces dialog 1520. Same guards, same
// reservation, web card -- AP_webShops false falls through to the native list.
if (missionNamespace getVariable ["AP_webShops", true]) exitWith { [_obj] spawn AP_fnc_lootOpen; };
if (AP_pickingUpItems) exitWith {["You are still in the process of picking up items!", "basic"] spawn AP_fnc_handleMessage};
if ((_obj getVariable["AP_ufoLoot", false]) && ((SRV_ufoCrash select 2) > serverTime - 900)) exitWith {closeDialog 0;
    [format["This radiated loot is unstable right now. Try in another %1 minutes. Check back frequently!", ceil((((SRV_ufoCrash select 2) + 900) - serverTime) / 60)], "basic"] spawn AP_fnc_handleMessage;
};
private _nearUnits = player nearEntities["CAManBase", 8] select {isPlayer _x && !(_x isEqualTo player)};
if !(isNull(_obj getVariable["AP_inUse", objNull])) exitWith {
    ["Someone is already accessing these items.", "basic"] spawn AP_fnc_handleMessage;
    closeDialog 0;};
if !(_nearUnits isEqualTo[]) then {uiSleep(random 1.5)};
if !(isNull(_obj getVariable["AP_inUse", objNull])) exitWith {
    ["Someone is already accessing these items.", "basic"] spawn AP_fnc_handleMessage;
    closeDialog 0;};
_obj setVariable["AP_inUse", player, true];
["AP_pickup_items"] call AP_fnc_createDialog;
private _display = findDisplay 1520;
private _itemList = _display displayCtrl 1521;
private _pickupButton = _display displayCtrl 1522;
_pickupButton ctrlEnable false;
lbClear _itemList;
AP_didServerRespond = false;
private _maxDelayTime = time + 5; [[player], "APS_fnc_lagCheck", 2] spawn AP_fnc_MP;
waitUntil {time > _maxDelayTime || AP_didServerRespond};
if (time > _maxDelayTime) exitWith {closeDialog 0;
    ["Menu failed, try again.", "basic"] spawn AP_fnc_handleMessage;
    if (_obj getVariable["AP_inUse", objNull] isEqualTo player) then {_obj setVariable["AP_inUse", nil, true]};};
_pickupButton ctrlEnable true;
private _items = _obj getVariable["AP_droppedItems", []];
AP_pickMenuItems = +_items; {_x params["_itemShortName", "_itemAmount"];
    private _text =
    if (_itemShortName isEqualTo "money") then {format["$%1 Cash", [_itemAmount] call AP_fnc_numberText];} else {
        format["%1x %2", _itemAmount, ["getName", _itemShortName] call AP_fnc_virtItemCfg];};
    private _index = _itemList lbAdd _text;
    _itemList lbSetData[_index, format["['%1', %2]", _itemShortName, _itemAmount]];
    _itemList lbSetPicture[_index, ["getIcon", _itemShortName] call AP_fnc_virtItemCfg];}
forEach AP_pickMenuItems;
waitUntil {isNull _display && !AP_pickingUpItems};
if !(isNull _obj) then {uiSleep 0.1;
    _obj setVariable["AP_inUse", nil, true];
    if (AP_pickMenuItems isNotEqualTo _items) then {_obj setVariable["AP_droppedItems", AP_pickMenuItems, true];};};