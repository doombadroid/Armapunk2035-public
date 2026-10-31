/*
    File: fn_mapEditPoll.sqf  (APS_fnc_mapEditPoll)
    Notice map edits this server did not make, and broadcast what changed.

    The primary authoring path is 3DEN -> tools/map_push.py -> Postgres, which never
    touches the game. Without this loop those edits sit in the database until the next
    mission restart -- which is exactly the 90-second repack cycle this feature exists
    to remove.

    Polls ONE INTEGER. map_meta.rev is bumped by a database TRIGGER on every write to
    map_objects, so no writer can forget to signal and no writer needs to know this loop
    exists. On a change it reads only rows with rev > APS_mapRev (the cache's high-water
    mark, kept by APS_fnc_mapRowUpdate) and pushes each through that one mutator, which
    re-indexes the cell, drops the stale blobs and broadcasts. mapdb.md D4.
    APS_mapRev and the column list live in localNamespace (APS_fnc_mapLoad); the last rev
    this loop saw is its own local. A client's publicVariableServer can reach none of them.

    Server-only. No CfgRE entry: nothing may call this remotely.
*/
if (!isServer) exitWith {};

[localNamespace getVariable "APS_mapRev"] spawn {   // the boot load (APS_fnc_mapLoad) already holds this rev
    params ["_pollRev"];
    private _world = worldName;
    while {true} do {
        uiSleep 10;

        private _row = ["SELECT rev FROM map_meta WHERE world = %s", 2, false, [_world]] call DB_fnc_asyncQuery;
        private _rev = parseNumber format ["%1", _row param [0, -1]];

        if (_rev >= 0 && {!(_rev isEqualTo _pollRev)}) then {
            // Only rows newer than what the cache holds -- deleted ones included, they become
            // "del" ops. An in-game edit already bumped APS_mapRev, so it does not come back.
            private _fresh = ["SELECT " + (localNamespace getVariable "APS_mapSelectCols") + " FROM map_objects WHERE world = %s AND rev > %s ORDER BY rev", 2, true, [_world, localNamespace getVariable "APS_mapRev"]] call DB_fnc_asyncQuery;
            private _sent = 0;
            {
                private _t = [_x] call APS_fnc_mapRowOp;
                if (_t isNotEqualTo []) then { [_t, true] call APS_fnc_mapRowUpdate; _sent = _sent + 1; uiSleep 0.01; };
            } forEach _fresh;
            _pollRev = _rev;
            diag_log format ["[AP-MAP] rev=%1 applied: %2 row(s)", _rev, _sent];
        };
    };
};
