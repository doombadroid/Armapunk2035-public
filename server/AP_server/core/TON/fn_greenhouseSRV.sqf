/*
    APS_fnc_greenhouseSRV  (LooneyBin -- house weed grow, server-authoritative. spec: weed.md, 2026-06-13)
    Crop on each house object: _house AP_gh_crop = [[strain, plantedUnix, count], ...]
      strain "s" = Sativa (matures stage 2 = 2h),  "i" = Indica (matures stage 3 = 3h).
    Stage = floor((nowUnix - plantedUnix) / 3600). Persisted to houses.greenhouse_crop (str of the array).
    Capacity (max plants) = floor(house AP_vcap / 10).  Harvest yields the bud item (weight 1):
      Sativa -> cannas_3 (Weed),  Indica -> cannai_3 (High-Potency Weed).
    Cases:
      ["plant",   [player, house, strain, count]]
      ["harvest", [player, house, wantSativa, wantIndica]]   (want* = how many the client can carry)
      ["reload",  []]   -- boot: load crops from DB onto the house objects (after houses + buildings exist)
*/
params [["_case", "", [""]], ["_data", [], [[]]]];
private _nowUnix = (missionNamespace getVariable ["AP_bootUnix", 0]) + serverTime;   // wall-clock approx

// CALLER BINDING: every client caller (fn_greenhouse: plant/harvest/sync) passes `player` first in _data; "reload" is
// boot-only. Server calls pass.
private _caller = (allPlayers select { owner _x isEqualTo remoteExecutedOwner }) param [0, objNull];
if (isRemoteExecuted && {remoteExecutedOwner isNotEqualTo 2} && {_case isEqualTo "reload" || {(_data param [0, objNull]) isNotEqualTo _caller}}) exitWith {
    ["-SEC-", _caller, format ["BLOCKED greenhouseSRV %1: remote reload or actor is not the caller", _case]] call APS_fnc_logIt;};

// THE SERVER'S COPY (same defect as fn_barrelSRV, audit Lecon-0-3). AP_gh_crop on the house is PUBLIC: after the one DB
// sync a client could overwrite it with forged mature plants and harvest them, and an unknown strain string survived
// harvest into `str` and the UPDATE. The server keeps its own copy in localNamespace (nothing on the network can write
// it), keyed by the house's AUTHORISED oid (the row APS_fnc_houseRights read in the calling case -- never the
// client-writable AP_houseID); the object var is only ever published FROM it. Rows are kept only in the shape plant writes.
private _fnClean = {params [["_c", []]];
    if !(_c isEqualType []) exitWith {[]};
    _c select { _x isEqualType [] && {count _x isEqualTo 3} && {(_x select 0) in ["s", "i"]} && {(_x select 1) isEqualType 0} && {(_x select 2) isEqualType 0} && {(_x select 2) >= 1} }};

// set the server copy, mirror it onto the house for the menus, persist it (NULL when empty so the reload filter skips it).
// PARAMETERISED: both values are bound, never formatted into the SQL.
private _persist = {params ["_h", "_oid", "_c"];
    localNamespace setVariable ["APS_gh_" + _oid, _c];
    _h setVariable ["AP_gh_crop", +_c, true];
    if (_c isEqualTo []) then {["UPDATE houses SET greenhouse_crop=NULL WHERE oid=%s", 1, false, [_oid]] call DB_fnc_asyncQuery;} else {
        ["UPDATE houses SET greenhouse_crop=%s WHERE oid=%s", 1, false, [str _c, _oid]] call DB_fnc_asyncQuery;};};

