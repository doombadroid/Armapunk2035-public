/*
    fn_invBridge.sqf -- the I-screen's bridge half (dialog 938500 onLoad). INVENTORY_SPEC.md §9.

    fn_invOpen.sqf has reserved the reach container (AP_veh_in_use) and put the dialog up. This
    file wires the page: bridge init + server page serve, the 40x22 windowed geometry, one handler
    per verb of the contract (inventory_plan.md "Contract"), a 1 Hz watcher that re-pushes when the
    engine changed something behind the page's back (a vehicle driving off, someone else opening
    the crate, a mag emptied), and the Unload cleanup that releases the reservation.

    NOTHING HERE MOVES AN ITEM. Verbs route to
      AP_fnc_invLocal     own-body moves (client-local)
      AP_fnc_invGunsmith  attachments and magazines (client-local)
      APS_fnc_invCargo    vehicle / crate / ground-holder cargo (server, one serialised mutator),
                          asked through AP_fnc_invCargoAsk below and answered by AP_fnc_invCargoRecv
    and every successful mutation ends in AP_fnc_invCommit (Take/Put replication, saveGear, push).

    Handlers run in the bridge's spawned thread (webui_fnc_init answers the page's alert
    immediately and delivers from a spawn), so waiting on a server ticket inside one is fine.
*/

