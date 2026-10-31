/*
    APS_fnc_createItem  (LooneyBin: spawn / grow a dropped-item pile) -- runs on the SERVER.
    Callers: fn_dropItem (manual Y-menu drop), fn_dropItems (death drop), fn_loginBonusGive, fn_chopTree,
    fn_openChristmasTreePresentCL -- all pass [_items, _pos, _class]:
        _items = [[shortName, amount], ...]   ("money" shortName carries cash) -- the virtual items dropped
        _pos   = position ASL
        _class = holder class, normally "Land_Suitcase_F" (forced to it for a client call)
    Was a logging-only STUB, so every drop decremented/cleared the player's inventory but no pile ever
    spawned -- items "just disappeared". Create a global holder, stash the items on it under AP_droppedItems
    (the var AP_fnc_menuPickupItems reads on pickup), and self-delete once the pile is emptied or after
    30 min so dropped cases don't accumulate forever.

    LooneyBin tweak (drop bug #8): every manual drop used to spawn its OWN suitcase, so a few drops left a
    heap of cases -- and as live-PhysX objects they spawned overlapping and violently ejected nearby
    vehicles/players. Now we (1) MERGE into a same-class pile already on the ground within 6 m (stacking
    like items) instead of making another case, and (2) disable simulation on any new case so it sits inert
    and can't punt things around. Net: one tidy, non-colliding pile per spot.
*/
params [["_items", [], [[]]], ["_pos", [0, 0, 0], [[]]], ["_class", "Land_Suitcase_F", [""]]];
if (_class isEqualTo "") then { _class = "Land_Suitcase_F"; };
if (_items isEqualTo []) exitWith {};
// owner 2026-06-23 SECURITY (security.md §2.1/§2.3 -- item/cash dupe): the client passes _items verbatim and
// fn_pickupItem credits them, incl. the "money" pseudo-item -> AP_cash. Any client could remoteExec a
// [["money",1e9]] pile and loot it. We can't fully validate the dropper's CLIENT-side inventory here (legit
// DEATH drops in fn_dropItems pass [money, AP_cash]), so this is a BOUNDED mitigation: structurally validate
// every entry (kills malformed/injection-ish), drop bad ones, hard-cap money + item amounts, and log oversized
// drops for CLANKR. FULL fix = server-authoritative cash/inventory (drop-system refactor) -- flagged §2.1.
// Audit 2026-09-26 (mints/TONa-0-3): that bound still let a client remoteExec [["money",1e7]] in a loop and walk
// over every pile ($10M a call), and name any string as an item. For a CLIENT call now:
//   * the holder is always a Land_Suitcase_F. Every legit caller sends exactly that, and a client-named class went
//     straight into createVehicle below -- any vehicle, at a chop-shop marker, is a second mint;
//   * the caller must resolve to a unit. A LIVING caller gets one call per second (a manual drop is already 3 s
//     apart client-side); a dead one is exempt, so a death drop never loses to a manual drop a moment earlier --
//     the budgets below bound him exactly the same;
//   * every name must be a virtItemCfg row. "newdrachma" (the server wallet) and the gift boxes (account-bound:
//     fn_dropItems never drops them and fn_dropItem refuses them) are refused outright;
//   * "money" is only ever legit as a DEATH drop (fn_dropItems; cash cannot be dropped by hand), so it is taken
//     only while the caller's unit is dead;
//   * duplicate names are folded first, then every entry draws on per-uid budgets per 30 minutes: cash-class
//     ("money", "bank_money") $1,000,000; weighted items 500 weight (a full death drop -- Carryall 96 + talents
//     220/224 = 132 at most -- plus the largest login-bonus overflow, day 92's 5 gold bars = 320); weightless
//     non-cash items (loonycoin) 100 units; and non-cash items $3,000,000 at the dearest price column of the
//     STATIC config row (not getMaxPrice, which an owner price override can move). virtItemCfg keeps those rows
//     in localNamespace, so no client publicVariable can rewrite the weight or price read here. The
//     excess is left out of the pile and logged, and a living caller is told what did not make it. A dying
//     player loses his inventory either way; the budgets only shrink the loot.
// Nothing over budget is refunded: a refund pays back what the CLIENT says it dropped, through a server-origin
// handleInv the item monitor trusts -- that is the laundering path, not a fix for it.
// State is in localNamespace so a client publicVariable cannot reset it. The exits are flat: an exitWith inside
// the `if` below would only leave that block, which is how the old empty-list exit never stopped anything.
// A cap hit logs -DROPCAP-, NOT -SEC-: honest play reaches these budgets (four full death drops in 30 minutes, a
// rich player dying with over $1M on him), and clankr turns every -SEC- row into a ban signal. So do the throttle
// and the living-cash refusal: a robbery drop can land <1 s after a manual one, and an engine/network ordering
// miss on the death stamp would refuse an honest death drop.
// "Dead" is the server's own EntityKilled stamp (server init.sqf, AP_diedAt, one use, 30 s), NOT `alive`:
// respawnDelay=0 and fn_onPlayerKilled is spawned, so a death drop arrives from the caller's new, LIVING unit.
private _src = remoteExecutedOwner;
private _rc = (allPlayers select { owner _x isEqualTo _src }) param [0, objNull];
if (_src != 0 && {isNull _rc}) exitWith {};
private _blocked = false;
if (_src != 0) then {
    _class = "Land_Suitcase_F";
    private _cashBudget = 1000000;
    private _wBudget    = 500;
    private _nwBudget   = 100;
    private _vBudget    = 3000000;
    private _uid = getPlayerUID _rc;
    private _died = localNamespace getVariable ["AP_diedAt", createHashMap];
    private _dead = !alive _rc || {diag_tickTime - (_died getOrDefault [_src, -1e9]) < 30};
    _died deleteAt _src;
    private _st = localNamespace getVariable "AP_createItemState";
    if (isNil "_st") then { _st = createHashMap; localNamespace setVariable ["AP_createItemState", _st]; };
    (_st getOrDefault [_uid, []]) params [["_last", -1e9], ["_winT0", diag_tickTime], ["_cashUsed", 0], ["_wUsed", 0], ["_nwUsed", 0], ["_vUsed", 0]];
    if (!_dead && {diag_tickTime - _last < 1}) exitWith {
        _blocked = true;
        ["-DROPCAP-", _rc, format ["createItem THROTTLED: %1 entries refused (<1 s since the last call)", count _items]] call APS_fnc_logIt;
    };
    if (diag_tickTime - _winT0 > 1800) then { _winT0 = diag_tickTime; _cashUsed = 0; _wUsed = 0; _nwUsed = 0; _vUsed = 0; };
    private _fold = createHashMap; {
        if (_x isEqualType [] && {count _x >= 2} && {(_x select 0) isEqualType ""} && {(_x select 1) isEqualType 0} && {(_x select 1) >= 1}) then {
            _fold set [_x select 0, (_fold getOrDefault [_x select 0, 0]) + floor (_x select 1)];};} forEach _items;
    private _clean = [];
    private _short = [];
    private _strippedTimber = 0; {
        private _n = _x;
        private _amt = _y;
        private _ln = toLower _n;
        private _row = ["getItemRow", _n] call AP_fnc_virtItemCfg;
        switch (true) do {
            case (_ln in ["timber","timberl","timberh"]): {
                // owner 2026-06-24: STRIP client-spawned timber. The ONLY legit fresh-timber path is now
                // APS_fnc_chopTreeSRV (server validates a real tree); a CLIENT createItem of timber is the mint
                // exploit (player093 76561190000000040). Trade-off: a manual/death DROP of carried timber is also lost --
                // rare, accepted to close the mint. Logged below.
                _strippedTimber = _strippedTimber + _amt;};
            case (_ln in ["newdrachma", "giftadmin", "gifthallo", "giftxmas"] || {_row isEqualTo []}): {
                _short pushBack _n;
                ["-SEC-", _rc, format ["createItem REFUSED '%1' x%2 (not a droppable virtual item)", _n, _amt]] call APS_fnc_logIt;};
            case (_ln isEqualTo "money" && {!_dead}): {
                ["-DROPCAP-", _rc, format ["createItem REFUSED a $%1 cash pile from a living player (cash only drops on death)", _amt]] call APS_fnc_logIt;};
            case (_ln in ["money", "bank_money"]): {
                private _ok = (_amt min (_cashBudget - _cashUsed)) max 0;
                if (_ok < _amt) then { _short pushBack _n;
                    ["-DROPCAP-", _rc, format ["createItem cash CAPPED %1 x%2 -> %3 ($%4 per 30 min budget)", _n, _amt, _ok, _cashBudget]] call APS_fnc_logIt;};
                _cashUsed = _cashUsed + _ok;
                if (_ok > 0) then { _clean pushBack [_n, _ok]; };};
            default {
                private _w = (_row param [2, 0]) max 0;
                private _p = selectMax [_row param [6, 0], _row param [7, 0], _row param [8, 0], 0];
                private _ok = if (_w > 0) then { floor ((_wBudget - _wUsed) / _w) } else { _nwBudget - _nwUsed };
                if (_p > 0) then { _ok = _ok min floor ((_vBudget - _vUsed) / _p); };
                _ok = (_amt min _ok) max 0;
                if (_ok < _amt) then { _short pushBack _n;
                    ["-DROPCAP-", _rc, format ["createItem CAPPED %1 x%2 -> %3 (30 min budget used: weight %4/%5, weightless %6/%7, value $%8/$%9)", _n, _amt, _ok, _wUsed, _wBudget, _nwUsed, _nwBudget, _vUsed, _vBudget]] call APS_fnc_logIt;};
                if (_w > 0) then { _wUsed = _wUsed + _ok * _w; } else { _nwUsed = _nwUsed + _ok; };
                _vUsed = _vUsed + _ok * _p;
                if (_ok > 0) then { _clean pushBack [_n, _ok]; };};
            };} forEach _fold;
    _st set [_uid, [diag_tickTime, _winT0, _cashUsed, _wUsed, _nwUsed, _vUsed]];
    if (_strippedTimber > 0) then {
        ["-SEC-", _rc, format ["createItem TIMBER stripped x%1 (mint attempt -- fresh timber only via a tree)", _strippedTimber]] call APS_fnc_logIt;
    };
    if (_short isNotEqualTo [] && {alive _rc}) then {
        private _names = _short apply { private _nm = ["getName", _x] call AP_fnc_virtItemCfg; if (isNil "_nm" || {_nm isEqualTo ""}) then { _x } else { _nm } };
        [[format ["Over the drop limit -- this did not make it into the pile and is gone: %1.", _names joinString ", "], "basic"], "AP_fnc_handleMessage", _rc, false, false] spawn AP_fnc_MP;
    };
    _items = _clean;};
