#include "..\..\macro.h"
/*
    AP_fnc_sellVehicleInv  (owner 2026-07-06) -- scroll option at a Drug Dealer: bulk-sell the NEAREST vehicle
    you have KEYS to, dumping every dealer-sellable virtual item in its trunk at the dealer's price. Progress bar,
    10 units/sec (sold in <=10-unit chunks, one per second, so walking away keeps whatever already sold and leaves
    the rest in the trunk). Mirrors fn_virtualShopManage sellItem: dealer price (getLowestPrice * getDiscount, or
    min of buy/sell if both-listed) + quest buff, heroin turf cut (20%) / wongs cut (10%) into the owner buffer,
    drug-trace persist, dynamic-market saturation, sold-stat + quest hooks. Reserves the vehicle for the run.
    addAction wires args at slot 3 -> [_target, _caller, _id, _shopType].
*/
params [["_target", objNull, [objNull]], "", "", ["_shopType", "heroin", [""]]];
if (missionNamespace getVariable ["AP_bulkSell", false]) exitWith { ["You're already selling a vehicle's inventory.", "basic"] spawn AP_fnc_handleMessage; };
if !(AP_effSide isEqualTo civilian) exitWith {};
if (AP_is_processing) exitWith { ["Finish what you're doing first.", "basic"] spawn AP_fnc_handleMessage; };
if !(isNull objectParent player) exitWith { ["Get out of the vehicle first.", "basic"] spawn AP_fnc_handleMessage; };

private _shopInfo = [_shopType] call AP_fnc_virt_shops;
_shopInfo params [["_title", ""], ["_buyItems", []], ["_sellItems", []]];
if (_sellItems isEqualTo []) exitWith { ["This dealer doesn't buy anything.", "basic"] spawn AP_fnc_handleMessage; };

// nearest vehicle you have KEYS to (uid anywhere in AP_vehOwners), within 30m, unlocked + free
private _uid = getPlayerUID player;
private _near = nearestObjects [player, ["Car", "Air", "Ship"], 30];
private _veh = objNull; {if (alive _x) then {private _cand = _x;
        private _hasKey = ((_cand getVariable ["AP_vehOwners", []]) findIf { (_x param [0, ""]) isEqualTo _uid }) > -1;
        if (_hasKey
            && {(_cand getVariable ["AP_activeTrunk", objNull]) isEqualTo objNull}
            && {(_cand getVariable ["AP_veh_in_use", objNull]) isEqualTo objNull}
            && {!(_cand getVariable ["AP_trunkLock", false])}
            && {!(_cand getVariable ["AP_seizing", false])}) exitWith { _veh = _cand; };};} forEach _near;
if (isNull _veh) exitWith { ["No vehicle you have keys to is parked within 30m, unlocked and free.", "basic"] spawn AP_fnc_handleMessage; };

// what in the trunk this dealer will buy
private _vInv = +((_veh getVariable ["AP_vinv", [[], 0]]) select 0);
private _work = _vInv select { ((_x param [0, ""]) in _sellItems) && {(_x param [1, 0]) > 0} };
if (_work isEqualTo []) exitWith { ["That vehicle has nothing this dealer will buy.", "basic"] spawn AP_fnc_handleMessage; };
private _total = 0; { _total = _total + (_x select 1); } forEach _work;

