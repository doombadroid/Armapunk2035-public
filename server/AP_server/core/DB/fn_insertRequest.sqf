/*
    DB_fnc_insertRequest  (LooneyBin: 2020 new-player create)
    client fn_insertPlayerInfo -> [player, getPlayerUID player, profileName]
    Creates the players_global + players rows (column defaults fill the rest).
    Client then re-runs fn_dataQuery -> DB_fnc_queryRequest to load.
*/
params [["_player",objNull,[objNull]],["_uid","",[""]],["_name","",[""]]];
// A client creates and loads ITSELF only (audit 2026-09-26, r2gangmap): the tail call below re-runs the named
// unit's login onto that unit's machine, and a null unit fell back to a client-typed uid. Same bind as queryRequest.
private _src = remoteExecutedOwner;
if (_src isNotEqualTo 0 && {(owner _player) isNotEqualTo _src}) exitWith {
    ["-SEC-", (allPlayers select { owner _x isEqualTo _src }) param [0, objNull], format ["BLOCKED insertRequest for another unit (uid %1)", _uid]] call APS_fnc_logIt;
};
if (_uid == "" || _name == "") exitWith {};
// owner 2026-07-24 SECURITY (audit): _uid arrives as a CLIENT argument and was interpolated raw into the
// bans SELECT and both INSERTs below (only _name was sanitized, at the splitString further down), so a
// crafted uid could break out of the string literal -- and could also create/overwrite rows under someone
// else's playerid. Derive it from the engine whenever we have the unit (getPlayerUID cannot be spoofed);
// fall back to the sanitized client value only if the object is null. Same strip idiom as _name.
if (!isNull _player) then { _uid = getPlayerUID _player; };
_uid = (_uid splitString "\'""") joinString "";
if (_uid isEqualTo "") exitWith {};
// LooneyBin: loonybot ban gate. DB_fnc_asyncQuery returns [] on ANY error, so a DB hiccup can never
// wrongly block a normal load. A live (non-expired) bans row -> kick on connect + skip the load.
private _banRow = [format ["SELECT id FROM bans WHERE playerid='%1' AND (until IS NULL OR until > NOW()) LIMIT 1", _uid], 2] call DB_fnc_asyncQuery;
if (_banRow isEqualType [] && {(count _banRow) > 0} && {!isNull _player}) exitWith {
    diag_log format ["[LooneyBin] banned player blocked on connect: %1", _uid];
    [["You are banned from this server."], "AP_fnc_botKick", _player, false, false] spawn AP_fnc_MP;};
// LooneyBin: KRON_Replace is a MISSION-only global (fn_KRON_Strings.sqf), UNDEFINED on the
// dedicated server. Sanitize the name natively. NB: SQF has NO string-minus operator
// (STRING - STRING throws "Type String, expected Number"), so strip via splitString/joinString:
// split on the unsafe chars (each becomes a delimiter, dropped) then rejoin.
_name = (_name splitString "\'""") joinString "";

// mode 2 = block until each write COMMITS. The inserts are otherwise fire-and-forget on an extDB3 worker
// thread, so the queryRequest below could read before the rows exist -> empty -> client stuck loading.
[format ["INSERT INTO players_global (playerid) VALUES ('%1') ON CONFLICT DO NOTHING", _uid], 2] call DB_fnc_asyncQuery;
[format ["INSERT INTO players (playerid, name, instance, new_player) VALUES ('%1', '%2', '%3', '1') ON CONFLICT DO NOTHING", _uid, _name, (localNamespace getVariable "APS_serverInstance")], 2] call DB_fnc_asyncQuery;

// CRITICAL: the client's fn_insertPlayerInfo only FIRES this request and never re-queries, so the server
// must load the freshly-created player and push the data back via fn_requestReceived -- otherwise the new
// player hangs on the loading screen forever (a soft-relog "fixed" it because the 2nd connect found the
// rows already inserted). New players spawn civilian, which is fn_queryRequest's default side.
if (!isNull _player) then { [_player] call DB_fnc_queryRequest; };
