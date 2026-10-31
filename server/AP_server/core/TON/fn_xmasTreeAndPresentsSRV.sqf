/*
    APS_fnc_xmasTreeAndPresentsSRV  (LooneyBin -- implemented from stub 2026-06-09)
    Christmas tree presents (season-gated: only runs when "winter" is in SRV_enabledSeasonalEvents).
    Client (core/seasonalEvents/fn_openChristmasTreePresentCL.sqf) sends
    ["updatePlayerData", [uid, player]] after opening a present -> record the daily claim.
    DB: players.xmas_last (DATE, added 2026-06-09).
*/
params [["_caseType", "", [""]], ["_data", [], [[]]]];
// owner 2026-06-23 SECURITY (security.md §2.3 — cross-account write + SQLi): the client _uid was used raw in the
// UPDATE. Force the actor to the NON-SPOOFABLE caller's OWN account (the present-open always passes the local
// player's uid); escape it. Server-internal (_src==0) keeps the passed _uid.
private _src = remoteExecutedOwner;
private _realUID = if (_src isEqualTo 0) then { "" } else { getPlayerUID ((allPlayers select { owner _x isEqualTo _src }) param [0, objNull]) };
private _san = { (format ["%1", _this]) splitString "\'""" joinString "" };
switch (_caseType) do {case "updatePlayerData": {_data params [["_uid", "", [""]], ["_unit", objNull, [objNull]]];
        if (_src != 0) then { _uid = _realUID; };
        _uid = _uid call _san;
        if (_uid isEqualTo "") exitWith {};
        [format ["UPDATE players SET xmas_last=CURRENT_DATE WHERE playerid='%1'", _uid]] call DB_fnc_asyncQuery;
        diag_log format ["[LooneyBin][xmas] %1 opened a tree present", _uid];};
    default { diag_log format ["[LooneyBin][xmas] unhandled case: %1", _this]; };};
