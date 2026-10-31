/*
    APS_fnc_rigSRV -- RESOURCE EXTRACTOR / PROCESSOR authority (traded system,
    2026-08-27, renamed to this project).

    The HEMTT is the authoritative entity; every visual is client-local (see
    AP_fnc_rigClient). This function owns spawn, the drill state machine, every
    validation, the mining tick, and cleanup. Clients REQUEST; this verifies,
    mutates published state, and the clients render it.

        ["spawn", [_kind, _pos, _dir, _ownerUid]]      (server-internal/admin)
        ["deploy", [_player, _truck]]
        ["fold",   [_player, _truck]]
        ["mineStart", [_player, _truck]]
        ["mineStop",  [_player, _truck]]
        ["link",   [_player, _processor, _extractor]]     (35m, max 2, netId)
        ["unlink", [_player, _processor, _netIdStr]]
        ["procStart", [_player, _processor]]
        ["procStop",  [_player, _processor]]

    State machine (public stable states compact/deployed/mining):
        compact -> deploying -> deployed -> startingMining -> mining
        mining -> stoppingMining -> deployed -> folding -> compact

    Yields tick into the TRUCK'S OWN virtual trunk (AP_vinv), weight-capped by
    the same AP_fnc_vehicleWeight every trunk reader uses -- so what the drill
    pulls is already in the economy: process it, list it on the Exchange SELL
    tab, feed the fabricator. Zone -> resource comes from the SAME markers
    fn_gather reads; a rig parked nowhere mines nothing.
*/
#define RIG_TRANS_DUR   5.00
#define RIG_MINE_TICK   1.3
#define RIG_MAX_SPEED   0.6
#define RIG_PROC_TICK   2.6
#define RIG_LINK_RANGE  35

if (!isServer) exitWith {};
params [["_verb", "", [""]], ["_data", [], [[]]]];

// "spawn" is server-internal/admin (audit 2026-09-26, mints/TONb-0-0): it creates a HEMTT for any owner uid at no
// cost, and this function is CfgRE-whitelisted for its request verbs, so any client could mint trucks with it.
// Nothing legitimate sends it over the wire, so a remote-executed "spawn" is refused. A server-side `call` is not.
if (toLower _verb isEqualTo "spawn" && {isRemoteExecuted}) exitWith {
    ["-SEC-", (allPlayers select { owner _x isEqualTo remoteExecutedOwner }) param [0, objNull], format ["BLOCKED rigSRV spawn %1", (str _data) select [0, 160]]] call APS_fnc_logIt;
};

private _no = {
    params ["_p", "_m"];
    if (!isNull _p) then { [[_m, "basic"], "AP_fnc_handleMessage", _p, false, false] spawn AP_fnc_MP; };
    false
};

// zone -> [radius, weighted loot] -- mirrors fn_gather's own table
private _zoneOf = {
    params ["_truck"];
    private _zones = ["mine_1","mine_2","mine_3","mine_4","mine_5","mine_6","oil_1","oil_2","oil_3","rock_1","rock_2","rock_3","salt_1"];
    private _near = _zones select { markerType _x isNotEqualTo "" && {_truck distance2D (getMarkerPos _x) <= ([150, 70] select ((_x find "mine") != -1))} };
    _near param [0, ""]
};
private _lootOf = {
    params ["_zone"];
    switch (true) do {
        case (_zone find "mine" != -1): { ["ironore","ironore","copperore","copperore","sand","diamond"] };
        case (_zone find "oil"  != -1): { ["oilu"] };
        case (_zone find "rock" != -1): { ["redshift"] };
        case (_zone find "salt" != -1): { ["salt"] };
        default { [] };
    }
};

// raw -> refined, 1:1 -- the SAME conversions the processing plants run
// (AP_processMap, client side); redshift is already refined and passes nothing.
private _procMap = createHashMapFromArray [
    ["ironore", "iron_r"], ["copperore", "copper_r"], ["sand", "glass"],
    ["diamond", "diamondc"], ["oilu", "oilp"], ["salt", "salt_r"]
];