// ----------------------------------------------------------------- pushers --
// Global fns: the handlers and the watcher outlive this scope.
if !(isFinal "AP_fnc_invPush") then {AP_fnc_invPush = compileFinal {
    private _c = uiNamespace getVariable ["AP_invCtrl", controlNull];
    if (isNull _c) exitWith {};
    uiNamespace setVariable ["AP_invSig", [] call AP_fnc_invSig];
    private _snap = [] call AP_fnc_invSnapshot;
    diag_log format ["[INV] push: uniform=%1 vest=%2 backpack=%3 primary=%4 handgun=%5 conts=%6 ground=%7/%8 cont=%9",
        uniform player, vest player, backpack player, primaryWeapon player, handgunWeapon player,
        count ((_snap get "you") get "containers"), count ((_snap get "ground") get "physical"), count ((_snap get "ground") get "virtual"),
        !((_snap get "container") isEqualType objNull)];
    [_c, "inventory", _snap] call webui_fnc_push;
    if (!isNil "AP_fnc_invFigSync") then { call AP_fnc_invFigSync; };   // the studio mannequin follows the gear
    private _gs = uiNamespace getVariable ["AP_invGsOpen", ""];
    if (_gs != "") then {
        // the verb takes [slot], not the slot (a bare string failed params and the gunsmith never opened, 2026-09-07);
        // "no weapon" comes back as objNull, which toJSON cannot carry -- the page's contract is null (a 2-arg push)
        private _d = ["data", [_gs]] call AP_fnc_invGunsmith;
        if (_d isEqualType objNull) then {
            uiNamespace setVariable ["AP_invGsOpen", ""];
            [_c, "gunsmith"] call webui_fnc_push;
        } else {
            [_c, "gunsmith", _d] call webui_fnc_push;
        };
    };
}};
if !(isFinal "AP_fnc_invPushGs") then {AP_fnc_invPushGs = compileFinal {
    private _c = uiNamespace getVariable ["AP_invCtrl", controlNull];
    if (isNull _c) exitWith {};
    private _gs = uiNamespace getVariable ["AP_invGsOpen", ""];
    private _d = if (_gs isEqualTo "") then { objNull } else { ["data", [_gs]] call AP_fnc_invGunsmith };
    // closed / no weapon -> null on the wire: a pushed objNull threw in toJSON on every refresh (2026-09-07)
    if (_d isEqualType objNull) then { [_c, "gunsmith"] call webui_fnc_push } else { [_c, "gunsmith", _d] call webui_fnc_push };
}};
// a cheap "did anything change" fingerprint for the watcher
if !(isFinal "AP_fnc_invSig") then {AP_fnc_invSig = compileFinal {
    private _cont = uiNamespace getVariable ["AP_invContainer", objNull];
    private _near = (nearestObjects [player, ["WeaponHolder", "WeaponHolderSimulated", "Land_Suitcase_F"], 5]) apply {
        [_x, loadAbs _x, _x getVariable ["AP_droppedItems", []]]
    };
    private _c = if (isNull _cont) then { [] } else {
        [alive _cont, loadAbs _cont, _cont getVariable ["AP_veh_in_use", objNull], _cont getVariable ["AP_trunkLock", false], player distance _cont > 12]
    };
    str [getUnitLoadout player, loadAbs player, AP_carryWeight, AP_maxWeight, _near, _c, count allPlayers]
}};
// ask the server's cargo arbiter and wait for its verdict (5 s)
if !(isFinal "AP_fnc_invCargoAsk") then {AP_fnc_invCargoAsk = compileFinal {
    params ["_verb", "_target", "_spec"];
    AP_invTicket = AP_invTicket + 1;
    private _t = AP_invTicket;
    [[_t, _verb, if (isNull _target) then { "" } else { netId _target }, _spec], "APS_fnc_invCargo", 2, false] spawn AP_fnc_MP;
    private _until = time + 5;
    waitUntil { uiSleep 0.05; (!isNil { AP_invTickets get _t }) || { time > _until } };
    private _r = AP_invTickets getOrDefault [_t, [false, "THE SERVER DID NOT ANSWER.", []]];
    AP_invTickets deleteAt _t;
    createHashMapFromArray [["ok", _r param [0, false]], ["msg", _r param [1, ""]], ["extra", _r param [2, []]]]
}};
// finish a verb: commit on success, resync on refusal, answer the page
if !(isFinal "AP_fnc_invDone") then {AP_fnc_invDone = compileFinal {
    params ["_r"];
    if (_r get "ok") then {
        [_r getOrDefault ["took", []], _r getOrDefault ["put", []]] call AP_fnc_invCommit;
    } else {
        [] call AP_fnc_invPush;
    };
    createHashMapFromArray [["ok", _r get "ok"], ["msg", _r getOrDefault ["msg", ""]]]
}};
AP_fnc_invSlots = ["primary", "handgun", "launcher", "uniform", "vest", "backpack", "headgear", "facewear", "binocular"];
if !(isFinal "AP_fnc_invIsSlot") then {AP_fnc_invIsSlot = compileFinal { params ["_s"]; (_s in AP_fnc_invSlots) || {(_s select [0, 9]) isEqualTo "assigned:"} }};
if !(isFinal "AP_fnc_invNormSlot") then {AP_fnc_invNormSlot = compileFinal { params ["_s"]; if (_s in ["map", "gps", "radio", "compass", "watch", "nvg"]) then { "assigned:" + _s } else { _s } }};
// "slot|<slot>|<cls>" / "loc|cls|ammo[|k]" -> [loc, cls, ammo, slotName]
if !(isFinal "AP_fnc_invParseAny") then {AP_fnc_invParseAny = compileFinal {
    params ["_id"];
    private _p = _id splitString "|";
    if ((_p param [0, ""]) isEqualTo "slot") exitWith { ["slot", _p param [2, ""], -1, _p param [1, ""]] };
    [_p param [0, ""], _p param [1, ""], parseNumber (_p param [2, "-1"]), ""]
}};
if !(isFinal "AP_fnc_invReachObj") then {AP_fnc_invReachObj = compileFinal {
    params ["_loc"];
    if (_loc isEqualTo "container") exitWith { uiNamespace getVariable ["AP_invContainer", objNull] };
    if ((_loc select [0, 7]) isEqualTo "ground:") exitWith { objectFromNetId (_loc select [7]) };
    objNull
}};
if !(isFinal "AP_fnc_invSpecOf") then {AP_fnc_invSpecOf = compileFinal {
    // what the server needs to find one unit: [cls, kind, ammo]
    params ["_cls", "_ammo"];
    private _i = [_cls] call AP_fnc_invItemInfo;
    [_cls, _i get "kind", _ammo]
}};
// bring one unit from the reach container / a holder onto the player: into toLoc (an own container or
// a weapon slot). Returns the invLocal-shaped verdict.
if !(isFinal "AP_fnc_invTakeFromReach") then {AP_fnc_invTakeFromReach = compileFinal {
    params ["_loc", "_cls", "_ammo", "_toLoc", "_qty"];
    private _obj = [_loc] call AP_fnc_invReachObj;
    if (isNull _obj) exitWith { createHashMapFromArray [["ok", false], ["msg", "THAT IS GONE."]] };
    private _verb = if (_loc isEqualTo "container") then { "take" } else { "pickup" };
    private _r = [_verb, _obj, ([_cls, _ammo] call AP_fnc_invSpecOf) + [_toLoc, _qty]] call AP_fnc_invCargoAsk;
    if (_r get "ok") then {
        // a weapon landed in a slot by addWeaponGlobal; its attachments and magazine are local-arg
        // commands, so the server hands them back and the owner's client mounts them here
        private _wi = _r get "extra";
        if (_toLoc in ["primary", "handgun", "launcher"] && {_wi isNotEqualTo []}) then {
            { if (_x != "") then { player addWeaponItem [_cls, _x, true]; }; } forEach [_wi param [1, ""], _wi param [2, ""], _wi param [3, ""], _wi param [6, ""]];
            private _m = _wi param [4, []];
            if (_m isNotEqualTo []) then { player addWeaponItem [_cls, [_m select 0, _m select 1], true]; };
        };
        _r set ["took", [[_obj, _cls]]];
    };
    _r
}};
// the whole drag matrix (INVENTORY_SPEC.md §5a) in one router
if !(isFinal "AP_fnc_invMoveVerb") then {AP_fnc_invMoveVerb = compileFinal {
    params ["_from", "_id", "_to", "_qty"];
    ([_id] call AP_fnc_invParseAny) params ["_loc", "_cls", "_ammo", "_slotName"];
    if (_from isEqualTo "") then { _from = _loc };
    _slotName = [_slotName] call AP_fnc_invNormSlot;
    _to = [_to] call AP_fnc_invNormSlot;
    private _own = ["uniform", "vest", "backpack"];
    private _fromReach = (_from isEqualTo "container") || {(_from select [0, 7]) isEqualTo "ground:"};
    private _toSlot = [_to] call AP_fnc_invIsSlot;
    _qty = _qty max 1;

    // worn slot -> somewhere
    if (_loc isEqualTo "slot") exitWith {
        if (_to in _own || {_to isEqualTo "ground"}) exitWith { ["unequip", [_slotName, _to]] call AP_fnc_invLocal };
        if (_to isEqualTo "container") exitWith {
            private _obj = ["container"] call AP_fnc_invReachObj;
            private _r = ["store", _obj, ([_cls, -1] call AP_fnc_invSpecOf) + [_slotName, 1]] call AP_fnc_invCargoAsk;
            if (_r get "ok") then { _r set ["put", [[_obj, _cls]]]; if (_slotName isEqualTo "backpack") then { [true] call AP_fnc_invisBag; }; };
            _r
        };
        createHashMapFromArray [["ok", false], ["msg", "NOWHERE TO PUT THAT."]]
    };

    // own container -> somewhere
    if (_from in _own) exitWith {
        if (_to in _own) exitWith { ["move", [_from, _id, _to, _qty]] call AP_fnc_invLocal };
        if (_toSlot) exitWith { ["equip", [_from, _id, _to]] call AP_fnc_invLocal };
        if (_to in ["ground", "container"]) exitWith {
            private _obj = if (_to isEqualTo "container") then { ["container"] call AP_fnc_invReachObj } else { objNull };
            if (_to isEqualTo "container" && {isNull _obj}) exitWith { createHashMapFromArray [["ok", false], ["msg", "NOTHING IN REACH."]] };
            private _verb = if (_to isEqualTo "container") then { "store" } else { "drop" };
            private _r = [_verb, _obj, ([_cls, _ammo] call AP_fnc_invSpecOf) + [_from, _qty]] call AP_fnc_invCargoAsk;
            if (_r get "ok") then {
                private _h = _r get "extra";
                private _dest = if (_to isEqualTo "container") then { _obj } else { if (_h isEqualType "" && {_h != ""}) then { objectFromNetId _h } else { objNull } };
                _r set ["put", [[_dest, _cls]]];
            };
            _r
        };
        createHashMapFromArray [["ok", false], ["msg", "NOWHERE TO PUT THAT."]]
    };

    // reach (vehicle / crate / ground holder) -> the player
    if (_fromReach) exitWith {
        if (_to in _own) exitWith { [_from, _cls, _ammo, _to, _qty] call AP_fnc_invTakeFromReach };
        if (_toSlot) exitWith {
            private _i = [_cls] call AP_fnc_invItemInfo;
            if ((_i get "kind") isEqualTo "weapon" && {_to in ["primary", "handgun", "launcher"]}) exitWith {
                // clear the slot first (the displaced weapon goes back to the source if it fits, else
                // into a container, else the ground), then the server lifts the new one straight in
                private _old = switch (_to) do { case "primary": { primaryWeapon player }; case "handgun": { handgunWeapon player }; default { secondaryWeapon player } };
                if (_old != "") then {
                    private _put = false;
                    if (_from isEqualTo "container") then {
                        private _obj = ["container"] call AP_fnc_invReachObj;
                        private _s = ["store", _obj, ([_old, -1] call AP_fnc_invSpecOf) + [_to, 1]] call AP_fnc_invCargoAsk;
                        _put = _s get "ok";
                    };
                    if (!_put) then { ["unequip", [_to, ""]] call AP_fnc_invLocal; };
                };
                [_from, _cls, _ammo, _to, 1] call AP_fnc_invTakeFromReach
            };
            // everything else stages into a container, then equips locally (migration, textures, all of it)
            private _row = [_cls, _ammo] call AP_fnc_invRowFor;
            private _stage = [_row] call AP_fnc_invFirstRoom;
            if (_stage isEqualTo "") exitWith { createHashMapFromArray [["ok", false], ["msg", "NO ROOM TO PICK THAT UP FIRST."]] };
            private _r = [_from, _cls, _ammo, _stage, 1] call AP_fnc_invTakeFromReach;
            if !(_r get "ok") exitWith { _r };
            private _e = ["equip", [_stage, format ["%1|%2|%3", _stage, _cls, _ammo], _to]] call AP_fnc_invLocal;
            _e set ["took", _r get "took"];
            _e
        };
        createHashMapFromArray [["ok", false], ["msg", "ONE HOP AT A TIME."]]
    };

    createHashMapFromArray [["ok", false], ["msg", "UNKNOWN MOVE."]]
}};

