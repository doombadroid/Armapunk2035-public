/*
    fn_storageBridge.sqf -- STORAGE (dual manifest) bridge half, web dialog
    938000 (onLoad of AP_web_storage). fn_storageOpen.sqf has already run the
    guard chain, reserved AP_activeTrunk and (for houses) hydrated
    AP_vinv/AP_pinv, and set AP_trunk_vehicle / AP_is_virtual -- the same
    globals TrunkMenu uses.

    WHY THE VIRTUAL MOVES DO NOT CALL fn_takeInventory / fn_storeInventory
    directly, even though "nothing new decides what is in a container" is the
    whole point of this port:

    Those two natives DO take parameters -- [_deckItem, _deckQty, _deckMax], the
    deck route -- but only their PHYSICAL branches are reachable that way without
    dialog 4500. Their virtual branches still read the TrunkMenu listbox controls
    for the surrounding state, and createDialog is exclusive (opening
    AP_web_storage closes TrunkMenu and vice versa), so there is no way to keep
    4500 alive off-screen to feed them.

    So the virtual moves route through the layer BELOW the listbox coupling --
    the same primitives fn_takeInventory/fn_storeInventory themselves call -- and
    reproduce their container-mutation pattern (read AP_vinv/pinv, findIf/set/
    deleteAt, setVariable broadcast) exactly, rather than inventing a new one:
      AP_fnc_handleInv       -- the player-side virtual inventory engine
                                 (weight clamp, AP_invMonitor anti-cheat,
                                 the 2s debounced write-through save)
      AP_fnc_calWeightDiff   -- clamps a take to the player's remaining
                                 carry weight
      AP_fnc_virtItemCfg     -- the item catalogue (name/weight/icon)
      APS_fnc_initHouseInventory / APS_fnc_updateHouseTrunk -- the ONLY
                                 house hydrate/persist chokepoints; both do
                                 the mres decode/encode and server-side
                                 auth+sanitization internally, called with
                                 the exact args fn_openInventory/
                                 fn_houseToVehicleStore already use

    Compare fn_pickupItem (LOOT's engine, called from fn_lootBridge.sqf): it
    already takes [_obj, _itemClass, _qty] as real params -- its OWN listbox
    writes (aimed at the now-absent display 1520) are just null-safe OUTPUT
    for when the old dialog happens to be open, not its input.

    PHYSICAL moves DO go straight through the natives (2026-09-05, storage_
    physical.md). Their physical branches take everything they need as
    parameters once the quantity ceiling is supplied -- that ceiling was the one
    thing still coming from a listbox (`lbValue[4502/4503]`), which off dialog
    4500 reads 0 and made the transfer loop run zero times. With _deckMax passed
    from this file's own tallies they work unchanged, and reimplementing them was
    never an option worth taking: fn_storeInventory's physical branch alone is
    ~130 lines of per-slot equip logic carrying #288, #328/#341, #369, #545 and
    #581, and fn_takeInventory's carries the cop seize path. Physical is HOUSES
    ONLY here, for the reason spelled out at the gate in stMove.

    stMove's bulk (stBulkVehicle) mirrors fn_houseToVehicleStore.sqf /
    fn_vehicleToHouseStore.sqf's discovery + eligibility + reservation
    pattern, but SINGLE-SHOT instead of their 10-units/sec animated loop:
    no uiSleep between the read and the write means no scheduler window for
    another script to interleave, so there is no TOCTOU gap to re-read
    against -- the paced native version's safety came from AP_trunkLock /
    AP_activeTrunk plus re-reading the non-reserved side live each tick, and
    both of those are preserved here (reserve the target for the duration;
    re-read nothing stale). The visible 10/sec trickle + AP_progress HUD was
    UX pacing on top of that, not the safety mechanism itself, and is
    dropped for a single reconciling push instead. In PHYSICAL mode the bulk
    target is the vehicle's real engine cargo, never its AP_pinv -- a vehicle's
    script-side physical store is a dead end nothing will display.
*/
params [["_display", displayNull, [displayNull]]];
if (isNull _display) exitWith {};
disableSerialization;

private _ctrl = _display displayCtrl 938001;
if (isNull _ctrl) exitWith { diag_log "[STORAGE] control missing" };
if !([_ctrl] call webui_fnc_init) exitWith { diag_log "[STORAGE] bridge init failed" };
// Let the SERVER replace this page's markup if it holds a newer copy, so UI ships
// without a client repack. No-op unless AP_fnc_webServeInit registered a fetcher and
// the server actually has the file -- otherwise the PBO page you just loaded stands.
[_ctrl, "ui\html\storage.html"] call webui_fnc_serve;

// windowed web UI, base 40x20 grid scaled by the phone's size slider, centred
// (owner standing order 2026-08-13, same convention fn_armoryOpen.sqf uses).
private _s = profileNamespace getVariable ["AP_deckScale", 1];
private _gw = 2.5 * pixelW * pixelGrid; private _gh = 2.5 * pixelH * pixelGrid;
private _w = 40 * _gw * _s; private _h = 20 * _gh * _s;
_ctrl ctrlSetPosition [0.5 - _w / 2, 0.5 - _h / 2, _w, _h];
_ctrl ctrlCommit 0;

