/*
    APS_fnc_marketTick — server NEGLECT-PREMIUM market engine (LooneyBin, reworked owner spec 2026-06-16)

    MODEL: every farmable/tradeable good FLOORS at its MAX sell price (premium = 1). A good that ISN'T being
    sold drifts its premium UP indefinitely (prem *= 1+RISE each idle tick) -> a neglected good keeps getting
    more lucrative until players farm it. Once a good accumulates CRASH (2500) cumulative SALES (counted in
    APS_fnc_stockUpdate), its premium CRASHES back to 1 (= max price) and the sales counter resets.

    APS_priceIndex = [[class, prem, sales], ...]   prem >= 1 (sanity-capped), sales >= 0.
    Persisted via `itemstock` (quantity = prem, sales = sales) so premiums + counters survive restarts.
    Client sell price = maxPrice * prem  (AP_fnc_marketFactor returns prem; virtItemCfg getLowestPrice
    floors tracked goods at idx 6 = max). Buys of untracked goods are unaffected (factor = 1 for them).

    SERVER-ONLY AUTHORITY (2026-09-26): a client publicVariable of an AP_ name overwrites the SERVER's own
    missionNamespace copy too, so everything the server READS (tuning, goods list, price index, drug-bust window)
    lives in localNamespace -- which no network message can write -- under an APS_ name. The AP_ names are
    display copies for clients (marketFactor, deck, virtItemCfg); each tick re-publishes any that were overwritten.
*/
if (!isServer) exitWith {};

private _TICK     = 90;
// owner 2026-06-17 (#338): HYBRID supply/demand model. Price = maxPrice * prem, prem in [FLOOR, CEIL]. SELLING
// pushes prem DOWN toward the FLOOR (oversupply discount); an IDLE tick recovers/climbs prem UP toward the CEIL
// (scarcity premium). So prices move BOTH ways now -- dump a good and it drops; leave it alone and it recovers
// then rises. (Was one-sided: floored at max, only rose when neglected, never dropped on a dump.)
localNamespace setVariable ["APS_marketRise",    0.006];   // prem recovery/climb per IDLE tick (toward CEIL)
localNamespace setVariable ["APS_marketFloor",   0.6];     // FLOOR: an oversupplied good bottoms at 60% of its max
localNamespace setVariable ["APS_marketCrash",   1500];    // DEPTH: SALES to drop a good from neutral (1.0) to the FLOOR (lower = more volatile/visible)
localNamespace setVariable ["APS_marketMaxPrem", 1.3];     // CEIL: a scarce/neglected good tops at 130% of its max
private _floor = localNamespace getVariable "APS_marketFloor";
// per-item overrides [class, dropDepth, ceiling]. House-weed WAX (canna_dab): dropDepth 400 (a 400-unit dump
// drops it to the 60% floor = $240 = anti-hoard) + ceiling 1.0 (best case = its $400 base = ~$120k/maxed-house/
// 3h, no scarcity premium above that). Goods not listed use the globals. Read in the sell hook (APS_fnc_stockUpdate),
// the client clamp (AP_fnc_marketFactor), and the climb loop below. Published so clients clamp the same.
localNamespace setVariable ["APS_marketItemOv", [["canna_dab", 400, 1.0]]];
// owner 2026-07-08 (DRUG BUST event -- casino wheel "BUST" prize): while AP_drugBustUntil is in the future, every
// illegal drug in AP_drugBustGoods sells +12% server-wide (AP_fnc_marketFactor stacks it above the ceiling for the
// window). Auto-expires off serverTime (no timer). List + until published so clients apply the same boost.
localNamespace setVariable ["APS_drugBustGoods", [
    "smash","smashbrick","cocainepure","blacklace","blacklaceprime","marijuana","marijuanam","canna_dab","toxicslurry",
    "redshift","glitter","lacebase"]];
if (isNil {localNamespace getVariable "APS_drugBustUntil"}) then { localNamespace setVariable ["APS_drugBustUntil", 0]; };   // fn_casinoSRV starts a bust

localNamespace setVariable ["APS_marketGoods", ["smash","smashbrick","cocainepure","diamond","diamondc","diamondf","diamondr",
    "goldbar","goldnugget","ruby","uraniump","turtle",
    "blacklace","blacklaceprime","marijuana","marijuanam","canna_dab","toxicslurry",
    "redshift","glitter","lacebase","scotch_2","scotch_3","rum_3","moonshine","moonshinep","gingerale_0",
    "dog","dogp","goatp","sheep","sheepp","manfleshp","humanscalp",
    "salt_r","iron_r","copper_r","timber","timberh","timberl","plank","oilp","rubber"
    // NEW DRACHMA (owner 2026-07-23): loonycoin REMOVED from the floating market -- coins are no longer a
    // tradable good. Rigs deposit ND straight to the wallet, held coins auto-convert at login, and any
    // straggler sells at the Blackmarket for a FIXED 1 coin = 1 ND (fn_virtualShopManage). No drift.
]];
private _idx = localNamespace getVariable ["APS_priceIndex", []];   // fn_queryStock loads it from itemstock
if (!(_idx isEqualType [])) then { _idx = []; };
localNamespace setVariable ["APS_priceIndex", _idx];
// seed/migrate: every good gets a 3-element row [class, prem, sales]; upgrade any legacy 2-element rows
// (old signed-demand model) by treating them as a fresh floor (prem 1, sales 0).
{private _c = _x;
    private _i = _idx findIf {(_x isEqualType []) && {(_x param [0,""]) isEqualTo _c}};
    if (_i < 0) then {_idx pushBack [_c, 1, 0];} else {private _r = _idx select _i;
        private _prem  = _r param [1, 1]; if (!(_prem isEqualType 0)  || {_prem < _floor}) then { _prem = 1 };   // keep a valid loaded prem (may be <1 from a drop); reset only if invalid/below floor
        private _sales = _r param [2, 0]; if (!(_sales isEqualType 0) || {_sales < 0}) then { _sales = 0 };
        _idx set [_i, [_c, _prem, _sales]];};} forEach (localNamespace getVariable "APS_marketGoods");
