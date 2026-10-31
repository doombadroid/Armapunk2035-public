/*
    fn_virtShopSellPrice.sqf  (AP_fnc_virtShopSellPrice) — what one item SELLS
    for at one virtual shop, before the quest buff.

    Lifted verbatim out of fn_virtualShopManage's sellItem branch. Nothing about
    the logic changed; it moved so the web shop can DISPLAY a sell price without
    becoming a second copy of it. Every guard below is anti-arbitrage and each one
    was added to close a specific money pump -- read the comments before touching
    any of them.

    Usage:  [_shopType, _item, _buyItems, _sellItems] call AP_fnc_virtShopSellPrice
*/

params [["_shopType", "", [""]], ["_item", "", [""]], ["_buyItems", [], [[]]], ["_sellItems", [], [[]]]];
if (_shopType isEqualTo "" || { _item isEqualTo "" }) exitWith { 0 };

// ECONOMY 2026-09-05: the MERCHANT talents moved IN HERE from fn_virtualShopManage, where they were
// applied to the ALREADY-CAPPED figure this function returns -- `_price * _amount * _sellMult` after
// the anti-arbitrage min() had run. That put 70 buyable+sellable goods above their own buy price at
// up to 1.30x: a Homegoods flat-screen bought for $9,000 sold back for $11,700, unbounded, no travel,
// no cooldown. The multiplier is a real talent reward, so it is not removed -- it is applied BEFORE
// both caps, which is where every other multiplier in this chain already sits. Sell-only goods
// (base = -1) never reach a cap, so Broker/Plug/Wholesaler pay out on them exactly as before.
// All three callers (shop dialog, web shop, shop diag) now agree on one number.
private _sellMult = 1;
private _isDrugShop = _shopType in ["wongs", "heroin"];
if (230 in AP_side_talents) then { _sellMult = _sellMult + 0.10; };                      // Broker
if (231 in AP_side_talents && {_isDrugShop}) then { _sellMult = _sellMult + 0.25; };     // Plug
if (232 in AP_side_talents && {!_isDrugShop}) then { _sellMult = _sellMult + 0.20; };    // Wholesaler

if ((_item in _buyItems) && (_item in _sellItems)) exitWith {
    private _buyPrice = ["getBasePrice", _item] call AP_fnc_virtItemCfg;
    // marketFactor MUST match the actual buy price (fn_virtualShopPopulate: base*marketFactor*discount).
    // Without it the cap = base*discount while an OVERSUPPLIED drug BUYS for base*factor*discount (factor<1)
    // -> buy cheap, sell at the higher cap = free money (the gang drug perk pushes sell up to that cap).
    _buyPrice = _buyPrice * ([_item] call AP_fnc_marketFactor) * ([_shopType, true] call AP_fnc_getDiscount);
    private _sellPrice = ["getLowestPrice", _item] call AP_fnc_virtItemCfg;
    _sellPrice = _sellPrice * ([_shopType, false] call AP_fnc_getDiscount) * _sellMult;
    selectMin [_sellPrice, _buyPrice]
};

private _sellPrice = ["getLowestPrice", _item] call AP_fnc_virtItemCfg;
if (_item == "goldbar" && (AP_gang_data select 0) isEqualTo (zaros_flag getVariable ["AP_turf_data", []] select 0)) then {
    _sellPrice = _sellPrice * 1.1} else {_sellPrice};
_sellPrice = _sellPrice * ([_shopType, false] call AP_fnc_getDiscount) * _sellMult;
// LooneyBin anti-arbitrage (global): a BUYABLE good (base buy price > 0) can NEVER sell for
// more than its buy price. The per-shop `selectMin` guard above only caught items that are
// buyable+sellable at the SAME shop, so buying a raw drug cheap at shop A and selling it at
// the Drug Dealer -- where sell = maxPrice * marketFactor (>> base) -- was free money. Processed
// sell-only goods have base = -1 -> skipped, so they keep their intended max*premium sell.
private _basePrice = ["getBasePrice", _item] call AP_fnc_virtItemCfg;
if (_basePrice > 0) then {
    // * marketFactor so the cap tracks the ACTUAL buy price (base*marketFactor*discount), not just
    // base*discount -- otherwise an oversupplied good (factor<1) buys below the cap = arbitrage.
    _sellPrice = _sellPrice min (_basePrice * ([_item] call AP_fnc_marketFactor) * ([_shopType, true] call AP_fnc_getDiscount));
};
_sellPrice