// per-item unit price (matches fn_virtualShopManage sellItem, incl. quest buff)
private _fnPrice = {params ["_item"];
    private _p = if ((_item in _buyItems) && (_item in _sellItems)) then {
        // owner 2026-07-08: the anti-arb cap MUST scale by marketFactor, exactly like the on-foot path
        // (fn_virtualShopManage.sqf:169). Without it the cap was a FLAT base price, so buy+sell drugs
        // (smash/black lace/marijuana/glitter) sold here ignored the market premium AND the
        // DRUG BUST +12% -- selectMin always picked the un-scaled _bp. Now vehicle sales match foot sales.
        private _bp = (["getBasePrice", _item] call AP_fnc_virtItemCfg) * ([_item] call AP_fnc_marketFactor) * ([_shopType, true] call AP_fnc_getDiscount);
        private _sp = (["getLowestPrice", _item] call AP_fnc_virtItemCfg) * ([_shopType, false] call AP_fnc_getDiscount);
        selectMin [_sp, _bp];} else {
        (["getLowestPrice", _item] call AP_fnc_virtItemCfg) * ([_shopType, false] call AP_fnc_getDiscount);};
    private _buff = ["questBuffs", false, _item] call AP_fnc_getDiscount;
    if (_buff != 0) then { _p = _p + (_p * _buff); };
    _p;};
private _fnWeight = { params ["_arr"]; private _w = 0; { _w = _w + ((_x select 1) * (["getItemWeight", _x select 0] call AP_fnc_virtItemCfg)); } forEach _arr; _w; };
private _inTurf = (player inArea "turf_area_rodo_flag" || player inArea "turf_area_panagia_flag" || player inArea "turf_area_zaros_flag");

// reserve + lock
_veh setVariable ["AP_activeTrunk", player, true];
_veh setVariable ["AP_veh_in_use", player, true];
missionNamespace setVariable ["AP_bulkSell", true];
AP_is_processing = true;
AP_action_in_use = true;

disableSerialization;
5 cutRsc ["AP_progress", "PLAIN"];
private _ui = uiNamespace getVariable "AP_progress";
private _pg = _ui displayCtrl 38201;
private _pgT = _ui displayCtrl 38202;
_pg progressSetPosition 0.01;