// SECURITY 2026-09-26: core\init.sqf calls this with "boot" at client init, so the helpers above are
// defined (final) before another client can publicVariable a final copy of one first.
if (_this isEqualTo "boot") exitWith {};

params [["_display", displayNull, [displayNull]]];
if (isNull _display) exitWith {};
disableSerialization;

private _ctrl = _display displayCtrl 938501;
if (isNull _ctrl) exitWith { diag_log "[INV] control 938501 missing" };
if !([_ctrl] call webui_fnc_init) exitWith { diag_log "[INV] bridge init failed" };
[_ctrl, "ui\html\inventory.html"] call webui_fnc_serve;

// windowed web UI: base 40x22 grid scaled by the phone's size slider, centred (armory convention;
// 1.82:1 is the ratio the design was drawn at)
private _s = profileNamespace getVariable ["AP_deckScale", 1];
private _gw = 2.5 * pixelW * pixelGrid; private _gh = 2.5 * pixelH * pixelGrid;
private _w = 40 * _gw * _s; private _h = 22 * _gh * _s;
_ctrl ctrlSetPosition [0.5 - _w / 2, 0.5 - _h / 2, _w, _h];
_ctrl ctrlCommit 0;

uiNamespace setVariable ["AP_invCtrl", _ctrl];
uiNamespace setVariable ["AP_invGsOpen", ""];
uiNamespace setVariable ["AP_invSig", ""];
AP_invTicket = 0;
AP_invTickets = createHashMap;
AP_invBusy = false;
["init", []] call AP_fnc_invLocal;

