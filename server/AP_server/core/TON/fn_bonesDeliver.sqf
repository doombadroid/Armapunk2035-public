/*
    APS_fnc_bonesDeliver  (LooneyBin, owner 2026-07-15) -- deliver bones.py replies back in-game.
    Server-only, called on an 8s loop (init.sqf). Pulls answered-but-undelivered DMs; if the recipient is
    online, pushes the reply as an incoming "Ben Bones Official" text (AP_fnc_bonesText) + marks it delivered.
    QUOTE(uid): a bare 17-digit Steam64 compiles to a NUMBER and loses precision -> the player match would miss.
*/
if (!isServer) exitWith {};
private _rows = ["SELECT id, uid, reply FROM bones_dm WHERE reply IS NOT NULL AND delivered = 0 AND ts > (NOW() - interval '1 hour') ORDER BY id ASC LIMIT 10", 2, true] call DB_fnc_asyncQuery;
if (isNil "_rows" || {!(_rows isEqualType [])}) exitWith {};
if (_rows isEqualTo []) exitWith {};
diag_log format ["[LooneyBin][bonesDeliver] %1 pending reply(ies)", count _rows]; {_x params [["_id", 0], ["_uid", ""], ["_reply", ""]];
    _uid = format ["%1", _uid];
    _reply = format ["%1", _reply];
    private _p = (allPlayers select { (getPlayerUID _x) isEqualTo _uid }) param [0, objNull];
    if (!isNull _p) then {[[_reply], "AP_fnc_bonesText", _p, false, false] spawn AP_fnc_MP;
        [format ["UPDATE bones_dm SET delivered = 1 WHERE id = %1", _id]] call DB_fnc_asyncQuery;
        diag_log format ["[LooneyBin][bonesDeliver] delivered #%1 to %2", _id, _uid];};} forEach _rows;
["UPDATE bones_dm SET delivered = 1 WHERE reply IS NOT NULL AND delivered = 0 AND ts <= (NOW() - interval '1 hour')"] call DB_fnc_asyncQuery;
