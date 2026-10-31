/*
    APS_fnc_medSupplyPay  (LooneyBin) — runs on the SERVER.
    A buyer bought from a medic's med-supply (IDAP supply crate OR the revive drone); pay the shop owner.
    Client args: [_buyer, _owner, _price]. The owner is credited to their BANK via AP_fnc_medSupplyEarn on
    their client (server is exempt from CfgRE filtering, so no whitelist entry is required for this push).
*/
params [["_buyer", objNull, [objNull]], ["_owner", objNull, [objNull]], ["_price", 0, [0]]];

// owner 2026-06-23 SECURITY (security.md §2.1 HIGH): CfgRE-whitelisted -> a client could remoteExec
// [anyBuyer, accomplice, 9.9e8] to credit an accomplice's bank an arbitrary sum (the buyer "debit" is
// client-side, never run by a scripter). (1) Derive the BUYER from the non-spoofable remoteExecutedOwner
// (model fn_seizeLock:22) -- the buyer is the one initiating the purchase. (2) CLAMP _price to a sane single-
// sale ceiling so the payout can't be inflated. The payee _owner is a genuinely different player (the shop
// owner) we can't derive server-side -> bounding the amount is the authoritative control; the "is _owner
// really the crate owner" check is NEEDS OWNER REVIEW.
private _src = remoteExecutedOwner;
if (_src isNotEqualTo 0) then { _buyer = (allPlayers select { owner _x isEqualTo _src }) param [0, objNull]; };
if (_src isNotEqualTo 0 && {isNull _buyer}) exitWith { ["-SEC-", objNull, format ["BLOCKED medSupplyPay (no real buyer, src %1)", _src]] call APS_fnc_logIt; };
private _MAX_SALE = 250000;   // generous single med-supply sale ceiling (catalog prices are far below this)
_price = (round _price) min _MAX_SALE;
if (isNull _owner || {_price <= 0} || {!(_owner in allPlayers)} || {_owner isEqualTo _buyer}) exitWith {};
[[_price], "AP_fnc_medSupplyEarn", _owner] spawn AP_fnc_MP;
diag_log format ["[LooneyBin][medSupplyPay] paid %1 ($%2) for a sale to %3", name _owner, _price, name _buyer];