private _OK = { createHashMapFromArray [["ok", true], ["msg", ""]] };
private _NO = { params ["_m"]; createHashMapFromArray [["ok", false], ["msg", _m]] };

// ------------------------------------------------------------- handlers ----
private _fnRun = {
    // serialise the verbs and keep the watcher quiet while one runs
    params ["_code"];
    private _until = time + 6;
    waitUntil { !AP_invBusy || time > _until };
    AP_invBusy = true;
    private _r = call _code;
    AP_invBusy = false;
    [_r] call AP_fnc_invDone
};
uiNamespace setVariable ["AP_invRun", _fnRun];

[_ctrl, "inventory", { [] call AP_fnc_invSnapshot }] call webui_fnc_on;
[_ctrl, "gunsmith", {
    private _gs = uiNamespace getVariable ["AP_invGsOpen", ""];
    private _d = if (_gs isEqualTo "") then { objNull } else { ["data", [_gs]] call AP_fnc_invGunsmith };
    if (_d isEqualType objNull) then { nil } else { _d }   // nil -> null for the page; objNull is not serialisable
}] call webui_fnc_on;
[_ctrl, "log", {
    params [["_m", "", [""]]];
    diag_log format ["[INV] %1", _m];
    createHashMapFromArray [["ok", true], ["msg", ""]]
}] call webui_fnc_on;
[_ctrl, "invRefresh", { [] call AP_fnc_invPush; createHashMapFromArray [["ok", true], ["msg", ""]] }] call webui_fnc_on;
// the page reports where its figure strip sits (fractions of the Page control); the live body
// camera is laid over it -- fn_invFigure.sqf. Re-sent by the page whenever the strip moves.
[_ctrl, "invFigureBox", {
    // [fx, fy, fw, fh, vw, vh, dpr, frameL, frameT, frameW, frameH] -- the tail is calibration data
    ["start", _this] call AP_fnc_invFigure
}] call webui_fnc_on;
// drag across the figure strip turns the studio mannequin
[_ctrl, "invFigureRot", {
    params [["_deg", 0, [0]]];
    private _ok = if (isNil "AP_fnc_invFigRot") then { false } else { [_deg] call AP_fnc_invFigRot };
    createHashMapFromArray [["ok", _ok], ["msg", ""]]
}] call webui_fnc_on;
[_ctrl, "invClose", { closeDialog 0; true }] call webui_fnc_on;