private _vStart = getPosATL _veh;
private _earned = 0;
private _totalCut = 0;
private _soldUnits = 0;
private _traced = false;
private _abort = false;
private _summary = [];                                            // [[item, qty, net], ...] for one end-of-run log
 {if (_abort) exitWith {};
    _x params ["_item", "_qtyPlanned"];
    private _unit = [_item] call _fnPrice;
    private _left = _qtyPlanned;
    while { _left > 0 && !_abort } do {if ((player distance _target) > 20
            || {isNull _veh} || {!alive _veh}
            || {(player distance _veh) > 30} || {((getPosATL _veh) distance _vStart) > 5}
            || {!AP_action_in_use}) exitWith { _abort = true; };

        // re-read the live (reserved) trunk each chunk
        private _cur = +((_veh getVariable ["AP_vinv", [[], 0]]) select 0);
        private _ix = _cur findIf { (_x param [0, ""]) isEqualTo _item };
        if (_ix < 0) exitWith {};
        private _have = (_cur select _ix) param [1, 0];
        private _chunk = (10 min _left) min _have;
        if (_chunk < 1) exitWith {};

        private _gross = round (_unit * _chunk);
        private _cut = 0;
        if ((_shopType == "heroin") && !(AP_turfTax select 0) && _inTurf && ((call AP_adminLevel) <= 2)) then { _cut = floor (_gross * 0.20); };
        if ((_shopType == "wongs") && !(AP_wongsCartel select 0) && ((call AP_adminLevel) <= 2) && !(_item in ["rum_0", "scotch_0", "scotch_3", "whiskeyc_0", "whiskeyr_0"])) then { _cut = floor (_gross * 0.10); };
        private _net = _gross - _cut;

        // pull the chunk out of the trunk + recompute weight, broadcast
        private _rem = _have - _chunk;
        if (_rem > 0) then { _cur set [_ix, [_item, _rem]]; } else { _cur deleteAt _ix; };
        _veh setVariable ["AP_vinv", [_cur, [_cur] call _fnWeight], true];

        // credit + tax buffers
        AP_cash = (round (AP_cash + _net)) max 0;
        AP_cashCacheB = ((AP_cash / 4) + 9);
        [0] call AP_fnc_ClupdatePartial;   // owner 2026-07-06: sync cash EACH chunk (not just at end) -> a DC mid-sell can't lose already-sold proceeds
        _earned = _earned + _net;
        _totalCut = _totalCut + _cut;
        if (_cut > 0 && {_shopType == "heroin"}) then { AP_turfTax set [1, (AP_turfTax select 1) + _cut]; };
        if (_cut > 0 && {_shopType == "wongs"}) then { AP_wongsCartel set [1, (AP_wongsCartel select 1) + _cut]; };

        // drug-trace persist -- once per run (mirrors the manageShop per-sale guard)
        if ((_shopType in ["wongs", "heroin"]) && !_traced) then {_traced = true;
            [[getPlayerUID player, "AP_drugtrace", time], "APS_fnc_varPersist", 2] spawn AP_fnc_MP;
            AP_lastPersistVar = ["AP_drugtrace", (time + 30)];
            [] spawn {private _t = time;
                waitUntil { uiSleep 1; (AP_cash isEqualTo 0) || ((time - _t) > 400) };
                if (AP_cash isEqualTo 0) then { [[getPlayerUID player, "AP_drugtrace", -1000], "APS_fnc_varPersist", 2] spawn AP_fnc_MP; };
            };};

        // sold-stat + quest + dynamic market (per chunk, matching manageShop)
        if (_item in ["uraniump", "smashbrick", "blacklaceprime", "moonshine", "moonshinep"]) then {
            [format ["%1_sold", _item], _chunk] call AP_fnc_statArrUpdate;} else {[_item, _chunk] call AP_fnc_statArrUpdate;};
        ["sell", _item, _chunk] call AP_fnc_handleQuest;
        if (!isNil "AP_price_index" && {(AP_price_index findIf { (_x isEqualType []) && {(_x param [0, ""]) isEqualTo _item} }) > -1}) then {
            [[_item, _chunk], "APS_fnc_stockUpdate", 2] spawn AP_fnc_MP;};

        // running summary
        private _si = _summary findIf { (_x select 0) isEqualTo _item };
        if (_si < 0) then { _summary pushBack [_item, _chunk, _net]; } else { (_summary select _si) set [1, ((_summary select _si) select 1) + _chunk]; (_summary select _si) set [2, ((_summary select _si) select 2) + _net]; };

        _left = _left - _chunk;
        _soldUnits = _soldUnits + _chunk;
        _pg progressSetPosition ((_soldUnits / _total) min 1);
        _pgT ctrlSetText format ["Selling vehicle inventory... $%1 (%2%3)", [_earned] call AP_fnc_numberText, round (((_soldUnits / _total) min 1) * 100), "%"];
        uiSleep 1;};} forEach _work;

5 cutText ["", "PLAIN"];
AP_is_processing = false;
AP_action_in_use = false;

// release reservation + run-lock
_veh setVariable ["AP_activeTrunk", nil, true];
_veh setVariable ["AP_veh_in_use", nil, true];
missionNamespace setVariable ["AP_bulkSell", false];

if (_soldUnits < 1) exitWith {["Nothing was sold.", "basic"] spawn AP_fnc_handleMessage;};

// persist the earned cash
[0] call AP_fnc_ClupdatePartial;
[true] call AP_fnc_saveGear;

private _cutMsg = if (_totalCut > 0) then { format [" ($%1 in cuts taken)", [_totalCut] call AP_fnc_numberText] } else { "" };
systemChat format ["Sold %1 items from your %2 for $%3%4.", _soldUnits, getText (configFile >> "CfgVehicles" >> (typeOf _veh) >> "displayName"), [_earned] call AP_fnc_numberText, _cutMsg];
[["-VEHSELL-", player, profileName, format ["bulk-sold vehicle trunk at %1 (%2): earned $%3, cuts $%4, breakdown %5. POS: %6", _shopType, typeOf _veh, _earned, _totalCut, _summary, getPosATL player]], "APS_fnc_logIt", 2, false, false] spawn AP_fnc_MP;
