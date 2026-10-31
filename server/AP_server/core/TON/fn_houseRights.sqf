/*
    APS_fnc_houseRights  (audit 2026-09-26, houses cluster) -- who may touch a house, read from the DB.

        [_house, _caller] call APS_fnc_houseRights   ->   [_oid, _ownerUID, _canAccess, _gangId, _wsPos, _keyUIDs]

      _oid       houses.oid of the building's row ("" = no row / object not bound to it). The position hash
                 (addHouse's getPosWorld x/y) is tried first, AP_houseID only when no row has it (legacy oids,
                 Malden shells) -- and that fallback row only counts when the object STANDS on it (getPosATL
                 within 3 m of houses.worldspace). The object must be a house-type building either way.
                 Callers authorise AND write by THIS oid.
      _ownerUID  houses.owners ("" = no row / unowned)
      _canAccess _caller may use the storage: the owner, a keyholder (houses.keyholders), a member of the
                 gang whose HQ this ROW is (APS_gangOfUid vs gangs.house_pos near houses.worldspace), or an
                 on-duty cop
      _gangId    the gang whose gangs.house_pos is this row's building, -1 if none
      _wsPos     houses.worldspace parsed to [x,y,z] ([] if unreadable)
      _keyUIDs   keyholder UIDs from houses.keyholders

    AP_homeOwner / AP_house_keys / AP_houseID / AP_house_gang (and a player's gang_data) are object vars
    any client can setVariable publicly, so no server gate may authorise from them; every right above is a
    property of the ROW, never of the object passed in. Server-internal only (no CfgRE entry). Scheduled
    callers only (mode-2 queries); every remoteExec'd caller is scheduled.
*/
params [["_house", objNull, [objNull]], ["_caller", objNull, [objNull]]];
private _none = ["", "", false, -1, [], []];
// a house-type building only (the client's own storage test): never a vehicle / prop parked on a house's spot
if (isNull _house || {!((_house isKindOf "House_F") || {(typeOf _house) in (["getHouses"] call AP_fnc_houseConfig)})}) exitWith { _none };
private _p = getPosWorld _house;
private _ids = [format ["%1%2", round (_p select 0), round (_p select 1)]];
private _hid = format ["%1", _house getVariable ["AP_houseID", ""]];
if !(_hid in ["", "-1", _ids select 0]) then { _ids pushBack _hid; };
private _row = [];
private _viaHid = false;
{
    _row = ["SELECT oid, owners, COALESCE(keyholders, ''), worldspace FROM houses WHERE oid = %s", 2, false, [_x]] call DB_fnc_asyncQuery;
    if (_row isEqualType [] && {_row isNotEqualTo []}) exitWith { _viaHid = _forEachIndex > 0; };   // exits the forEach
} forEach _ids;
if !(_row isEqualType [] && {_row isNotEqualTo []}) exitWith { _none };
// worldspace = str getPosATL of the building at buy time (fn_addHouse); old rows nest it as [[x,y,z], dir]
private _ws = format ["%1", _row param [3, ""]];
_ws = if ((_ws select [0, 1]) isEqualTo "[") then { parseSimpleArray _ws } else { [] };
if (isNil "_ws" || {!(_ws isEqualType [])}) then { _ws = []; };
if ((_ws param [0, 0]) isEqualType []) then { _ws = _ws select 0; };
if (count _ws < 2 || {(_ws findIf { !(_x isEqualType 0) }) != -1}) then { _ws = []; };
// the AP_houseID fallback is client-writable: that row binds only to the building standing on its worldspace
if (_viaHid && {_ws isEqualTo [] || {((getPosATL _house) distance2D _ws) > 3}}) exitWith { _none };
private _oid = format ["%1", _row select 0];
private _own = format ["%1", _row select 1];
if (_own in ["0", "NULL"]) then { _own = ""; };

private _keys = [];
private _kh = format ["%1", _row select 2];
if !(_kh in ["", "NULL", "[]"]) then {private _a = [_kh] call DB_fnc_mresToArray;
    if (_a isEqualType "") then { _a = parseSimpleArray _a; };
    if (!isNil "_a" && {_a isEqualType []}) then { _keys = _a apply { if (_x isEqualType []) then { format ["%1", _x param [0, ""]] } else { "" } }; };};

// the gang HQ'd at this ROW's building. gangs.house_pos is the building's getPosATL (fn_addGangHouse /
// fn_changeGangHouseSRV store the row's worldspace), so it sits ~0 m from houses.worldspace; 3 m, not the boot
// re-tag's 14 m nearestBuilding radius, so a neighbouring house never inherits the HQ's gang access.
private _gang = -1;
if (_ws isNotEqualTo []) then {private _gr = ["SELECT id, house_pos FROM gangs WHERE house_pos IS NOT NULL", 2, true] call DB_fnc_asyncQuery;
    if (_gr isEqualType []) then {private _gi = _gr findIf {private _gp = format ["%1", _x param [1, ""]];
            ((_gp select [0, 1]) isEqualTo "[") && {_gp = parseSimpleArray _gp; (count _gp >= 2) && {(_ws distance2D _gp) < 3}}};
        if (_gi != -1) then { _gang = parseNumber format ["%1", (_gr select _gi) param [0, -1]]; };};};

private _uid = if (isNull _caller) then { "" } else { getPlayerUID _caller };
private _access = (_uid isNotEqualTo "") && {(_uid isEqualTo _own) || {_uid in _keys}
    || {(_gang > 0) && {_gang isEqualTo ((localNamespace getVariable ["APS_gangOfUid", createHashMap]) getOrDefault [_uid, 0])}}
    || {_caller call APS_fnc_isDutyCop}};
[_oid, _own, _access, _gang, _ws, _keys]
