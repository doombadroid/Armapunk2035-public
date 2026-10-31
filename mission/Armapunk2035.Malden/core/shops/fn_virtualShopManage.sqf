#include "..\..\macro.h"
if (scriptAvailable(0.275)) exitWith {};
/*
    Re-plumbed 2026-08-12 for the web shop. Item and amount used to come only from
    dialog 39500's controls, so only that dialog could trade.

        [_shop, _ctrl, "buyItem"] call AP_fnc_virtualShopManage;              // native
        [_shop, controlNull, "buyItem", "apple", 3] call AP_fnc_virtualShopManage;  // web

    THE PRICE IS NEVER A PARAMETER. A direct caller supplies an item id and an
    amount; the cost is recomputed here through AP_fnc_virtShopPrice, exactly as
    the native path reads it off its own list. Accepting a price from the page
    would move the money boundary, and the whole point is that it does not move.

    Every guard below -- the spam limiter, weight, cash,
    the sell-side anti-arbitrage caps -- is untouched and runs for both callers.
*/
params[["_shopType", ""], ["_control", controlNull], ["_manageType", ""], ["_itemIn", "", [""]], ["_qtyIn", -1, [0]]];
private _direct = _itemIn isNotEqualTo "";
if (!_direct && {isNull _control}) exitWith {};
if (_shopType isEqualTo "") exitWith {};
if (!_direct && {!(ctrlEnabled _control)}) exitWith {};
private _plb_display = findDisplay 39500;
if (!_direct && {isNull _plb_display}) exitWith {};
private _topTitle = _plb_display displayCtrl 39501;
private _subTitle = _plb_display displayCtrl 39502;
private _mainListGroup = _plb_display displayCtrl 39503;
private _mainItemList = _mainListGroup controlsGroupCtrl 1000;
private _mainItemListEdit = _mainListGroup controlsGroupCtrl 1004;
private _mainItemListBackground = _mainListGroup controlsGroupCtrl 1003;
private _mainItemListBuyButton = _mainListGroup controlsGroupCtrl 1005;
private _mainItemListSellButton = _mainListGroup controlsGroupCtrl 1006;
private _mainItemListSelect = if (_direct) then { -1 } else { lbCurSel _mainItemList };
if (!_direct && {(_control isEqualTo _mainItemListBuyButton) && (_mainItemListSelect isEqualTo - 1)}) exitWith {
    ["You need to select an item to buy", "basic"] spawn AP_fnc_handleMessage;};
if (!_direct && {(_control isEqualTo _mainItemListSellButton) && (_mainItemListSelect isEqualTo - 1)}) exitWith {
    ["You need to select an item to sell", "basic"] spawn AP_fnc_handleMessage;};
