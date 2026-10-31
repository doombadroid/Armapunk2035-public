/*
    APS_fnc_vehOwnerSwap  (LooneyBin) -- chop-shop "Claim Vehicle".  client args: [claimer, vehicle, claimPrice]
    Transfer the vehicle's PERSISTENT ownership (vehicles.pid) to the claimer so the ORIGINAL owner loses
    it -- and its key -- on their next load (keys derive from pid; there is no separate keys column). Update
    the live vehicle's owner/keyholder vars so the claimer drives away with the only key. The claimer's bank
    was already debited client-side (ClupdatePartial[1] -> bankacc); online keyholders had their live key
    pulled by AP_fnc_removeVehKey -- the pid transfer covers OFFLINE owners (was a stub -> nothing moved).
*/
params [["_player", objNull, [objNull]], ["_vehicle", objNull, [objNull]], ["_claimPrice", 0, [0]]];
if (isNull _player || {isNull _vehicle}) exitWith {};

// owner 2026-06-23 SECURITY (security.md §2.2 HIGH): CfgRE-whitelisted -> a client can remoteExec
// [player, ANY_veh, 0] to seize any vehicle's DB ownership + key. Derive the CLAIMER from the
// non-spoofable remoteExecutedOwner (model fn_seizeLock:22) -- never the passed _player object -- and
// require the SAME conditions the legit chop-shop claim (client fn_chopShopClaim) satisfies: the vehicle
// is at a chop shop AND is a claimable civ vehicle (a chop-shop claim is INTENDED to steal another player's
// vehicle, so possession is deliberately NOT required -- but it can only happen at a shop, on a claimable
// civ car, by the real caller). This closes "claim any vehicle anywhere as anyone".
// FLAT top-level exitWith guards (the jailSys/seizeLock idiom -- an exitWith nested in `then{}` only leaves
// the block, falling through into the theft). _client = the real caller for a client invocation.
private _src = remoteExecutedOwner;
private _client = if (_src isEqualTo 0) then { objNull } else { (allPlayers select { owner _x isEqualTo _src }) param [0, objNull] };
if (_src isNotEqualTo 0 && {isNull _client}) exitWith { ["-SEC-", objNull, format ["BLOCKED vehOwnerSwap (no real caller, src %1)", _src]] call APS_fnc_logIt; };
// claimable-civ gate (mirror of the client fn_chopShopClaim gate)
if (_src isNotEqualTo 0 && {(format ["%1", _vehicle getVariable ["AP_side", ""]]) isNotEqualTo "civ"}) exitWith { ["-SEC-", _client, format ["BLOCKED vehOwnerSwap (veh not claimable civ) by %1", getPlayerUID _client]] call APS_fnc_logIt; };
if (_src isNotEqualTo 0 && {!(_vehicle getVariable ["AP_canChop", true]) || {_vehicle getVariable ["AP_vehIsMaxTac", false]} || {_vehicle getVariable ["AP_vehIsFirefighter", false]} || {_vehicle getVariable ["AP_vehicleAirdrop", false]}}) exitWith { ["-SEC-", _client, format ["BLOCKED vehOwnerSwap (protected/unclaimable veh) by %1", getPlayerUID _client]] call APS_fnc_logIt; };
// chop-zone gate (same 25m radius the client lists within; 30m server slack)
if (_src isNotEqualTo 0 && {(["chop_shop_1","chop_shop_2"] findIf { (markerType _x) isNotEqualTo "" && {(_vehicle distance2D (getMarkerPos _x)) <= 30} }) isEqualTo -1}) exitWith { ["-SEC-", _client, format ["BLOCKED vehOwnerSwap (not at a chop shop) by %1", getPlayerUID _client]] call APS_fnc_logIt; };
if (_src isNotEqualTo 0) then { _player = _client; };   // the claimer IS the caller

private _newUID = getPlayerUID _player;
if (_newUID isEqualTo "") exitWith {};
(_vehicle getVariable ["AP_dbInfo", ["", 0, false]]) params [["_oldUID", "", [""]], ["_plate", 0, [0]], ["_isGang", false, [false]]];
if (_oldUID isEqualTo "" || {_oldUID isEqualTo _newUID}) exitWith {};
// owner 2026-06-23 SECURITY (security.md §2.3): SQL-escape the ids/plate from dbInfo into LOCAL copies for the
// UPDATE only -- keep the original _newUID/_plate types intact for the setVariable/log below (plate is a Number;
// re-typing it would break downstream numeric plate matches in fn_vehicleStore etc.).
private _newUIDsql = (format ["%1", _newUID]) splitString "'" joinString "";
private _oldUIDsql = (format ["%1", _oldUID]) splitString "'" joinString "";
private _plateSql  = (format ["%1", _plate])  splitString "'" joinString "";
[format ["UPDATE vehicles SET pid='%1' WHERE pid='%2' AND plate='%3'", _newUIDsql, _oldUIDsql, _plateSql]] call DB_fnc_asyncQuery;
_vehicle setVariable ["AP_dbInfo", [_newUID, _plate, _isGang], true];
_vehicle setVariable ["AP_vehOwners", [[_newUID, name _player]], true];
// owner 2026-06-15 (#210): also swap the LEGACY `dbInfo` var. fn_vehicleStore (the garage "Store vehicle"
// path) reads ownership from dbInfo select 0, NOT AP_dbInfo -> after a chop-shop claim it still saw the
// OLD owner, so the claimer got "this vehicle doesn't belong to you" / "not claimed" when trying to store.
// Swap just the owner uid, keep the plate/alarm fields.
private _legacy = _vehicle getVariable ["dbInfo", [_oldUID, _plate, 0, false]];
if (!(_legacy isEqualType []) || {count _legacy < 4}) then { _legacy = [_oldUID, _plate, 0, false]; };
_legacy set [0, _newUID];
_legacy set [1, _plate];
_vehicle setVariable ["dbInfo", _legacy, true];
[["-VEHCLAIM-", _player, (name _player), format ["claimed vehicle plate %1 from %2 for $%3", _plate, _oldUID, _claimPrice]], "APS_fnc_logIt", 2, false, false] spawn AP_fnc_MP;
