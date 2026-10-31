/*
    fn_shopData.sqf — one payload for every virtual shop.

    Six shop types share one screen: market, rebel, gas, hospital, wongs, black
    market and the rest all resolve through AP_fnc_virt_shops, which answers
    [title, buyItems, sellItems]. An item can be in either list or both.

    PRICES ARE NOT COMPUTED HERE. Both figures come from the same functions the
    native shop charges through -- AP_fnc_virtShopPrice and
    AP_fnc_virtShopSellPrice -- so the number on the page and the number the
    till uses cannot drift apart. That matters more than usual: the sell chain
    carries several anti-arbitrage caps, and a display that rounded differently
    would be read as a bug in the economy rather than in the screen.

    The page never sends a price back. It sends an item id and an amount.

    Usage:  private _payload = ["market"] call AP_fnc_shopData;
*/

params [["_shopType", "", [""]]];
if (_shopType isEqualTo "") exitWith { createHashMap };

private _info = [_shopType] call AP_fnc_virt_shops;
_info params [["_title", "", [""]], ["_buy", [], [[]]], ["_sell", [], [[]]]];
if (_title isEqualTo "") exitWith { createHashMap };

// Kabuki trades in New Drachma; everything else in cash. The page needs to know
// which so it can label totals without guessing from the shop name.
private _nd = _shopType isEqualTo "tech";

private _seen = [];
private _items = [];
{
    // virt_shops returns FLAT ARRAYS OF STRINGS for both lists -- not [class, price]
    // pairs, whatever a `params ["_cls", "_pr"]` reading would imply.
    private _id = _x;
    if (_id isEqualType "" && { _id isNotEqualTo "" } && { !(_id in _seen) }) then {
        _seen pushBack _id;
        private _canBuy  = _id in _buy;
        private _canSell = _id in _sell;
        private _w = ["getItemWeight", _id] call AP_fnc_virtItemCfg;
        if (!(_w isEqualType 0)) then { _w = 0 };

        _items pushBack (createHashMapFromArray [
            ["id",    _id],
            ["name",  ["getName", _id] call AP_fnc_virtItemCfg],
            ["buy",   if (_canBuy)  then { round ([_shopType, _id] call AP_fnc_virtShopPrice) } else { -1 }],
            ["sell",  if (_canSell) then { round ([_shopType, _id, _buy, _sell] call AP_fnc_virtShopSellPrice) } else { -1 }],
            ["wt",    _w],
            ["own",   missionNamespace getVariable [format ["AP_inv_%1", _id], 0]],
            // the same explainer the native list puts in its tooltip
            ["desc",  if (isNil "AP_itemDesc") then { "" } else { AP_itemDesc getOrDefault [_id, ""] }]
        ]);
    };
} forEach (_buy + _sell);

createHashMapFromArray [
    ["id",     _shopType],
    ["name",   _title],
    ["items",  _items],
    ["cash",   AP_cash],
    ["bank",   AP_atmcash],
    ["nd",     _nd],
    // Weight room is what MAX has to respect, alongside cash. Both are re-checked
    // by fn_virtualShopManage; these are so the page can grey a button rather
    // than let the player click into a refusal.
    ["weight", missionNamespace getVariable ["AP_carryWeight", 0]],
    ["maxWeight", missionNamespace getVariable ["AP_maxWeight", 0]]
]
