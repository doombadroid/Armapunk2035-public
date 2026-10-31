/*
    APS_fnc_srvPersistentBounties  (LooneyBin)
    client args: [uid]   (from fn_fetchPersistentBounties)
    Reply with this player's standing bounties on the client (AP_persistentBounties).
*/
params [["_uid","",[""]]];
private _player = objNull;
{ if (getPlayerUID _x isEqualTo _uid) exitWith { _player = _x; }; } forEach allPlayers;
if (isNull _player) exitWith {};
private _r = [format ["SELECT target_uid,target_name,amount FROM bounties WHERE target_uid='%1'", _uid], 2, true] call DB_fnc_asyncQuery;
if (isNil "_r") then { _r = []; };
private _out = _r apply { [_x select 0, _x select 1, parseNumber (_x select 2)] };
[_out, "AP_persistentBounties", owner _player] call AP_fnc_MP;
