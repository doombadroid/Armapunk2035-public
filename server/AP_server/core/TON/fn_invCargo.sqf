/*
    APS_fnc_invCargo -- the ONE mutator for vehicle / crate cargo and ground weapon holders used by
    the I-screen. INVENTORY_SPEC.md Appendix A hazard 2, §9.4 "Shared containers".

        [_ticket, _verb, _targetNetId, _spec] remoteExec'd by a client (CfgRE allowedTargets = 2)
        answers [[_ticket, ok, msg, extra], "AP_fnc_invCargoRecv", <that client>]

    verbs / spec
      "take"    [cls, kind, ammo, toLoc, qty]   target cargo -> the player's uniform/vest/backpack, or
                                                a weapon slot (primary/handgun/launcher, must be empty)
      "pickup"  [cls, kind, ammo, toLoc, qty]   same, target = a WeaponHolder within 5 m
      "store"   [cls, kind, ammo, fromLoc, qty] the player's container or worn slot -> target cargo
      "drop"    [cls, kind, ammo, fromLoc, qty] the player's container or worn slot -> the nearest holder
                                                within 2 m, else a fresh GroundWeaponHolder (450 s clean)

    WHY ONE FUNCTION. The engine has no "remove one magazine from a vehicle": taking a single item
    out of cargo means reading the cargo, clearing it and re-adding the rest. Two clients doing that
    against the same vehicle at once (or a client racing the engine's own cargo edit) lose or
    duplicate items. Every read-clear-readd of shared cargo therefore happens HERE, inside one
    isNil { } block -- unscheduled, so no other script can run between the read and the write.

    ACTOR = remoteExecutedOwner, never the payload (the -SEC- attribution rule). The single-user lock
    the client set when it opened the screen (AP_veh_in_use == the player) is required for vehicles
    and crates: it is both the serialisation the native dialog relied on and proof the client passed
    fn_inventoryOpened's access chain. This is a race guard, not a trust boundary -- every inventory
    command is global-effect from any client, which is the codebase's existing boundary.

    Backpacks in cargo keep their contents across the rebuild (everyBackpack before/after).
    Weapon slots use addWeaponGlobal / removeWeaponGlobal (global-argument); the attachments and
    the magazine are local-argument commands, so on a take they ride back to the owning client in
    `extra` and fn_invBridge mounts them there.
*/
params [["_ticket", 0, [0]], ["_verb", "", [""]], ["_targetId", "", [""]], ["_spec", [], [[]]]];
private _src = remoteExecutedOwner;
if (_src isEqualTo 0 || {_src isEqualTo 2}) exitWith {};
private _pl = (allPlayers select { owner _x isEqualTo _src }) param [0, objNull];
private _fnReply = {
    params ["_ok", "_msg", ["_extra", []]];
    [[_ticket, _ok, _msg, _extra], "AP_fnc_invCargoRecv", _src, false] spawn AP_fnc_MP;
    if (!_ok) then { diag_log format ["[INV][SRV] %1 refused for %2: %3", _verb, name _pl, _msg]; };
};
if (isNull _pl || {!alive _pl}) exitWith { [false, "NO PLAYER."] call _fnReply };
_spec params [["_cls", "", [""]], ["_kind", "", [""]], ["_ammo", -1, [0]], ["_loc", "", [""]], ["_qty", 1, [0]]];
if (_cls isEqualTo "" || {_kind isEqualTo ""}) exitWith { [false, "BAD REQUEST."] call _fnReply };
_qty = (_qty max 1) min 50;
private _own = ["uniform", "vest", "backpack"];
private _wslots = ["primary", "handgun", "launcher"];

