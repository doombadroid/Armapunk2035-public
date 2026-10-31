#include "..\..\macro.h"
/*
    AP_fnc_deckExchange -- the deck's EXCHANGE app (approved mock deck-exchange).

    Browse / buy / my-listings / vault over the existing exchange backend
    (APS_fnc_exchangeSystemSRV). The money boundary is the NATIVE one on
    purpose: the buyer still debits client-side before the mode-1/2/3 call,
    because fixing that is P4 (server-authoritative money + escrow) and doing
    it here would fork the trust model mid-wave. Every guard the native buy
    enforced is enforced here -- stock clamp, bank check, restart window, the
    lag check -- just fed by parameters instead of ctrlText.

    v1 SCOPE, stated where it can refuse: CREATE LISTING stays on the NPC's
    native flow (it reads a trunk interactively), and the vault retrieves
    VIRTUAL goods only -- physical gear and vehicles still collect at the
    storage terminal. Both refusals name the place to go.

    Verbs:
      ["fetch"]                      spawned -- the open dance, then push
      ["data"]                       payload for the "exchange" channel
      ["avail", <class>]             spawned -- mode-5 search for one class
      ["buy", <exID>, <qty>]         spawned -- ported purchase, all 3 kinds
      ["retract", <exID>]            mode 4
      ["take", <storageID>, <qty>]   vault withdraw, virtual only
*/
params [["_verb", "", [""]], ["_a", 0, [0, ""]], ["_b", 0, [0]]];

private _no   = { params ["_m"]; createHashMapFromArray [["ok", false], ["msg", _m]] };
private _yes  = { params ["_m"]; createHashMapFromArray [["ok", true],  ["msg", _m]] };
private _push = {
    private _c = uiNamespace getVariable ["WEBUI_ctrl", controlNull];
    if (!isNull _c) then { [_c, "exchange", (["data"] call AP_fnc_deckExchange)] call webui_fnc_push; };
};

