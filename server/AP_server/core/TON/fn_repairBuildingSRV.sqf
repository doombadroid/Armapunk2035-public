/*
    APS_fnc_repairBuildingSRV  (LooneyBin) -- finish a Trauma Team house repair. Runs on the SERVER.
    2020 client args: [_owner, _building, _ruins]

    Was a no-op stub: the Trauma Team repair announced "fee taken" + paid the medic + the owner-side
    payForRequest stripped the house from AP_houses/AP_vehicles, but the building was NEVER
    un-ruined -> "doesn't actually fix the house". No DB write is needed: a destroyed house keeps its
    DB row (only selling deletes it) so it auto-repairs on the next restart anyway -- this just does it
    live: setDamage 0 to un-ruin the terrain building (global), re-stamp the ownership vars, then tell
    the owner to re-register it (civRepairBuilding 'houseRepaired' re-adds to AP_houses/AP_vehicles
    + CLinitHouses + restores the marker & inventory).
*/
params [["_owner", objNull, [objNull]], ["_building", objNull, [objNull]], ["_ruins", objNull, [objNull]]];
if (isNull _owner || isNull _building) exitWith {};

private _pos    = getPosATL _building;
private _type   = typeOf _building;
private _oid    = _building getVariable ["AP_houseID", -1];
private _uid    = _building getVariable ["AP_homeOwner", getPlayerUID _owner];
private _gangID = _building getVariable ["AP_house_gang", -1];

// un-ruin the terrain building (global). repair the ruins handle too if it's separate.
_building setDamage 0;
if (!isNull _ruins && {_ruins != _building}) then { _ruins setDamage 0; };

// the repaired house is normally the same handle; if setDamage 0 didn't take (engine swapped the
// object for a fresh one), re-fetch the house at the spot and repair that.
private _newHouse = _building;
if (isNull _building || {(damage _building) isEqualTo 1}) then {
    private _re = (nearestTerrainObjects [_pos, ["House"], 8, true, true]) param [0, objNull];
    if (isNull _re) then { _re = (nearestObjects [_pos, ["House"], 8]) param [0, _building]; };
    if (!isNull _re) then { _newHouse = _re; _newHouse setDamage 0; };};

// re-stamp ownership so it counts as a registered house again
_newHouse setVariable ["AP_houseID", _oid, true];
_newHouse setVariable ["AP_buildID", _oid, true];
_newHouse setVariable ["houseId", _oid, true];
_newHouse setVariable ["AP_homeOwner", _uid, true];
_newHouse setVariable ["AP_repairRequested", false, true];
if (_gangID != -1) then { _newHouse setVariable ["AP_house_gang", _gangID, true]; };

// owner 2026-07-17: GREENHOUSE-ON-REBUILD FIX. The identity re-stamp above dropped the rest of the house's
// state -- AP_greenhouse_unaged, storage caps (AP_vcap/phys_cap/keycap), keyholders, barrel/lead-container
// flags, lock, and custom name. Every greenhouse action (and the server plant/harvest authority) gates on
// AP_greenhouse_unaged, so a rebuilt shed's greenhouse (and barrel/caps/shared-keys/name) went DEAD until the
// next restart re-tagged from the DB. Re-run THE house tagger now: it re-reads every house's full state from
// the DB and re-stamps it PUBLIC onto the resolved building -- greenhouse included. Idempotent (this is the same
// pass init.sqf runs every 300s and that malden/replace_sheds call). The DB row survives a destroy (only selling
// deletes it), so the correct values are still there to restore.
call APS_fnc_tagHousesSRV;

// tell the owner to re-register the (now repaired) house client-side (whitelisted server->client cb)
private _case = if (_gangID != -1) then { "gangHouseRepaired" } else { "houseRepaired" };
[_case, [_newHouse, _building]] remoteExec ["AP_fnc_civRepairBuilding", owner _owner];

diag_log format ["[LooneyBin][repairBuildingSRV] repaired oid=%1 uid=%2 type=%3 pos=%4", _oid, _uid, _type, _pos];