// ---- the target and the reach / lock rules --------------------------------------------------
private _target = if (_targetId isEqualTo "") then { objNull } else { objectFromNetId _targetId };
if (_verb isEqualTo "drop") then {
    private _near = (nearestObjects [_pl, ["WeaponHolder", "WeaponHolderSimulated"], 2]) select { alive _x };
    _target = _near param [0, objNull];
    if (isNull _target) then {
        _target = createVehicle ["GroundWeaponHolder", getPosATL _pl, [], 0, "CAN_COLLIDE"];
        [_target, 450] spawn APS_fnc_setCleanTime;
    };
};
if (isNull _target || {!alive _target}) exitWith { [false, "THAT IS GONE."] call _fnReply };
private _isHolder = (_target isKindOf "WeaponHolder") || {_target isKindOf "WeaponHolderSimulated"};
// _refused carries the verdict out: an exitWith inside if/else only leaves that block, so these
// refusals used to reply "no" and then move the cargo anyway.
private _refused = "";
if (_isHolder) then {
    if (_pl distance _target > 6) exitWith { _refused = "TOO FAR FROM THE PILE." };
} else {
    if (vehicle _pl != _target && {_pl distance _target > (10 + 0.5 * sizeOf typeOf _target)}) exitWith { _refused = "OUT OF REACH." };
    private _u = _target getVariable ["AP_veh_in_use", objNull];
    if (_u != _pl) exitWith { _refused = "YOU ARE NOT IN THAT INVENTORY." };
    if (_target getVariable ["AP_trunkLock", false]) exitWith { _refused = "THE SERVER IS SAVING THIS VEHICLE." };
    if (_target getVariable ["AP_seizing", false]) exitWith { _refused = "THIS VEHICLE IS BEING SEIZED." };
};
if (_refused isNotEqualTo "") exitWith { [false, _refused] call _fnReply };