[_ctrl, "invMove", {
    params [["_from", "", [""]], ["_id", "", [""]], ["_to", "", [""]], ["_qty", 1, [0]]];
    [{ [_from, _id, _to, _qty] call AP_fnc_invMoveVerb }] call (uiNamespace getVariable "AP_invRun")
}] call webui_fnc_on;

[_ctrl, "invEquip", {
    params [["_id", "", [""]]];
    ([_id] call AP_fnc_invParseAny) params ["_loc", "_cls", "_ammo", "_slotName"];
    [{
        if (_loc isEqualTo "slot") exitWith { ["unequip", [_slotName, ""]] call AP_fnc_invLocal };
        if (_loc in ["uniform", "vest", "backpack"]) exitWith { ["equip", [_loc, _id, ""]] call AP_fnc_invLocal };
        // from reach: weapons and clothing to their slot, everything else into the first container with room
        private _i = [_cls] call AP_fnc_invItemInfo;
        private _kind = _i get "kind";
        private _wtype = getNumber (configFile >> "CfgWeapons" >> _cls >> "type");
        private _home = switch (_kind) do {
            case "weapon": { switch (_wtype) do { case 1: { "primary" }; case 2: { "handgun" }; case 4: { "launcher" }; default { "" } } };
            case "uniform"; case "vest"; case "backpack"; case "headgear"; case "facewear"; case "binocular": { _kind };
            default { "" };
        };
        if (_home != "") exitWith { [_loc, _id, _home, 1] call AP_fnc_invMoveVerb };
        private _row = [_cls, _ammo] call AP_fnc_invRowFor;
        private _to = [_row] call AP_fnc_invFirstRoom;
        if (_to isEqualTo "") exitWith { createHashMapFromArray [["ok", false], ["msg", "NO ROOM IN YOUR CONTAINERS."]] };
        [_loc, _id, _to, 1] call AP_fnc_invMoveVerb
    }] call (uiNamespace getVariable "AP_invRun")
}] call webui_fnc_on;

[_ctrl, "invUnequip", {
    params [["_slot", "", [""]]];
    _slot = [_slot] call AP_fnc_invNormSlot;
    [{ ["unequip", [_slot, ""]] call AP_fnc_invLocal }] call (uiNamespace getVariable "AP_invRun")
}] call webui_fnc_on;