// shared request validation (the donor contract's list, on our primitives)
private _checkReq = {
    params ["_p", "_truck", "_needState", ["_kind", "extractor"]];
    if (isNull _p || {!isPlayer _p} || {!alive _p}) exitWith { false };
    if (isNull _truck || {!alive _truck}) exitWith { [_p, "The vehicle is gone."] call _no };
    if ((localNamespace getVariable ["APS_rigKind_" + netId _truck, ""]) isNotEqualTo _kind) exitWith { [_p, format ["That is not a %1.", _kind]] call _no };   // server copy (APS_fnc_rigAdopt)
    if ((_p distance _truck) > 12) exitWith { [_p, "Stand at the vehicle."] call _no };
    if (speed _truck > RIG_MAX_SPEED) exitWith { [_p, "Stop the vehicle first."] call _no };
    if ((crew _truck) isNotEqualTo []) exitWith { [_p, "Everyone out before the drill moves."] call _no };
    // ownership: the vehicle's owner list or a keyholder
    private _uid = getPlayerUID _p;
    private _owners = _truck getVariable ["AP_vehOwners", []];
    private _isOwner = (_owners findIf { (format ["%1", _x param [0, ""]]) isEqualTo _uid }) != -1;
    if (!_isOwner && {!([_truck, _uid, "accessLock"] call AP_fnc_keyHolderStatus)}) exitWith {
        [_p, "You need the keys to operate this rig."] call _no };
    if (_needState isNotEqualTo "" && {(_truck getVariable ["AP_rigState", "compact"]) isNotEqualTo _needState}) exitWith {
        [_p, format ["Cannot do that from '%1'.", _truck getVariable ["AP_rigState", "compact"]]] call _no };
    true
};

// does _p hold keys to _truck (owner row or keyholder)? -- the same test
// _checkReq runs, reusable against the SECOND truck of a link request
private _hasKeys = {
    params ["_p", "_truck"];
    private _uid = getPlayerUID _p;
    private _owners = _truck getVariable ["AP_vehOwners", []];
    ((_owners findIf { (format ["%1", _x param [0, ""]]) isEqualTo _uid }) != -1)
        || {[_truck, _uid, "accessLock"] call AP_fnc_keyHolderStatus}
};

// transition helper: publish transient state + transition, settle to stable
private _transit = {
    params ["_truck", "_from", "_transient", "_to", "_dur"];
    _truck setVariable ["AP_rigTransition", [_from, _to, serverTime, _dur], true];
    _truck setVariable ["AP_rigState", _transient, true];
    [_truck, _transient, _to, _dur] spawn {
        params ["_truck", "_transient", "_to", "_dur"];
        uiSleep _dur;
        if (isNull _truck) exitWith {};
        if ((_truck getVariable ["AP_rigState", ""]) isEqualTo _transient) then {
            _truck setVariable ["AP_rigState", _to, true];
        };
    };
};