AP_marketEvents = [];   // legacy client-board var kept empty (no SURGE/GLUT in the premium model)
publicVariable "AP_marketEvents";
// display copies for clients (the AP_ name of each APS_ value); the tick below re-publishes any a client overwrote
{ missionNamespace setVariable [_x, +(localNamespace getVariable ("APS" + (_x select [2])))]; publicVariable _x; }
    forEach ["AP_marketFloor", "AP_marketMaxPrem", "AP_marketItemOv", "AP_drugBustGoods", "AP_drugBustUntil", "AP_marketGoods"];
AP_price_index = _idx;
publicVariable "AP_price_index";

// class-keyed snapshot of last tick's sales, so "sold since last tick?" is order-independent
private _lastSales = _idx apply { [_x param [0,""], _x param [2,0]] };
private _tickN = 0;
// singleevh.md: market recompute/publish migrated onto the single-wheel scheduler (id "marketTick", _TICK~90s).
// Cross-iteration state (_lastSales snapshot, _tickN counter) -> per-job state _st; the one-shot boot setup above
// (config read + AP_price_index seed + publicVariables) still runs once when this fn is spawned. Runs in the
// wheel's transient spawn (may suspend). Flag OFF => original loop runs byte-for-byte (else branch).
["marketTick", {params ["_st"];
    private _idx   = localNamespace getVariable ["APS_priceIndex", []];
    private _floor = localNamespace getVariable ["APS_marketFloor", 0.6];
    private _ov    = localNamespace getVariable ["APS_marketItemOv", []];
    private _ceil  = localNamespace getVariable ["APS_marketMaxPrem", 1.3];
    private _rise  = localNamespace getVariable ["APS_marketRise", 0.006];
    private _lastSales = _st getOrDefault ["lastSales", _idx apply { [_x param [0,""], _x param [2,0]] }];
    private _tickN = (_st getOrDefault ["tickN", 0]) + 1;
    _st set ["tickN", _tickN]; {if (_x isEqualType [] && {count _x >= 3}) then {_x params ["_c", "_prem", "_sales"];
        if (!(_prem isEqualType 0)  || {_prem < _floor}) then { _prem = 1 };
        if (!(_sales isEqualType 0) || {_sales < 0}) then { _sales = 0 };
        private _psi  = _lastSales findIf {(_x select 0) isEqualTo _c};
        private _prev = if (_psi >= 0) then { (_lastSales select _psi) select 1 } else { _sales };
        // idle (no NEW sales since last tick) -> premium climbs; actively-sold -> hold (the crash is
        // handled the moment sales >= APS_marketCrash in APS_fnc_stockUpdate).
        if (_sales <= _prev) then {
            // findIf (NOT forEach) -- a nested forEach here would clobber the outer _forEachIndex used by the
            // `_idx set [_forEachIndex,...]` below and write the wrong row.
            private _ovi  = _ov findIf { (_x select 0) isEqualTo _c };
            private _maxP = if (_ovi >= 0) then { (_ov select _ovi) param [2, _ceil] } else { _ceil };
            _prem = (_prem * (1 + _rise)) min _maxP;};
        _prem = _prem max _floor;
        _idx set [_forEachIndex, [_c, _prem, _sales]];};} forEach _idx;
AP_price_index = _idx;
publicVariable "AP_price_index";
{ private _v = localNamespace getVariable ("APS" + (_x select [2]));
    if !((missionNamespace getVariable [_x, objNull]) isEqualTo _v) then { missionNamespace setVariable [_x, +_v]; publicVariable _x; };
} forEach ["AP_marketFloor", "AP_marketMaxPrem", "AP_marketItemOv", "AP_drugBustGoods", "AP_drugBustUntil", "AP_marketGoods"];
_lastSales = _idx apply { [_x param [0,""], _x param [2,0]] };
    _st set ["lastSales", _lastSales];

if ((_tickN % 10) isEqualTo 0) then {private _smp = (_idx param [0, ["?",1,0]]);
    diag_log format ["[AP_marketTick] alive tick=%1 sample %2", _tickN, _smp];};}, _TICK, false, true] call AP_fnc_schedule;
