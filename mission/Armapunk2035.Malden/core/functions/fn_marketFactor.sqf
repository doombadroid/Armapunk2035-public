/*
    AP_fnc_marketFactor  (LooneyBin Economy — HYBRID supply/demand market, #338 2026-06-17)
    Price multiplier for a good = its current factor from AP_price_index ([[class, prem, sales], ...], driven
    by APS_fnc_marketTick + the APS_fnc_stockUpdate sell hook). factor in [FLOOR(0.6), CEIL(1.3)]: SELLING drops it
    toward FLOOR (oversupply -> cheaper than max), an IDLE tick recovers/climbs it toward CEIL (scarcity premium).
    Returns 1 for any good not in the tracked market (safe no-op everywhere it's applied).

    Applied as:  sellPrice = maxPrice * marketFactor   (virtItemCfg getLowestPrice floors tracked goods at
    idx 6 = max, then multiplies by this). Untracked goods keep their static prices (factor 1).
*/
params [["_class", "", [""]]];
if (_class isEqualTo "") exitWith {1};
if (isNil "AP_price_index" || {!(AP_price_index isEqualType [])}) exitWith {1};
private _i = AP_price_index findIf {(_x isEqualType []) && {(_x param [0, ""]) isEqualTo _class}};
if (_i isEqualTo -1) exitWith {1};
private _prem = (AP_price_index select _i) param [1, 1];
if (!(_prem isEqualType 0)) exitWith {1};
// owner 2026-06-18 (login price exploit): a real prem is ALWAYS >= FLOOR (0.6). A prem of 0 (or negative) means
// the row is UNSET / a stale legacy [class,0] seed (the old configuration.sqf seed) NOT yet overwritten by the
// server's synced index -> treat it as "no data" and return 1 (full price) instead of clamping 0 up to 0.6, which
// briefly discounted EVERY tracked good ~40% on each login = buy cheap, resync, sell normal. Defense-in-depth: the
// bad seed itself is now removed from configuration.sqf, but this stops any future unset/legacy row from discounting.
if (_prem <= 0) exitWith {1};
// owner 2026-06-17 (#338 HYBRID): clamp the factor to [FLOOR, CEIL]. prem can be < 1 now -- an OVERSUPPLIED good
// sells BELOW its max (down to FLOOR = 60%). Per-item ceiling override (wax capped at 1.0 = no scarcity premium).
private _floor = missionNamespace getVariable ["AP_marketFloor", 0.6];
private _maxP  = missionNamespace getVariable ["AP_marketMaxPrem", 1.3];
{ if ((_x select 0) isEqualTo _class) exitWith { _maxP = _x param [2, _maxP]; }; } forEach (missionNamespace getVariable ["AP_marketItemOv", []]);
private _factor = (_prem max _floor) min _maxP;
// owner 2026-07-08 (DRUG BUST event -- casino wheel "BUST" prize): while live, every illegal drug sells +12%
// server-wide. Applied AFTER the clamp so it stacks ABOVE the normal ceiling for the 5-min window; auto-expires the
// moment serverTime passes AP_drugBustUntil (both vars publicVariable'd from the server so all clients agree).
if ((_class in (missionNamespace getVariable ["AP_drugBustGoods", []])) && {serverTime < (missionNamespace getVariable ["AP_drugBustUntil", 0])}) then {
    _factor = _factor * 1.12;};
_factor
