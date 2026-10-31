/*
    APS_fnc_garageCount  (LooneyBin: 2020 garage-count adapter)
    2020 client args : [getPlayerUID player, playerSide, player]   (fn_vehicleShopMenu / fn_factory)
    Counts the player's owned vehicles (any type, alive) on that side and pushes the total to
    the client as AP_garageCount — gates the AP_maxGarageVeh purchase check. Without this the
    client sits at AP_garageCount = -1 -> "Failed to fetch garage count from server."
    Replaces the old passthrough stub to APS_fnc_getVehicles (arg-mismatched, set AP_veh_count).
*/
params [["_uid","",[""]], ["_side",sideUnknown,[west]], ["_unit",objNull,[objNull]]];
// owner 2026-06-23 SECURITY (security.md §2.3 — cross-account read + SQLi): the client _uid was interpolated
// RAW into the SELECT (UNION-exfil / injection) and the count is the player's OWN garage. Force the actor to
// the NON-SPOOFABLE caller's OWN account (fn_vehicleShopMenu/fn_factory pass getPlayerUID player) and reply to
// the real caller. Server-internal (_src==0) keeps the passed _uid/_unit.
private _src = remoteExecutedOwner;
if (_src != 0) then {private _rc = (allPlayers select { owner _x isEqualTo _src }) param [0, objNull];
    _unit = _rc;
    _uid  = getPlayerUID _rc;};
if (_uid == "" || isNull _unit) exitWith {};
_uid = (format ["%1", _uid]) splitString "\'""" joinString "";

// Same roster routing as APS_fnc_getVehicles, and needed here for a second reason: this `_side` is not even
// the engine's, it is the CLIENT's own playerSide, sent in the packet (fn_vehicleShopMenu / fn_factory), so it
// was always the caller's to choose. The purchase cap it feeds is per-side, so picking the side picks which
// cap you are counted against. The uid was hardened to the non-spoofable caller in 2026-06-23; this is the
// same treatment for the other half of the WHERE clause. Unrostered / flag-false: unchanged.
private _sideStr = switch (_side) do {case west: {"cop"};
    case civilian: {"civ"};
    case independent: {"med"};
    default {"civ"};};
// Ack flag required -- see the note in APS_fnc_getVehicles / DB_fnc_updatePartial.
private _dutyRow = _uid call APS_fnc_dutyLookup;
if ((localNamespace getVariable ["AP_dutyEnabled", false]) && {_dutyRow param [3, false]}) then {
    switch (_dutyRow param [0, ""]) do {
        case "maxsec": { _sideStr = "cop"; };
        case "trauma": { _sideStr = "med"; };
    };
};

// Count every alive vehicle the player owns on this side (active-out + stored) toward the cap.
private _q = format ["SELECT id FROM %1 WHERE pid='%2' AND side='%3' AND alive='1'", "vehicles", _uid, _sideStr];
private _rows = [_q, 2, true] call DB_fnc_asyncQuery;
private _n = if (isNil "_rows" || {!(_rows isEqualType [])}) then { 0 } else { count _rows };

AP_garageCount = _n;
(owner _unit) publicVariableClient "AP_garageCount";
