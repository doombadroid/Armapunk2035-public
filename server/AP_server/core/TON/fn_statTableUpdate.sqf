/*
    APS_fnc_statTableUpdate  (LooneyBin -- implemented 2026-06-09; was a passthrough into the buffered
    2017 player-save with wrong args -> EVERY lifetime stat increment was silently lost.)
    Client (fn_ClupdateRequest stats flush) sends [uid, [[statIndex, delta], ...]].
    Stats live as a JSON-ish number array in players_global.lifetime_stats (the 148-slot APV_statTotals).
    Read-modify-write with the increments; grow the array if the index is past the stored length.
    owner 2026-06-21 (#462): MOVED off the shared `stats` column to its OWN `lifetime_stats` column. `stats`
    was shared with the 17-slot A_stats achievement array (fn_updatePartial mode 9 / fn_queryRequest load);
    the two clobbered each other -> A_stats[4] read this array's `prisontime` as `civArrests` -> false
    Bounty Hunter grants. The split + a one-time migration (move >17 `stats` arrays here) de-clobbers them.
*/
params [["_uid", "", [""]], ["_updates", [], [[]]]];

// owner 2026-06-23 SECURITY (security.md §2.1/2.3 — cross-account stat pump + SQLi): the client _uid was used
// raw to read+write lifetime_stats, so a scripter could pump ANY account's stats (title/BH fuel) and inject
// SQL. Force the actor to the NON-SPOOFABLE caller's OWN account (fn_ClupdateRequest always passes the local
// player's uid). Server-internal (_src==0) keeps the passed _uid. (Deltas already clamped idx<500, max 0.)
private _src = remoteExecutedOwner;
if (_src != 0) then { _uid = getPlayerUID ((allPlayers select { owner _x isEqualTo _src }) param [0, objNull]); };
if (_uid isEqualTo "" || {_updates isEqualTo []}) exitWith {};
private _san = { (format ["%1", _this]) splitString "\'""" joinString "" };
_uid = _uid call _san;
private _r = [format ["SELECT COALESCE(lifetime_stats, '[]') AS lifetime_stats FROM players_global WHERE playerid='%1'", _uid], 2] call DB_fnc_asyncQuery;
private _stats = [];
if (_r isEqualType []) then {
    // legacy rows store the array QUOTE-wrapped / mres-encoded ('"[0,..]"' or backticked) -> strip the
    // wrappers before parsing (stats are numbers only, so dropping all quotes/backticks is lossless).
    // Without this, parseSimpleArray threw on old accounts and the fallback WIPED their stats.
    private _raw = (format ["%1", _r param [0, "[]"]]) splitString "`'""" joinString "";
    if (_raw isEqualTo "") then { _raw = "[]"; };
    _stats = parseSimpleArray _raw;
    if !(_stats isEqualType []) then { _stats = []; };}; {_x params [["_idx", -1, [0]], ["_delta", 0, [0]]];
    if (_idx >= 0 && {_idx < 500}) then {while {count _stats <= _idx} do { _stats pushBack 0; };
        _stats set [_idx, ((_stats select _idx) + _delta) max 0];};} forEach _updates;
[format ["UPDATE players_global SET lifetime_stats='%2' WHERE playerid='%1'", _uid, str _stats]] call DB_fnc_asyncQuery;
