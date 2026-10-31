/*
    fn_virtShopPrice.sqf  (AP_fnc_virtShopPrice) — what one item COSTS at one
    virtual shop, in cash, before rounding for display.

    Lifted verbatim out of fn_virtualShopPopulate so there is ONE copy. The buy
    price is a chain -- base, market premium, shop discount, an achievement
    special case, government tax -- and it was already being
    re-derived in fn_virtualShopManage's sell branch, which carries a comment
    warning that the two MUST match. A second consumer (the web shop) would have
    made three copies of a money calculation kept in step by hand.

    This does not touch the SELL side. That chain has its own anti-exploit history
    (the Drug Dealer round-trip, where sell = maxPrice * marketFactor exceeded the
    buy price and became free money) and is left exactly where it is.

    Usage:  private _p = ["market", "apple"] call AP_fnc_virtShopPrice;
*/

params [["_shopType", "", [""]], ["_item", "", [""]]];
if (_shopType isEqualTo "" || { _item isEqualTo "" }) exitWith { 0 };

private _price = (["getBasePrice", _item] call AP_fnc_virtItemCfg)
    * ([_item] call AP_fnc_marketFactor)
    * ([_shopType, true] call AP_fnc_getDiscount);

// Weapon-ammo crate is free once the achievement is held
_price = switch (true) do {
    case ((_item isEqualTo "vammo") && { 7 in AP_achievements }): { 0 };
    default { _price };
};
// rebel and turf trade outside the tax system
_price = if (_shopType in ["rebel", "turf"]) then { _price } else { _price + (_price * (call AP_fnc_getGovTax)) };

_price
