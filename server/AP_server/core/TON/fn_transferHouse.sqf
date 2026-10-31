/*
    APS_fnc_transferHouse  (LooneyBin -- implemented 2026-06-09; the passthrough fed
    [player, uid, house, price] into 2017 setOwnerID -> buying a MARKET-LISTED house never transferred
    ownership.)  Client (core/housing/fn_buyHouse.sqf market branch, buyer already paid client-side)
    sends [player, buyerUID, houseObj, buyPrice]. Transfer the row, pay the seller, retag the building.
*/
params [["_buyer", objNull, [objNull]], ["_uid", "", [""]], ["_house", objNull, [objNull]], ["_price", 0, [0]]];
// owner 2026-09-26 SECURITY (audit TONd-0-0): the buyer/UID came from the payload, and the oid, the SELLER (who gets
// paid) and the gang were read off AP_houseID / AP_homeOwner / AP_house_gang -- object vars any client can set
// publicly. The buyer is now the NON-SPOOFABLE caller; oid, seller and gang come from the houses ROW
// (APS_fnc_houseRights); the seller is never paid more than the DB listing price.
private _src = remoteExecutedOwner;   // 0 == server-internal = trusted
if (_src isNotEqualTo 0) then {_buyer = (allPlayers select { owner _x isEqualTo _src }) param [0, objNull];
    _uid = getPlayerUID _buyer;};
if (isNull _buyer || {_uid isEqualTo ""} || {isNull _house}) exitWith {};
private _rights = [_house] call APS_fnc_houseRights;
private _id = _rights select 0;
if (_id isEqualTo "") exitWith {
    [["The realtor couldn't process the sale (house not registered). Contact staff.", "basic"], "AP_fnc_handleMessage", _buyer, false, false] spawn AP_fnc_MP;
    [3, _house, _uid, _price, -1] remoteExec ["AP_fnc_handleHouse", owner _buyer];   // refund + release the buy lock
};
private _seller = _rights select 1;
private _gangid = _rights select 3;   // case-4 marker handling (gang house vs normal)

// SECURITY (owner 2026-06-17, house-theft hardening — sibling of the fn_addHouse fix): verify SERVER-SIDE that
// this is a real listed resale before overwriting ownership. The DB `sale` column = the listing price (>0 =
// for sale). Block + refund if the row has no real seller, the buyer IS the seller, or it isn't actually
// listed -- so a stale AP_homeOwner / forged call can't transfer an unlisted (or unowned) house = theft.
private _chk = ["SELECT COALESCE(owners,'') AS owners, COALESCE(sale,'0') AS sale FROM houses WHERE oid = %s", 2, false, [_id]] call DB_fnc_asyncQuery;
private _dbOwner = ""; private _dbSale = 0;
if (_chk isEqualType [] && {count _chk > 1}) then {_dbOwner = format ["%1", _chk select 0];
    _dbSale  = _chk select 1; if !(_dbSale isEqualType 0) then { _dbSale = parseNumber _dbSale; };};   // never via format: six sig figs
// the only legit reason to pay under the listing is the HOMESTEADER -20% (fn_buyHouse); a lower claim would short the seller
if (_dbOwner isEqualTo "" || {_dbOwner isEqualTo "0"} || {_dbOwner isEqualTo _uid} || {_dbSale <= 0} || {_price < ((_dbSale * 0.8) - 1)}) exitWith {
    diag_log format ["[LooneyBin][transferHouse] BLOCKED illegit transfer: oid=%1 dbOwner=%2 sale=%3 buyer=%4 -- refunded", _id, _dbOwner, _dbSale, _uid];
    ["-HOUSETHEFT-", _uid, format ["BLOCKED transfer of house oid=%1 (owner %2, sale %3) -- not a legit listed resale; refunded", _id, _dbOwner, _dbSale]] call APS_fnc_logIt;
    [3, _house, _uid, _price, -1] remoteExec ["AP_fnc_handleHouse", owner _buyer];};
_price = _price min _dbSale;   // the seller is credited this: never more than they listed for

