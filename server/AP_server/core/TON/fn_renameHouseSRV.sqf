/*
    APS_fnc_renameHouseSRV  (LooneyBin, owner 2026-07-10) -- OWNER-gated house rename.
    CfgRE-whitelisted: under CfgRemoteExec mode=1 a client can't remoteExec raw engine commands, so the
    rename travels as this whitelisted function. SECURITY: the actor is derived from the non-spoofable
    remoteExecutedOwner (NOT any client-passed identity), and must be the house's AP_homeOwner. The name
    is RE-SANITIZED here (the real trust boundary -- the client sanitizes for UX only): a strict whitelist
    of letters / digits / space / '-' / '_' , capped at 24 chars, so nothing that could inject SQL or be
    compiled survives. Persists to houses.custom_name and sets AP_houseName GLOBAL so the map marker +
    spawn list show it for everyone. Clearing (sell/transfer) lives in fn_srvSellHouse / fn_transferHouse.
    _this = [_house, _name]
*/
params [["_house", objNull, [objNull]], ["_name", "", [""]]];
if (isNull _house) exitWith {};

private _src = remoteExecutedOwner;
private _caller = if (_src isEqualTo 0) then { objNull } else { (allPlayers select { owner _x isEqualTo _src }) param [0, objNull] };
// server-internal (_src==0) is trusted; otherwise the caller MUST own the house
// owner 2026-09-26 SECURITY (houses audit, TONd-0-0 class): this gate was a NESTED exitWith (it left only the then{},
// so every caller fell through to the rename) and it read the client-writable AP_homeOwner. Flat top-level gate,
// owner + oid from the houses ROW (APS_fnc_houseRights).
private _rights = if (_src isEqualTo 0) then { [] } else { [_house] call APS_fnc_houseRights };
if (_src isNotEqualTo 0 && {isNull _caller || {(_rights select 1) isEqualTo ""} || {(getPlayerUID _caller) isNotEqualTo (_rights select 1)}}) exitWith {
    ["-SEC-", _caller, format ["BLOCKED renameHouse (not owner) oid=%1 by %2", _rights select 0, if (isNull _caller) then {"?"} else {getPlayerUID _caller}]] call APS_fnc_logIt;
};

// RE-SANITIZE server-side -- whitelist A-Z a-z 0-9 space '-' '_' only, cap 24. Strips quotes/semicolons/
// brackets/backslash by construction -> SQL-safe AND cannot form executable SQF.
private _clean = toString ((toArray _name) select {
    (_x >= 48 && {_x <= 57}) || {_x >= 65 && {_x <= 90}} || {_x >= 97 && {_x <= 122}} || {_x == 32} || {_x == 45} || {_x == 95}});
// trim leading/trailing spaces, cap length
while { (count _clean) > 0 && {(_clean select [0,1]) isEqualTo " "} } do { _clean = _clean select [1]; };
while { (count _clean) > 0 && {(_clean select [(count _clean) - 1]) isEqualTo " "} } do { _clean = _clean select [0, (count _clean) - 1]; };
if ((count _clean) > 24) then { _clean = _clean select [0, 24]; };

private _oid = if (_src isEqualTo 0) then { _house getVariable ["AP_houseID", ""] } else { _rights select 0 };
if (_oid isEqualTo "" || {(str _oid) isEqualTo "-1"}) exitWith {
    if (!isNull _caller) then { [["That house isn't ready yet -- try again in a moment.", "basic"], "AP_fnc_handleMessage", _caller] spawn AP_fnc_MP; };
};
private _oidSql = (format ["%1", _oid]) splitString "'" joinString "";

// _clean is already quote-free -> safe to inline. Empty name clears the custom name (back to type name).
if (_clean isEqualTo "") then {[format ["UPDATE houses SET custom_name=NULL WHERE oid='%1'", _oidSql]] call DB_fnc_asyncQuery;} else {
    [format ["UPDATE houses SET custom_name='%1' WHERE oid='%2'", _clean, _oidSql]] call DB_fnc_asyncQuery;};

_house setVariable ["AP_houseName", _clean, true];   // GLOBAL -> spawn list (fn_spawnPointCfg) + markers read it
if (!isNull _caller) then {
    [[_house, _clean], "AP_fnc_renameHouseDone", _caller] spawn AP_fnc_MP;   // client: refresh marker + confirm toast
};
diag_log format ["[LooneyBin][house] %1 renamed oid=%2 -> '%3'", if (isNull _caller) then {"server"} else {name _caller}, _oid, _clean];
