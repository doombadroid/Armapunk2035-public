/*
    APS_fnc_houseFurnitureSRV  (LooneyBin -- built 2026-06-10, presence-spawn added 2026-06-12)
    House furniture persistence. Furniture = placeable items (AP_furnitureItems) placed via the standard
    hold/place pipeline, gated client-side to 20m of an OWNED house, sim+damage OFF.

    DB: houses.furniture = mresArray of [class, posATL(XYZ), dir, placerUID] per house.

    KEYING (owner 2026-07-10 -- THE "furniture never persists" root cause): every houseID passed in from the
    clients is AP_houseID = the houses.oid VARCHAR position-hash, NOT the auto-increment int id. This file
    originally queried `WHERE id='<oid>'`, which matched NOTHING -> the add-SELECT returned 0 rows -> exitWith
    -> NO furniture row was EVER written (and presenceStart/show found nothing to load). Furniture only lived
    as session objects and vanished on every restart. All queries now key on `oid` (the fn_transferHouse
    lesson), the cache is keyed on oid, and oid/owners are QUOTE()'d on read (bare varchars get call-compiled
    into mangled numbers -- the fn_getVehicles/classname footgun).

    PRESENCE SPAWN (owner request): furniture is only SPAWNED while the home is "occupied" -- the homeowner is
    online, OR (gang house) any member of the owning gang is online. When nobody's home it despawns (DB row
    kept) and respawns when they return. Server-side cache (localNamespace APS_furnCache) avoids re-querying the DB each tick.
      cache key = houseID(str) -> [ ownerUID(str), buildingObj, entries[[class,pos,dir,uid],...], spawnedObjs ]

    Modes:
      ["add", houseID, class, posATL, dir, obj, placer, itemKey]   client placed a piece (cap 20)
      ["remove", posATL]                                           client picked a piece up
      ["presenceStart"]                                            boot: build cache + run the presence loop
*/
// owner 2026-07-12: LIGHT-EMITTING FURNITURE. Map class -> [[r,g,b], brightness, zOffset]; spawned
// pieces in this map get a #lightpoint attached (server-side object = glows for everyone). Campfires
// keep simulation ON and are inflamed instead (fire needs sim; one object, negligible cost).
if !(isFinal "AP_fnc_furnLight") then {localNamespace setVariable ["APS_furnLights", createHashMapFromArray [   // localNamespace: a client publicVariable can't reach it
        ["Land_Camping_Light_F",                  [[1.00, 0.75, 0.45], 0.45, 0.10]],
        ["Land_LampShabby_F",                     [[1.00, 0.80, 0.55], 0.70, 3.20]],
        ["Land_LampDecor_F",                      [[1.00, 0.85, 0.60], 0.60, 2.60]],
        ["Land_LampHarbour_F",                    [[1.00, 0.90, 0.70], 0.70, 3.00]],
        ["Land_LampSolar_F",                      [[0.85, 0.95, 1.00], 0.55, 2.80]],
        ["Land_LampStreet_small_F",               [[1.00, 0.85, 0.60], 0.70, 3.40]],
        ["Land_PortableLight_single_F",           [[0.95, 0.95, 1.00], 0.80, 1.30]],
        ["Land_PortableLight_double_F",           [[0.95, 0.95, 1.00], 1.00, 1.30]],
        ["Land_FloodLight_F",                     [[0.95, 0.95, 1.00], 1.20, 3.60]],
        ["Land_Flush_Light_green_F",              [[0.20, 1.00, 0.30], 0.45, 0.10]],
        ["Land_Flush_Light_red_F",                [[1.00, 0.15, 0.15], 0.45, 0.10]],
        ["Land_Flush_Light_yellow_F",             [[1.00, 0.85, 0.20], 0.45, 0.10]],
        ["Land_PortableHelipadLight_01_F",        [[1.00, 1.00, 1.00], 0.45, 0.15]]]];
AP_fnc_furnLight = compileFinal {params ["_o", "_class"];
    if (_class isEqualTo "Land_Campfire_F") exitWith {_o enableSimulationGlobal true;   // fire needs sim
        _o inflame true;};
    private _cfg = (localNamespace getVariable ["APS_furnLights", createHashMap]) getOrDefault [_class, []];
    if (_cfg isEqualTo []) exitWith {};
    _cfg params ["_rgb", "_bright", "_zOff"];
    private _l = createVehicle ["#lightpoint", getPosATL _o, [], 0, "CAN_COLLIDE"];
    _l setLightColor _rgb;
    _l setLightAmbient (_rgb vectorMultiply 0.12);
    _l setLightBrightness _bright;
    _l setLightUseFlare false;
    _l lightAttachObject [_o, [0, 0, _zOff]];
    _o setVariable ["AP_furnLight", _l];   // deleted alongside the piece by AP_fnc_furnKill
};
// delete a piece + its light. Any client's public setVariable overwrites AP_furnLight on the server too, so only a
// #lightpoint is ever deleted through it (it was a server-side deleteVehicle of any object: audit r2furn).
AP_fnc_furnKill = compileFinal {private _l = _this getVariable ["AP_furnLight", objNull];
    if (typeOf _l isEqualTo "#lightpoint") then { deleteVehicle _l; };
    deleteVehicle _this;};};