// PERSIST FIX (owner 2026-06-13): the houses row key is `oid` (varchar position-hash = AP_houseID), NOT the
// auto-increment int `id`. The old `WHERE id='<oid-hash>'` never matched -> the ownership transfer NEVER
// persisted (the shed reverted to the seller on reboot). Match on oid.
// owner 2026-07-10: a resale to a NEW owner drops the previous owner's custom name (custom_name=NULL).
// owner 2026-07-11 (Malden Makeover): a resale also ends the makeover -- malden=0 + restore the original look.
// revert DELETES the shell _house points at and returns the restored original; the retag below must run on THAT.
if (_house getVariable ["AP_malden", false]) then {localNamespace setVariable ["APS_maldenRevertOk", _house];   // one-shot token (fn_maldenSRV revert)
    private _restored = ["revert", _house, _id] call APS_fnc_maldenSRV;
    if (!isNull _restored) then { _house = _restored; };};
["UPDATE houses SET owners = %s, sale = 0, keyholders = NULL, custom_name = NULL, malden = 0 WHERE oid = %s AND owners = %s", 1, false, [_uid, _id, _dbOwner]] call DB_fnc_asyncQuery;
// owner 2026-09-26 SECURITY (houses review): a resold gang HQ stops being that gang's HQ, as on a sale (fn_srvSellHouse).
// Gang storage access is derived from gangs.house_pos (APS_fnc_houseRights), so a stale one kept the SELLER's gang in
// the buyer's house.
if (_gangid > 0) then {["UPDATE gangs SET house_pos = NULL WHERE id = %s", 1, false, [_gangid]] call DB_fnc_asyncQuery;
    _house setVariable ["AP_house_gang", -1, true];};

// keep the server-side ownership cache in sync (cleanup + later sell/delete + ownership scans read it)
if (!isNil "AP_house_owners") then {
    private _oi = AP_house_owners findIf { (format ["%1", _x select 0]) isEqualTo (format ["%1", _id]) };
    if (_oi > -1) then { (AP_house_owners select _oi) set [1, _uid]; };};

// retag the building globally BEFORE the client finalizes read it
_house setVariable ["AP_homeOwner", _uid, true];
_house setVariable ["AP_houseName", "", true];   // owner 2026-07-10: new owner starts with the type name, not the seller's custom name
_house setVariable ["salePrice", 0, true];
// owner 2026-06-13: CLEAR the market listing on purchase. fn_buyHouse gates a "for sale" buy on
// AP_house_price > 0 -- transferHouse cleared salePrice/DB sale but NOT AP_house_price, so the house
// stayed buyable at the listed price to everyone else after it sold. Reset it + drop it from the phone-market
// list so the listing dies the instant it's bought (no manual unlist needed).
_house setVariable ["AP_house_price", -1, true];
if (!isNil "AP_forSaleHouses") then { AP_forSaleHouses = AP_forSaleHouses - [_house]; publicVariable "AP_forSaleHouses"; };

// SELLER finalize: handleHouse mode 4 removes the house from THEIR client AP_houses/AP_vehicles + deletes
// their marker AND credits them (_marketPrice). Offline -> credit the DB directly. Pay ONCE: the old code
// double-paid (uC AND the DB UPDATE). mode-4 was never even called before this fix -> seller kept phantom ownership.
if (_seller isNotEqualTo "" && {_price > 0}) then {
    private _sellerObj = allPlayers param [allPlayers findIf { (getPlayerUID _x) isEqualTo _seller }, objNull];
    if (!isNull _sellerObj) then {[4, _house, _seller, _price, _gangid] remoteExec ["AP_fnc_handleHouse", owner _sellerObj];} else {
        ["UPDATE players SET bankacc = bankacc + %s WHERE playerid = %s", 1, false, [_price, _seller]] call DB_fnc_asyncQuery;};};

// BUYER finalize: handleHouse mode 5 registers the house in the buyer's AP_houses + AP_vehicles, draws the
// owned-property marker, adds the keychain, and (at its top) clears AP_houseTxn/AP_action_in_use. WITHOUT
// this the buyer could open the menu (AP_homeOwner is global) but had NO AP_houses entry -> couldn't place
// objects / open the vehicle garage / see it as owned, and the buy lock stayed stuck. This was the reported bug.
[5, _house, _uid, _price, -1] remoteExec ["AP_fnc_handleHouse", owner _buyer];

["-HOUSEBUY-", _buyer, format ["bought house %1 for $%2 from %3", _id, _price, _seller]] call APS_fnc_logIt;