if (_blocked || {_items isEqualTo []}) exitWith {};

// find an existing pile (same holder class, still holding items, not currently being looted) near the drop
private _existing = objNull; {
    if ( !((_x getVariable ["AP_droppedItems", []]) isEqualTo []) && {isNull (_x getVariable ["AP_inUse", objNull])} ) exitWith { _existing = _x; };
} forEach (nearestObjects [ASLToAGL _pos, [_class], 6]);

// merge onto the existing pile -- stack matching shortNames, append the rest -- and stop (no new case)
if (!isNull _existing) exitWith {private _cur = +(_existing getVariable ["AP_droppedItems", []]); {private _entry = _x;
        private _i = -1;
        { if ((_x select 0) isEqualTo (_entry select 0)) exitWith { _i = _forEachIndex; }; } forEach _cur;
        if (_i >= 0) then {(_cur select _i) set [1, ((_cur select _i) select 1) + (_entry select 1)];} else {_cur pushBack +_entry;};
    } forEach _items;
    _existing setVariable ["AP_droppedItems", _cur, true];};

private _holder = createVehicle [_class, [0, 0, 0], [], 0, "CAN_COLLIDE"];
// the LOOT CARD shows the real despawn clock; serverTime is comparable on
// clients, unlike the `time` the cleanup loop below runs on (same 30min window)
_holder setVariable ["AP_dropUntilSrv", serverTime + 1800, true];
_holder setPosASL _pos;
// inert: no PhysX, no damage -- the case can't ragdoll itself or shove vehicles/players (drop bug #8)
_holder enableSimulationGlobal false;
_holder allowDamage false;
_holder setVariable ["AP_droppedItems", _items, true];
_holder setVariable ["AP_inUse", nil, true];

// housekeeping: delete the pile once it's been picked clean (and nobody is in it) or after 30 minutes.
[_holder] spawn {params ["_h"];
    private _start   = time;
    private _minLife = 1200;            // LooneyBin: dropped briefcases live >= 20 min even if picked clean
    private _end     = time + 1800;     // hard cap 30 min
    waitUntil {uiSleep 30;
        isNull _h || time > _end ||
        ((time - _start >= _minLife) && ((_h getVariable ["AP_droppedItems", []]) isEqualTo []) && isNull (_h getVariable ["AP_inUse", objNull]))
    };
    if (!isNull _h) then { deleteVehicle _h; };};
