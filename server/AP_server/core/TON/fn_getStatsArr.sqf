/*
    APS_fnc_getStatsArr  (LooneyBin -- implemented 2026-06-09; the passthrough fed a UID into the 2017
    full-player-load's unit slot -> the titles/stats menu (fn_getMyStats) never got data.)
    Client sends [uid]; expects APV_statTotals back (netSetVar-approved var).
*/
params [["_uid", "", [""]]];
if (_uid isEqualTo "") exitWith {};
private _unit = allPlayers param [allPlayers findIf { (getPlayerUID _x) isEqualTo _uid }, objNull];
if (isNull _unit) exitWith {};
// owner 2026-06-21 (#462): lifetime stats moved to their OWN `lifetime_stats` column (was sharing `stats`
// with the 17-slot A_stats achievement array, which clobbered both). Read the new column.
private _r = [format ["SELECT COALESCE(lifetime_stats,'[]') AS lifetime_stats FROM players_global WHERE playerid='%1'", _uid], 2] call DB_fnc_asyncQuery;
private _stats = [];
if (_r isEqualType []) then {
    // legacy rows store the array QUOTE-wrapped / mres-encoded ('"[0,..]"' or backticked) -> strip the
    // wrappers before parsing (stats are numbers only, so dropping all quotes/backticks is lossless).
    // Without this, parseSimpleArray threw on old accounts and the fallback WIPED their stats.
    private _raw = (format ["%1", _r param [0, "[]"]]) splitString "`'""" joinString "";
    if (_raw isEqualTo "") then { _raw = "[]"; };
    _stats = parseSimpleArray _raw;
    if !(_stats isEqualType []) then { _stats = []; };};
// LooneyBin 2026-06-11: the titles/stats menus index up to `APV_statTotals select 129`; old/short DB stat
// rows (fewer slots) overran -> this build surfaces an out-of-range select as "Zero divisor" (same class as
// the lottery select-8 bug), spamming fn_titleCfg ScriptErrors. Coerce any non-numeric slot to 0 and pad to
// the client's 148-slot default length before sending, so every consumer's select stays in range.
_stats = _stats apply { if (_x isEqualType 0) then { _x } else { 0 } };
if ((count _stats) < 148) then { for "_i" from (count _stats) to 147 do { _stats pushBack 0; }; };
[["APV_statTotals", _stats], "AP_fnc_netSetVar", _unit, false, false] spawn AP_fnc_MP;