// Furniture class whitelist for house AND suite "add" (APS_fnc_suiteFurnitureSRV reads it too). Server copy of the
// client-only AP_furnitureClasses (core/configuration.sqf) minus the fabricator stand-ins, which route to APS_fnc_fabSRV.
// localNamespace (audit r2furn): the suite path read the client global, which is nil on the server and set by any client's
// publicVariableServer. Kept in step by tools/test_furniture_whitelist.py.
if (isNil {localNamespace getVariable "APS_furnClasses"}) then { localNamespace setVariable ["APS_furnClasses", [
    "Land_ChairWood_F", "Land_ChairPlastic_F", "Land_CampingChair_V1_F", "Land_CampingChair_V2_F",
    "Land_Sun_chair_F", "Land_CampingTable_F", "Land_WoodenTable_small_F", "Land_WoodenTable_large_F", "Land_Sleeping_bag_F",
    "Land_WoodenBed_01_F", "Item_Laptop_Unfolded", "Land_TableSmall_01_F", "Land_TableBig_01_F", "Land_RattanTable_01_F",
    "OfficeTable_01_new_F", "Land_OfficeChair_01_F", "Land_ArmChair_01_F", "Land_FlatTV_01_F", "Land_WaterCooler_01_new_F",
    "GalleryFrame_01_large_v1_F", "GalleryFrame_01_Large_Portrait_F", "Land_GamingSet_01_camera_F", "Land_GamingSet_01_console_F",
    "Land_GamingSet_01_controller_F", "Land_GamingSet_01_powerSupply_F", "SatelliteAntenna_01_Mounted_Black_F",
    "SatelliteAntenna_01_Mounted_Olive_F", "SatelliteAntenna_01_Mounted_Sand_F", "SatelliteAntenna_01_Small_Mounted_Black_F",
    "SatelliteAntenna_01_Small_Mounted_Olive_F", "SatelliteAntenna_01_Small_Mounted_Sand_F", "Land_PCSet_01_case_F",
    "Land_PCSet_01_keyboard_F", "Land_PCSet_01_mouse_F", "Land_PCSet_01_mousepad_F", "Land_PCSet_01_screen_F", "Land_PCSet_Intel_01_F",
    "Land_PCSet_Intel_02_F", "Land_Fridge_01_F", "Land_PierLadder_F", "Land_DeerStand_01_F", "Land_DeerStand_02_F",
    "Land_LifeguardTower_01_F", "Land_LampShabby_F", "Land_LampDecor_F", "Land_LampHarbour_F", "Land_LampSolar_F",
    "Land_LampStreet_small_F", "Land_PortableLight_single_F", "Land_PortableLight_double_F", "Land_FloodLight_F",
    "Land_Camping_Light_F", "Land_Campfire_F", "Land_Flush_Light_green_F", "Land_Flush_Light_red_F", "Land_Flush_Light_yellow_F",
    "Land_PortableHelipadLight_01_F", "Land_Sofa_01_F", "Land_OfficeCabinet_01_F", "Land_OfficeCabinet_02_F", "Land_Rug_01_F",
    "Land_FlowerPot_01_F", "Land_Sink_F", "Land_GasCooker_F", "Land_Microwave_01_F", "Land_Sunshade_F", "scarecrow_01_F",
    "Land_Camera_01_F", "Land_WoodenCrate_01_F", "Land_PortableServer_01_olive_F"]]; };

