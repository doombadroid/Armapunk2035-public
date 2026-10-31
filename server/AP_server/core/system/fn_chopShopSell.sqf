
private["_unit","_vehicle","_price","_player"];
_unit = [_this,0,objNull,[objNull]] call BIS_fnc_param;
_vehicle = [_this,1,objNull,[objNull]] call BIS_fnc_param;
_price = [_this,2,500,[0]] call BIS_fnc_param;

// owner 2026-06-23 SECURITY (security.md §2.1 CRIT / §2.2): this is APS_fnc_srvChopShopSell's target, a
// CfgRE-whitelisted server fn -> any client can remoteExec it with arbitrary args. Two holes were live:
//   (a) MONEY DUPE: the client-sent _price (arg2) was paid verbatim -> [player,anyVeh,9.9e8] minted 9.9e8.
//   (b) the actor credited was the passed _unit object -> a scripter could direct the payout anywhere.
// Fix: derive the actor from the NON-SPOOFABLE remoteExecutedOwner (model fn_seizeLock:22), RECOMPUTE the
// chop price server-side from the vehicle config (model fn_srvSellVehicle -- getVehicleRow idx 8 by side),
// and require the vehicle to actually be at a chop shop. The client _price is now ignored entirely.
private _src = remoteExecutedOwner;
private _caller = if (_src isEqualTo 0) then { objNull } else { (allPlayers select { owner _x isEqualTo _src }) param [0, objNull] };
private _callerUID = getPlayerUID _caller;
// server-internal (_src==0) always trusted; for a real client call the actor IS the caller, never the passed
// object (closes "credit the payout to anyone"). A null/unknown caller on a client call = reject.
if (_src isNotEqualTo 0) then { _unit = _caller; };
if (_src isNotEqualTo 0 && {isNull _unit}) exitWith { ["-SEC-", _caller, format ["BLOCKED chopShopSell (no real caller) by %1", _callerUID]] call APS_fnc_logIt; };

if (isNull _vehicle OR isNull _unit) exitWith {};
if (_vehicle getVariable ["CHOPPED", false]) exitWith {};

// owner 2026-06-23 SECURITY (security.md §2.2): chop-zone gate. A legit chop only happens at a chop shop
// (client fn_chopShopMenu lists vehicles within 25m of a chop_shop marker). Server-verify the same so a
// remote call can't "chop" (destroy) a vehicle sitting anywhere on the map. Always-safe: it's exactly the
// condition the legit client already satisfies. (Possession is NOT checked here BY DESIGN -- a chop shop
// destroys OTHER players' stolen vehicles; that's the feature. See NEEDS OWNER REVIEW in the report.)
// FLAT top-level exitWith (the jailSys/seizeLock idiom -- a nested exitWith would only leave a then-block).
if (_src isNotEqualTo 0 && {(["chop_shop_1","chop_shop_2"] findIf { (markerType _x) isNotEqualTo "" && {(_vehicle distance2D (getMarkerPos _x)) <= 30} }) isEqualTo -1}) exitWith {
    ["-SEC-", _caller, format ["BLOCKED chopShopSell (veh not at a chop shop) by %1", _callerUID]] call APS_fnc_logIt;};

_displayName = getText(configFile >> "CfgVehicles" >> (typeOf _vehicle) >> "displayName");
_player = _unit;

_dbInfo = _vehicle getVariable["dbInfo",[]]; // owner 2026-06-21 (#477): gang + garage-pulled vehicles set only AP_dbInfo, not dbInfo -> the old dbInfo read came back [] -> the chop EXITED at the count-0 guard = silent no-op ("cant chop a gang vehicle"). Fall back.
if (count _dbInfo == 0) then { _dbInfo = _vehicle getVariable["AP_dbInfo",[]]; };
if (count _dbInfo == 0) exitWith {};

// owner 2026-06-23 SECURITY (security.md §2.1): server-recompute the chop price from the vehicle config
// (idx 8, indexed by the vehicle's stored side) -- the SAME source the client UI reads in fn_chopShopMenu
// and that fn_srvSellVehicle uses for its sell-back. The client-sent _price is NOT trusted. _SANITY_CAP
// guards a config typo; unknown/custom classes fall back to a tight cap rather than paying the client figure.
private _SANITY_CAP = 5000000;
private _FALLBACK   = 100000;
private _sideStr = format ["%1", _vehicle getVariable ["AP_side", _dbInfo param [4, ""]]];
private _sideIdx = switch (toLower _sideStr) do { case "cop": {1}; case "med": {2}; default {0} };
private _srvPrice = -1;
private _row = ["getVehicleRow", "", (typeOf _vehicle)] call AP_fnc_vehicleConfig;
if (_row isEqualType [] && {count _row > 8}) then {private _raw = _row select 8;
    private _p = if (_raw isEqualType []) then { _raw param [_sideIdx, (_raw param [0, 0])] } else { _raw };
    private _ov = ["veh", (typeOf _vehicle)] call AP_fnc_priceOv;
    if (_ov isNotEqualTo [] && {(_ov param [3, -1]) >= 0}) then { _p = _ov select 3; };
    if (_p isEqualType 0) then { _srvPrice = round _p; };};
