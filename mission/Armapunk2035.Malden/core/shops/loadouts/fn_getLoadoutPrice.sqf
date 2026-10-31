params[["_type", "", [""]], ["_loadout", [], [[]]], ["_virtualLoadout", [], [[]]], ["_msg", false, [false]]];
if (_type isEqualTo "" || _loadout isEqualTo[]) exitWith {
    ["An error has occured. Please try again.", "weppurchase"] spawn AP_fnc_handleMessage; - 1};
_loadout params[["_primary", [], [[]]], ["_secondary", [], [[]]], ["_hgun", [], [[]]], ["_uniform", [], [[]]], ["_vest", [], [[]]
], ["_backpack", [], [[]]], ["_helmet", "", [""]], ["_facewear", "", [""]], ["_binos", [], [[]]], ["_assignedItems", [], [[]]]];
private _items = []; {if !(_x isEqualTo[]) then {_items pushBack[_x select 0, 1];
        if !((_x select 1) isEqualTo "") then {_items pushBack[_x select 1, 1];};
        if !((_x select 2) isEqualTo "") then {_items pushBack[_x select 2, 1];};
        if !((_x select 3) isEqualTo "") then {_items pushBack[_x select 3, 1];};
        if !((_x select 4) isEqualTo[]) then {_items pushBack[(_x select 4) select 0, 1];};
        if !((_x select 5) isEqualTo[]) then {_items pushBack[(_x select 5) select 0, 1];};
        if !((_x select 6) isEqualTo "") then {_items pushBack[_x select 6, 1];};};}
forEach[_primary, _secondary, _hgun]; {if !(_x isEqualTo[]) then {_items pushBack[_x select 0, 1];
        if !((_x select 1) isEqualTo[]) then {{_x params["_item", "_itemCount"];
                if (_item isEqualType[]) then {{if (_x isEqualType "" && {_x != ""}) then {private _count =
                            if (_forEachIndex isEqualTo 0) then {_itemCount} else {1};
                            _items pushBack[_x, _count];};
                        if (_x isEqualType[] && {!(_x isEqualTo[])}) then {_items pushBack[_x select 0, 1];};}
                    forEach _item;} else {_items pushBack[_item, _itemCount];}}
            forEach(_x select 1);};};}
forEach[_uniform, _backpack, _vest];
if !(_helmet isEqualTo "") then {_items pushBack[_helmet, 1];};
if !(_facewear isEqualTo "") then {_items pushBack[_facewear, 1];};
if !(_binos isEqualTo[]) then {_items pushBack[_binos select 0, 1];};
if !(_assignedItems isEqualTo[]) then {if !((_assignedItems select 1) isEqualTo "") then {_items pushBack[_assignedItems select 0, 1];};
    if !((_assignedItems select 5) isEqualTo "") then {_items pushBack[_assignedItems select 5, 1];};};
private _priceArr = [];
switch (_type) do {case "rebel": {_priceArr = [5] call AP_fnc_clothing_reb;
            _priceArr append(["rebelwep"] call AP_fnc_weaponAddons);
            _priceArr append((["rebelwep"] call AP_fnc_weaponShopCfg) select 1);
            _priceArr append([5] call AP_fnc_clothing_civ);}; case "cop": {_priceArr = [5] call AP_fnc_clothing_cop;
                _priceArr append(["police_weapons"] call AP_fnc_weaponAddons);
                _priceArr append((["police_weapons"] call AP_fnc_weaponShopCfg) select 1);
                _priceArr append((["police_equipment"] call AP_fnc_weaponShopCfg) select 1);};
        case "skiptracer": {_priceArr = [5] call AP_fnc_clothing_reb;
                _priceArr append(["skiptracer"] call AP_fnc_weaponAddons);
                _priceArr append((["skiptracer"] call AP_fnc_weaponShopCfg) select 1);};
        case "medic": {_priceArr = [5] call AP_fnc_clothing_med;
                _priceArr append(["med_basic"] call AP_fnc_weaponAddons);
                _priceArr append((["med_basic"] call AP_fnc_weaponShopCfg) select 1);};}; private _virtualPrice = 0;
private _shopType =
if (AP_effSide isEqualTo civilian) then {"rebel"} else {
    "cop"}; if (_virtualLoadout isNotEqualTo[]) then {{_x params[["_virtName", ""], ["_virtQty", 0]];
        private _basePrice = ["getBasePrice", _virtName] call AP_fnc_virtItemCfg;
        private _price = _basePrice * ([_shopType, true] call AP_fnc_getDiscount);
        private _shortName = ["getShortName", _virtName] call AP_fnc_virtItemCfg;
        _price =
        switch (true) do {case ((_virtName isEqualTo "vammo") && (7 in AP_achievements)): {0};
            default {_price};}; _price =
        if (_shopType in ["rebel", "turf"]) then {_price} else {_price + (_price * (call AP_fnc_getGovTax))};
        _virtualPrice = _virtualPrice + (_price * _virtQty);}
    forEach _virtualLoadout;};
if (_items isEqualTo[] || _priceArr isEqualTo[]) exitWith {-1};
private _noPrice = false;
private _loadoutCost = 0;
private _unavailItems = ""; {_x params["_classname", "_count"];
    private _index = _priceArr findIf {_classname == (_x select 0)};
    if (_count isEqualType true) then {_count = 1};
    if !(_index isEqualTo - 1) then {_loadoutCost = _loadoutCost + (((_priceArr select _index) select 2) * _count);} else {
        // LooneyBin: MaxSec standard-issue gear (esp. the SCD kit -- H_Watchcap_blk, G_Bandanna_aviator)
        // is issued on spawn and sold in NO shop, so it has no price entry and would -1 the whole loadout,
        // silently blocking cops/SCD officers from saving. Treat issued items as free (skip the block).
        if !(toLower _classname in ["u_rangemaster", "v_rangemaster_belt", "v_tacvest_blk_police", "h_cap_police", "h_watchcap_blk", "g_bandanna_aviator"]) then {
            _noPrice = true;
            _unavailItems = _unavailItems + format["%1<br/>", (([_classname] call AP_fnc_fetchCfgDetails) select 1)];};};}
forEach _items;
if (_noPrice) exitWith {if (_msg) then {
        [format["The following items are unavailable at this shop location and will not allow saving or purchasing of this loadout.<br/><t color='#FF0000'>%1</t>", _unavailItems], "weppurchase"] spawn AP_fnc_handleMessage;
    }; - 1};
_loadoutCost =
if (31 in AP_infamy_talents && license_civ_rebel) then {_loadoutCost - (_loadoutCost * 0.05)} else {_loadoutCost};
_loadoutCost =
if (AP_effSide isEqualTo west && {SRV_communityEvent param [1, false]}) then {_loadoutCost - (_loadoutCost * 0.5)} else {_loadoutCost};
_loadoutCost = _loadoutCost + _virtualPrice;
if (_type isNotEqualTo "rebel") then {_loadoutCost = _loadoutCost + (_loadoutCost * (call AP_fnc_getGovTax))};
_loadoutCost =
_loadoutCost;
_loadoutCost;