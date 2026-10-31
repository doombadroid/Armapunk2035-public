/*
    APS_fnc_stockUpdate -- the market's sell/buy hook (client -> server, CfgRE allowedTargets 2).

    [_cls, _qty]   _qty > 0 = SELL: pushes the good's prem DOWN toward the FLOOR (oversupply) and counts toward
                   the sales counter. _qty < 0 = BUY: restores prem toward the CEIL by the same per-unit amount and
                   gives the counter back, so a buy<->sell round-trip is price-neutral (owner 2026-07-07). Idle
                   ticks in APS_fnc_marketTick recover prem. Per-unit move = (1 - FLOOR) / DEPTH, DEPTH = the
                   good's per-item dropDepth else APS_marketCrash, so DEPTH units cross the whole band.

    Replaces the "AP_stock_update" publicVariable handler (eventhandlers.sqf, deleted 2026-09-26). Everything it
    reads is server-only (localNamespace, set by APS_fnc_marketTick) -- the AP_ copies are client display values
    that any client can overwrite with its own publicVariable.

    Trades are client-authoritative, so _qty cannot be derived server-side. Two bounds instead: one call moves at
    most DEPTH, and each caller (remoteExecutedOwner) gets a NET budget of +/-DEPTH per good per 10 minutes --
    one full legit dump already takes a good across the whole band, so a real seller loses nothing, while one
    forged client can no longer hammer the shared price every few seconds.
*/
params [["_cls", "", [""]], ["_qty", 0, [0]]];
if (!isServer || {_cls isEqualTo ""} || {!(finite _qty)}) exitWith {};
private _idx = localNamespace getVariable ["APS_priceIndex", []];
private _i = _idx findIf {(_x isEqualType []) && {(_x param [0, ""]) isEqualTo _cls}};
if (_i < 0) exitWith {};

private _floor = localNamespace getVariable ["APS_marketFloor", 0.6];
private _depth = localNamespace getVariable ["APS_marketCrash", 2500];
private _maxP  = localNamespace getVariable ["APS_marketMaxPrem", 1.3];
{ if ((_x select 0) isEqualTo _cls) exitWith { _depth = _x param [1, _depth]; _maxP = _x param [2, _maxP]; }; } forEach (localNamespace getVariable ["APS_marketItemOv", []]);
if (_depth < 1) then { _depth = 1 };
_qty = (_qty max (0 - _depth)) min _depth;

// ponytail: fixed 10-min window per (owner, good); a server-side trade record would let qty be derived instead.
if (isRemoteExecuted) then {
    private _src = remoteExecutedOwner;
    private _budget = localNamespace getVariable "APS_stockBudget";
    if (isNil "_budget") then { _budget = createHashMap; localNamespace setVariable ["APS_stockBudget", _budget]; };
    private _key = format ["%1|%2", _src, _cls];
    (_budget getOrDefault [_key, [-1e9, 0]]) params ["_t0", "_net"];
    if ((serverTime - _t0) > 600) then { _t0 = serverTime; _net = 0; };
    private _want = _qty;
    _qty = (((_net + _qty) max (0 - _depth)) min _depth) - _net;
    _budget set [_key, [_t0, _net + _qty]];
    if (_qty isNotEqualTo _want) then {
        private _caller = (allPlayers select {owner _x == _src}) param [0, objNull];
        // NOT -SEC-: one honest bulk sell crosses DEPTH, and clankr turns every -SEC- row into a ban signal.
        ["-MARKET-", _caller, format ["throttled stockUpdate %1 qty %2 -> %3 (net %4 of +/-%5 per 10 min)", _cls, _want, _qty, _net + _qty, _depth]] call APS_fnc_logIt;
    };
};
if (_qty isEqualTo 0) exitWith {};

private _row   = _idx select _i;
private _prem  = _row param [1, 1]; if (!(_prem isEqualType 0)  || {_prem < _floor}) then { _prem = 1 };
private _prem0 = _prem;   // publish the per-good sync only when the premium actually moves
private _sales = _row param [2, 0]; if (!(_sales isEqualType 0) || {_sales < 0}) then { _sales = 0 };
private _step  = (abs _qty) * ((1.0 - _floor) / _depth);
if (_qty > 0) then {_sales = _sales + _qty;          // SELL: accumulate toward the crash counter, drop prem
    _prem  = (_prem - _step) max _floor;} else {
    _sales = (_sales + _qty) max 0;                   // BUY: give back the counter (qty<0), raise prem
    _prem  = (_prem + _step) min _maxP;};
_idx set [_i, [_cls, _prem, _sales]];

// keep each client's per-good premium in sync (initPlayerLocal applies AP_stock_change -> index 1).
if (_prem isNotEqualTo _prem0) then {AP_stock_change = [_cls, _prem];
    publicVariable "AP_stock_change";};