private _item = ""; private _price = 0;
if (_direct) then {
    _item  = _itemIn;
    // recomputed, never supplied -- see the header
    _price = round ([_shopType, _item] call AP_fnc_virtShopPrice);
} else {
    private _selectedData = [_mainItemList lnbData[_mainItemListSelect, 0], _mainItemList lnbValue[_mainItemListSelect, 1], _mainItemList lnbValue[_mainItemListSelect, 2]];
    _selectedData params["_item", "_price"];
};
private _shopInfo = [_shopType] call AP_fnc_virt_shops;
_shopInfo params[["_shopTitle", ""], ["_buyItems", []], ["_sellItems", []]];
switch (_manageType) do {case ("buyItem"): {
            if !(_item in _buyItems) exitWith {["You can't buy this item!", "basic"] spawn AP_fnc_handleMessage;};
            private _amount = if (_direct) then { _qtyIn } else { parseNumber(ctrlText _mainItemListEdit) };
            if !([str _amount] call AP_fnc_isNumber) exitWith {["Invalid number.", "basic"] spawn AP_fnc_handleMessage;};
            if (_amount > 100) exitWith {["You cannot buy more than 100 at a time.", "basic"] spawn AP_fnc_handleMessage;};
            if (_amount <= 0) exitWith {["You need to buy at least one", "basic"] spawn AP_fnc_handleMessage;};
            
            private _diff = [_item, _amount, AP_carryWeight, AP_maxWeight] call AP_fnc_calWeightDiff;
            if (_diff <= 0) exitWith {["You don't have enough space for that amount!", "basic"] spawn AP_fnc_handleMessage;};
            private _amount = _diff;
            private _itemName = ["getName", _item] call AP_fnc_virtItemCfg;
            private _exit = false;
            _price = round(_price * _amount);
            if ([true, _item, _amount] call AP_fnc_handleInv) then {
                private _pointData = drug_flag getVariable["AP_capData", [0, "Neutral", 0.5]];
                _pointData params["_flagGangID", "_flagGangName", "_progress"];
                private _extra = "";
                private _govTaxedShops = ["market", "gas", "turf", "redburger", "hospital", "oil", "fishmarket", "diamond", "salt", "cop", "commod", "home", "vig", "delivery", "meditemshop", "medicaldispensary"];
                private _cut =
                switch (true) do {case ((_shopType == "rebel") && !(AP_armsCartel select 0) && ((call AP_adminLevel) <= 2)): {
                            floor(_price * 0.08)};
                    case (_shopType in _govTaxedShops): {floor(_price * (call AP_fnc_getGovTax))};
                    default {0};
                }; if ((_shopType isEqualTo "rebel") && !(AP_armsCartel select 0) && ((call AP_adminLevel) <= 2)) then {
                    private _updateVal = (AP_armsCartel select 1);
                    _updateVal = _updateVal + _cut;
                    AP_armsCartel set[1, _updateVal];
                    _extra = format[", with $%1 going to the owner of the Arms Dealer", [_cut] call AP_fnc_numberText];};
                if ((_shopType in _govTaxedShops) && !(AP_govTax param[0, false]) && ((call AP_adminLevel) <= 2)) then {
                    private _updateVal = (AP_govTax select 1);
                    _updateVal = _updateVal + _cut;
                    AP_govTax set[1, _updateVal];
                    _extra = format[", with $%1 going to the Govenor of %2", [_cut] call AP_fnc_numberText, worldName];};
                if (!isNull _control) then { _control ctrlEnable false };
                // NEW DRACHMA: Kabuki Electronics ("tech") takes ND ONLY -- no cash. Price is the cash
                // catalogue value at 6000:1. Server-authoritative debit (this fn is spawned, so the blocking
                // AP_fnc_ndBuySync is scheduler-legal). Item was granted above; _exit removes it on failure.
                if (_shopType isEqualTo "tech") then {private _ndPrice = [_price] call AP_fnc_ndFromLegacy;
                    if (!([_ndPrice] call AP_fnc_ndAfford)) exitWith {
                        [format["Kabuki Electronics only takes New Drachma. You need %1 ND.", [_ndPrice] call AP_fnc_ndText], "basic"] spawn AP_fnc_handleMessage;
                        _exit = true;};
                    if (!([_ndPrice] call AP_fnc_ndBuySync)) exitWith {
                        ["New Drachma payment failed -- try again.", "basic"] spawn AP_fnc_handleMessage;
                        _exit = true;};} else {if (_shopType isNotEqualTo "rebel") then {if !([_price] call AP_fnc_debitCard) exitWith {
                            _exit = true;};} else {if (AP_cash < _price) exitWith {
                            [format["You do not have enough cash on you to purchase this. Requires $%1.", [_price] call AP_fnc_numberText], "basic"] spawn AP_fnc_handleMessage;
                            _exit = true;};
                        AP_cash = (round(AP_cash - _price)) max 0;
                        AP_cashCacheB = ((AP_cash / 4) + 9);};};
                if (_exit) exitWith {[false, _item, _amount] call AP_fnc_handleInv;
                    if (!_direct) then { [_shopType, _mainItemListSelect] call AP_fnc_virtualShopUpdate };};
                private _nearMedSupply = nearestObjects[player, ["C_IDAP_supplyCrate_F", "I_UAV_06_medical_F", "C_IDAP_UAV_06_medical_F"], 6];
                if (count _nearMedSupply >= 1) then {
                    if (alive (_nearMedSupply select 0) && {(_nearMedSupply select 0) getVariable["AP_medSupply", false]}) then {
                        private _shopOwner = (_nearMedSupply select 0) getVariable["AP_owner", objNull];
                        if (!(isNull _shopOwner) && !(_shopOwner isEqualTo player)) then {[
                                [player, _shopOwner, _price], "APS_fnc_medSupplyPay", 2] spawn AP_fnc_MP;};};};
                private _rebelOutposts = ["Rebelop_1", "Rebelop_2", "Rebelop_3", "Rebelop_4", "Rebelop_5", "Rebelop_6"];
                if !(({player distance(getMarkerPos _x) <= 200}
                count _rebelOutposts) isEqualTo 0) then {["moneyspentrebel", _price] call AP_fnc_statArrUpdate;};
                private _taxName =
                switch (true) do {case ((_shopType isEqualTo "rebel") && !(AP_armsCartel select 0)): {"Arms"};
                    case (_shopType in _govTaxedShops): {"Tax"};}; private _index = AP_purchasedVItems findIf {_x select 0 == _itemName};
                if (_index isEqualTo - 1) then {AP_purchasedVItems pushBack[_itemName, _amount, _cut, _price, _taxName];} else {
                    private _oldValues = AP_purchasedVItems select _index;
                    _oldValues params["_itemName", "_xAmount", "_tax", "_prePrice"];
                    AP_purchasedVItems set[_index, [_itemName, _xAmount + _amount, _tax + _cut, _prePrice + _price, _taxName]];};
                if (!_direct) then { [_shopType, _mainItemListSelect] call AP_fnc_virtualShopUpdate }; [
                    ["-ITEMBOUGHT-", player, (profileName), format["purchased %1 %2 for $%3 at POS: %4", [_amount] call AP_fnc_numberText, ["getName", _item] call AP_fnc_virtItemCfg, [_price] call AP_fnc_numberText, getPosATL player]], "APS_fnc_logIt", 2, false, false] spawn AP_fnc_MP;
                // Dynamic market: a BUY raises demand -> push the demand index negative (buy -, sell +).
                if (!isNil "AP_price_index" && {(AP_price_index findIf {(_x isEqualType []) && {(_x param [0, ""]) isEqualTo _item}}) > -1}) then {
                    [[_item, -_amount], "APS_fnc_stockUpdate", 2] spawn AP_fnc_MP;};} else {
                [format["You do not have room in your inventory for %1 %2", _amount, _itemName], "basic"] spawn AP_fnc_handleMessage;};
        }; case ("sellItem"): {if !(_item in _sellItems) exitWith {["You can't sell this item!", "basic"] spawn AP_fnc_handleMessage;};
                private _amount = if (_direct) then { _qtyIn } else { parseNumber(ctrlText _mainItemListEdit) };
                if !([str _amount] call AP_fnc_isNumber) exitWith {["Invalid number.", "basic"] spawn AP_fnc_handleMessage;};
                // owner 2026-08-12: the chain -- and every anti-arbitrage guard in it --
                // moved to AP_fnc_virtShopSellPrice so the web shop can show a sell
                // price without a second copy of the exploit fixes.
                private _price = [_shopType, _item, _buyItems, _sellItems] call AP_fnc_virtShopSellPrice;
                private _inInventory = missionNameSpace getVariable[format["AP_inv_%1", _item], 0];
                private _itemName = ["getName", _item] call AP_fnc_virtItemCfg;
                if (_amount <= 0) exitWith {["You need to sell at least one", "basic"] spawn AP_fnc_handleMessage;};
                if (_amount > _inInventory) exitWith {["You don't have that many items to sell!", "basic"] spawn AP_fnc_handleMessage;};
                private _rebelOutposts = ["Rebelop_1", "Rebelop_2", "Rebelop_3", "Rebelop_4", "Rebelop_5", "Rebelop_6"];
                if (_item isEqualTo "goldbar" && (({player distance(getMarkerPos _x) <= 200}
                count _rebelOutposts) isEqualTo 0)) exitWith {["You cannot sell this here!", "basic"] spawn AP_fnc_handleMessage};
                private _buffPercent = ["questBuffs", false, _item] call AP_fnc_getDiscount;
                private _addBuff =
                if (_buffPercent isEqualTo 0) then {0} else {(_price * _buffPercent)};
                // ECONOMY 2026-09-05: the MERCHANT talents (Broker/Plug/Wholesaler) used to be applied HERE,
                // to the figure AP_fnc_virtShopSellPrice had already capped -- so a x1.30 sale beat the
                // anti-arbitrage cap on every good that is buyable and sellable at the same counter. They now
                // live inside that function, before its caps, so the web shop and this dialog quote the same
                // number and neither can exceed the buy price. Do not re-multiply here.
                _price = round((_price + _addBuff) * _amount);
                if ([false, _item, _amount] call AP_fnc_handleInv) then {
                    (wongs_flag getVariable["AP_capData", [0, "Neutral", 0.5]]) params["_flagGangID", "_flagGangName", "_progress"];
                    private _extra = "";
                    private _inTurf = (player inArea "turf_area_rodo_flag" || player inArea "turf_area_panagia_flag" || player inArea "turf_area_zaros_flag");
                    private _cut =
                    switch (true) do {case ((_shopType == "wongs") && !(AP_wongsCartel select 0)): {floor(_price * 0.10)};
                        case ((_shopType == "heroin") && !(AP_turfTax select 0) && _inTurf): {floor(_price * 0.20)};
                        default {0};
                    }; if ((_shopType == "wongs") && !(AP_wongsCartel select 0) && ((call AP_adminLevel) <= 2) && !(_item in ["rum_0", "scotch_0", "scotch_3", "whiskeyc_0", "whiskeyr_0"])) then {
                        private _updateVal = (AP_wongsCartel select 1);
                        _updateVal = _updateVal + _cut;
                        _price = _price - _cut;
                        AP_wongsCartel set[1, _updateVal];
                        _extra = format[", after a $%1 cut was taken by the owner of Wong Triad.", [_cut] call AP_fnc_numberText];};
                    if ((_shopType == "heroin") && !(AP_turfTax select 0) && _inTurf && ((call AP_adminLevel) <= 2)) then {
                        private _updateVal = (AP_turfTax select 1);
                        _updateVal = _updateVal + _cut;
                        _price = _price - _cut;
                        AP_turfTax set[1, _updateVal];
                        private _nearestFlag = (nearestObjects[player, ["Flag_Red_F", "FlagPole_F"], 500] select 0);
                        private _flagName = ["Rodopoli", "Zaros", "Panagia"] param[[rodo_flag, zaros_flag, panagia_flag] find _nearestFlag, "Capture Point"];
                        _extra = format[", after a $%1 cut was taken by the owner of the %2", [_cut] call AP_fnc_numberText, format["%1 Turf", _flagName]];
                    };
                    if (_shopType in ["wongs", "heroin"]) then {
                        if ((((AP_lastPersistVar select 0) isEqualTo "AP_drugtrace") && ((AP_lastPersistVar select 1) < time)) || !((AP_lastPersistVar select 0) isEqualTo "AP_drugtrace")) then {
                            [[getPlayerUID player, "AP_drugtrace", time], "APS_fnc_varPersist", 2] spawn AP_fnc_MP;
                            AP_lastPersistVar = ["AP_drugtrace", (time + 30)];
                            [] spawn {private _time = time;
                                waitUntil {uiSleep 1;
                                    (AP_cash isEqualTo 0) || ((time - _time) > 400)};
                                if (AP_cash isEqualTo 0) then {[
                                        [getPlayerUID player, "AP_drugtrace", -1000], "APS_fnc_varPersist", 2] spawn AP_fnc_MP;};};};};
                    if (!isNull _control) then { _control ctrlEnable false };
                    // NEW DRACHMA: legacy loonycoin sells straight to the WALLET at 1 coin = 1 ND (not cash) --
                    // the straggler path for coins still sitting in trunks/houses after the switch. Items are
                    // already removed above; here we just reroute the payout.
                    if (_item isEqualTo "loonycoin") then {[format["%1", _amount], "coinsell"] call AP_fnc_ndRequest;
                        systemChat format["You converted %1 mined coin%2 to %1 ND", _amount, ["s",""] select (_amount == 1)];} else {
                        AP_cash = (round(AP_cash + _price)) max 0;
                        AP_cashCacheB = ((AP_cash / 4) + 9);
                        [0] call AP_fnc_ClupdatePartial;
                        systemChat format["You sold %1 %2 for $%3%4", _amount, _itemName, [_price] call AP_fnc_numberText, _extra];};
                    private _index = AP_soldVItems findIf {_x select 0 == _itemName};
                    if (_index isEqualTo - 1) then {AP_soldVItems pushBack[_itemName, _amount, _cut, _price, _item];} else {
                        private _oldValues = AP_soldVItems select _index;
                        _oldValues params["_itemName", "_xAmount", "_tax", "_prePrice", "_cfgName"];
                        AP_soldVItems set[_index, [_itemName, _xAmount + _amount, _tax + _cut, _prePrice + _price, _cfgName]];};
                    if (_item in ["uraniump", "smashbrick", "blacklaceprime", "moonshine", "moonshinep"]) then {
                        [format["%1%2", _item, "_sold"], _amount] call AP_fnc_statArrUpdate;} else {
                        [_item, _amount] call AP_fnc_statArrUpdate;};
                    if (_item isEqualTo "goldbar") then {["goldsold", 1] call AP_fnc_statArrUpdate;};
                    ["sell", _item, _amount] call AP_fnc_handleQuest;
                    if (_item in ["salema", "ornate", "mackerel", "tuna", "mullet", "catshark"]) then {
                        ["sell", "fish", _amount] spawn AP_fnc_handleQuest;};
                    // Dynamic market: report the sale so the server raises this good's saturation
                    // (APS_fnc_stockUpdate -> server price index moves, AP_stock_change rebroadcast to all clients).
                    if (!isNil "AP_price_index" && {(AP_price_index findIf {(_x isEqualType []) && {(_x param [0, ""]) isEqualTo _item}}) > -1}) then {
                        [[_item, _amount], "APS_fnc_stockUpdate", 2] spawn AP_fnc_MP;};
                    if (_price > 2500) then {[0] call AP_fnc_ClupdatePartial;
                        [true] call AP_fnc_saveGear;};
                    if (!_direct) then { [_shopType, _mainItemListSelect] call AP_fnc_virtualShopUpdate }; [
                        ["-ITEMSOLD-", player, (profileName), format["sold %1 %2 for $%3 at POS: %4", [_amount] call AP_fnc_numberText, ["getName", _item] call AP_fnc_virtItemCfg, [_price] call AP_fnc_numberText, getPosATL player]], "APS_fnc_logIt", 2, false, false] spawn AP_fnc_MP;
                };};};