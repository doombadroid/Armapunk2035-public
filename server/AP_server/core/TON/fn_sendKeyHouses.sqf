/*
    APS_fnc_sendKeyHouses  (LooneyBin: owner 2026-06-23)
    A client (at login) asks the server for the map positions of every house it holds a KEY to but does NOT own
    (owned houses already get a blue phouse_ marker from AP_fnc_CLinitHouses). Server is authoritative: it
    derives the REAL caller from the non-spoofable remoteExecutedOwner, scans AP_house_owners, finds each house
    object, checks AP_house_keys for the caller's UID, and ships the filtered position list back to that one
    client, which draws green "(Key)" markers (AP_fnc_initKeyHouseMarkers).

    Client args: []   (NOTHING client-supplied is trusted; caller identity comes from remoteExecutedOwner)
*/
private _src = remoteExecutedOwner;
// 0 = server-internal call -> no client to send markers to; bail.
if (_src isEqualTo 0) exitWith {};
private _caller = (allPlayers select { owner _x isEqualTo _src }) param [0, objNull];
if (isNull _caller) exitWith {};

// anti-spam: this scans every house (nearestObjects per row); a client could remoteExec it in a loop. One
// refresh per ~15s per caller is plenty (it is normally login-triggered, once per session).
private _now = diag_tickTime;
if ((_now - (_caller getVariable ["AP_lastKeyHouseReq", -999])) < 15) exitWith {};
_caller setVariable ["AP_lastKeyHouseReq", _now];

private _uid = getPlayerUID _caller;
if (_uid isEqualTo "") exitWith {};

private _out = []; {_x params [["_oid", -1], ["_ownerUID", ""], ["_ws", []]];
    // skip houses the caller OWNS -- those already show as blue phouse_ markers.
    if (_ownerUID isEqualTo _uid) then { continue };
    if !(_ws isEqualType [] && {count _ws > 0}) then { continue };
    // owner 2026-07-09: was ["House_F"], which never reliably matches Land_i_Shed_Ind_F (see fn_receiveHouses)
    // -> key-held SHEDS resolved null (or the coincident hidden derelict) and their green (Key) markers never
    // sent. Mirror the receiveHouses resolve: broad ["House"] + house-type filter, derelict-proof.
    private _htypes = ["getHouses"] call AP_fnc_houseConfig;
    private _kcands = nearestObjects [_ws, ["House"], 15, true];
    private _bldg = (_kcands select { (typeOf _x) in _htypes }) param [0, (_kcands param [0, objNull])];
    if (isNull _bldg) then { continue };
    private _keys = _bldg getVariable ["AP_house_keys", []];
    if (_keys isEqualTo []) then { continue };
    if ((_keys findIf { _uid isEqualTo (_x param [0, ""]) }) != -1) then {_out pushBack [getPosATL _bldg, _oid];};
} forEach AP_house_owners;

if (_out isEqualTo []) exitWith {};
[[_out], "AP_fnc_initKeyHouseMarkers", _caller] spawn AP_fnc_MP;
