/*
    APS_fnc_handleLoadouts  (LooneyBin: persist a saved loadout) -- runs on the SERVER.
    Callers: fn_saveLoadout, fn_deleteLoadout. Arg shapes:
        delete  : [1, uid, uniqueID, side]
        new     : [2, uid, uniqueID, side, type, name, loadout, virtualInv, skins]
        update  : [3, uid, uniqueID, side, type, name, loadout, virtualInv, skins]
    Was a logging-only STUB, so loadouts never persisted. The loadouts table keys a player's loadouts by
    (pid, side, slot) where `slot` holds the client's uniqueID; the gear column stores the mres-encoded
    [type, name, loadout, virtualInv, skins] payload (the same codec as house storage). New = INSERT,
    update = atomic UPDATE, delete = DELETE -- never a DELETE+INSERT pair on one row (avoids the extDB3
    multi-thread reorder hazard). APS_fnc_fetchLoadouts reads these rows back into AP_loadoutHolder.
*/
params [["_mode", 0, [0]], ["_uid", "", [""]], ["_uniqueID", 0, [0, ""]], ["_side", civilian, [civilian]],
        ["_type", "", [""]], ["_name", "", [""]], ["_loadout", [], [[]]], ["_virtualInv", [], [[]]], ["_skins", [-1, -1], [[]]]];
// owner 2026-06-23 SECURITY (security.md §2.3 — cross-account write + SQLi): the client _uid was used raw in
// every loadout query, and _uniqueID (slot, interpolated UNQUOTED) could arrive as a string -> injection.
// Force the actor to the NON-SPOOFABLE caller's OWN account (fn_saveLoadout/fn_deleteLoadout always pass the
// local player's uid) and coerce the slot to a number. Server-internal (_src==0) keeps the passed _uid.
private _src = remoteExecutedOwner;
if (_src != 0) then { _uid = getPlayerUID ((allPlayers select { owner _x isEqualTo _src }) param [0, objNull]); };
if (_uid isEqualTo "" || _mode <= 0) exitWith {};
private _san = { (format ["%1", _this]) splitString "\'""" joinString "" };
_uid = _uid call _san;
_uniqueID = round (parseNumber format ["%1", _uniqueID]);   // slot is a number (round serverTime) -- force numeric to kill string injection
private _sideStr  = str _side;
private _safeName = (_name splitString "'") joinString "''";   // names are alnum+space client-side; escape defensively

switch (_mode) do {case 1: {   // delete
        [format ["DELETE FROM loadouts WHERE pid='%1' AND side='%2' AND slot=%3", _uid, _sideStr, _uniqueID]] call DB_fnc_asyncQuery;};
    case 2: {   // new loadout -> insert
        private _gear = (([[_type, _name, _loadout, _virtualInv, _skins]] call DB_fnc_mresArray) splitString "'") joinString "''";
        [format ["INSERT INTO loadouts (pid, side, slot, name, gear, currency) VALUES ('%1','%2',%3,'%4','%5','cash')", _uid, _sideStr, _uniqueID, _safeName, _gear]] call DB_fnc_asyncQuery;
    };
    case 3: {   // overwrite existing -> atomic update
        private _gear = (([[_type, _name, _loadout, _virtualInv, _skins]] call DB_fnc_mresArray) splitString "'") joinString "''";
        [format ["UPDATE loadouts SET name='%1', gear='%2' WHERE pid='%3' AND side='%4' AND slot=%5", _safeName, _gear, _uid, _sideStr, _uniqueID]] call DB_fnc_asyncQuery;
    };};