switch (toLower _verb) do {

// The native open's fetch dance (fn_exchangeMenu:7-16), spawned so the JSDialog
// handler never blocks. Bug B's lesson is kept: storage waits on the STORAGE
// flag, mode 6 -- not mode 7, which sets the other one.
case "fetch": {
    [] spawn {
        if !(SRV_exchangeIsReady) exitWith {
            private _c = uiNamespace getVariable ["WEBUI_ctrl", controlNull];
            if (!isNull _c) then { [_c, "exchange", createHashMapFromArray [["down", true]]] call webui_fnc_push; };
        };
        if (AP_exchangePlayerOwnedListings isEqualTo [] || AP_exchangeAllListings isEqualTo [] || !AP_exchangeRequested) then {
            AP_exchangeRequested = false;
            [[5, [0, getPlayerUID player, player]], "APS_fnc_exchangeSystemSRV", 2] call AP_fnc_MP;
            waitUntil { uiSleep 0.1; AP_exchangeRequested };
        };
        AP_exchangeRequested = false;
        if (AP_exchangeStorageMaxListings isEqualTo [0, 0] || !AP_exchangeStorageRequested) then {
            AP_exchangeStorageRequested = false;
            [[6, [0, getPlayerUID player, player]], "APS_fnc_exchangeSystemSRV", 2] call AP_fnc_MP;
            waitUntil { uiSleep 0.1; AP_exchangeStorageRequested };
        };
        AP_exchangeStorageRequested = false;
        private _c = uiNamespace getVariable ["WEBUI_ctrl", controlNull];
        if (!isNull _c) then { [_c, "exchange", (["data"] call AP_fnc_deckExchange)] call webui_fnc_push; };
    };
    ["fetching"] call _yes
};

case "data": {
    // Whitelist -> categories and class->category. The listing pool is the
    // top-cheapest-per-type set the server hands every browser; a per-class
    // AVAIL search refreshes it for that class. Counts are of FETCHED rows and
    // the page labels them as such -- nothing stores sale history, so there is
    // no "last sale" to fake.
    private _cfg = ["getCfg"] call AP_fnc_exchangeCfg;
    private _catOf = createHashMap;
    private _cats = createHashMap;
    {
        _x params ["_cat", "_class"];
        _catOf set [_class, _cat];
        _cats set [_cat, (_cats getOrDefault [_cat, []]) + [_class]];
    } forEach _cfg;

    private _rows = [];
    {
        _x params ["_exID", "_uid", "_pname", "_class", "_vehID", "_price", "_qty", "_isVirt", "_isPhys", "_isVeh", "_expArr", "_crArr"];
        ([_class] call AP_fnc_fetchCfgDetails) params ["", "_dName", ""];
        _rows pushBack (createHashMapFromArray [
            ["id", _exID], ["seller", _pname], ["mine", _uid isEqualTo (getPlayerUID player)],
            ["class", _class], ["name", _dName], ["cat", _catOf getOrDefault [_class, "Other"]],
            ["price", _price], ["qty", _qty],
            ["kind", switch (true) do { case (_isVeh isEqualTo 1): {"vehicle"}; case (_isPhys isEqualTo 1): {"physical"}; default {"virtual"} }],
            ["exp", format ["%1d %2h", _expArr param [0, 0], _expArr param [1, 0]]]
        ]);
    } forEach AP_exchangeAllListings;

    private _mine = [];
    {
        _x params ["_exID", "_uid", "_pname", "_class", "_vehID", "_price", "_qty", "_isVirt", "_isPhys", "_isVeh", "_expArr"];
        ([_class] call AP_fnc_fetchCfgDetails) params ["", "_dName", ""];
        _mine pushBack (createHashMapFromArray [
            ["id", _exID], ["class", _class], ["name", _dName],
            ["price", _price], ["qty", _qty],
            ["exp", format ["%1d %2h", _expArr param [0, 0], _expArr param [1, 0]]]
        ]);
    } forEach AP_exchangePlayerOwnedListings;

    private _vault = [];
    {
        // storage rows are [stID, purchaserUID, boughtFromUID, class, qty, price,
        // isVirt, isPhys, expires, bought] -- fn_exchangeStorageMenuSelection:24
        _x params ["_stID", "", "", "_class", "_qty", "", "_isVirt", "_isPhys"];
        ([_class] call AP_fnc_fetchCfgDetails) params ["", "_dName", ""];
        _vault pushBack (createHashMapFromArray [
            ["id", _stID], ["class", _class], ["name", _dName], ["qty", _qty],
            ["kind", if (_isVirt isEqualTo 1) then {"virtual"} else {"physical"}]
        ]);
    } forEach AP_exchangeStorage;

    private _catRows = [];
    {
        _catRows pushBack (createHashMapFromArray [["id", _x], ["n", count (_cats get _x)]]);
    } forEach (keys _cats);

    // 741 whitelist rows x a config walk each is too expensive per push; the
    // catalogue cannot change mid-session, so build it once.
    if (isNil "AP_deckExchClasses") then {
        AP_deckExchClasses = _cfg apply { createHashMapFromArray [
            ["class", _x select 1], ["cat", _x select 0],
            ["name", (([_x select 1] call AP_fnc_fetchCfgDetails) param [1, _x select 1])],
            ["fee", _x select 6]
        ] };
    };
    createHashMapFromArray [
        ["cats", _catRows], ["classes", AP_deckExchClasses],
        ["rows", _rows], ["mine", _mine], ["vault", _vault],
        ["bank", AP_atmcash], ["nd", AP_nd toFixed 4],
        ["down", !SRV_exchangeIsReady]
    ]
};

case "avail": {
    private _class = _a;
    if !(_class isEqualType "") exitWith { ["bad class"] call _no };
    [_class] spawn {
        params ["_class"];
        AP_exchangeRequested = false;
        [[5, [1, getPlayerUID player, player, _class]], "APS_fnc_exchangeSystemSRV", 2] call AP_fnc_MP;
        waitUntil { uiSleep 0.1; AP_exchangeRequested };
        AP_exchangeRequested = false;
        private _c = uiNamespace getVariable ["WEBUI_ctrl", controlNull];
        if (!isNull _c) then { [_c, "exchange", (["data"] call AP_fnc_deckExchange)] call webui_fnc_push; };
    };
    ["checking availability"] call _yes
};

case "buy": {
    private _exID = _a;
    private _want = _b max 1;
    private _row = AP_exchangeAllListings param [
        AP_exchangeAllListings findIf { (_x param [0, -1]) isEqualTo _exID }, []];
    if (_row isEqualTo []) exitWith { ["That listing is gone -- refresh."] call _no };
    _row params ["", "_uid", "_pname", "_class", "_vehID", "_price", "_qty", "_isVirt", "_isPhys", "_isVeh"];
    if (_uid isEqualTo (getPlayerUID player)) exitWith { ["That is your own listing -- retract it instead."] call _no };
    if (_want > _qty) exitWith { [format ["Only %1 in stock.", _qty]] call _no };
    if ((_isVeh isEqualTo 1) && {AP_garageCount >= call AP_maxGarageVeh}) exitWith {
        [format ["Garage full (%1/%2) -- sell or destroy a vehicle first.", AP_garageCount, call AP_maxGarageVeh]] call _no };
    private _qtyEff = if (_isVirt isEqualTo 1 || _isPhys isEqualTo 1) then { _want } else { 1 };
    private _total = _qtyEff * _price;
    if (AP_atmcash < _total) exitWith {
        [format ["You need $%1 in the bank for that.", [_total] call AP_fnc_numberText]] call _no };
    if ((serverCycleLength - (serverTime - serverStartTime)) <= 180) exitWith {
        ["The exchange closes just before a restart."] call _no };

    [_exID, _class, _price, _qtyEff, _total, _isVirt, _isPhys, _isVeh, _uid, _pname] spawn {
        params ["_exID", "_class", "_price", "_qtyEff", "_total", "_isVirt", "_isPhys", "_isVeh", "_uid", "_pname"];
        // The native lag check, verbatim: a stalled server must refuse the buy,
        // not eat the money and answer nothing.
        private _randID = AP_lagRandomID;
        AP_didServerRespond = false;
        private _maxDelayTime = time + 5;
        [[player], "APS_fnc_lagCheck", 2] spawn AP_fnc_MP;
        waitUntil { time > _maxDelayTime || AP_didServerRespond };
        private _c = uiNamespace getVariable ["WEBUI_ctrl", controlNull];
        if (time > _maxDelayTime) exitWith {
            if (!isNull _c) then { [_c, "exchange", (["data"] call AP_fnc_deckExchange)] call webui_fnc_push; };
            ["Exchange failed (server busy) -- money untouched. Try again.", "basic"] spawn AP_fnc_handleMessage;
        };
        if !(_randID isEqualTo AP_lagRandomID) exitWith {};
        AP_atmcash = AP_atmcash - _total;
        AP_atmcashCacheB = ((AP_atmcash / 4) + 11);
        [1] call AP_fnc_ClupdatePartial;
        private _mode = switch (true) do { case (_isVeh isEqualTo 1): {2}; case (_isPhys isEqualTo 1): {3}; default {1} };
        private _kindWord = switch (_mode) do { case 2: {"vehicle"}; case 3: {"physical item"}; default {"virtual item"} };
        [["-EXCHANGEPURCHASE-", player, profileName, format ["ID: %1, deck-purchased a %2 listing from (%3)(%4), Item: %5, Qty: %6, Total: $%7",
            _exID, _kindWord, _uid, _pname, _class, _qtyEff, [_total] call AP_fnc_numberText]], "APS_fnc_logIt", 2] spawn AP_fnc_MP;
        if (_mode isEqualTo 2) then {
            [[2, [2, _exID, player, _class, _price]], "APS_fnc_exchangeSystemSRV", 2] call AP_fnc_MP;
        } else {
            [[_mode, [2, _exID, player, _class, _price, _qtyEff]], "APS_fnc_exchangeSystemSRV", 2] call AP_fnc_MP;
        };
        // The server answers by refilling the listing pool; re-fetch and push so
        // the row the player just bought does not sit there looking buyable.
        uiSleep 1.2;
        AP_exchangeRequested = false;
        [[5, [0, getPlayerUID player, player]], "APS_fnc_exchangeSystemSRV", 2] call AP_fnc_MP;
        waitUntil { uiSleep 0.1; AP_exchangeRequested };
        AP_exchangeRequested = false;
        if (!isNull _c) then { [_c, "exchange", (["data"] call AP_fnc_deckExchange)] call webui_fnc_push; };
    };
    [format ["Purchase sent -- $%1.", [_total] call AP_fnc_numberText]] call _yes
};

case "retract": {
    private _exID = _a;
    private _row = AP_exchangePlayerOwnedListings param [
        AP_exchangePlayerOwnedListings findIf { (_x param [0, -1]) isEqualTo _exID }, []];
    if (_row isEqualTo []) exitWith { ["Not your listing."] call _no };
    _row params ["", "", "", "_class"];
    [[4, [_exID, player, getPlayerUID player, _class]], "APS_fnc_exchangeSystemSRV", 2] call AP_fnc_MP;
    [_exID] spawn {
        params ["_exID"];
        uiSleep 1.2;
        AP_exchangeRequested = false;
        [[5, [0, getPlayerUID player, player]], "APS_fnc_exchangeSystemSRV", 2] call AP_fnc_MP;
        waitUntil { uiSleep 0.1; AP_exchangeRequested };
        AP_exchangeRequested = false;
        private _c = uiNamespace getVariable ["WEBUI_ctrl", controlNull];
        if (!isNull _c) then { [_c, "exchange", (["data"] call AP_fnc_deckExchange)] call webui_fnc_push; };
    };
    ["Retract sent -- it lands in your vault."] call _yes
};

case "take": {
    private _stID = _a;
    private _want = _b max 0;
    private _row = AP_exchangeStorage param [
        AP_exchangeStorage findIf { (_x param [0, -1]) isEqualTo _stID }, []];
    if (_row isEqualTo []) exitWith { ["Nothing there."] call _no };
    _row params ["", "", "", "_class", "_qty", "", "_isVirt"];
    if !(_isVirt isEqualTo 1) exitWith {
        ["Gear and vehicles collect at the Exchange storage terminal -- this app hands out virtual goods only."] call _no };
    if (_want <= 0 || _want > _qty) then { _want = _qty };
    // Weight-clamped exactly like the native (fn_exchangeStorageMenuManage:43-61):
    // take what fits, leave the remainder listed.
    private _wEach = ["getItemWeight", _class] call AP_fnc_virtItemCfg;
    if !(_wEach isEqualType 0) then { _wEach = 1 };
    private _fit = if (_wEach <= 0) then { _want } else {
        floor ((AP_maxWeight - AP_carryWeight) / _wEach) min _want };
    if (_fit <= 0) exitWith { ["You cannot carry any more."] call _no };
    if !([true, _class, _fit] call AP_fnc_handleInv) exitWith { ["Could not add to inventory."] call _no };
    private _left = _qty - _fit;
    [[6, [1, getPlayerUID player, player, _stID, [_class, _left]]], "APS_fnc_exchangeSystemSRV", 2] call AP_fnc_MP;
    // mirror locally so the very next data build shows the truth
    if (_left <= 0) then {
        AP_exchangeStorage deleteAt (AP_exchangeStorage findIf { (_x param [0, -1]) isEqualTo _stID });
    } else {
        (AP_exchangeStorage select (AP_exchangeStorage findIf { (_x param [0, -1]) isEqualTo _stID })) set [4, _left];
    };
    call _push;
    [format ["Took %1.", _fit]] call _yes
};

// ═════════════════════════════════════════════ SELL SIDE (needstest) ═══════
// The native fn_exchangeCreateListing was an interactive chain: a guiMessage
// per trunk item, an input dialog for the price, a confirm for the fee. The
// deck replaces the CHAIN, not the rules -- every bound, fee, lock and the lag
// check are the native's, fed by parameters. The trunk lock is held only
// across the commit instead of the whole browse, because the page reads a
// SNAPSHOT and the commit re-reads the trunk under the lock before touching it.

case "sellables": {
    // caps ride AP_exchangeMaxListings; fire the mode-7 refresh and snapshot
    // what we have -- the sell verbs re-check under their own fetch anyway
    [] spawn {
        AP_exchangeRequested = false;
        [[7, [0, getPlayerUID player, player]], "APS_fnc_exchangeSystemSRV", 2] call AP_fnc_MP;
        waitUntil { uiSleep 0.1; AP_exchangeRequested };
        AP_exchangeRequested = false;
        private _c = uiNamespace getVariable ["WEBUI_ctrl", controlNull];
        if (!isNull _c) then { [_c, "exchange", (["data"] call AP_fnc_deckExchange)] call webui_fnc_push; };
    };
    private _nearVehicles = nearestObjects [player, ["Car", "Air", "Ship"], 35];
    private _veh = _nearVehicles param [_nearVehicles findIf {
        (((_x getVariable ["AP_vehOwners", [[]]] param [0, []]) param [0, ""]) isEqualTo getPlayerUID player)
        && ((_x getVariable ["AP_activeTrunk", objNull]) isEqualTo objNull)
        && ((_x getVariable ["AP_veh_in_use", objNull]) isEqualTo objNull)
        && alive _x }, objNull];

    private _virt = [];
    private _phys = [];
    if (!isNull _veh) then {
        private _wlVirt = [1, "virtualItem"] call AP_fnc_exchangeCfg;
        {
            _x params ["_vItem", "_n"];
            if (!((_wlVirt findIf { _vItem in _x }) isEqualTo -1)) then {
                _virt pushBack (createHashMapFromArray [
                    ["id", _vItem], ["name", ["getName", _vItem] call AP_fnc_virtItemCfg],
                    ["qty", _n],
                    ["minQ", ["getMinimumQuantity", _vItem] call AP_fnc_exchangeCfg],
                    ["maxQ", ["getMaximumQuantity", _vItem] call AP_fnc_exchangeCfg],
                    ["minP", ["getMinimumPrice", _vItem] call AP_fnc_exchangeCfg],
                    ["maxP", ["getMaximumPrice", _vItem] call AP_fnc_exchangeCfg]
                ]);
            };
        } forEach ((_veh getVariable ["AP_vinv", [[], 0]]) select 0);
        private _wlPhys = ([1, "Weapons"] call AP_fnc_exchangeCfg) + ([1, "Ammo"] call AP_fnc_exchangeCfg)
            + ([1, "Attachments"] call AP_fnc_exchangeCfg) + ([1, "Headgear"] call AP_fnc_exchangeCfg)
            + ([1, "Glasses"] call AP_fnc_exchangeCfg) + ([1, "Vests"] call AP_fnc_exchangeCfg)
            + ([1, "Uniforms"] call AP_fnc_exchangeCfg) + ([1, "Backpacks"] call AP_fnc_exchangeCfg);
        {
            _x params ["_pItem", "_n"];
            if (_pItem in _wlPhys) then {
                _phys pushBack (createHashMapFromArray [
                    ["id", _pItem], ["name", ([_pItem] call AP_fnc_fetchCfgDetails) param [1, _pItem]],
                    ["qty", _n],
                    ["minP", ["getMinimumPrice", _pItem] call AP_fnc_exchangeCfg],
                    ["maxP", ["getMaximumPrice", _pItem] call AP_fnc_exchangeCfg]
                ]);
            };
        } forEach (([getItemCargo _veh] call AP_fnc_formatContainer) + ([getWeaponCargo _veh] call AP_fnc_formatContainer)
            + ([getMagazineCargo _veh] call AP_fnc_formatContainer) + ([getBackpackCargo _veh] call AP_fnc_formatContainer));
    };

    // vehicles: the aimed-at one first, else every owned whitelisted one nearby
    private _wlVeh = [1, "vehicle"] call AP_fnc_exchangeCfg;
    private _vehRows = [];
    {
        private _cn = typeOf _x;
        private _db = _x getVariable ["AP_dbInfo", []];
        if (alive _x && {(_cn in _wlVeh)} && {(_db param [0, ""]) isEqualTo getPlayerUID player}
            && {(_db param [1, ""]) isNotEqualTo ""}) then {
            (getItemCargo _x) params [["_ci", []]];
            private _hasCargo = ((_x getVariable ["AP_vinv", [[], 0]]) select 1 > 0)
                || {(count ((getWeaponCargo _x) select 0)) + (count ((getMagazineCargo _x) select 0)) > 0}
                || {(_ci findIf { _x find "Toolkit" isEqualTo -1 && _x != "FirstAidKit" }) isNotEqualTo -1};
            _vehRows pushBack (createHashMapFromArray [
                ["net", netId _x],
                ["name", [configFile >> "CfgVehicles" >> _cn] call BIS_fnc_displayName],
                ["minP", ["getMinimumPrice", _cn] call AP_fnc_exchangeCfg],
                ["maxP", ["getMaximumPrice", _cn] call AP_fnc_exchangeCfg],
                ["cargo", _hasCargo],
                ["dist", round (player distance _x)]
            ]);
        };
    } forEach _nearVehicles;

    AP_exchangeMaxListings params [["_mVirt", 0], ["_mPhys", 0], ["_mVeh", 0]];
    createHashMapFromArray [
        ["truck", if (isNull _veh) then { "" } else {
            [configFile >> "CfgVehicles" >> (typeOf _veh)] call BIS_fnc_displayName }],
        ["truckNet", if (isNull _veh) then { "" } else { netId _veh }],
        ["virt", _virt], ["phys", _phys], ["vehs", _vehRows],
        ["caps", [_mVirt, _mPhys, _mVeh]],
        ["fee", 5], ["bank", AP_atmcash]
    ]
};

case "sellvirt": {
    private _class = _a;
    private _price = _b;
    if !(_class isEqualType "") exitWith { ["bad class"] call _no };
    [_class, _price] spawn {
        params ["_class", "_price"];
        private _say = { params ["_m"]; [_m, "basic"] spawn AP_fnc_handleMessage };
        private _pushX = {
            private _c = uiNamespace getVariable ["WEBUI_ctrl", controlNull];
            if (!isNull _c) then { [_c, "exchange", (["data"] call AP_fnc_deckExchange)] call webui_fnc_push; };
        };
        // caps, fresh -- the native fetched before every listing
        AP_exchangeRequested = false;
        [[7, [0, getPlayerUID player, player]], "APS_fnc_exchangeSystemSRV", 2] call AP_fnc_MP;
        waitUntil { uiSleep 0.1; AP_exchangeRequested };
        AP_exchangeRequested = false;
        if ((AP_exchangeMaxListings param [0, 0]) >= 20) exitWith { ["You already hold 20 virtual-item listings."] call _say };

        private _nearVehicles = nearestObjects [player, ["Car", "Air", "Ship"], 35];
        private _veh = _nearVehicles param [_nearVehicles findIf {
            (((_x getVariable ["AP_vehOwners", [[]]] param [0, []]) param [0, ""]) isEqualTo getPlayerUID player)
            && ((_x getVariable ["AP_activeTrunk", objNull]) isEqualTo objNull)
            && ((_x getVariable ["AP_veh_in_use", objNull]) isEqualTo objNull)
            && alive _x }, objNull];
        if (isNull _veh) exitWith { ["No idle vehicle of yours within 35 m."] call _say };
        if (_veh getVariable ["AP_trunkLock", false]) exitWith { ["That trunk is being saved -- a moment."] call _say };

        _veh setVariable ["AP_activeTrunk", player, true];
        _veh setVariable ["AP_veh_in_use", player, true];
        private _unlock = { _veh setVariable ["AP_activeTrunk", nil, true]; _veh setVariable ["AP_veh_in_use", nil, true]; };

        (_veh getVariable ["AP_vinv", [[], 0]]) params [["_vehItems", []], ["_vehWeight", 0]];
        private _idx = _vehItems findIf { (_x select 0) isEqualTo _class };
        if (_idx isEqualTo -1) exitWith { call _unlock; ["That item is no longer in the trunk."] call _say };
        private _amt = (_vehItems select _idx) select 1;
        if (_amt < (["getMinimumQuantity", _class] call AP_fnc_exchangeCfg)) exitWith {
            call _unlock; [format ["You need at least %1 to list.", ["getMinimumQuantity", _class] call AP_fnc_exchangeCfg]] call _say };
        if (_amt > (["getMaximumQuantity", _class] call AP_fnc_exchangeCfg)) exitWith {
            call _unlock; [format ["No more than %1 may be listed at once.", ["getMaximumQuantity", _class] call AP_fnc_exchangeCfg]] call _say };
        if (_price < (["getMinimumPrice", _class] call AP_fnc_exchangeCfg)) exitWith {
            call _unlock; [format ["Minimum price is $%1.", [["getMinimumPrice", _class] call AP_fnc_exchangeCfg] call AP_fnc_numberText]] call _say };
        if (_price > (["getMaximumPrice", _class] call AP_fnc_exchangeCfg)) exitWith {
            call _unlock; [format ["Maximum price is $%1.", [["getMaximumPrice", _class] call AP_fnc_exchangeCfg] call AP_fnc_numberText]] call _say };
        private _fee = (_price * _amt) * 0.05;
        if (AP_atmcash < _fee) exitWith { call _unlock;
            [format ["The 5%2 listing fee is $%1 -- you cannot cover it.", [_fee] call AP_fnc_numberText, "%"]] call _say };
        if ((serverCycleLength - (serverTime - serverStartTime)) <= 180) exitWith {
            call _unlock; ["The exchange closes just before a restart."] call _say };

        private _randID = AP_lagRandomID;
        AP_didServerRespond = false;
        private _maxDelayTime = time + 5;
        [[player], "APS_fnc_lagCheck", 2] spawn AP_fnc_MP;
        waitUntil { time > _maxDelayTime || AP_didServerRespond };
        if (time > _maxDelayTime) exitWith { call _unlock; ["Exchange failed, try again."] call _say };
        if !(_randID isEqualTo AP_lagRandomID) exitWith { call _unlock; ["Please wait for the exchange..."] call _say };

        AP_atmcash = AP_atmcash - _fee;
        AP_atmcashCacheB = ((AP_atmcash / 4) + 11);
        [1] call AP_fnc_ClupdatePartial;
        _vehItems deleteAt _idx;
        _vehWeight = _vehWeight - (_amt * (["getItemWeight", _class] call AP_fnc_virtItemCfg));
        _veh setVariable ["AP_vinv", [_vehItems, _vehWeight], true];
        call _unlock;
        [[1, [1, player, getPlayerUID player, _class, _price, _amt, _fee]], "APS_fnc_exchangeSystemSRV", 2] spawn AP_fnc_MP;
        [["-EXCHANGELISTED-", player, profileName, format ["Deck-listed virtual: Item: %1, Qty: %2, Price: $%3, Fee: $%4",
            ["getName", _class] call AP_fnc_virtItemCfg, _amt, [_price] call AP_fnc_numberText, [_fee] call AP_fnc_numberText]],
            "APS_fnc_logIt", 2] spawn AP_fnc_MP;
        [format ["Listed %1 x %2 at $%3 each (fee $%4). Unsold in 7 days lands in your vault.",
            _amt, ["getName", _class] call AP_fnc_virtItemCfg, [_price] call AP_fnc_numberText, [_fee] call AP_fnc_numberText], "exchange"] spawn AP_fnc_handleMessage;
        uiSleep 1.2;
        AP_exchangeRequested = false;
        [[5, [0, getPlayerUID player, player]], "APS_fnc_exchangeSystemSRV", 2] call AP_fnc_MP;
        waitUntil { uiSleep 0.1; AP_exchangeRequested };
        AP_exchangeRequested = false;
        call _pushX;
    };
    ["Listing sent."] call _yes
};

case "sellphys": {
    private _class = _a;
    private _price = _b;
    if !(_class isEqualType "") exitWith { ["bad class"] call _no };
    [_class, _price] spawn {
        params ["_class", "_price"];
        private _say = { params ["_m"]; [_m, "basic"] spawn AP_fnc_handleMessage };
        AP_exchangeRequested = false;
        [[7, [0, getPlayerUID player, player]], "APS_fnc_exchangeSystemSRV", 2] call AP_fnc_MP;
        waitUntil { uiSleep 0.1; AP_exchangeRequested };
        AP_exchangeRequested = false;
        if ((AP_exchangeMaxListings param [1, 0]) >= 20) exitWith { ["You already hold 20 physical-item listings."] call _say };

        private _nearVehicles = nearestObjects [player, ["Car", "Air", "Ship"], 35];
        private _veh = _nearVehicles param [_nearVehicles findIf {
            (((_x getVariable ["AP_vehOwners", [[]]] param [0, []]) param [0, ""]) isEqualTo getPlayerUID player)
            && ((_x getVariable ["AP_activeTrunk", objNull]) isEqualTo objNull)
            && ((_x getVariable ["AP_veh_in_use", objNull]) isEqualTo objNull)
            && alive _x }, objNull];
        if (isNull _veh) exitWith { ["No idle vehicle of yours within 35 m."] call _say };
        _veh setVariable ["AP_activeTrunk", player, true];
        _veh setVariable ["AP_veh_in_use", player, true];
        private _unlock = { _veh setVariable ["AP_activeTrunk", nil, true]; _veh setVariable ["AP_veh_in_use", nil, true]; };

        private _pre = +(([getItemCargo _veh] call AP_fnc_formatContainer) + ([getWeaponCargo _veh] call AP_fnc_formatContainer)
            + ([getMagazineCargo _veh] call AP_fnc_formatContainer) + ([getBackpackCargo _veh] call AP_fnc_formatContainer));
        private _idx = _pre findIf { (_x select 0) isEqualTo _class };
        if (_idx isEqualTo -1) exitWith { call _unlock; ["That item is no longer in the trunk."] call _say };
        private _sel = _pre select _idx;
        private _amt = _sel select 1;
        private _new = _pre - [_sel];
        if (_price < (["getMinimumPrice", _class] call AP_fnc_exchangeCfg)) exitWith {
            call _unlock; [format ["Minimum price is $%1.", [["getMinimumPrice", _class] call AP_fnc_exchangeCfg] call AP_fnc_numberText]] call _say };
        if (_price > (["getMaximumPrice", _class] call AP_fnc_exchangeCfg)) exitWith {
            call _unlock; [format ["Maximum price is $%1.", [["getMaximumPrice", _class] call AP_fnc_exchangeCfg] call AP_fnc_numberText]] call _say };
        private _fee = (_price * _amt) * 0.05;
        if (AP_atmcash < _fee) exitWith { call _unlock;
            [format ["The 5%2 listing fee is $%1 -- you cannot cover it.", [_fee] call AP_fnc_numberText, "%"]] call _say };
        if ((serverCycleLength - (serverTime - serverStartTime)) <= 180) exitWith {
            call _unlock; ["The exchange closes just before a restart."] call _say };

        private _randID = AP_lagRandomID;
        AP_didServerRespond = false;
        private _maxDelayTime = time + 5;
        [[player], "APS_fnc_lagCheck", 2] spawn AP_fnc_MP;
        waitUntil { time > _maxDelayTime || AP_didServerRespond };
        if (time > _maxDelayTime) exitWith { call _unlock; ["Exchange failed, try again."] call _say };
        if !(_randID isEqualTo AP_lagRandomID) exitWith { call _unlock; ["Please wait for the exchange..."] call _say };

        AP_atmcash = AP_atmcash - _fee;
        AP_atmcashCacheB = ((AP_atmcash / 4) + 11);
        [1] call AP_fnc_ClupdatePartial;
        // native rebuild, faithfully: clear all four cargos and re-add the rest
        // via addItemCargoGlobal (yes, ALL of it -- diverging here would make the
        // deck trunk differ from the NPC one)
        clearMagazineCargoGlobal _veh;
        clearBackpackCargoGlobal _veh;
        clearItemCargoGlobal _veh;
        clearWeaponCargoGlobal _veh;
        { _veh addItemCargoGlobal _x; } forEach _new;
        call _unlock;
        [[3, [1, player, getPlayerUID player, _class, _price, _amt, _fee]], "APS_fnc_exchangeSystemSRV", 2] spawn AP_fnc_MP;
        [["-EXCHANGELISTED-", player, profileName, format ["Deck-listed physical: Item: %1, Qty: %2, Price: $%3, Fee: $%4",
            ([_class] call AP_fnc_fetchCfgDetails) param [1, _class], _amt, [_price] call AP_fnc_numberText, [_fee] call AP_fnc_numberText]],
            "APS_fnc_logIt", 2] spawn AP_fnc_MP;
        [format ["Listed %1 x %2 at $%3 each (fee $%4).", _amt, ([_class] call AP_fnc_fetchCfgDetails) param [1, _class],
            [_price] call AP_fnc_numberText, [_fee] call AP_fnc_numberText], "exchange"] spawn AP_fnc_handleMessage;
        uiSleep 1.2;
        AP_exchangeRequested = false;
        [[5, [0, getPlayerUID player, player]], "APS_fnc_exchangeSystemSRV", 2] call AP_fnc_MP;
        waitUntil { uiSleep 0.1; AP_exchangeRequested };
        AP_exchangeRequested = false;
        private _c = uiNamespace getVariable ["WEBUI_ctrl", controlNull];
        if (!isNull _c) then { [_c, "exchange", (["data"] call AP_fnc_deckExchange)] call webui_fnc_push; };
    };
    ["Listing sent."] call _yes
};

case "sellveh": {
    private _net = _a;
    private _price = _b;
    if !(_net isEqualType "") exitWith { ["bad id"] call _no };
    [_net, _price] spawn {
        params ["_net", "_price"];
        private _say = { params ["_m"]; [_m, "basic"] spawn AP_fnc_handleMessage };
        AP_exchangeRequested = false;
        [[7, [0, getPlayerUID player, player]], "APS_fnc_exchangeSystemSRV", 2] call AP_fnc_MP;
        waitUntil { uiSleep 0.1; AP_exchangeRequested };
        AP_exchangeRequested = false;
        if ((AP_exchangeMaxListings param [2, 0]) >= 20) exitWith { ["You already hold 20 vehicle listings."] call _say };

        private _veh = objectFromNetId _net;
        private _cn = typeOf _veh;
        if (isNull _veh || {!alive _veh} || {!(_cn in ([1, "vehicle"] call AP_fnc_exchangeCfg))}) exitWith {
            ["This vehicle is not accepted into the exchange."] call _say };
        private _db = _veh getVariable ["AP_dbInfo", []];
        if !((getPlayerUID player) isEqualTo (_db param [0, ""])) exitWith { ["You must own this vehicle."] call _say };
        if ("" in [_db param [0, ""], _db param [1, ""]]) exitWith { ["You cannot list this vehicle."] call _say };
        if ((player distance2D _veh) > 25) exitWith { ["Stand within 25 m of the vehicle."] call _say };
        if (_price < (["getMinimumPrice", _cn] call AP_fnc_exchangeCfg)) exitWith {
            [format ["Minimum price is $%1.", [["getMinimumPrice", _cn] call AP_fnc_exchangeCfg] call AP_fnc_numberText]] call _say };
        if (_price > (["getMaximumPrice", _cn] call AP_fnc_exchangeCfg)) exitWith {
            [format ["Maximum price is $%1.", [["getMaximumPrice", _cn] call AP_fnc_exchangeCfg] call AP_fnc_numberText]] call _say };
        private _fee = _price * 0.05;
        if (AP_atmcash < _fee) exitWith {
            [format ["The 5%2 listing fee is $%1 -- you cannot cover it.", [_fee] call AP_fnc_numberText, "%"]] call _say };

        private _randID = AP_lagRandomID;
        AP_didServerRespond = false;
        private _maxDelayTime = time + 5;
        [[player], "APS_fnc_lagCheck", 2] spawn AP_fnc_MP;
        waitUntil { time > _maxDelayTime || AP_didServerRespond };
        if (time > _maxDelayTime) exitWith { ["Exchange failed, try again."] call _say };
        if !(_randID isEqualTo AP_lagRandomID) exitWith { ["Please wait for the exchange..."] call _say };

        AP_atmcash = AP_atmcash - _fee;
        AP_atmcashCacheB = ((AP_atmcash / 4) + 11);
        [1] call AP_fnc_ClupdatePartial;
        [[2, [1, player, getPlayerUID player, _cn, _price, _db param [1, ""], _veh, _fee]], "APS_fnc_exchangeSystemSRV", 2] spawn AP_fnc_MP;
        [["-EXCHANGELISTED-", player, profileName, format ["Deck-listed vehicle: %1, Price: $%2, Fee: $%3",
            [configFile >> "CfgVehicles" >> _cn] call BIS_fnc_displayName, [_price] call AP_fnc_numberText, [_fee] call AP_fnc_numberText]],
            "APS_fnc_logIt", 2] spawn AP_fnc_MP;
        [format ["Vehicle listed at $%1 (fee $%2). Unsold in 7 days returns to your garage.",
            [_price] call AP_fnc_numberText, [_fee] call AP_fnc_numberText], "exchange"] spawn AP_fnc_handleMessage;
        uiSleep 1.2;
        AP_exchangeRequested = false;
        [[5, [0, getPlayerUID player, player]], "APS_fnc_exchangeSystemSRV", 2] call AP_fnc_MP;
        waitUntil { uiSleep 0.1; AP_exchangeRequested };
        AP_exchangeRequested = false;
        private _c = uiNamespace getVariable ["WEBUI_ctrl", controlNull];
        if (!isNull _c) then { [_c, "exchange", (["data"] call AP_fnc_deckExchange)] call webui_fnc_push; };
    };
    ["Listing sent."] call _yes
};

default { ["unknown exchange verb"] call _no };
};