// NEW DRACHMA: a nd_car (ND) vehicle chops for ND, not cash -- else buy-cheap-in-ND / chop-for-cash
// is a money printer (same hole as the garage sell-back). Shop keys are config row idx 3.
// owner 2026-07-24: also accept the "nd_priced" currency-only sentinel (see fn_srvSellVehicle) -- pulling a
// vehicle from the ND shop empties its shop-key list, which used to erase its ND-ness and reopen the
// ND-buy/cash-chop printer.
private _isND = (_row isEqualType [] && {count _row > 3} && {(_row select 3) isEqualType []} && {("nd_car" in (_row select 3)) || {"nd_priced" in (_row select 3)}});
if (_srvPrice < 0) then { _srvPrice = _FALLBACK; };
// preserve the legacy "sought-after vehicle" 10% chop bonus (server-owned list)
private _bonus = ((typeOf _vehicle) in AP_chopVehicle);
if (_bonus) then { _srvPrice = round (_srvPrice * 1.1); };
_price = (_srvPrice max 0) min _SANITY_CAP;

_uid = _dbInfo param [0, ""];
_plate = _dbInfo param [1, -1];

_vehicle setVariable ["insured", false, true];
// Audit 2026-09-26 (mints, review): dbInfo / AP_dbInfo are PUBLIC object vars, so a client can stamp a vehicle it
// spawned itself with any registration. The DELETE is the proof: pay only when it removed this vehicle's real row
// (owner + plate + THIS class). No row -> the vehicle is still chopped, for nothing. Parameterised, so the
// client-writable ids never reach the SQL text. Gang vehicle (AP_dbInfo=[gangId,plate,true]): its row is in
// gang_vehicles, and _uid is the gang id.
private _del = if ((_dbInfo param [2, false]) isEqualTo true) then {
    ["DELETE FROM gang_vehicles WHERE gang_id = %s::integer AND plate = %s::integer AND lower(classname) = lower(%s)", [_uid, _plate, typeOf _vehicle]] call DB_fnc_asyncExec
} else {
    ["DELETE FROM vehicles WHERE pid = %s AND plate = %s::integer AND lower(classname) = lower(%s)", [_uid, _plate, typeOf _vehicle]] call DB_fnc_asyncExec
};

_vehicle setVariable ["CHOPPED", true];
deleteVehicle _vehicle;
if !((_del param [0, 0]) isEqualTo 1 && {(_del param [1, 0]) > 0}) exitWith {
    [[2, format ["The chop shop scrapped the %1, but it has no registration on file -- nothing to pay.", _displayName]], "AP_fnc_broadcast", _unit, false] spawn AP_fnc_MP;
    ["-SEC-", _caller, format ["chopShopSell: %1 with dbInfo %2 matched no DB row -- chopped, NOT paid", typeOf _vehicle, _dbInfo]] call APS_fnc_logIt;
};
// OUTLAW talents (server-minted -> read via the talent bridge, not client-asserted): Chop Artist(233) +20%,
// Master Thief(235) +15% more. Boost before the credit + message so both reflect it.
private _outTal = _unit getVariable ["AP_talents", []];
private _chopMult = 1;
if (233 in _outTal) then { _chopMult = _chopMult + 0.20; };
if (235 in _outTal) then { _chopMult = _chopMult + 0.15; };
if (_chopMult > 1) then { _price = round (_price * _chopMult); };
// Audit 2026-09-26 (mints, review): the same hourly ND cap as fn_srvSellVehicle for an ND vehicle that is ALSO sold
// for cash -- nothing proves it was bought in ND, so any client can register one and chop it. Over the cap the chop
// still happens and pays nothing.
private _ndCapHit = false;
if (_isND && {((_row select 3) - ["nd_car", "nd_priced"]) isNotEqualTo []}) then {
    private _win = localNamespace getVariable "AP_ndVehPayWin";
    if (isNil "_win") then { _win = createHashMap; localNamespace setVariable ["AP_ndVehPayWin", _win]; };
    private _cu = getPlayerUID _unit;
    private _w = _win getOrDefault [_cu, [serverTime, 0]];
    if (serverTime - (_w select 0) > 3600) then { _w = [serverTime, 0]; };
    _ndCapHit = ((_w select 1) + (_price / 6000)) > 20;
    if (!_ndCapHit) then { _w set [1, (_w select 1) + (_price / 6000)]; _win set [_cu, _w]; };
};
if (_ndCapHit) exitWith {
    [[2, format ["The chop shop scrapped the %1, but New Drachma payouts for this vehicle type are capped at 20 ND per hour -- nothing paid.", _displayName]], "AP_fnc_broadcast", _unit, false] spawn AP_fnc_MP;
};
if (_isND) then {
    // ND vehicle -> pay the chop in New Drachma (6000:1 of the cash chop value), not cash.
    private _ndStr = (_price / 6000) toFixed 4;
    [_unit, _ndStr, "vehchop"] call APS_fnc_ndCreditSrv;
    _message = if (_bonus) then
    { format["You have chopped a %1 for %2 New Drachma (10%4 sought-after bonus).",_displayName,_ndStr,"","%"] }
    else { format["You have chopped a %1 for %2 New Drachma.",_displayName,_ndStr] };} else {
    [["cash","add",_price],"AP_fnc_uC",_unit,false] spawn AP_fnc_MP;
    _message = if (_bonus) then {
    format["You have chopped a %1 for $%2, having received a 10% bonus for being a sought after vehicle.",_displayName,[_price] call AP_fnc_numberText]
    }
    else {format["You have chopped a %1 for $%2",_displayName,[_price] call AP_fnc_numberText]};};

[[2,_message],"AP_fnc_broadcast",_unit,false] spawn AP_fnc_MP;

[109, _player, format["%1 chopped %2 for %3", name _player, typeOf _vehicle, _price]] spawn APS_fnc_logIt;