params [["_mode", "", [""]]];

private _decode = {params ["_raw"];
    if (isNil "_raw" || {_raw isEqualTo ""} || {_raw isEqualTo "[]"}) exitWith { [] };
    private _s = [_raw] call DB_fnc_mresToArray;
    if (_s isEqualType "") then { _s = parseSimpleArray (format ["%1", _s]); };
    if (isNil "_s" || {!(_s isEqualType [])}) exitWith { [] };
    _s};

// spawn one cached piece (sim/damage off, pickup vars restored) -> returns the object (objNull on bad class)
private _spawnPiece = {params ["_e"];
    _e params [["_class", "", [""]], ["_pos", [0,0,0], [[]]], ["_dir", 0, [0]], ["_uid", "", [""]]];
    if (_class isEqualTo "") exitWith { objNull };

    // owner 2026-07-10: CAN_COLLIDE = spawn at the EXACT stored position. The simple `_class createVehicle _pos`
    // syntax uses engine "safe" placement, which shoved big pieces (ladders/towers against a shed wall) to a
    // collision-free spot -> furniture "didn't go back exactly the way it was" after show/hide.
    private _o = createVehicle [_class, [0, 0, -100], [], 0, "CAN_COLLIDE"];
    _o setDir _dir;
    _o setPosATL _pos;
    _o enableSimulationGlobal false;
    _o allowDamage false;
    _o setVariable ["AP_placedItem", true, true];
    _o setVariable ["AP_ownerID", _uid, true];
    _o setVariable ["AP_furniture", true, true];   // exempt from the server cleanup sweep (fn_cleanup)
    [_o, _class] call AP_fnc_furnLight;
    _o};

// resolve the house building for a houseID near a position (match AP_houseID)
// owner 2026-07-10: ["House"] not ["House_F"] -- the buyable industrial shed (Land_i_Shed_Ind_F) is not
// reliably isKindOf House_F (the receiveHouses/gang-tagger #208 lesson), so shed furniture never resolved
// its building. "House" covers sheds + every normal home.
private _findBldg = {params ["_hid", "_pos"];
    private _b = objNull;
    // never a hidden object: a maldened house's hidden original keeps the shell's AP_houseID 0.2 m away (APS_fnc_houseRights refuses it)
    { if ((format ["%1", _x getVariable ["AP_houseID", -1]]) isEqualTo (format ["%1", _hid]) && {!isObjectHidden _x}) exitWith { _b = _x; }; } forEach (nearestObjects [_pos, ["House"], 45]);
    _b};

// localNamespace (audit r2furn): as the missionNamespace global AP_furnCache one client publicVariable replaced it on the
// server, and "show" then createVehicle'd any class anywhere; show/hide/the presence despawn deleteVehicle'd any object.
if (isNil {localNamespace getVariable "APS_furnCache"}) then { localNamespace setVariable ["APS_furnCache", createHashMap]; };
private _cache = localNamespace getVariable "APS_furnCache";   // live reference: set/deleteAt write through