// ---- gunsmith ----
[_ctrl, "invOpenWeapon", {
    params [["_slot", "", [""]]];
    private _r = ["open", [_slot]] call AP_fnc_invGunsmith;
    if (_r get "ok") then { [] call AP_fnc_invPushGs; };
    createHashMapFromArray [["ok", _r get "ok"], ["msg", _r get "msg"]]
}] call webui_fnc_on;
[_ctrl, "invCloseWeapon", {
    ["close", []] call AP_fnc_invGunsmith;
    [] call AP_fnc_invPushGs;
    createHashMapFromArray [["ok", true], ["msg", ""]]
}] call webui_fnc_on;
[_ctrl, "invMount", {
    params [["_id", "", [""]], ["_slot", "", [""]], ["_socket", "", [""]]];
    [{
        ([_id] call AP_fnc_invParseAny) params ["_loc", "_cls", "_ammo", ""];
        private _ownId = _id;
        private _took = [];
        if (_loc isEqualTo "container" || {(_loc select [0, 7]) isEqualTo "ground:"}) then {
            // stage the attachment / magazine on the body first; the server owns the shared cargo
            private _row = [_cls, _ammo] call AP_fnc_invRowFor;
            private _stage = [_row] call AP_fnc_invFirstRoom;
            if (_stage isEqualTo "") exitWith { createHashMapFromArray [["ok", false], ["msg", "NO ROOM TO PICK THAT UP FIRST."]] };
            private _r = [_loc, _cls, _ammo, _stage, 1] call AP_fnc_invTakeFromReach;
            if !(_r get "ok") exitWith { _r };
            _took = _r get "took";
            _ownId = format ["%1|%2|%3", _stage, _cls, _ammo];
        };
        private _m = ["mount", [_ownId, _slot, _socket]] call AP_fnc_invGunsmith;
        _m set ["took", (_m getOrDefault ["took", []]) + _took];
        _m
    }] call (uiNamespace getVariable "AP_invRun")
}] call webui_fnc_on;
[_ctrl, "invDetach", {
    params [["_slot", "", [""]], ["_socket", "", [""]]];
    [{ ["detach", [_slot, _socket]] call AP_fnc_invGunsmith }] call (uiNamespace getVariable "AP_invRun")
}] call webui_fnc_on;
[_ctrl, "invUnload", {
    params [["_slot", "", [""]]];
    [{ ["unload", [_slot]] call AP_fnc_invGunsmith }] call (uiNamespace getVariable "AP_invRun")
}] call webui_fnc_on;
[_ctrl, "invReload", {
    params [["_slot", "", [""]], ["_id", "", [""]]];
    [{ ["reload", [_slot, _id]] call AP_fnc_invGunsmith }] call (uiNamespace getVariable "AP_invRun")
}] call webui_fnc_on;

// ---- the bag: the phone's own functions, explicit-arg forms ----
private _later = { [] spawn { uiSleep 0.8; [] call AP_fnc_invPush; }; };
uiNamespace setVariable ["AP_invLater", _later];
[_ctrl, "bagUse", {
    params [["_id", "", [""]]];
    if (_id isEqualTo "") exitWith { createHashMapFromArray [["ok", false], ["msg", "NO ITEM."]] };
    [controlNull, _id] spawn AP_fnc_useItem;
    call (uiNamespace getVariable "AP_invLater");
    createHashMapFromArray [["ok", true], ["msg", ""]]
}] call webui_fnc_on;
[_ctrl, "bagDrop", {
    params [["_id", "", [""]], ["_qty", 1, [0]]];
    if (_id isEqualTo "") exitWith { createHashMapFromArray [["ok", false], ["msg", "NO ITEM."]] };
    [_id, _qty max 1] spawn AP_fnc_dropItem;
    call (uiNamespace getVariable "AP_invLater");
    createHashMapFromArray [["ok", true], ["msg", ""]]
}] call webui_fnc_on;
[_ctrl, "bagGive", {
    params [["_id", "", [""]], ["_qty", 1, [0]], ["_uid", "", [""]]];
    if (_id isEqualTo "" || {_uid isEqualTo ""}) exitWith { createHashMapFromArray [["ok", false], ["msg", "PICK SOMEONE FIRST."]] };
    [controlNull, _id, _qty max 1, _uid] spawn AP_fnc_giveItem;
    call (uiNamespace getVariable "AP_invLater");
    createHashMapFromArray [["ok", true], ["msg", ""]]
}] call webui_fnc_on;
[_ctrl, "groundTake", {
    // fn_lootBridge's pre-split take, against the case by netId, under its AP_inUse reservation
    params [["_case", "", [""]], ["_id", "", [""]], ["_qty", 1, [0]]];
    private _obj = objectFromNetId _case;
    if (isNull _obj) exitWith { createHashMapFromArray [["ok", false], ["msg", "THE CASE IS GONE."]] };
    if (player distance _obj > 6) exitWith { createHashMapFromArray [["ok", false], ["msg", "TOO FAR."]] };
    private _u = _obj getVariable ["AP_inUse", objNull];
    if (!isNull _u && {_u != player}) exitWith { createHashMapFromArray [["ok", false], ["msg", "SOMEONE ELSE IS IN THAT CASE."]] };
    _obj setVariable ["AP_inUse", player, true];
    AP_pickMenuItems = +(_obj getVariable ["AP_droppedItems", []]);
    private _i = AP_pickMenuItems findIf { (_x select 0) isEqualTo _id };
    private _out = createHashMapFromArray [["ok", false], ["msg", "ALREADY GONE."]];
    if (_i > -1) then {
        private _have = (AP_pickMenuItems select _i) select 1;
        _qty = (_qty min _have) max 1;
        private _rem = _have - _qty;
        (AP_pickMenuItems select _i) set [1, _qty];
        AP_pickingUpItems = true;
        [_obj, _id, _qty] call AP_fnc_pickupItem;
        AP_pickingUpItems = false;
        if (_rem > 0) then {
            private _j = AP_pickMenuItems findIf { (_x select 0) isEqualTo _id };
            if (_j > -1) then { (AP_pickMenuItems select _j) set [1, ((AP_pickMenuItems select _j) select 1) + _rem]; }
            else { AP_pickMenuItems pushBack [_id, _rem]; };
        };
        if (!isNull _obj) then { _obj setVariable ["AP_droppedItems", AP_pickMenuItems, true]; };
        [] call AP_fnc_calWeight;
        _out = createHashMapFromArray [["ok", true], ["msg", ""]];
    };
    _obj setVariable ["AP_inUse", nil, true];
    [] call AP_fnc_invPush;
    _out
}] call webui_fnc_on;

