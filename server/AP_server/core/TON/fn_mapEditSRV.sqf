/*
    File: fn_mapEditSRV.sqf  (APS_fnc_mapEditSRV)
    The authority for every in-game live map edit. Validate, persist, broadcast.

    NOT the primary authoring path. 3DEN -> tools/map_push.py writes these tables
    directly and never enters the game; this exists for the one thing Eden is bad
    at (pruning a prop you are standing in front of) and as the door a future Zeus
    surface would come through.

    THE CALLER IS remoteExecutedOwner, NEVER THE PAYLOAD (standing rule). This repo
    has been bitten by the other shape twice -- fn_adminKickBan.sqf and
    fn_adminPlayerQuerySRV.sqf both fed a client-passed unit OBJECT into the
    adminlevel lookup, so any player could pass a real admin's object and inherit
    their level. Do not reintroduce it.

    THE CLIENT CANNOT SET `init`. That column is compiled and spawned on every
    client by AP_fnc_createVehicleLocal, so a client-writable init is client-side
    RCE against everyone on the server. Rows created here get "". map_push.py
    writing that column is a different matter -- it is a trusted tool on the box,
    at the same trust level as hand-editing fn_mapData.sqf. The two paths are not
    equivalent and must not be validated as if they were.

    THE CLASS ALLOWLIST is what stops this being a vehicle and crate spawner for
    anyone who gets a level-5 session. Inert world geometry only.

    params: 0 = op string ("add" | "move" | "del"), 1 = payload
*/
params [["_op", "", [""]], ["_payload", [], [[]]]];
if (!isServer) exitWith {};

private _src = remoteExecutedOwner;
// 0 = not remote-executed, OR sent by a headless client (engine returns 0 for those by
// design). Either way there is no trustworthy caller, so nothing happens -- and it is
// logged, because a silent refusal cost a debugging round once already.
if (_src isEqualTo 0) exitWith { diag_log format ["[AP-MAPEDIT] mapEditSRV %1: no remoteExecutedOwner (headless client?) -- refused", _op]; };
private _caller = (allPlayers select { owner _x isEqualTo _src }) param [0, objNull];
if (isNull _caller) exitWith {};
private _uid = getPlayerUID _caller;
if (_uid isEqualTo "") exitWith {};

// --- rank gate: re-read every call. A cached level survives a demotion. -----
private _lvlRow = [format ["SELECT adminlevel FROM players_global WHERE playerid='%1'", _uid], 2] call DB_fnc_asyncQuery;
private _lvl = parseNumber format ["%1", _lvlRow param [0, 0]];
if (_lvl < 5) exitWith {
    diag_log format ["[AP-MAPEDIT] REFUSED %1 from uid %2 (level %3)", _op, _uid, _lvl];
    [["-SEC-", _caller, name _caller, format ["BLOCKED mapEditSRV: level %1 tried op %2", _lvl, _op]], "APS_fnc_logIt", 2] spawn AP_fnc_MP;
};

// --- rate limit: a stuck client or a hijacked staff session should not be able
// --- to write ten thousand rows before anyone notices.
private _bucketVar = format ["APS_mapEditBucket_%1", _uid];
private _bucket = missionNamespace getVariable [_bucketVar, [0, 0]];
_bucket params ["_windowStart", "_count"];
if ((diag_tickTime - _windowStart) > 60) then { _windowStart = diag_tickTime; _count = 0; };
if (_count >= 60) exitWith { diag_log format ["[AP-MAPEDIT] RATE LIMIT uid %1", _uid]; };
missionNamespace setVariable [_bucketVar, [_windowStart, _count + 1]];

private _world = worldName;

switch (toLower _op) do {

    case "add": {
        _payload params [["_class", "", [""]], ["_pos", [], [[]]], ["_vdirup", [], [[]]]];
        if (_class isEqualTo "" || {count _pos < 3} || {count _vdirup < 2}) exitWith {};
        if !([_class] call AP_fnc_mapPlaceable) exitWith {
            diag_log format ["[AP-MAPEDIT] class refused by allowlist: %1 (uid %2)", _class, _uid];
            [["-SEC-", _caller, name _caller, format ["BLOCKED mapEditSRV: class %1 outside the inert-geometry allowlist", _class]], "APS_fnc_logIt", 2] spawn AP_fnc_MP;
        };
        _vdirup params ["_vdir", "_vup"];
        // init is NOT a column here. It is compiled and spawned on every client; a client
        // that could set it would have code execution on every connected machine.
        [
            "INSERT INTO map_objects (world, classname, x, y, z, vdir_x, vdir_y, vdir_z, vup_x, vup_y, vup_z, author_uid) VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s)",
            1, false,
            [_world, _class, _pos select 0, _pos select 1, _pos select 2,
             _vdir select 0, _vdir select 1, _vdir select 2, _vup select 0, _vup select 1, _vup select 2, _uid]
        ] call DB_fnc_asyncQuery;
        private _idRow = ["SELECT id FROM map_objects WHERE world = %s AND author_uid = %s ORDER BY id DESC LIMIT 1", 2, false, [_world, _uid]] call DB_fnc_asyncQuery;
        private _id = parseNumber format ["%1", _idRow param [0, -1]];
        if (_id < 1) exitWith { diag_log format ["[AP-MAPEDIT] INSERT did not land for uid %1 class %2", _uid, _class]; };
        [_id] call APS_fnc_mapEditEmit;
        [_uid, "add", _class, format ["%1 id=%2", _pos, _id]] spawn APS_fnc_mapEditAudit;
    };

    case "move": {
        _payload params [["_id", -1, [0]], ["_pos", [], [[]]], ["_vdirup", [], [[]]]];
        if (_id < 1 || {count _pos < 3} || {count _vdirup < 2}) exitWith {};
        _vdirup params ["_vdir", "_vup"];
        // Transform columns only. init, loadout, layer are untouched -- a moved NPC anchor
        // keeps its behaviour. Server rows and deleted rows are excluded by the WHERE.
        [
            "UPDATE map_objects SET x=%s, y=%s, z=%s, vdir_x=%s, vdir_y=%s, vdir_z=%s, vup_x=%s, vup_y=%s, vup_z=%s, author_uid=%s WHERE id=%s AND world=%s AND deleted=false AND is_server=false",
            1, false,
            [_pos select 0, _pos select 1, _pos select 2, _vdir select 0, _vdir select 1, _vdir select 2,
             _vup select 0, _vup select 1, _vup select 2, _uid, _id, _world]
        ] call DB_fnc_asyncQuery;
        [_id] call APS_fnc_mapEditEmit;
        [_uid, "move", str _id, format ["%1", _pos]] spawn APS_fnc_mapEditAudit;
    };

    case "del": {
        _payload params [["_id", -1, [0]]];
        if (_id < 1) exitWith {};
        ["UPDATE map_objects SET deleted=true, author_uid=%s WHERE id=%s AND world=%s AND is_server=false", 1, false, [_uid, _id, _world]] call DB_fnc_asyncQuery;
        [_id] call APS_fnc_mapEditEmit;
        [_uid, "del", str _id, ""] spawn APS_fnc_mapEditAudit;
    };
};
