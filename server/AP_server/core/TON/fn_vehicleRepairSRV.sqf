/*
    APS_fnc_vehicleRepairSRV  (LooneyBin: REPAIRED -- was a broken passthrough to DB_fnc_updateVehicle)
    Client (garage repair-refuel) args: [_plate, _uid, _displayName, _repairPriceText, _isGang?, _gangID?]
    Repairs a GARAGED vehicle by zeroing its stored damage so the next pull spawns it undamaged. The
    repair price is debited client-side before this fires. The old stub fed these into updateVehicle,
    which expects a vehicle OBJECT at index 2 (it got a display-name string) -> no-op -> garage repair
    never persisted. Gang vehicles are stored under the gang id; personal under the player uid.
*/
params [["_plate", -1, [0]], ["_uid", "", [""]], ["_dn", "", [""]], ["_price", "", [""]], ["_isGang", false, [false]], ["_gangID", -1, [0, -1]]];
if (_plate < 0) exitWith {};
// owner 2026-06-23 SECURITY (security.md §2.3 — cross-account write + SQLi): the client _uid was used raw in
// the personal-vehicle UPDATE. Force the PERSONAL path to the NON-SPOOFABLE caller's OWN account (the garage
// repair always passes the local player's uid). _plate/_gangID are numeric (params type [0]) -> round them
// into the SQL. Server-internal (_src==0) keeps the passed _uid. NB: the GANG path writes gang_vehicles by
// gang_id with NO rank/membership check -- that authz gap is tracked separately in security.md §2.2 (gang
// authority) and is NOT in this fn's scope; here we only coerce/escape the interpolated values.
private _src = remoteExecutedOwner;
if (_src != 0) then { _uid = getPlayerUID ((allPlayers select { owner _x isEqualTo _src }) param [0, objNull]); };
private _san = { (format ["%1", _this]) splitString "\'""" joinString "" };
_uid = _uid call _san;
// owner 2026-06-21 (#464 "hit repair, nothing happened"): the button is "Repair & REFUEL" and charges a
// fuel-based price, but this fn only zeroed DAMAGE -- it never restored fuel, so a low-fuel garaged vehicle
// stayed low-fuel and the player saw no change. REFUEL too (fuel 100 = full tank on the next pull). And gang
// vehicles live in `gang_vehicles` keyed by `gang_id` -- the old `UPDATE vehicles ... pid='<gangID>'` hit the
// wrong table and matched no row, so GANG repair was a complete no-op. Route each side to its real table.
if (_isGang && {_gangID < 0}) exitWith {};
if (!_isGang && {_uid isEqualTo ""}) exitWith {};
private _q = if (_isGang) then {
    format ["UPDATE gang_vehicles SET damage='0', fuel='100' WHERE gang_id='%1' AND plate='%2'", round _gangID, round _plate]} else {
    format ["UPDATE vehicles SET damage='0', fuel='100' WHERE pid='%1' AND plate='%2'", _uid, round _plate]};
[_q] call DB_fnc_asyncQuery;
