if !(params[["_obj", objNull, [objNull]], ["_itemShortName", "", [""]], ["_itemValue", -1, [0]]]) exitWith {closeDialog 0};
private _items = AP_pickMenuItems;
private _itemLongName = ["getName", _itemShortName] call AP_fnc_virtItemCfg;
private _illegalItems = ["getIllegalItems"] call AP_fnc_virtItemCfg;
private _illegalItem = _illegalItems findIf {(_x select 0) isEqualTo _itemShortName}
isNotEqualTo - 1;
private _itemList = (findDisplay 1520) displayCtrl 1521;
if (_itemShortName isEqualTo "bank_money" && AP_effSide isEqualTo civilian) then {
    AP_dirtyMoneyTime = time;   // Dirty Money: 5-min launder clock starts at pickup (fn_useItem)
    [[getPlayerUID player, "AP_banktrace", time], "APS_fnc_varPersist", 2] spawn AP_fnc_MP;};
if (AP_effSide isEqualTo independent && {_itemShortName in _illegalItems}) exitWith {closeDialog 0;
    ["Medics are unable to pick up illegal items while on duty!", "basic"] spawn AP_fnc_handleMessage;};
private _lockedGold = false;
if (_itemShortName in ["goldbar"] && {
    (player distance(getMarkerPos "fed_reserve") <= 180) && !(nearestObjects[player, ["Land_Dome_Big_F", "Land_Dome_Small_F"], 30] isEqualTo[])
}) then {private _vault = (nearestObjects[player, ["Land_Dome_Big_F", "Land_Dome_Small_F"], 30]) param[0, objNull];
    private _safe = (nearestObjects[player, ["Land_Research_house_V1_F", "Land_Research_HQ_F"], 10]) param[0, objNull];
    _lockedGold = (_vault getVariable["AP_vaultlocked", 1] isEqualTo 1) || (_safe getVariable["AP_vaultlocked", 1] isEqualTo 1);};
if (_lockedGold) exitWith {closeDialog 0;
    [format["You cannot pick up %1(s) from a locked safe!", ["getName", _itemShortName] call AP_fnc_virtItemCfg], "basic"] spawn AP_fnc_handleMessage;
    [
        ["-EXPLOITITEMPICKUP-", player, (profileName), format["tried to pick up a %1 from a locked safe at POS: %2", ["getName", _itemShortName] call AP_fnc_virtItemCfg, getPosATL player]], "APS_fnc_logIt", 2, false, false] spawn AP_fnc_MP;
};
private _lockedTreasure = false;
if ((_itemShortName isEqualTo "treasure") && ((typeOf _obj) isEqualTo "Box_Syndicate_WpsLaunch_F")) then {
    if !([false, "treasuremap", 1] call AP_fnc_handleInv) then {_lockedTreasure = true;};};
if (_lockedTreasure) exitWith {closeDialog 0;
    ["You cannot pick up treasure without the map!", "basic"] spawn AP_fnc_handleMessage; [
        ["-EXPLOITITEMPICKUP-", player, (profileName), format["tried to loot a treasure chest with no map at POS: %3", getPosATL player]], "APS_fnc_logIt", 2, false, false] spawn AP_fnc_MP;
};
private _deleteItem = {private _lbIndex = -1;
    for "_i"
    from 0 to(lbSize _itemList - 1) do {(parseSimpleArray(_itemList lbData _i)) params[["_shortName", "", [""]], ["_itemAmount", -1, [0]]];
        if (_itemShortName isEqualTo _shortName) then {_lbIndex = _i};}; _items deleteAt(_items findIf {
        (_x select 0) isEqualTo _itemShortName});
    _itemList lbDelete _lbIndex;};