// ---- generic one-unit cargo primitives (any container object) -------------------------------
private _fnCont = {
    params ["_loc"];
    switch (_loc) do {
        case "uniform":  { uniformContainer _pl };
        case "vest":     { vestContainer _pl };
        case "backpack": { backpackContainer _pl };
        default          { objNull };
    }
};
private _fnFind = {
    // the row matching [cls, kind, ammo] in an object's cargo, or objNull
    params ["_obj"];
    private _rows = [_obj, "srv"] call AP_fnc_invCargoRead;
    private _i = _rows findIf {
        (_x get "cls") isEqualTo _cls && {(_x get "kind") isEqualTo _kind} && {_kind != "mag" || {(_x get "ammo") isEqualTo _ammo}}
    };
    if (_i < 0) then { objNull } else { _rows select _i }
};
private _fnCanAdd = {
    params ["_obj", "_row"];
    if ((_row get "kind") isEqualTo "backpack" && {!(_obj isKindOf "Bag_Base")} && {!(_obj isKindOf "LandVehicle")} && {!(_obj isKindOf "Air")} && {!(_obj isKindOf "Ship")} && {!(_obj isKindOf "ReammoBox_F")} && {!_isHolder}) exitWith { false };
    if ((_row get "kind") isEqualTo "mag") then { _obj canAdd [_row get "cls", 1] } else { _obj canAdd (_row get "cls") }
};
private _fnRemove = {
    params ["_obj", "_row"];
    private _c = _row get "cls";
    switch (_row get "kind") do {
        case "mag": {
            private _all = magazinesAmmoCargo _obj;
            private _i = _all findIf { (_x select 0) isEqualTo _c && {(_x select 1) isEqualTo (_row get "ammo")} };
            if (_i < 0) exitWith { false };
            _all deleteAt _i;
            clearMagazineCargoGlobal _obj;
            { _obj addMagazineAmmoCargo [_x select 0, 1, _x select 1]; } forEach _all;
            true
        };
        case "weapon": {
            private _wi = (uiNamespace getVariable ["AP_invWI", createHashMap]) getOrDefault [_row get "id", []];
            private _all = weaponsItemsCargo _obj;
            private _i = if (_wi isEqualTo []) then { -1 } else { _all findIf { _x isEqualTo _wi } };
            if (_i < 0) then { _i = _all findIf { (_x select 0) isEqualTo _c }; };
            if (_i < 0) exitWith { false };
            _all deleteAt _i;
            clearWeaponCargoGlobal _obj;
            { _obj addWeaponWithAttachmentsCargoGlobal [_x, 1]; } forEach _all;
            true
        };
        case "backpack": {
            (getBackpackCargo _obj) params [["_bcls", []], ["_bqty", []]];
            private _i = _bcls find _c;
            if (_i < 0) exitWith { false };
            // remember every pack's contents, in order; the one leaving is the first of its class
            private _packs = everyBackpack _obj;
            private _keep = [];
            private _skipped = false;
            {
                private _p = _x;
                if (!_skipped && {(typeOf _p) isEqualTo _c}) then { _skipped = true; } else {
                    _keep pushBack [typeOf _p, weaponsItemsCargo _p, magazinesAmmoCargo _p, getItemCargo _p];
                };
            } forEach _packs;
            clearBackpackCargoGlobal _obj;
            { _obj addBackpackCargoGlobal [_x select 0, 1]; } forEach _keep;
            private _new = everyBackpack _obj;
            {
                _x params ["", "_w", "_m", "_it"];
                private _p = _new param [_forEachIndex, objNull];
                if (!isNull _p) then {
                    { _p addWeaponWithAttachmentsCargoGlobal [_x, 1]; } forEach _w;
                    { _p addMagazineAmmoCargo [_x select 0, 1, _x select 1]; } forEach _m;
                    _it params [["_ic", []], ["_iq", []]];
                    { _p addItemCargoGlobal [_x, _iq select _forEachIndex]; } forEach _ic;
                };
            } forEach _keep;
            true
        };
        default {
            (getItemCargo _obj) params [["_icls", []], ["_iqty", []]];
            private _i = _icls find _c;
            if (_i < 0) exitWith { false };
            _iqty set [_i, (_iqty select _i) - 1];
            clearItemCargoGlobal _obj;
            { if ((_iqty select _forEachIndex) > 0) then { _obj addItemCargoGlobal [_x, _iqty select _forEachIndex]; }; } forEach _icls;
            true
        };
    }
};
private _fnAdd = {
    params ["_obj", "_row"];
    switch (_row get "kind") do {
        case "mag":      { _obj addMagazineAmmoCargo [_row get "cls", 1, _row get "ammo"]; };
        case "weapon":   { _obj addWeaponWithAttachmentsCargoGlobal [(uiNamespace getVariable ["AP_invWI", createHashMap]) getOrDefault [_row get "id", [_row get "cls", "", "", "", [], [], ""]], 1]; };
        case "backpack": { _obj addBackpackCargoGlobal [_row get "cls", 1]; };
        default          { _obj addItemCargoGlobal [_row get "cls", 1]; };
    };
    true
};
// a synthetic row for a class that is worn (not in any cargo)
private _fnRowFor = {
    params ["_c", ["_a", -1], ["_wi", []]];
    private _i = [_c] call AP_fnc_invItemInfo;
    private _id = format ["srvhand|%1|%2|%3", _c, _a, round (random 1e6)];
    if (_wi isNotEqualTo []) then {
        private _m = uiNamespace getVariable "AP_invWI";
        if (isNil "_m") then { _m = createHashMap; uiNamespace setVariable ["AP_invWI", _m]; };
        _m set [_id, _wi];
    };
    createHashMapFromArray [["id", _id], ["cls", _c], ["kind", _i get "kind"], ["ammo", _a], ["name", _i get "name"]]
};