// owner 2026-07-15 ("Enrique plants and they vanish", rebuilt sheds): resolve the building for a crop row the
// way fn_tagHousesSRV does, NOT via a bare nearest-House_F grab. Buyable-shed spots hold TWO buildings at ~0m:
// the hidden derelict Land_u_Shed_Ind_F (terrain object, hideObjectGlobal'd by replace_sheds) and the intact
// createVehicle'd Land_i_Shed_Ind_F (which is NOT reliably isKindOf House_F, so the old filter could only ever
// find the DERELICT there). Crops attached to the hidden derelict while the players' menus target the intact
// shed -> Enrique's overnight plants were invisible, and the next in-game plant persisted the intact shed's
// empty crop over them. Prefer the intact shed, and never attach to a hidden object (also covers the hidden
// Malden originals).
private _fnResolveHouse = {params ["_pos"];
    private _cands = (nearestObjects [_pos, ["House_F", "Land_i_Shed_Ind_F"], 12]) select { !isObjectHidden _x };
    private _sheds = _cands select { (typeOf _x) isEqualTo "Land_i_Shed_Ind_F" };
    if (_sheds isNotEqualTo []) then { _sheds select 0 } else { _cands param [0, objNull] }};

// owner 2026-07-15: DB re-read on the FIRST in-game touch of a house's greenhouse each session. Enrique writes
// greenhouse_crop while the server is running (owner + keyholders all offline -- his gate), but the server only
// read the column at boot, so a mid-session Enrique run stayed invisible and the next plant/harvest clobbered it.
// Race-free: Enrique refuses to run while anyone with keys is online, and only key-holders can trigger this.
// Also self-heals rows whose crop got attached to the derelict by the pre-fix reload.
// Now it SEEDS THE SERVER'S COPY: "synced" = the localNamespace entry exists (the old AP_gh_synced object var was
// client-writable too). Enrique's mid-run "ghrefresh" (init.sqf) drops the entry so the next touch re-reads.
// [house, authorised oid] -> that oid once its server copy exists, else "" (no row, or the DB could not answer -- never
// seed an empty greenhouse over a real one)
private _fnSyncFromDB = {params ["_h", ["_oid", "", [""]]];
    if (_oid in ["-1", ""]) exitWith {""};
    if (isNil {localNamespace getVariable ("APS_gh_" + _oid)}) then {
        private _rows = ["SELECT COALESCE(greenhouse_crop,'') AS greenhouse_crop FROM houses WHERE oid=%s", 2, true, [_oid]] call DB_fnc_asyncQuery;
        if !(_rows isEqualType [] && {_rows isNotEqualTo []}) exitWith {};
        private _cropStr = format ["%1", (_rows select 0) param [0, ""]];
        private _crop = if (_cropStr in ["", "''"]) then { [] } else { parseSimpleArray _cropStr };
        if (isNil {localNamespace getVariable ("APS_gh_" + _oid)}) then { localNamespace setVariable ["APS_gh_" + _oid, [_crop] call _fnClean]; };   // a parallel seed may have won
    };
    if (isNil {localNamespace getVariable ("APS_gh_" + _oid)}) exitWith {""};
    private _crop = localNamespace getVariable ["APS_gh_" + _oid, []];
    if (_crop isNotEqualTo (_h getVariable ["AP_gh_crop", []])) then {_h setVariable ["AP_gh_crop", +_crop, true];};
    _oid};