if (AP_effSide isEqualTo west && _illegalItem) exitWith {private _nearVehicles = nearestObjects[player, ["Car", "Air", "Ship"], 30];
    private _copVehicle = _nearVehicles param[_nearVehicles findIf {_x getVariable["AP_side", ""] isEqualTo "cop"}, objNull];
    if (isNull _copVehicle) exitWith {["There aren't any nearby police vehicles to seize this into!", "basic"] spawn AP_fnc_handleMessage
    };
    call _deleteItem;
    if (_items isEqualTo[]) then {deleteVehicle _obj;
        closeDialog 0;};
    private _adjustedArray = [_copVehicle getVariable "AP_vinv", _itemShortName, _itemValue] call AP_fnc_adjustInventoryArray;
    _copVehicle setVariable["AP_vinv", _adjustedArray, true];
    titleText["This item has been seized into the nearest police vehicle. The item(s) can be placed into evidence from any Police HQ.", "PLAIN"];
};
if (_itemShortName isEqualTo "money") exitWith {player playMoveNow "AinvPknlMstpSlayWrflDnon";
    titleText[format["You have picked up $%1", [_itemValue] call AP_fnc_numberText], "PLAIN"];
    call _deleteItem;
    if (_items isEqualTo[]) then {deleteVehicle _obj;
        closeDialog 0;};
    AP_cash = AP_cash + _itemValue;
    AP_cashCacheB = ((AP_cash / 4) + 9);
    if (_itemValue >= 80000) then {[
            ["-CASHPICKUP2-", player, (profileName), format["picked up $%1 at POS: %2", [_itemValue] call AP_fnc_numberText, getPosATL player]], "APS_fnc_logIt", 2, false, false] spawn AP_fnc_MP;
    } else {[
            ["-CASHPICKUP-", player, (profileName), format["picked up $%1 at POS: %2", [_itemValue] call AP_fnc_numberText, getPosATL player]], "APS_fnc_logIt", 2, false, false] spawn AP_fnc_MP;
    };
    ["moneypickedup", _itemValue] call AP_fnc_statArrUpdate;};
private _diff = [_itemShortName, _itemValue, AP_carryWeight, AP_maxWeight] call AP_fnc_calWeightDiff;
if (_diff <= 0) exitWith {["Your inventory space is full.", "basic"] spawn AP_fnc_handleMessage};
if !(_diff isEqualTo _itemValue) then {if !([true, _itemShortName, _diff] call AP_fnc_handleInv) exitWith {};
    private _fnc_updateLB = {private _items = AP_pickMenuItems;
        if (isNull _obj) exitWith {};
        lbClear _itemList; {_x params["_itemShortName", "_itemAmount"];
            private _text =
            if (_itemShortName isEqualTo "money") then {format["$%1 Cash", [_itemAmount] call AP_fnc_numberText];} else {
                format["%1x %2", _itemAmount, ["getName", _itemShortName] call AP_fnc_virtItemCfg];};
            private _index = _itemList lbAdd _text;
            _itemList lbSetPicture[_index, ["getIcon", _itemShortName] call AP_fnc_virtItemCfg];
            _itemList lbSetData[_index, format["['%1', %2]", _itemShortName, _itemAmount]];}
        forEach _items;};
    private _index = _items findIf {(_x select 0) isEqualTo _itemShortName};
    _items set[_index, [_itemShortName, _itemValue - _diff]];
    player playMoveNow "AinvPknlMstpSlayWrflDnon";
    titleText[format["You have picked up %1 %2", _diff, _itemLongName], "PLAIN"];
    call _fnc_updateLB;} else {if ([true, _itemShortName, _itemValue] call AP_fnc_handleInv) then {
        player playMoveNow "AinvPknlMstpSlayWrflDnon";
        titleText[format["You have picked up %1 %2", _itemValue, _itemLongName], "PLAIN"];
        call _deleteItem;};};
if (_items isEqualTo[] && !(_obj getVariable["AP_questloot", false])) then {deleteVehicle _obj;
    closeDialog 0};
[] call AP_fnc_calWeight; [
    ["-ITEMPICKUP-", player, (profileName), format["picked up %1 out of %2 %3 at POS: %4", [_diff] call AP_fnc_numberText, [_itemValue] call AP_fnc_numberText, _itemLongName, getPosATL player]], "APS_fnc_logIt", 2, false, false] spawn AP_fnc_MP;