switch (toLower _verb) do {

// ADOPT moved to APS_fnc_rigAdopt (audit 2026-09-26, mints): this function is CfgRE-whitelisted for its request
// verbs, so any client could stamp extractor/processor identity -- a working mining rig -- onto any truck it held
// keys to, without crafting one. It cannot be gated here by remoteExecutedOwner, because its legit callers `call`
// it from inside a client's remote-executed frame (APS_fnc_vehicleSetActive on a garage pull), so it lives in a
// function that is simply not in CfgRE.hpp -- the ndCreditSrv/fabXp pattern. Nothing legit sends "adopt" here.
case "adopt": {
    ["-SEC-", (allPlayers select { owner _x isEqualTo remoteExecutedOwner }) param [0, objNull], format ["BLOCKED rigSRV adopt %1", (str _data) select [0, 160]]] call APS_fnc_logIt;
};

case "spawn": {
    _data params [["_kind", "", [""]], ["_pos", [], [[]]], ["_dir", 0, [0]], ["_ownerUid", "", [""]]];
    if !(_kind in ["extractor", "processor"]) exitWith {};
    private _truck = createVehicle ["B_Truck_01_flatbed_F", _pos, [], 0, "NONE"];
    _truck setDir _dir;
    _truck setPosATL _pos;
    if (_ownerUid isNotEqualTo "") then {
        _truck setVariable ["AP_vehOwners", [[_ownerUid, "owner"]], true];
    };
    _truck setVariable ["AP_vinv", [[], 0], true];
    [_truck, _kind] call APS_fnc_rigAdopt;
    [["-RIG-", objNull, "server", format ["spawned %1 at %2 for %3", _kind, _pos, _ownerUid]], "APS_fnc_logIt", 2, false, false] spawn AP_fnc_MP;
    _truck
};

// CRAFT: the Factory's build request. Materials were consumed client-side --
// the Factory's existing trust model, unchanged -- so this spawns, adopts,
// stamps ownership and PERSISTS through the same vehicleCreate/insertVehicle
// pipe every bought vehicle rides (server-internal call keeps the uid, and
// vehicleCreate reads rigAdopt's localNamespace APS_rigKind_<netId> for the rig_kind column, and refuses a live
// rig unless the APS_rigPersist_<netId> token below says this is its craft).
case "craft": {
    _data params [["_p", objNull, [objNull]], ["_kind", "", [""]], ["_pos", [], [[]]], ["_dir", 0, [0]]];
    if (isNull _p || {!isPlayer _p} || {!(_kind in ["extractor", "processor"])}) exitWith {};
    if (count _pos < 3) exitWith {};
    // Audit 2026-09-26 (mints): the materials are consumed client-side, so every craft request used to put a
    // persisted, garage-sellable HEMTT into the garage of whichever player the payload named, as often as it was
    // sent. A client request now crafts for the CALLER only, and one rig per player per 30 minutes (a rig takes
    // 140+ refined ingots, so an honest player never gets near that) -- the bound, since the server cannot see
    // the materials. localNamespace, so a client publicVariable cannot reset it.
    if (isRemoteExecuted && {_p isNotEqualTo ((allPlayers select { owner _x isEqualTo remoteExecutedOwner }) param [0, objNull])}) exitWith {
        ["-SEC-", (allPlayers select { owner _x isEqualTo remoteExecutedOwner }) param [0, objNull], format ["BLOCKED rigSRV craft of a %1 for %2 (not the caller)", _kind, name _p]] call APS_fnc_logIt;
    };
    private _uid = getPlayerUID _p;
    private _ccd = localNamespace getVariable "AP_rigCraftCd";
    if (isNil "_ccd") then { _ccd = createHashMap; localNamespace setVariable ["AP_rigCraftCd", _ccd]; };
    if ((_ccd getOrDefault [_uid, -1]) > serverTime) exitWith {
        ["-SEC-", _p, format ["BLOCKED rigSRV craft of a %1 (one rig per 30 min per player)", _kind]] call APS_fnc_logIt;
        [_p, "The Factory builds you one rig every 30 minutes -- try again later."] call _no;
    };
    _ccd set [_uid, serverTime + 1800];
    private _truck = createVehicle ["B_Truck_01_flatbed_F", _pos, [], 0, "NONE"];
    _truck setDir _dir;
    _truck setPosATL _pos;
    _truck lock true;
    _truck setVariable ["AP_vehOwners", [[_uid, name _p]], true];
    _truck setVariable ["AP_vinv", [[], 0], true];
    [_truck, _kind] call APS_fnc_rigAdopt;
    localNamespace setVariable ["APS_rigPersist_" + netId _truck, true];   // one-shot: vehicleCreate registers a live rig only with this (r2rig)
    [objNull, _truck, _uid, "civ", 0, 0] call APS_fnc_vehicleCreate;
    [["-RIG-", _p, name _p, format ["crafted a %1 at the factory (%2)", _kind, _pos]], "APS_fnc_logIt", 2, false, false] spawn AP_fnc_MP;
};

// TARGET: the deck console picks WHAT to mine. Validated against the loot the
// zone under the truck actually offers -- a client-sent resource name buys
// nothing anywhere else.
case "settarget": {
    _data params [["_p", objNull, [objNull]], ["_truck", objNull, [objNull]], ["_res", "", [""]]];
    if (isNull _p || {isNull _truck}) exitWith {};
    if ((localNamespace getVariable ["APS_rigKind_" + netId _truck, ""]) isNotEqualTo "extractor") exitWith {};
    if ((_p distance _truck) > 25) exitWith {};
    private _zone = [_truck] call _zoneOf;
    private _offer = [_zone] call _lootOf;
    if (_res isNotEqualTo "" && {!(_res in _offer)}) exitWith {
        [_p, "This deposit does not hold that."] call _no };
    _truck setVariable ["AP_rigTarget", _res, true];   // "" = take the roll
};

case "deploy": {
    _data params [["_p", objNull, [objNull]], ["_truck", objNull, [objNull]]];
    if !([_p, _truck, "compact"] call _checkReq) exitWith {};
    [_truck, "compact", "deploying", "deployed", RIG_TRANS_DUR] call _transit;
    // the contract: engine forced off whenever the drill is not compact
    [_truck] spawn {
        params ["_truck"];
        while { !isNull _truck && { (_truck getVariable ["AP_rigState", "compact"]) isNotEqualTo "compact" } } do {
            if (isEngineOn _truck) then { _truck engineOn false; };
            uiSleep 1;
        };
    };
};

case "fold": {
    _data params [["_p", objNull, [objNull]], ["_truck", objNull, [objNull]]];
    if !([_p, _truck, "deployed"] call _checkReq) exitWith {};
    [_truck, "deployed", "folding", "compact", RIG_TRANS_DUR] call _transit;
};

case "minestart": {
    _data params [["_p", objNull, [objNull]], ["_truck", objNull, [objNull]]];
    if !([_p, _truck, "deployed"] call _checkReq) exitWith {};
    private _zone = [_truck] call _zoneOf;
    if (_zone isEqualTo "") exitWith { [_p, "No extractable deposit here -- park inside a resource field."] call _no };
    [_truck, "deployed", "startingMining", "mining", 1.15] call _transit;
    [_truck, _zone, _lootOf] spawn {
        params ["_truck", "_zone", "_lootOf"];
        uiSleep 1.2;
        while { !isNull _truck && {alive _truck} && {(_truck getVariable ["AP_rigState", ""]) isEqualTo "mining"} } do {
            private _loot = [_zone] call _lootOf;
            if (_loot isEqualTo []) exitWith {};
            // the deck console's pick, if it names something this deposit holds;
            // otherwise the zone's own weighted roll
            private _want = _truck getVariable ["AP_rigTarget", ""];
            private _item = if (_want isNotEqualTo "" && {_want in _loot}) then { _want } else { selectRandom _loot };
            private _w = ["getItemWeight", _item] call AP_fnc_virtItemCfg;
            if !(_w isEqualType 0) then { _w = 1 };
            (_truck getVariable ["AP_vinv", [[], 0]]) params [["_inv", []], ["_used", 0]];
            private _cap = ([_truck, true] call AP_fnc_vehicleWeight) param [0, 0];
            if (_used + _w > _cap) exitWith {
                // hopper full: stop mining, leave the drill deployed
                _truck setVariable ["AP_rigState", "stoppingMining", true];
                _truck setVariable ["AP_rigTransition", ["mining", "deployed", serverTime, 1.15], true];
                uiSleep 1.2;
                if (!isNull _truck) then { _truck setVariable ["AP_rigState", "deployed", true]; };
            };
            private _i = _inv findIf { (_x select 0) isEqualTo _item };
            if (_i isEqualTo -1) then { _inv pushBack [_item, 1]; } else {
                (_inv select _i) set [1, ((_inv select _i) select 1) + 1]; };
            _truck setVariable ["AP_vinv", [_inv, _used + _w], true];
            uiSleep RIG_MINE_TICK;
        };
    };
    [["-RIG-", _p, name _p, format ["started mining at %1 (%2)", _zone, getPosATL _truck]], "APS_fnc_logIt", 2, false, false] spawn AP_fnc_MP;
};

// LINK: bind an extractor's hopper to this processor. Donor defaults kept:
// 35m, max 2 per processor, one processor per extractor, stored by netId
// (presentation objects never own state; netIds die at restart -> links are
// runtime-only and re-made after a pull, which the deck console makes cheap).
case "link": {
    _data params [["_p", objNull, [objNull]], ["_proc", objNull, [objNull]], ["_extr", objNull, [objNull]]];
    if !([_p, _proc, "", "processor"] call _checkReq) exitWith {};
    if (isNull _extr || {!alive _extr} || {(localNamespace getVariable ["APS_rigKind_" + netId _extr, ""]) isNotEqualTo "extractor"}) exitWith {
        [_p, "No extractor there."] call _no };
    if ((_proc distance _extr) > RIG_LINK_RANGE) exitWith { [_p, format ["Out of feed range (%1m).", RIG_LINK_RANGE]] call _no };
    if !([_p, _extr] call _hasKeys) exitWith { [_p, "You need the keys to that extractor too."] call _no };
    private _links = _proc getVariable ["AP_rigLinks", []];
    if ((count _links) >= 2) exitWith { [_p, "This processor already feeds from two extractors."] call _no };
    private _already = _extr getVariable ["AP_rigLinkedTo", ""];
    if (_already isNotEqualTo "" && {!isNull objectFromNetId _already}) exitWith {
        [_p, "That extractor is already feeding another processor."] call _no };
    _proc setVariable ["AP_rigLinks", _links + [netId _extr], true];
    _extr setVariable ["AP_rigLinkedTo", netId _proc, true];
    [["-RIG-", _p, name _p, format ["linked extractor %1 to processor %2", netId _extr, netId _proc]], "APS_fnc_logIt", 2, false, false] spawn AP_fnc_MP;
};

case "unlink": {
    _data params [["_p", objNull, [objNull]], ["_proc", objNull, [objNull]], ["_nid", "", [""]]];
    if !([_p, _proc, "", "processor"] call _checkReq) exitWith {};
    _proc setVariable ["AP_rigLinks", (_proc getVariable ["AP_rigLinks", []]) - [_nid], true];
    private _e = objectFromNetId _nid;
    if (!isNull _e) then { _e setVariable ["AP_rigLinkedTo", "", true]; };
};

// PROCSTART: the refine loop. One raw unit per tick, linked extractor hoppers
// first, the processor's own trunk second (raw hand-loaded via the Trunk app
// refines too). Everything mutates server-side published AP_vinv with weights
// re-derived from AP_fnc_virtItemCfg -- the clients only ever read.
case "procstart": {
    _data params [["_p", objNull, [objNull]], ["_truck", objNull, [objNull]]];
    if !([_p, _truck, "idle", "processor"] call _checkReq) exitWith {};
    _truck setVariable ["AP_rigState", "processing", true];
    [_truck, _procMap] spawn {
        params ["_truck", "_procMap"];
        while { !isNull _truck && {alive _truck} && {(_truck getVariable ["AP_rigState", ""]) isEqualTo "processing"} } do {
            if (isEngineOn _truck) then { _truck engineOn false; };   // the contract: engine off while working
            if (speed _truck > RIG_MAX_SPEED) exitWith { _truck setVariable ["AP_rigState", "idle", true]; };
            // prune links that died or drifted out of range (5m grace over link range)
            private _links = _truck getVariable ["AP_rigLinks", []];
            private _live = _links select {
                private _e = objectFromNetId _x;
                !isNull _e && {alive _e} && {(_truck distance _e) <= (RIG_LINK_RANGE + 5)}
            };
            if ((count _live) != (count _links)) then {
                {
                    private _e = objectFromNetId _x;
                    if (!isNull _e) then { _e setVariable ["AP_rigLinkedTo", "", true]; };
                } forEach (_links - _live);
                _truck setVariable ["AP_rigLinks", _live, true];
            };
            // first raw unit anywhere: linked extractors first, own trunk second
            private _sources = (_live apply { objectFromNetId _x }) + [_truck];
            private _src = objNull; private _raw = "";
            {
                private _inv = (_x getVariable ["AP_vinv", [[], 0]]) param [0, []];
                private _i = _inv findIf { (_x select 0) in _procMap && {(_x select 1) > 0} };
                if (_i != -1) exitWith { _src = _x; _raw = (_inv select _i) select 0; };
            } forEach _sources;
            if (isNull _src) then { uiSleep RIG_PROC_TICK; continue };   // nothing to refine yet -- extractors may still be filling
            private _ref = _procMap get _raw;
            private _wRaw = ["getItemWeight", _raw] call AP_fnc_virtItemCfg;
            private _wRef = ["getItemWeight", _ref] call AP_fnc_virtItemCfg;
            if !(_wRaw isEqualType 0) then { _wRaw = 1 };
            if !(_wRef isEqualType 0) then { _wRef = 1 };
            // capacity gate on the PROCESSOR (own-trunk refines net weight change _wRef-_wRaw)
            (_truck getVariable ["AP_vinv", [[], 0]]) params [["_pInv", []], ["_pUsed", 0]];
            private _cap = ([_truck, true] call AP_fnc_vehicleWeight) param [0, 0];
            private _delta = [_wRef, _wRef - _wRaw] select (_src isEqualTo _truck);
            if (_pUsed + _delta > _cap) exitWith { _truck setVariable ["AP_rigState", "idle", true] };   // hopper full
            // take 1 raw from the source
            (_src getVariable ["AP_vinv", [[], 0]]) params [["_sInv", []], ["_sUsed", 0]];
            private _si = _sInv findIf { (_x select 0) isEqualTo _raw };
            if (_si != -1) then {
                private _q = ((_sInv select _si) select 1) - 1;
                if (_q <= 0) then { _sInv deleteAt _si; } else { (_sInv select _si) set [1, _q]; };
                if (_src isEqualTo _truck) then { _pInv = _sInv; _pUsed = _sUsed; };   // same array after the take
                _src setVariable ["AP_vinv", [_sInv, 0 max (_sUsed - _wRaw)], true];
                if (_src isEqualTo _truck) then { _pUsed = 0 max (_pUsed - _wRaw); };
                // add 1 refined to the processor
                private _pi = _pInv findIf { (_x select 0) isEqualTo _ref };
                if (_pi isEqualTo -1) then { _pInv pushBack [_ref, 1]; } else {
                    (_pInv select _pi) set [1, ((_pInv select _pi) select 1) + 1]; };
                _truck setVariable ["AP_vinv", [_pInv, _pUsed + _wRef], true];
            };
            uiSleep RIG_PROC_TICK;
        };
        if (!isNull _truck && {(_truck getVariable ["AP_rigState", ""]) isEqualTo "processing"}) then {
            _truck setVariable ["AP_rigState", "idle", true]; };
    };
    [["-RIG-", _p, name _p, format ["started processing (%1)", getPosATL _truck]], "APS_fnc_logIt", 2, false, false] spawn AP_fnc_MP;
};

case "procstop": {
    _data params [["_p", objNull, [objNull]], ["_truck", objNull, [objNull]]];
    if !([_p, _truck, "processing", "processor"] call _checkReq) exitWith {};
    _truck setVariable ["AP_rigState", "idle", true];
};

case "minestop": {
    _data params [["_p", objNull, [objNull]], ["_truck", objNull, [objNull]]];
    if !([_p, _truck, "mining"] call _checkReq) exitWith {};
    [_truck, "mining", "stoppingMining", "deployed", 1.15] call _transit;
};

default {};
};