switch (_case) do {case "reload": {
        private _rows = ["SELECT oid, worldspace, COALESCE(greenhouse_crop,'') AS greenhouse_crop FROM houses WHERE greenhouse_crop IS NOT NULL AND greenhouse_crop <> ''", 2, true] call DB_fnc_asyncQuery;
        if (!(_rows isEqualType [])) exitWith {};
        private _n = 0; {_x params [["_oid", ""], ["_ws", ""], ["_cropStr", ""]];
            private _pos  = parseSimpleArray _ws;
            private _crop = parseSimpleArray _cropStr;
            if (_pos isEqualType [] && {count _pos >= 2} && {_crop isEqualType []} && {!(_crop isEqualTo [])}) then {
                private _b = [_pos] call _fnResolveHouse;
                if (!isNull _b) then { _b setVariable ["AP_gh_crop", _crop, true]; _n = _n + 1; };
            };} forEach _rows;
        diag_log format ["[LooneyBin][weed] reloaded greenhouse crops onto %1 house(s)", _n];};

    case "plant": {
        _data params [["_player", objNull, [objNull]], ["_house", objNull, [objNull]], ["_strain", "", [""]], ["_count", 0, [0]]];
        if (isNull _player || {isNull _house} || {!(_strain in ["s", "i"])} || {_count < 1}) exitWith {};
        // owner 2026-07-15: the client consumes the seeds BEFORE this call, so every reject below must hand
        // them back or a server-side refusal silently eats the seeds.
        private _seedItem = if (_strain isEqualTo "s") then {"cannas_0"} else {"cannai_0"};
        private _fnRefund = { [[true, _seedItem, _count], "AP_fnc_handleInv", _player, false, false] spawn AP_fnc_MP; };
        if !(_house getVariable ["AP_greenhouse_unaged", false]) exitWith {call _fnRefund;
            [["This property has no greenhouse installed.", "basic"], "AP_fnc_handleMessage", _player, false, false] spawn AP_fnc_MP;};
        // owner 2026-06-16: greenhouse usable by anyone with KEYS to the house, not just the owner.
        // owner 2026-09-26 SECURITY (houses audit, TONd-0-0 class): the planter came from the payload and the gate read the
        // client-writable AP_homeOwner / AP_house_keys; owner/keyholder + the persisted row now come from the houses ROW.
        // (The planter is the caller: the CALLER BINDING block above refuses any other.)
        private _ghUid = getPlayerUID _player;
        private _ghR = [_house, _player] call APS_fnc_houseRights;
        private _authOid = _ghR select 0;
        if !(_ghUid isNotEqualTo "" && {(_ghR select 1) isEqualTo _ghUid || {_ghUid in (_ghR select 5)}}) exitWith {
            call _fnRefund;
            [["You need keys to this property to plant in its greenhouse.", "basic"], "AP_fnc_handleMessage", _player, false, false] spawn AP_fnc_MP;
        };
        private _oid = [_house, _authOid] call _fnSyncFromDB;
        if (_oid isEqualTo "") exitWith {call _fnRefund;
            [["The greenhouse's records are unavailable right now -- try again in a moment.", "basic"], "AP_fnc_handleMessage", _player, false, false] spawn AP_fnc_MP;};
        private _crop = +(localNamespace getVariable ["APS_gh_" + _oid, []]);
        private _cur = 0; { _cur = _cur + (_x param [2, 0]); } forEach _crop;
        private _maxPlants = floor ((_house getVariable ["AP_vcap", 0]) / 10);
        if (_cur + _count > _maxPlants) exitWith {call _fnRefund;
            [[format ["Greenhouse is full -- %1 / %2 plants (cap = virtual storage capacity / 10). You can plant %3 more.", _cur, _maxPlants, (_maxPlants - _cur) max 0], "basic"], "AP_fnc_handleMessage", _player, false, false] spawn AP_fnc_MP;
        };
        _crop pushBack [_strain, _nowUnix, _count];
        [_house, _oid, _crop] call _persist;
        private _hrs = if (_strain isEqualTo "s") then {2} else {3};
        private _sName = if (_strain isEqualTo "s") then {"Sativa"} else {"Indica"};
        [[format ["Planted %1 %2 seed(s). Mature in %3 hours -- grows while you're offline.", _count, _sName, _hrs], "basic"], "AP_fnc_handleMessage", _player, false, false] spawn AP_fnc_MP;
        ["-WEED-", _player, format ["planted %1 %2 (house %3) -> %4/%5", _count, _strain, _oid, _cur + _count, _maxPlants]] call APS_fnc_logIt;
    };

    case "sync": {_data params [["_player", objNull, [objNull]], ["_house", objNull, [objNull]]];
        if (isNull _house) exitWith {};
        // read-only (seeds the server copy from the DB, republishes it onto the house) -> no access gate, as before;
        // the row is still the one APS_fnc_houseRights binds this building to, never AP_houseID
        [_house, ([_house, _player] call APS_fnc_houseRights) select 0] call _fnSyncFromDB;};

    case "harvest": {
        _data params [["_player", objNull, [objNull]], ["_house", objNull, [objNull]], ["_wantS", 0, [0]], ["_wantI", 0, [0]]];
        if (isNull _player || {isNull _house}) exitWith {};
        // owner 2026-09-26 SECURITY (houses audit): harvester = caller (CALLER BINDING above); owner/keyholder + the
        // persisted row from the houses ROW
        private _ghUid = getPlayerUID _player;
        private _ghR = [_house, _player] call APS_fnc_houseRights;
        private _authOid = _ghR select 0;
        if !(_ghUid isNotEqualTo "" && {(_ghR select 1) isEqualTo _ghUid || {_ghUid in (_ghR select 5)}}) exitWith {
            [["You need keys to this property to harvest its greenhouse.", "basic"], "AP_fnc_handleMessage", _player, false, false] spawn AP_fnc_MP;
        };
        private _oid = [_house, _authOid] call _fnSyncFromDB;
        private _crop = if (_oid isEqualTo "") then {[]} else {localNamespace getVariable ["APS_gh_" + _oid, []]};
        if (_crop isEqualTo []) exitWith {
            [["Nothing is growing here.", "basic"], "AP_fnc_handleMessage", _player, false, false] spawn AP_fnc_MP;};
        // tally mature per strain
        private _matS = 0; private _matI = 0; {
            _x params ["_st", "_pt", "_cnt"]; if (_pt > 1000000000) then { _pt = _pt - 1700000000 };  // owner 2026-06-16: normalize PRE-#248 full-unix plant times to the epoch-offset clock so old crops still mature
            private _need = if (_st isEqualTo "s") then {2} else {3};
            if (floor (((_nowUnix - _pt) max 0) / 3600) >= _need) then {
                if (_st isEqualTo "s") then { _matS = _matS + _cnt } else { _matI = _matI + _cnt };};} forEach _crop;
        private _giveS = (_wantS max 0) min _matS;
        private _giveI = (_wantI max 0) min _matI;
        if (_giveS + _giveI <= 0) exitWith {
            [[format ["No mature plants you can carry right now (mature: %1 Weed, %2 High-Potency -- free up inventory).", _matS, _matI], "basic"], "AP_fnc_handleMessage", _player, false, false] spawn AP_fnc_MP;
        };
        // consume from mature batches (oldest first), keep the rest
        private _newCrop = [];
        private _remS = _giveS; private _remI = _giveI; {
            _x params ["_st", "_pt", "_cnt"]; if (_pt > 1000000000) then { _pt = _pt - 1700000000 };  // owner 2026-06-16: normalize PRE-#248 full-unix plant times to the epoch-offset clock so old crops still mature
            private _need = if (_st isEqualTo "s") then {2} else {3};
            private _keep = _cnt;
            if (floor (((_nowUnix - _pt) max 0) / 3600) >= _need) then {
                if (_st isEqualTo "s" && {_remS > 0}) then { private _take = _remS min _cnt; _keep = _cnt - _take; _remS = _remS - _take; };
                if (_st isEqualTo "i" && {_remI > 0}) then { private _take = _remI min _cnt; _keep = _cnt - _take; _remI = _remI - _take; };
            };
            if (_keep > 0) then { _newCrop pushBack [_st, _pt, _keep]; };} forEach _crop;
        [_house, _oid, _newCrop] call _persist;
        if (_giveS > 0) then { [[true, "cannas_3", _giveS], "AP_fnc_handleInv", _player, false, false] spawn AP_fnc_MP; };
        if (_giveI > 0) then { [[true, "cannai_3", _giveI], "AP_fnc_handleInv", _player, false, false] spawn AP_fnc_MP; };
        [[format ["Harvested %1 Weed + %2 High-Potency Weed.", _giveS, _giveI], "basic"], "AP_fnc_handleMessage", _player, false, false] spawn AP_fnc_MP;
        ["-WEED-", _player, format ["harvested s=%1 i=%2 (house %3)", _giveS, _giveI, _oid]] call APS_fnc_logIt;
    };};