// ---- the verbs, each atomic -------------------------------------------------------------------
private _res = [false, "NOTHING HAPPENED."];
private _extra = [];
switch (_verb) do {

    case "take"; case "pickup": {
        if (!(_loc in _own) && {!(_loc in _wslots)}) exitWith { _res = [false, "BAD DESTINATION."] };
        isNil {
            private _moved = 0; private _last = "";
            for "_k" from 1 to _qty do {
                private _row = [_target] call _fnFind;
                if (_row isEqualType objNull) then { _last = "THAT ITEM IS GONE."; break };
                if (_loc in _wslots) then {
                    if ((_row get "kind") != "weapon") then { _last = "THAT IS NOT A WEAPON."; break };
                    private _cur = switch (_loc) do { case "primary": { primaryWeapon _pl }; case "handgun": { handgunWeapon _pl }; default { secondaryWeapon _pl } };
                    if (_cur != "") then { _last = "THAT SLOT IS TAKEN."; break };
                    private _wi = (uiNamespace getVariable ["AP_invWI", createHashMap]) getOrDefault [_row get "id", [_cls, "", "", "", [], [], ""]];
                    if !([_target, _row] call _fnRemove) then { _last = "THAT ITEM IS GONE."; break };
                    _pl addWeaponGlobal _cls;
                    _extra = _wi;
                    _moved = _moved + 1;
                    break
                };
                private _dst = [_loc] call _fnCont;
                if (isNull _dst || {!([_dst, _row] call _fnCanAdd)}) then { _last = format ["NO ROOM IN YOUR %1.", toUpper _loc]; break };
                if !([_target, _row] call _fnRemove) then { _last = "THAT ITEM IS GONE."; break };
                [_dst, _row] call _fnAdd;
                _moved = _moved + 1;
            };
            _res = if (_moved > 0) then { [true, format ["%1 × %2 TAKEN.", _moved, toUpper (([_cls] call AP_fnc_invItemInfo) get "name")]] } else { [false, _last] };
        };
    };

    case "store"; case "drop": {
        private _fromSlot = !(_loc in _own);
        isNil {
            private _moved = 0; private _last = "";
            if (_fromSlot) then {
                // a worn item: verify the player wears it, take room in the target, then clear the slot
                private _worn = switch (_loc) do {
                    case "primary": { primaryWeapon _pl }; case "handgun": { handgunWeapon _pl }; case "launcher": { secondaryWeapon _pl };
                    case "uniform": { uniform _pl }; case "vest": { vest _pl }; case "backpack": { backpack _pl };
                    case "headgear": { headgear _pl }; case "facewear": { goggles _pl }; case "binocular": { binocular _pl };
                    default { "" };
                };
                if (_worn != _cls) then { _last = "YOU ARE NOT WEARING THAT."; } else {
                    if (_loc in ["uniform", "vest", "backpack"] && {(loadAbs ([_loc] call _fnCont)) > 0}) then { _last = "EMPTY IT FIRST."; } else {
                        private _wi = ((weaponsItems _pl) select { (_x select 0) isEqualTo _cls }) param [0, []];
                        private _row = [_cls, -1, _wi] call _fnRowFor;
                        if !([_target, _row] call _fnCanAdd) then { _last = "NO ROOM IN THERE."; } else {
                            switch (_loc) do {
                                case "primary"; case "handgun"; case "launcher"; case "binocular": { _pl removeWeaponGlobal _cls };
                                case "uniform":  { removeUniform _pl };
                                case "vest":     { removeVest _pl };
                                case "backpack": { removeBackpackGlobal _pl };
                                case "headgear": { removeHeadgear _pl };
                                case "facewear": { removeGoggles _pl };
                            };
                            [_target, _row] call _fnAdd;
                            _moved = 1;
                        };
                    };
                };
            } else {
                private _srcC = [_loc] call _fnCont;
                for "_k" from 1 to _qty do {
                    private _row = [_srcC] call _fnFind;
                    if (_row isEqualType objNull) then { _last = "THAT ITEM IS GONE."; break };
                    if !([_target, _row] call _fnCanAdd) then { _last = "NO ROOM IN THERE."; break };
                    if !([_srcC, _row] call _fnRemove) then { _last = "THAT ITEM IS GONE."; break };
                    [_target, _row] call _fnAdd;
                    _moved = _moved + 1;
                };
            };
            _res = if (_moved > 0) then { [true, format ["%1 × %2 %3.", _moved, toUpper (([_cls] call AP_fnc_invItemInfo) get "name"), if (_verb isEqualTo "drop") then { "DROPPED" } else { "STORED" }]] } else { [false, _last] };
        };
        if (_verb isEqualTo "drop" && {(_res select 0)}) then { _extra = netId _target; };
    };

    default { _res = [false, "UNKNOWN VERB."]; };
};

if (_res select 0) then {
    diag_log format ["[INV][SRV] %1 %2 x%3 %4 %5 by %6", _verb, _cls, _qty, _loc, typeOf _target, name _pl];
};
[_res select 0, _res select 1, _extra] call _fnReply;
