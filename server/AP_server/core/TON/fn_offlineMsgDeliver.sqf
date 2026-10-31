/*
    APS_fnc_offlineMsgDeliver  (Armapunk 2035, owner 2026-08-11) -- hand queued texts to players
    who have come back. Server-only, called on a loop from init.sqf, same as APS_fnc_bonesDeliver.

    A LOOP RATHER THAN A LOGIN HOOK on purpose: the session path is long and already carries the
    money and gear restore, and a message feature has no business anywhere near it. Polling for
    "is this recipient in allPlayers yet" catches the login for free, a few seconds later, and
    cannot break anything if it fails.

    QUOTE() on both uid columns: a bare 17-digit Steam64 compiles to a NUMBER and loses precision,
    so the player match silently misses. Same trap as fn_bonesDeliver's comment.
*/
if (!isServer) exitWith {};

// from_uid travels with the message on purpose: the recipient's thread store is keyed by
// display name, so without the sender's uid arriving here there is nothing to reply WITH --
// the client cannot resolve an absent player to a uid on its own.
private _rows = ["SELECT id, to_uid, from_uid, from_name, message FROM offline_msgs WHERE delivered = false ORDER BY id ASC LIMIT 30", 2, true] call DB_fnc_asyncQuery;
if (isNil "_rows" || {!(_rows isEqualType [])}) exitWith {};
if (_rows isEqualTo []) exitWith {};

// Group by recipient so a player who was away for a while gets ONE notification instead of a
// stack of message boxes -- the client renders the count, not one popup per text.
private _byPlayer = createHashMap;
private _ids = createHashMap;
{
    _x params [["_id", 0], ["_to", ""], ["_fromUid", ""], ["_from", ""], ["_txt", ""]];
    _to      = format ["%1", _to];
    _fromUid = format ["%1", _fromUid];
    _from    = format ["%1", _from];
    _txt     = format ["%1", _txt];
    private _p = (allPlayers select { (getPlayerUID _x) isEqualTo _to }) param [0, objNull];
    if (!isNull _p) then {
        private _bucket = _byPlayer getOrDefault [_to, []];
        _bucket pushBack [_from, _txt, _fromUid];
        _byPlayer set [_to, _bucket];
        private _idList = _ids getOrDefault [_to, []];
        _idList pushBack _id;
        _ids set [_to, _idList];
    };
} forEach _rows;

if (count _byPlayer isEqualTo 0) exitWith {};

{
    private _uid = _x;
    private _msgs = _byPlayer get _uid;
    private _p = (allPlayers select { (getPlayerUID _x) isEqualTo _uid }) param [0, objNull];
    if (!isNull _p) then {
        [[_msgs], "AP_fnc_offlineMsgRecv", _p, false, false] spawn AP_fnc_MP;
        // Marked delivered on send rather than on acknowledgement. A dropped packet loses a
        // text; keeping them undelivered would re-send the whole backlog on every tick, which
        // is the worse failure.
        [format ["UPDATE offline_msgs SET delivered = true WHERE id IN (%1)", (_ids get _uid) joinString ","]] call DB_fnc_asyncQuery;
        diag_log format ["[Armapunk][offlineMsg] delivered %1 message(s) to %2", count _msgs, _uid];
    };
} forEach (keys _byPlayer);

// Housekeeping: anything already handed over and older than a week is gone for good.
["DELETE FROM offline_msgs WHERE delivered = true AND ts <= (NOW() - interval '7 day')"] call DB_fnc_asyncQuery;
