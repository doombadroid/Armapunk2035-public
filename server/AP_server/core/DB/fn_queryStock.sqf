 
private["_query","_result","_ret"];

// Economy 2026-06-16 (neglect-premium): rows are [className, prem, sales] -- quantity column now holds the
// PREMIUM (>=1, float) and the sales column the cumulative sale count toward the next crash. APS_fnc_marketTick
// seeds any missing good, so an empty itemstock just starts everything at the max-price floor (prem 1).
_query = "SELECT className,quantity,sales FROM itemstock";

_ret = [_query,2,true] call DB_fnc_asyncQuery;
if (!(_ret isEqualType [])) then { _ret = []; };
// server-only authority (localNamespace: no client publicVariable can reach it); marketTick publishes AP_price_index
localNamespace setVariable ["APS_priceIndex", _ret];