private _data = {
    private _c = AP_trunk_vehicle;
    private _virt = AP_is_virtual;
    if (isNull _c) exitWith {
        createHashMapFromArray [
            ["mode", "virtual"], ["house", false], ["cont", "main"], ["conts", []],
            ["you", createHashMapFromArray [["cap", 0], ["items", []]]]
        ]
    };
    private _isHouse = (_c isKindOf "House_F") || {(typeOf _c) in AP_houseTypes};

    // No "kind" column exists in AP_fnc_virtItemCfg's catalogue (11 fields, none of them a category) --
    // this is a DISPLAY-ONLY placeholder heuristic, not a decision anything downstream reads. Physical
    // rows have real Arma classes, so those get a real isKindOf-derived bucket instead.
    private _fnVKind = {
        params ["_id"];
        if (_id in ["money", "bank_money", "newdrachma", "loonycoin"]) exitWith { "CASH" };
        private _illegal = ["getIllegalPrice", _id] call AP_fnc_virtItemCfg;
        if (_illegal isEqualType 0 && {_illegal >= 0}) exitWith { "ILL" };
        "GOOD"
    };
    private _fnPKind = {
        params ["_cls"];
        private _cw = configFile >> "CfgWeapons" >> _cls;
        if (isClass _cw && {_cls isKindOf ["Rifle", configFile >> "CfgWeapons"] || {_cls isKindOf ["Pistol", configFile >> "CfgWeapons"]} || {_cls isKindOf ["Launcher", configFile >> "CfgWeapons"]}}) exitWith { "WPN" };
        if (isClass (configFile >> "CfgMagazines" >> _cls)) exitWith { "AMMO" };
        "GEAR"
    };
    private _fnIcon = {
        params ["_cls"];
        private _d = [_cls] call AP_fnc_fetchCfgDetails;
        private _paa = _d param [2, ""];
        if ((_paa select [0, 1]) isEqualTo "\") then { _paa = _paa select [1]; };
        _paa
    };

    // ---- container side ----
    private _contItems = [];
    private _contCap = 100;
    if (_virt) then {
        private _cd = _c getVariable ["AP_vinv", [[], 0]];
        private _inv = _cd param [0, []];
        _contCap = _c getVariable ["AP_vcap", 100];
        { _x params [["_id", "", [""]], ["_qty", 0, [0]]];
            if (_qty > 0) then {
                _contItems pushBack (createHashMapFromArray [
                    ["id", _id], ["name", ["getName", _id] call AP_fnc_virtItemCfg],
                    ["kind", [_id] call _fnVKind], ["wt", ["getItemWeight", _id] call AP_fnc_virtItemCfg],
                    ["qty", _qty], ["icon", ["getIcon", _id] call AP_fnc_virtItemCfg]
                ]);
            };
        } forEach _inv;
    } else {
        private _cd = _c getVariable ["AP_pinv", [[], 0]];
        private _inv = _cd param [0, []];
        _contCap = if (_isHouse) then { _c getVariable ["AP_phys_cap", 100] } else { ["getPhysCap", "", typeOf _c] call AP_fnc_vehicleConfig };
        { _x params [["_cls", "", [""]], ["_qty", 0, [0]]];
            if (_qty > 0) then {
                private _d = [_cls] call AP_fnc_fetchCfgDetails;
                _contItems pushBack (createHashMapFromArray [
                    ["id", _cls], ["name", _d param [1, _cls]],
                    ["kind", [_cls] call _fnPKind], ["wt", getNumber (missionConfigFile >> "CfgWeights" >> _cls >> "weight")],
                    ["qty", _qty], ["icon", [_cls] call _fnIcon]
                ]);
            };
        } forEach _inv;
    };

    // ---- player side ----
    private _youItems = [];
    private _youCap = AP_maxWeight;
    if (_virt) then {
        { private _id = _x;
            private _qty = missionNamespace getVariable [format ["AP_inv_%1", _id], 0];
            if (_qty isEqualType 0 && {_qty > 0}) then {
                _youItems pushBack (createHashMapFromArray [
                    ["id", _id], ["name", ["getName", _id] call AP_fnc_virtItemCfg],
                    ["kind", [_id] call _fnVKind], ["wt", ["getItemWeight", _id] call AP_fnc_virtItemCfg],
                    ["qty", _qty], ["icon", ["getIcon", _id] call AP_fnc_virtItemCfg]
                ]);
            };
        } forEach ([2] call AP_fnc_virtItemCfg);
    } else {
        // The player's physical gear, from the one shared walk (AP_fnc_physTally) rather than a
        // fourth private copy of it. Deliberately the SET fn_refreshInventory paints for TrunkMenu,
        // so a row shown here is a row fn_storeInventory can actually move and the _deckMax ceiling
        // stMove hands the native is computed from the same tally the native's clamp expects.
        { _x params ["_cls", "_qty"];
            private _d = [_cls] call AP_fnc_fetchCfgDetails;
            _youItems pushBack (createHashMapFromArray [
                ["id", _cls], ["name", _d param [1, _cls]],
                ["kind", [_cls] call _fnPKind], ["wt", getNumber (missionConfigFile >> "CfgWeights" >> _cls >> "weight")],
                ["qty", _qty], ["icon", [_cls] call _fnIcon]
            ]);
        } forEach (call AP_fnc_physTally);
        // no single "physical capacity" scalar exists in this codebase (Arma's own uniform/vest/backpack
        // cargo space governs it, not AP_maxWeight) -- AP_maxWeight is a nominal reference only here.
    };

    createHashMapFromArray [
        ["mode", if (_virt) then { "virtual" } else { "physical" }],
        // the page hides its virtual/physical toggle when this is false: only a house has an
        // AP_pinv to show. See stMode.
        ["house", _isHouse],
        ["cont", "main"],
        ["conts", [createHashMapFromArray [
            ["id", "main"],
            ["name", toUpper (getText (configFile >> "CfgVehicles" >> (typeOf _c) >> "displayName"))],
            ["label", if (_isHouse) then { "IN STORAGE" } else { "IN TRUNK" }],
            ["cap", _contCap],
            ["items", _contItems]
        ]]],
        ["you", createHashMapFromArray [["cap", _youCap], ["items", _youItems]]]
    ]
};

[_ctrl, "storage", _data] call webui_fnc_on;
uiNamespace setVariable ["AP_storageData", _data];

[_ctrl, "stMove", {
    params [["_contId", "", [""]], ["_itemId", "", [""]], ["_dir", "", [""]], ["_qty", 1, [0]]];
    if (isNull AP_trunk_vehicle || {!alive AP_trunk_vehicle}) exitWith { createHashMapFromArray [["ok", false], ["msg", "storage is gone"]] };
    if (_contId != "main") exitWith { createHashMapFromArray [["ok", false], ["msg", "unknown container"]] };
    if (_itemId == "") exitWith { createHashMapFromArray [["ok", false], ["msg", "no item"]] };
    if !(_dir in ["take", "store"]) exitWith { createHashMapFromArray [["ok", false], ["msg", "unknown move"]] };
    _qty = _qty max 1;

    private _c = AP_trunk_vehicle;
    if ((vehicle player) isNotEqualTo _c && {((getPos _c) distance (getPos player)) > (10 + 0.5 * (sizeOf typeOf _c))}) exitWith {
        createHashMapFromArray [["ok", false], ["msg", "too far away"]]
    };

    // ---------------------------------------------------------------- physical
    // Routed straight through the natives' deck entry point rather than reimplemented.
    // fn_storeInventory's physical branch alone is ~130 lines of per-slot logic carrying
    // #288 (disconnect dupe), #328/#341 (bipod loss), #369 (loose attachments), #545
    // (second backpack vanished) and #581 (launcher missiles); fn_takeInventory carries the
    // matching set plus the cop seize path. A second copy is how dupes are born -- that
    // file's own header says so.
    //
    // HOUSES ONLY, and not as policy: fn_refreshInventory:9-11 refuses physical mode on a
    // Car/Air/Ship outright, because a vehicle already owns real engine cargo and a parallel
    // script-side AP_pinv would give one rifle two homes. A house has no engine container,
    // which is the reason AP_pinv exists for it at all. fn_deckTrunk:79 keeps the same gate.
    if !(AP_is_virtual) exitWith {
        if !((_c isKindOf "House_F") || {(typeOf _c) in AP_houseTypes}) exitWith {
            createHashMapFromArray [["ok", false],
                ["msg", "Physical inventory via this method is not allowed on vehicles! Please use the Arma 3 inventory method."]]
        };

        // The ceiling the native's physical branch used to read from TrunkMenu's listbox.
        // Off dialog 4500 that read is 0 and the transfer loop runs zero times, so the number
        // has to come from here -- from the same tallies this screen rendered its manifests
        // from, which is what makes the clamp agree with what the mover will find.
        private _max = if (_dir isEqualTo "take") then {
            private _inv = (_c getVariable ["AP_pinv", [[], 0]]) param [0, []];
            private _i = _inv findIf { (_x param [0, ""]) isEqualTo _itemId };
            if (_i < 0) then { 0 } else { (_inv select _i) param [1, 0] }
        } else {
            private _t = call AP_fnc_physTally;
            private _i = _t findIf { (_x param [0, ""]) isEqualTo _itemId };
            if (_i < 0) then { 0 } else { (_t select _i) param [1, 0] }
        };
        if (_max < 1) exitWith {
            createHashMapFromArray [["ok", false],
                ["msg", if (_dir isEqualTo "take") then { "none to take" } else { "none to store" }]]
        };
        _qty = _qty min _max;

        // AP_is_virtual is NOT touched: stMode already set it to match the screen and it must
        // stay that way across successive moves. (fn_deckTrunk's batch verb flips it per queued
        // move and resets it, because one batch there can mix both kinds.) Quantity travels as
        // the STRING the natives expect from ctrlText -- same convention as fn_deckTrunk:85-87.
        // The natives report their own outcome through AP_fnc_handleMessage and re-push this
        // screen themselves via AP_fnc_refreshInventory, so there is no verdict to invent here.
        if (_dir isEqualTo "take") then {
            [_itemId, str _qty, _max] call AP_fnc_takeInventory;
        } else {
            [_itemId, str _qty, _max] call AP_fnc_storeInventory;
        };

        private _wc = uiNamespace getVariable ["WEBUI_ctrl", controlNull];
        if (!isNull _wc) then { [_wc, "storage", (call (uiNamespace getVariable "AP_storageData"))] call webui_fnc_push; };
        createHashMapFromArray [["ok", true], ["msg", ""]]
    };

    private _cd = _c getVariable ["AP_vinv", [[], 0]];
    private _inv = _cd param [0, []];
    private _cWeight = _cd param [1, 0];
    private _cCap = _c getVariable ["AP_vcap", 100];
    private _idx = _inv findIf { (_x param [0, ""]) isEqualTo _itemId };
    private _itemW = ["getItemWeight", _itemId] call AP_fnc_virtItemCfg;
    private _itemName = ["getName", _itemId] call AP_fnc_virtItemCfg;
    private _out = createHashMapFromArray [["ok", false], ["msg", "nothing happened"]];

    if (_dir isEqualTo "take") then {
        private _have = if (_idx < 0) then { 0 } else { (_inv select _idx) param [1, 0] };
        _qty = _qty min _have;
        if (_qty < 1) exitWith { createHashMapFromArray [["ok", false], ["msg", "none to take"]] };
        _qty = [_itemId, _qty, AP_carryWeight, AP_maxWeight] call AP_fnc_calWeightDiff;
        if (_qty <= 0) exitWith {
            private _room = if (_itemW > 0) then { floor ((AP_maxWeight - AP_carryWeight) / _itemW) } else { 0 };
            createHashMapFromArray [["ok", false], ["msg", format ["too heavy -- room for %1 x %2", (_room max 0), _itemName]]]
        };
        if !([true, _itemId, _qty] call AP_fnc_handleInv) exitWith { createHashMapFromArray [["ok", false], ["msg", "your inventory is full"]] };
        private _rem = _have - _qty;
        if (_rem > 0) then { (_inv select _idx) set [1, _rem]; } else { _inv deleteAt _idx; };
        _c setVariable ["AP_vinv", [_inv, (_cWeight - (_itemW * _qty)) max 0], true];
        _out = createHashMapFromArray [["ok", true], ["msg", format ["+%1 %2", _qty, _itemName]]];
    } else {
        private _have = missionNamespace getVariable [format ["AP_inv_%1", _itemId], 0];
        if !(_have isEqualType 0) then { _have = 0; };
        _qty = _qty min _have;
        if (_qty < 1) exitWith { createHashMapFromArray [["ok", false], ["msg", "none to store"]] };
        private _room = if (_itemW > 0) then { floor ((_cCap - _cWeight) / _itemW) } else { _qty };
        _qty = _qty min (_room max 0);
        if (_qty < 1) exitWith { createHashMapFromArray [["ok", false], ["msg", format ["storage is full -- no room for %1", _itemName]]] };
        if !([false, _itemId, _qty] call AP_fnc_handleInv) exitWith { createHashMapFromArray [["ok", false], ["msg", "couldn't remove that from your inventory"]] };
        if (_idx < 0) then { _inv pushBack [_itemId, _qty]; } else { (_inv select _idx) set [1, ((_inv select _idx) param [1, 0]) + _qty]; };
        _c setVariable ["AP_vinv", [_inv, _cWeight + (_itemW * _qty)], true];
        _out = createHashMapFromArray [["ok", true], ["msg", format ["+%1 %2 stored", _qty, _itemName]]];
    };

    private _wc = uiNamespace getVariable ["WEBUI_ctrl", controlNull];
    if (!isNull _wc) then { [_wc, "storage", (call (uiNamespace getVariable "AP_storageData"))] call webui_fnc_push; };
    _out
}] call webui_fnc_on;

[_ctrl, "stBulkVehicle", {
    params [["_itemId", "", [""]]];

    // whole search+transfer wrapped in its own call scope so a refusal exitWith at ANY nesting depth
    // (house-target reservation cleanup included) still leaves the OUTER AP_bulkStore reset + push
    // below to always run -- exitWith terminates the CALL it is inside, not just the nearest then{}.
    private _fnCore = {
        params ["_itemId"];
        if (isNull AP_trunk_vehicle || {!alive AP_trunk_vehicle}) exitWith { createHashMapFromArray [["ok", false], ["msg", "storage is gone"]] };
        if (_itemId == "") exitWith { createHashMapFromArray [["ok", false], ["msg", "no item selected"]] };

        // ------------------------------------------------------------ physical bulk
        // House AP_pinv -> the nearest keyed vehicle's REAL engine cargo, not its AP_pinv.
        // A vehicle's script-side physical store is a dead end -- fn_refreshInventory:9-11
        // refuses to display it and TrunkMenu closes on the attempt -- so gear pushed there
        // would be invisible and unrecoverable. Engine cargo is where the native inventory
        // puts gear, so it is visible immediately and persists by the vehicle's own route.
        //
        // Same discovery, eligibility and reservation walk as the virtual path below, and the
        // same single-shot reconciling push rather than the natives' 10/sec trickle: with no
        // uiSleep between the read and the write there is no scheduler window for another
        // script to interleave, so there is no TOCTOU gap to re-read against.
        if !(AP_is_virtual) exitWith {
            private _src = AP_trunk_vehicle;
            if !((_src isKindOf "House_F") || {(typeOf _src) in AP_houseTypes}) exitWith {
                createHashMapFromArray [["ok", false],
                    ["msg", "Physical inventory via this method is not allowed on vehicles! Please use the Arma 3 inventory method."]]
            };

            private _srcData = _src getVariable ["AP_pinv", [[], 0]];
            private _srcInv = _srcData param [0, []];
            private _srcIdx = _srcInv findIf { (_x param [0, ""]) isEqualTo _itemId };
            private _have = if (_srcIdx < 0) then { 0 } else { (_srcInv select _srcIdx) param [1, 0] };
            if (_have < 1) exitWith { createHashMapFromArray [["ok", false], ["msg", "that item isn't here"]] };

            private _uid = getPlayerUID player;
            private _veh = objNull;
            { if (alive _x) then {
                private _cand = _x;
                private _hasKey = ((_cand getVariable ["AP_vehOwners", []]) findIf { (_x param [0, ""]) isEqualTo _uid }) > -1;
                if (_hasKey
                    && {(_cand getVariable ["AP_activeTrunk", objNull]) isEqualTo objNull}
                    && {(_cand getVariable ["AP_veh_in_use", objNull]) isEqualTo objNull}
                    && {!(_cand getVariable ["AP_trunkLock", false])}
                    && {!(_cand getVariable ["AP_seizing", false])}) exitWith { _veh = _cand; };
            }; } forEach (nearestObjects [player, ["Car", "Air", "Ship"], 25]);
            if (isNull _veh) exitWith { createHashMapFromArray [["ok", false], ["msg", "no vehicle you have keys to is parked within 25m, unlocked and free"]] };

            // Engine cargo is capped by mass, not by AP_vcap. `load` is the fraction of
            // maximumLoad already used, so the headroom is what is left of that mass budget;
            // one item's mass comes from the same CfgWeights table AP_pinv is weighed with,
            // and a class absent from that partial table weighs 0 -- which fits any headroom
            // and is the behaviour the rest of the physical system already has.
            private _cargoMax = getNumber (configFile >> "CfgVehicles" >> (typeOf _veh) >> "maximumLoad");
            private _room = _cargoMax - ((load _veh) * _cargoMax);
            private _itemW = getNumber (missionConfigFile >> "CfgWeights" >> _itemId >> "weight");
            private _fit = if (_itemW > 0) then { floor (_room / _itemW) } else { _have };
            _fit = _fit min _have;
            if (_fit < 1) exitWith { createHashMapFromArray [["ok", false], ["msg", "that vehicle is full"]] };

            // Weapons, backpacks and everything else take different cargo commands; a class
            // handed to the wrong one is silently dropped, so dispatch on what it actually is.
            private _isWeapon = isClass (configFile >> "CfgWeapons" >> _itemId)
                && {_itemId isKindOf ["Rifle", configFile >> "CfgWeapons"]
                    || {_itemId isKindOf ["Pistol", configFile >> "CfgWeapons"]}
                    || {_itemId isKindOf ["Launcher", configFile >> "CfgWeapons"]}};
            private _isBag = isClass (configFile >> "CfgVehicles" >> _itemId)
                && {_itemId isKindOf ["Bag_Base", configFile >> "CfgVehicles"]};
            switch (true) do {
                case (_isWeapon): { _veh addWeaponCargoGlobal [_itemId, _fit]; };
                case (_isBag):    { _veh addBackpackCargoGlobal [_itemId, _fit]; };
                default           { _veh addItemCargoGlobal [_itemId, _fit]; };
            };

            // Only what actually landed leaves the house, and the house weight is RECOMPUTED
            // from the surviving rows rather than adjusted arithmetically -- the same
            // AP_fnc_physicalInventoryWeight the natives use, so a rounding difference cannot
            // accumulate into a phantom capacity.
            private _rem = _have - _fit;
            if (_rem > 0) then { (_srcInv select _srcIdx) set [1, _rem]; } else { _srcInv deleteAt _srcIdx; };
            _src setVariable ["AP_pinv", [_srcInv, _srcInv call AP_fnc_physicalInventoryWeight], true];

            private _gen = _src getVariable ["AP_invGen", 0];
            private _vinv = _src getVariable ["AP_vinv", [[], 0]];
            private _pinv = _src getVariable ["AP_pinv", [[], 0]];
            [player, _src, _vinv, _pinv, _gen] spawn {
                params ["_pl", "_obj", "_v", "_p", "_g"];
                [[_pl, _obj, _v, _p, _g], "APS_fnc_updateHouseTrunk", false, false] spawn AP_fnc_MP;
            };

            private _nm = getText (configFile >> "CfgWeapons" >> _itemId >> "displayName");
            if (_nm isEqualTo "") then { _nm = getText (configFile >> "CfgVehicles" >> _itemId >> "displayName"); };
            if (_nm isEqualTo "") then { _nm = getText (configFile >> "CfgMagazines" >> _itemId >> "displayName"); };
            if (_nm isEqualTo "") then { _nm = _itemId; };
            createHashMapFromArray [["ok", true],
                ["msg", format ["moved %1 x %2 into %3", _fit, _nm, getText (configFile >> "CfgVehicles" >> (typeOf _veh) >> "displayName")]]]
        };

        private _src = AP_trunk_vehicle;
        private _srcIsHouse = (_src isKindOf "House_F") || {(typeOf _src) in AP_houseTypes};
        private _srcData = _src getVariable ["AP_vinv", [[], 0]];
        private _srcInv = _srcData param [0, []];
        private _srcIdx = _srcInv findIf { (_x param [0, ""]) isEqualTo _itemId };
        private _have = if (_srcIdx < 0) then { 0 } else { (_srcInv select _srcIdx) param [1, 0] };
        if (_have < 1) exitWith { createHashMapFromArray [["ok", false], ["msg", "that item isn't here"]] };
        private _itemW = ["getItemWeight", _itemId] call AP_fnc_virtItemCfg;
        private _itemName = ["getName", _itemId] call AP_fnc_virtItemCfg;

        if (_srcIsHouse) exitWith {
            // house -> nearest vehicle you hold keys to, unlocked + free (mirrors fn_houseToVehicleStore.sqf)
            private _uid = getPlayerUID player;
            private _veh = objNull;
            { if (alive _x) then {
                private _cand = _x;
                private _hasKey = ((_cand getVariable ["AP_vehOwners", []]) findIf { (_x param [0, ""]) isEqualTo _uid }) > -1;
                if (_hasKey
                    && {(_cand getVariable ["AP_activeTrunk", objNull]) isEqualTo objNull}
                    && {(_cand getVariable ["AP_veh_in_use", objNull]) isEqualTo objNull}
                    && {!(_cand getVariable ["AP_trunkLock", false])}
                    && {!(_cand getVariable ["AP_seizing", false])}) exitWith { _veh = _cand; };
            }; } forEach (nearestObjects [player, ["Car", "Air", "Ship"], 25]);
            if (isNull _veh) exitWith { createHashMapFromArray [["ok", false], ["msg", "no vehicle you have keys to is parked within 25m, unlocked and free"]] };

            private _vehIsAir = _veh isKindOf "Air";
            private _vehIsBox = (typeOf _veh) in ["B_Truck_01_box_F", "C_Van_01_box_F"];
            private _eligible = true;
            if (_itemId in ["goldbar", "bank_money"]) then { _eligible = !_vehIsAir; };
            if (_itemId in ["uraniumu", "uraniump"]) then { _eligible = _vehIsBox; };
            if (_itemId in ["jewelHope", "jewelRolex", "jewelAP", "jewelDiamonds", "jewelGoldBag", "jewelExoJewels", "jewelRing", "jewelBling", "jewelBag"]) then { _eligible = !_vehIsAir; };
            if !(_eligible) exitWith { createHashMapFromArray [["ok", false], ["msg", "that vehicle can't carry this item"]] };

            private _vData = _veh getVariable ["AP_vinv", [[], 0]];
            private _vInv = _vData param [0, []];
            private _vCap = _veh getVariable ["AP_vcap", 100];
            private _room = _vCap - (_vData param [1, 0]);
            private _fit = if (_itemW > 0) then { floor (_room / _itemW) } else { _have };
            _fit = _fit min _have;
            if (_fit < 1) exitWith { createHashMapFromArray [["ok", false], ["msg", "that vehicle is full"]] };

            private _rem = _have - _fit;
            if (_rem > 0) then { (_srcInv select _srcIdx) set [1, _rem]; } else { _srcInv deleteAt _srcIdx; };
            _src setVariable ["AP_vinv", [_srcInv, ((_srcData param [1, 0]) - (_itemW * _fit)) max 0], true];

            private _vIdx = _vInv findIf { (_x param [0, ""]) isEqualTo _itemId };
            if (_vIdx < 0) then { _vInv pushBack [_itemId, _fit]; } else { (_vInv select _vIdx) set [1, ((_vInv select _vIdx) param [1, 0]) + _fit]; };
            _veh setVariable ["AP_vinv", [_vInv, (_vData param [1, 0]) + (_itemW * _fit)], true];

            [true] call AP_fnc_saveGear;
            createHashMapFromArray [["ok", true], ["msg", format ["moved %1 x %2 to %3", _fit, _itemName, getText (configFile >> "CfgVehicles" >> (typeOf _veh) >> "displayName")]]]
        };

        // vehicle/tent -> nearest house you have access to, not locked/in-use, tax current (mirrors fn_vehicleToHouseStore.sqf)
        if (_itemId in ["goldbar", "bank_money", "glitterbase", "glitter", "uraniumu", "jewelHope", "jewelRolex", "jewelAP", "jewelDiamonds", "jewelGoldBag", "jewelExoJewels", "jewelRing", "jewelBling", "jewelBag"]) exitWith {
            createHashMapFromArray [["ok", false], ["msg", "you can't store that in a house"]]
        };
        private _uid = getPlayerUID player;
        private _myGang = AP_gang_data param [0, -1];
        private _house = objNull;
        { private _cand = _x;
            private _owner = _cand getVariable ["AP_homeOwner", ""];
            private _isOwner = (_owner isEqualType "") && {_owner != ""} && {_owner != "NoPidVar"} && {_uid isEqualTo _owner};
            private _isKey  = ([_cand, _uid, "accessInv"] call AP_fnc_keyHolderStatus) isEqualTo true;
            private _hGang  = _cand getVariable ["AP_house_gang", -1];
            private _isGang = (_hGang isEqualType 0) && {_hGang > 0} && {_myGang isEqualType 0} && {_hGang isEqualTo _myGang};
            if ((_isOwner || _isKey || _isGang)
                && {!(_cand getVariable ["AP_trunkLock", false])}
                && {(_cand getVariable ["AP_activeTrunk", objNull]) isEqualTo objNull}
                && {(_cand getVariable ["AP_house_tax", [false]]) select 0 isEqualTo false}) exitWith { _house = _cand; };
        } forEach (nearestObjects [player, ["House_F"], 25]);
        if (isNull _house) exitWith { createHashMapFromArray [["ok", false], ["msg", "no house you have access to is within 25m (or it's in use / tax overdue)"]] };

        _house setVariable ["AP_trunkLock", true, true];
        _house setVariable ["AP_activeTrunk", player, true];
        _house setVariable ["AP_vinv", nil];
        _house setVariable ["AP_pinv", nil];
        [[_house, _house getVariable ["AP_houseID", -1]], "APS_fnc_initHouseInventory", 2] call AP_fnc_MP;
        private _exitTime = time + 6;
        waitUntil { uiSleep 0.1; time > _exitTime || (!isNil { _house getVariable "AP_vinv" } && !isNil { _house getVariable "AP_pinv" }) };
        if (isNil { _house getVariable "AP_vinv" } || {isNil { _house getVariable "AP_pinv" }}) exitWith {
            _house setVariable ["AP_trunkLock", false, true];
            _house setVariable ["AP_activeTrunk", nil, true];
            createHashMapFromArray [["ok", false], ["msg", "couldn't load that house's storage -- try again"]]
        };

        private _gen = _house getVariable ["AP_invGen", 0];
        private _hData = _house getVariable ["AP_vinv", [[], 0]];
        private _hInv = _hData param [0, []];
        private _hPinv = _house getVariable ["AP_pinv", [[], 0]];
        private _hCap = _house getVariable ["AP_vcap", 100];
        private _room = _hCap - (_hData param [1, 0]);
        private _fit = if (_itemW > 0) then { floor (_room / _itemW) } else { _have };
        _fit = _fit min _have;
        if (_itemId isEqualTo "uraniump" && {!(_house getVariable ["AP_leadcontainer_unaged", false])}) then {
            private _hi = _hInv findIf { (_x param [0, ""]) isEqualTo "uraniump" };
            private _hu = if (_hi < 0) then { 0 } else { (_hInv select _hi) param [1, 0] };
            _fit = _fit min (50 - _hu);
        };
        if (_fit < 1) exitWith {
            _house setVariable ["AP_trunkLock", false, true];
            _house setVariable ["AP_activeTrunk", nil, true];
            createHashMapFromArray [["ok", false], ["msg", "that house is full (or can't hold more of that item)"]]
        };

        private _rem = _have - _fit;
        if (_rem > 0) then { (_srcInv select _srcIdx) set [1, _rem]; } else { _srcInv deleteAt _srcIdx; };
        _src setVariable ["AP_vinv", [_srcInv, ((_srcData param [1, 0]) - (_itemW * _fit)) max 0], true];

        private _hIdx = _hInv findIf { (_x param [0, ""]) isEqualTo _itemId };
        if (_hIdx < 0) then { _hInv pushBack [_itemId, _fit]; } else { (_hInv select _hIdx) set [1, ((_hInv select _hIdx) param [1, 0]) + _fit]; };
        private _finalVinv = [_hInv, (_hData param [1, 0]) + (_itemW * _fit)];

        [player, _house, _finalVinv, _hPinv, _gen] spawn {
            params ["_pl", "_obj", "_v", "_p", "_g"];
            [[_pl, _obj, _v, _p, _g], "APS_fnc_updateHouseTrunk", false, false] spawn AP_fnc_MP;
            uiSleep 0.75;
            if (!isNull _obj) then { _obj setVariable ["AP_trunkLock", false, true]; _obj setVariable ["AP_activeTrunk", nil, true]; };
        };
        [true] call AP_fnc_saveGear;
        createHashMapFromArray [["ok", true], ["msg", format ["moved %1 x %2 to %3", _fit, _itemName, getText (configFile >> "CfgVehicles" >> (typeOf _house) >> "displayName")]]]
    };

    if (missionNamespace getVariable ["AP_bulkStore", false]) exitWith { createHashMapFromArray [["ok", false], ["msg", "already moving items"]] };
    missionNamespace setVariable ["AP_bulkStore", true];
    private _result = [_itemId] call _fnCore;
    missionNamespace setVariable ["AP_bulkStore", false];

    private _wc = uiNamespace getVariable ["WEBUI_ctrl", controlNull];
    if (!isNull _wc) then { [_wc, "storage", (call (uiNamespace getVariable "AP_storageData"))] call webui_fnc_push; };
    _result
}] call webui_fnc_on;

[_ctrl, "stMode", {
    params [["_mode", "", [""]]];
    if !(_mode in ["virtual", "physical"]) exitWith { createHashMapFromArray [["ok", false], ["msg", "unknown mode"]] };
    // Only a house has an AP_pinv to switch to -- see the gate in stMove for why vehicles are
    // barred. The page hides the toggle on a non-house (the `house` flag in the snapshot), so
    // reaching this is either a stale page or someone poking the bridge; refuse either way.
    if (_mode isEqualTo "physical"
        && {isNull AP_trunk_vehicle || {!((AP_trunk_vehicle isKindOf "House_F") || {(typeOf AP_trunk_vehicle) in AP_houseTypes})}}) exitWith {
        createHashMapFromArray [["ok", false],
            ["msg", "Physical inventory via this method is not allowed on vehicles! Please use the Arma 3 inventory method."]]
    };
    AP_is_virtual = _mode isEqualTo "virtual";
    private _wc = uiNamespace getVariable ["WEBUI_ctrl", controlNull];
    if (!isNull _wc) then { [_wc, "storage", (call (uiNamespace getVariable "AP_storageData"))] call webui_fnc_push; };
    createHashMapFromArray [["ok", true]]
}] call webui_fnc_on;

[_ctrl, "stCont", {
    params [["_contId", "", [""]]];
    private _wc = uiNamespace getVariable ["WEBUI_ctrl", controlNull];
    if (!isNull _wc) then { [_wc, "storage", (call (uiNamespace getVariable "AP_storageData"))] call webui_fnc_push; };
    createHashMapFromArray [["ok", _contId isEqualTo "main"]]
}] call webui_fnc_on;

[_ctrl, "stClose", { closeDialog 0; true }] call webui_fnc_on;

_display displayAddEventHandler ["KeyDown", { params ["", "_k"]; if (_k isEqualTo 1) then { closeDialog 0 }; false }];
_display displayAddEventHandler ["Unload", {
    private _c = AP_trunk_vehicle;
    if (isNull _c) exitWith {};
    _c setVariable ["AP_activeTrunk", nil, true];
    if ((_c isKindOf "House_F") || {(typeOf _c) in AP_houseTypes}) then {
        // same close-time settle+persist dance fn_openInventory.sqf's own closing monitor runs
        private _gen = _c getVariable ["AP_invGen", 0];
        private _v = _c getVariable ["AP_vinv", [[], 0]];
        private _p = _c getVariable ["AP_pinv", [[], 0]];
        _c setVariable ["AP_trunkLock", true, true];
        [player, _c, _v, _p, _gen] spawn {
            params ["_pl", "_obj", "_v", "_p", "_g"];
            uiSleep 1.25;
            [[_pl, _obj, _v, _p, _g], "APS_fnc_updateHouseTrunk", false, false] spawn AP_fnc_MP;
            uiSleep 0.75;
            if (!isNull _obj) then { _obj setVariable ["AP_trunkLock", false, true]; };
        };
    };
    AP_trunk_vehicle = objNull;
}];

[_ctrl, "storage", (call _data)] call webui_fnc_push;
diag_log "[STORAGE] card ready";
