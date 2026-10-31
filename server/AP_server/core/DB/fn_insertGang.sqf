/*
    APS_fnc_insertGang  (LooneyBin: 2020 name-based gang creation)
    2020 client args : [player, gangName]   (fn_createGang)
    Creates a name-based gang (the 2017 file was house/building-based + used KRON_Replace, a MISSION-only
    fn undefined on the server -> insertGang threw -> gang never created). Now: unique-name check -> gen a
    gang id -> INSERT gangs row -> set creator's gang0/gangrank0 (+ deduct the $25k fee from the bank) ->
    push to the client via AP_fnc_gangCreated (sets AP_gang_data + deducts AP_atmcash for display).
*/
if ("AP_server_training" call DB_fnc_flag) exitWith {};
params [["_player", objNull, [objNull]], ["_name", "", [""]]];
if (isNull _player || _name == "") exitWith {};
private _uid = getPlayerUID _player;
if (_uid == "") exitWith {};

// KRON_Replace is mission-only; SQF has no string-minus operator. Strip unsafe chars (\ ' ") by
// splitting on each (they become dropped delimiters) then rejoining.
private _safeName = (_name splitString "\'""") joinString "";
if (_safeName == "") exitWith {};

// name already taken?
private _row = [format ["SELECT id FROM gangs WHERE name='%1' AND instance='%2'", _safeName, (localNamespace getVariable "APS_serverInstance")], 2] call DB_fnc_asyncQuery;
if (!isNil "_row" && {!(_row isEqualTo [])}) exitWith {
    [[1, "There is already an existing gang using the name which you provided."], "AP_fnc_broadcast", _player, false] spawn AP_fnc_MP;
};

// next free gang id (numeric col -> compiles clean, no QUOTE needed)
private _idRow = [format ["SELECT COALESCE(MAX(id),0)+1 AS id FROM gangs"], 2] call DB_fnc_asyncQuery;
private _gangId = if (isNil "_idRow" || {_idRow isEqualTo []}) then { 1 } else { parseNumber (format ["%1", _idRow select 0]) };
if (_gangId < 1) then { _gangId = 1; };

[format ["INSERT INTO gangs (id, name, inviterank, kickrank, bank, experience, instance) VALUES ('%1','%2','2','2','0','0','%3')", _gangId, _safeName, (localNamespace getVariable "APS_serverInstance")]] call DB_fnc_asyncQuery;
[format ["UPDATE players SET gang0='%1', gangrank0='1', bankacc=GREATEST(bankacc-25000,0) WHERE playerid='%2'", _gangId, _uid]] call DB_fnc_asyncQuery;
(localNamespace getVariable "APS_gangOfUid") set [_uid, _gangId];   // the server's uid -> gang map (vars.sqf) follows gang0, not the next login

[[group _player, _safeName, _gangId], "AP_fnc_gangCreated", _player, false] spawn AP_fnc_MP;
