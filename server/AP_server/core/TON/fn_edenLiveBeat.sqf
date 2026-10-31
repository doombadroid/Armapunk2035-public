/*
    File: fn_edenLiveBeat.sqf  (APS_fnc_edenLiveBeat)
    Eden Live player ghosts: every 2 s write where every player is into eden_live_players, so the
    Eden Live host (tools/edenlive_bridge.py on the box) can show editors who is where while they
    edit. One upsert per player; a row older than 10 s is dead to the bridge, so nobody is removed
    here. Positions are getPosWorld (model centre), the frame the map table and the editor share.
    Server-only. No CfgRE entry: nothing may call this remotely.
*/
if (!isServer) exitWith {};
[] spawn {
    ["CREATE TABLE IF NOT EXISTS eden_live_players (uid text PRIMARY KEY, name text NOT NULL DEFAULT '', x double precision NOT NULL, y double precision NOT NULL, z double precision NOT NULL, dir double precision NOT NULL DEFAULT 0, at timestamptz NOT NULL DEFAULT now())", 1] call DB_fnc_asyncQuery;
    while {true} do {
        uiSleep 2;
        {
            if (isPlayer _x && {alive _x}) then {
                private _w = getPosWorld _x;
                ["INSERT INTO eden_live_players (uid, name, x, y, z, dir, at) VALUES (%s, %s, %s, %s, %s, %s, now()) ON CONFLICT (uid) DO UPDATE SET name = EXCLUDED.name, x = EXCLUDED.x, y = EXCLUDED.y, z = EXCLUDED.z, dir = EXCLUDED.dir, at = now()",
                 1, false, [getPlayerUID _x, name _x, _w select 0, _w select 1, _w select 2, getDir _x]] call DB_fnc_asyncQuery;
            };
        } forEach allPlayers;
    };
};