switch (toLower _mode) do {case "add": {
        params ["", ["_houseID", "", ["", 0]], ["_class", "", [""]], ["_pos", [0,0,0], [[]]], ["_dir", 0, [0]], ["_obj", objNull, [objNull]], ["_placer", objNull, [objNull]], ["_itemKey", "", [""]]];
        if (((str _houseID) in ["-1", ""]) || {_class isEqualTo ""}) exitWith {};
        // owner 2026-09-26 SECURITY (audit TONb-0-15 / AUDIT A12): no caller or ownership check -- any client could
        // persist 20 pieces of ANY class (the server spawns + respawns them) at ANY position into ANY house, inject SQL
        // through _houseID, and have the server deleteVehicle any object passed as _obj. Now: the caller must own the
        // house on its DB row (APS_fnc_houseRights; the row it read is the row written), the class must be real
        // furniture, the piece must sit at the house, and _obj (a legacy ref -- current clients send objNull) is ignored.
        private _src = remoteExecutedOwner;   // 0 == server-internal = trusted
        private _caller = (allPlayers select { owner _x isEqualTo _src }) param [0, objNull];
        private _bldg = [_houseID, _pos] call _findBldg;
        private _rights = [_bldg] call APS_fnc_houseRights;
        if (_src isNotEqualTo 0) then {_obj = objNull;
            if (!isNull _placer) then { _placer = _caller; };   // refund/messages go to the real sender (first comp member only)
        };
        if (_src isNotEqualTo 0 && {isNull _caller || {(_rights select 1) isEqualTo ""} || {(_rights select 1) isNotEqualTo (getPlayerUID _caller)}
            || {!(_class in (localNamespace getVariable ["APS_furnClasses", []]))} || {count _pos != 3} || {(_pos findIf { !(_x isEqualType 0) }) != -1} || {(_bldg distance2D _pos) > 25}}) exitWith {
            ["-SEC-", _caller, format ["BLOCKED furniture add %1 at %2 house %3 (owner %4) by %5", _class, _pos, _houseID, _rights select 1, getPlayerUID _caller]] call APS_fnc_logIt;
            if (!isNull _placer) then {[[true, _itemKey, 1], "AP_fnc_handleInv", _placer, false, false] spawn AP_fnc_MP;
                [["You can only place furniture at a house you own.", "basic"], "AP_fnc_handleMessage", _placer, false, false] spawn AP_fnc_MP;
            };};
        if (_src isNotEqualTo 0) then { _houseID = _rights select 0; };
        private _rows = ["SELECT furniture FROM houses WHERE oid = %s", 2, true, [format ["%1", _houseID]]] call DB_fnc_asyncQuery;
        if !(_rows isEqualType [] && {count _rows > 0}) exitWith {
            diag_log format ["[LooneyBin][furniture] add: no houses row for oid=%1 -- piece NOT persisted", _houseID];
            // owner 2026-07-10: the client deleted its preview + consumed the item on send (server-spawn
            // handoff) -- on ANY reject the item must be refunded or it just vanishes.
            if (!isNull _placer) then {[[true, _itemKey, 1], "AP_fnc_handleInv", _placer, false, false] spawn AP_fnc_MP;
                [["That building isn't registered for furniture storage.", "basic"], "AP_fnc_handleMessage", _placer, false, false] spawn AP_fnc_MP;
            };};
        private _furn = [(_rows select 0) param [0, ""]] call _decode;
        if (count _furn >= 20) exitWith {
            if (!isNull _obj) then { _obj call AP_fnc_furnKill; };
            if (!isNull _placer) then {[[true, _itemKey, 1], "AP_fnc_handleInv", _placer, false, false] spawn AP_fnc_MP;
                [["This house already has the maximum of 20 furniture pieces.", "basic"], "AP_fnc_handleMessage", _placer, false, false] spawn AP_fnc_MP;
            };};
        private _entry = [_class, _pos, _dir, if (isNull _placer) then {""} else {getPlayerUID _placer}];
        _furn pushBack _entry;
        ["UPDATE houses SET furniture = %s WHERE oid = %s", 1, false, [[_furn] call DB_fnc_mresArray, format ["%1", _houseID]]] call DB_fnc_asyncQuery;
        // owner 2026-07-10 (SERVER-SPAWN HANDOFF): the SERVER spawns the live piece and tracks it from birth.
        // The client's preview is already deleted client-side; a legacy/late _obj ref (old clients mid-restart)
        // gets deleted here so it can't linger untracked -- untracked client copies were the show/hide dupe.
        if (!isNull _obj) then { _obj call AP_fnc_furnKill; };
        private _new = [_entry] call _spawnPiece;
        private _hk = format ["%1", _houseID];
        if (_hk in _cache) then {private _c = _cache get _hk;
            (_c select 2) pushBack _entry;
            if (!isNull _new) then { (_c select 3) pushBack _new; };} else {
            _cache set [_hk, [_rights select 1, _bldg, [_entry], (if (isNull _new) then {[]} else {[_new]})]];};   // owner from the DB row
        diag_log format ["[LooneyBin][furniture] +%1 @ house %2 (%3 pieces)", _class, _houseID, count _furn];};
    case "remove": {params ["", ["_pos", [0,0,0], [[]]]];
        // owner 2026-09-26 SECURITY (audit TONb-0-15, same file): any client could delete ANY house's persisted piece by
        // position. A remote caller may now only remove a piece it placed (entry uid) or one in a house it owns (row).
        private _src = remoteExecutedOwner;   // 0 == server-internal = trusted
        private _cuid = getPlayerUID ((allPlayers select { owner _x isEqualTo _src }) param [0, objNull]);
        private _rows = ["SELECT oid, furniture, owners FROM houses WHERE furniture IS NOT NULL AND furniture != ''", 2, true] call DB_fnc_asyncQuery;
        if !(_rows isEqualType []) exitWith {}; {private _hid = format ["%1", _x param [0, ""]];
            private _rowOwner = format ["%1", _x param [2, ""]];
            private _furn = [_x param [1, ""]] call _decode;
            private _i = _furn findIf { (((_x param [1, [0,0,0]]) distance _pos) < 1.5)
                && {(_src isEqualTo 0) || {(_cuid isNotEqualTo "") && {_cuid in [_rowOwner, format ["%1", _x param [3, ""]]]}}} };
            if (_i isNotEqualTo -1) exitWith {_furn deleteAt _i;
                ["UPDATE houses SET furniture = %s WHERE oid = %s", 1, false, [[_furn] call DB_fnc_mresArray, _hid]] call DB_fnc_asyncQuery;
                // cache: drop the matching entry + its spawned object (the client already deleteVehicle'd it)
                private _hk = format ["%1", _hid];
                if (_hk in _cache) then {private _c = _cache get _hk;
                    private _ei = (_c select 2) findIf { ((_x param [1, [0,0,0]]) distance _pos) < 1.5 };
                    if (_ei != -1) then { (_c select 2) deleteAt _ei; };
                    private _si = (_c select 3) findIf { !isNull _x && {(getPosATL _x) distance _pos < 1.5} };
                    if (_si != -1) then { private _fo = (_c select 3) select _si; _fo call AP_fnc_furnKill; (_c select 3) deleteAt _si; };
                };
                diag_log format ["[LooneyBin][furniture] -1 piece @ house %1 (%2 left)", _hid, count _furn];};} forEach _rows;};
    case "presencestart": {
        if (remoteExecutedOwner isNotEqualTo 0) exitWith {};   // boot-only (init.sqf); leaves the case = the file's last statement
        // build the cache from the DB (entries only; nothing spawned yet)
        private _rows = ["SELECT oid, owners, furniture FROM houses WHERE furniture IS NOT NULL AND furniture != ''", 2, true] call DB_fnc_asyncQuery;
        if (_rows isEqualType []) then {{_x params [["_hid", -1], ["_own", ""], ["_fraw", ""]];
                private _entries = [_fraw] call _decode;
                if (count _entries > 0) then {private _p = (_entries select 0) param [1, [0,0,0]];
                    private _bldg = [_hid, _p] call _findBldg;
                    _cache set [format ["%1", _hid], [format ["%1", _own], _bldg, _entries, []]];};} forEach _rows;};
        diag_log format ["[LooneyBin][furniture] presence cache built: %1 house(s) with furniture", count _cache];
        // OWNER-TRIGGERED design (owner 2026-06-12): furniture NO LONGER auto-spawns on presence.
        // The house owner uses the "Show Furniture" scroll action -> case "show" spawns it; this loop
        // ONLY despawns each house's set once its owner logs out (auto-disable on logout).
        // (Old loop was also broken: `_y params ... forEach (values AP_furnCache)` -- _y only exists
        // when forEach'ing the HashMap itself, so it errored every tick and never spawned anything.)
        // singleevh.md: furniture presence despawn-manager migrated onto the single-wheel scheduler (id
        // "houseFurniture", 30s). Self-contained body (recomputes _onlineUIDs each tick; mutates only
        // APS_furnCache rows). Flag OFF => original loop runs byte-for-byte (else branch) = ZERO behavior change.
        ["houseFurniture", {params ["_st"];
            private _onlineUIDs = (call AP_fnc_realPlayers) apply { getPlayerUID _x }; {private _c = _y;
                _c params ["_ownerUID", "_bldg", "_entries", "_spawned"];
                private _isUp = ((_spawned findIf { !isNull _x }) != -1);
                if (_isUp && !(_ownerUID in _onlineUIDs)) then {
                    { if (!isNull _x) then { _x call AP_fnc_furnKill; }; } forEach _spawned;
                    _c set [3, []];
                    diag_log format ["[LooneyBin][furniture] owner %1 offline -> despawned house furniture", _ownerUID];};
            } forEach (localNamespace getVariable ["APS_furnCache", createHashMap]);}, 30, false, true] call AP_fnc_schedule;};
    case "show": {params ["", ["_houseID", -1, [0, ""]], ["_requester", objNull, [objNull]]];
        // owner 2026-09-26 SECURITY: the requester is the caller (was the payload), and the lazy-load oid is a query
        // parameter (a raw _houseID could UNION a forged owner + furniture list into the cache, which "show" spawns)
        if (remoteExecutedOwner isNotEqualTo 0) then { _requester = (allPlayers select { owner _x isEqualTo remoteExecutedOwner }) param [0, objNull]; };
        private _hk = format ["%1", _houseID];
        private _uid = if (isNull _requester) then { "" } else { getPlayerUID _requester };
        // lazy-load the cache row if this house wasn't cached at boot (e.g. furniture added this session)
        if !(_hk in _cache) then {
            private _rows = ["SELECT owners, furniture FROM houses WHERE oid = %s", 2, true, [_hk]] call DB_fnc_asyncQuery;
            if (_rows isEqualType [] && {count _rows > 0}) then {(_rows select 0) params [["_own", ""], ["_fraw", ""]];
                private _entries = [_fraw] call _decode;
                if (count _entries > 0) then {private _p = (_entries select 0) param [1, [0,0,0]];
                    _cache set [_hk, [format ["%1", _own], [_houseID, _p] call _findBldg, _entries, []]];};};};
        if !(_hk in _cache) exitWith {
            if (!isNull _requester) then { [["This house has no saved furniture.", "basic"], "AP_fnc_handleMessage", _requester, false, false] spawn AP_fnc_MP; };
        };
        private _c = _cache get _hk;
        _c params ["_ownerUID", "_bldg", "_entries", "_spawned"];
        if (_uid isNotEqualTo _ownerUID) exitWith {};   // owner only
        // owner 2026-07-10: "Show" is now PURGE-THEN-RESPAWN instead of an "already out" refusal -- it deletes
        // whatever of this house's set is currently spawned and rebuilds from the SAVED entries. Idempotent:
        // spamming it can never accumulate copies (the ladder dupe), and it doubles as a "reset my furniture
        // to its saved layout" button if anything drifted or glitched.
        { if (!isNull _x) then { _x call AP_fnc_furnKill; }; } forEach _spawned;
        _c set [3, []];
        private _objs = []; {_x params [["_class", "", [""]], ["_pos", [0,0,0], [[]]], ["_dir", 0, [0]], ["_puid", "", [""]]];
            if (_class isNotEqualTo "") then {private _o = _class createVehicle _pos;
                _o setDir _dir;
                _o setPosATL _pos;
                _o enableSimulationGlobal false;
                _o allowDamage false;
                _o setVariable ["AP_placedItem", true, true];
                _o setVariable ["AP_ownerID", _puid, true];
                _o setVariable ["AP_furniture", true, true];
                [_o, _class] call AP_fnc_furnLight;
                _objs pushBack _o;};} forEach _entries;
        _c set [3, _objs];
        diag_log format ["[LooneyBin][furniture] SHOW house %1: spawned %2 piece(s) for %3", _houseID, count _objs, _uid];
        if (!isNull _requester) then { [[format ["Furniture set out (%1 piece(s)). It packs away when you log off.", count _objs], "basic"], "AP_fnc_handleMessage", _requester, false, false] spawn AP_fnc_MP; };
    };
    case "hide": {params ["", ["_houseID", -1, [0, ""]], ["_requester", objNull, [objNull]]];
        if (remoteExecutedOwner isNotEqualTo 0) then { _requester = (allPlayers select { owner _x isEqualTo remoteExecutedOwner }) param [0, objNull]; };
        private _hk = format ["%1", _houseID];
        if !(_hk in _cache) exitWith {};
        private _c = _cache get _hk;
        _c params ["_ownerUID", "_bldg", "_entries", "_spawned"];
        private _uid = if (isNull _requester) then { "" } else { getPlayerUID _requester };
        if (_uid isNotEqualTo _ownerUID) exitWith {};
        { if (!isNull _x) then { _x call AP_fnc_furnKill; }; } forEach _spawned;
        _c set [3, []];
        if (!isNull _requester) then { [["Furniture packed away.", "basic"], "AP_fnc_handleMessage", _requester, false, false] spawn AP_fnc_MP; };
    };};