// ------------------------------------------------------------ dialog EHs ----
_display displayAddEventHandler ["KeyDown", {
    params ["", "_k"];
    if (_k isEqualTo 1) then {
        // Esc closes the gunsmith first, then the screen -- the handoff's order
        if ((uiNamespace getVariable ["AP_invGsOpen", ""]) != "") then {
            ["close", []] call AP_fnc_invGunsmith;
            private _c = uiNamespace getVariable ["AP_invCtrl", controlNull];
            if (!isNull _c) then { [_c, "if (typeof closeGunsmith === 'function') closeGunsmith();"] call webui_fnc_exec; };
            [] call AP_fnc_invPushGs;
        } else {
            closeDialog 0;
        };
    };
    false
}];
_display displayAddEventHandler ["Unload", {
    ["stop"] call AP_fnc_invFigure;   // the r2t camera dies with the screen, every close path
    private _c = uiNamespace getVariable ["AP_invContainer", objNull];
    if (!isNull _c && {(_c getVariable ["AP_veh_in_use", objNull]) isEqualTo player}) then { _c setVariable ["AP_veh_in_use", nil, true]; };
    uiNamespace setVariable ["AP_invContainer", objNull];
    uiNamespace setVariable ["AP_invCtrl", controlNull];
    uiNamespace setVariable ["AP_invGsOpen", ""];
    AP_action_in_use = false;
    AP_invBusy = false;
}];

// ------------------------------------------------------------- watcher -----
// Hazard 7: the page never polls; this loop re-pushes when the engine moved something behind it, and
// closes the screen for the reasons the old 602 waiter did.
[] spawn {
    while { !isNull (findDisplay 938500) } do {
        uiSleep 1;
        if (isNull (findDisplay 938500)) exitWith {};
        private _cont = uiNamespace getVariable ["AP_invContainer", objNull];
        if (serverRestartLock || {!isNull _cont && {_cont getVariable ["AP_trunkLock", false]}}) exitWith {
            closeDialog 0;
            ["The server is saving this vehicle. Please wait until after restart to open the inventory.", "basic"] spawn AP_fnc_handleMessage;
        };
        if (AP_invBusy) then { continue };
        if (([] call AP_fnc_invSig) != (uiNamespace getVariable ["AP_invSig", ""])) then { [] call AP_fnc_invPush; };
    };
};

[] call AP_fnc_invPush;
diag_log "[INV] screen ready";
