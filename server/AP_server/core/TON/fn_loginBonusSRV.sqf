/*
    APS_fnc_loginBonusSRV  (LooneyBin -- implemented from stub 2026-06-09)
    Daily login bonus backend. DB: players.lb_days / lb_claimed / lb_last (added 2026-06-09).
    The connect-time streak compute + push of AP_loginBonusData lives in DB_fnc_queryRequest.
    Client cases (core/civilian/fn_loginBonusGive.sqf):
      ["giveCar",          [uid, player, classname]] -> CLAIM today's gift + insert its tier's vehicle into the garage
      ["updatePlayerData", [uid, consecutiveDays]]   -> CLAIM today's gift (+ credit its ND if it is an ND tier)
    Each case is a claim; the client sends exactly ONE of them per gift (giveCar for a car it has room for).
*/
params [["_caseType", "", [""]], ["_data", [], [[]]]];

// owner 2026-06-23 SECURITY (security.md §2.3 — cross-account write + SQLi): both cases used a client _uid raw
// (INSERT a garage vehicle / UPDATE lb_* flags), so a scripter could write to ANY account or inject SQL. Force
// the actor to the NON-SPOOFABLE caller's OWN account; escape _uid. Server-internal (_src==0) keeps the passed _uid.
// Audit 2026-09-26 (mints/config-0-0): the REWARD is the server's too now. giveCar used to insert whatever class
// the client named, as often as it was sent, and every car sells back through APS_fnc_srvSellVehicle -- a cash
// (or, for an nd_car, New Drachma) printer. The gift is now taken exactly once by the guarded write
// lb_claimed 0 -> 1, and what it pays comes from the tier row for the streak the SERVER stored (lb_days, written
// at login by DB_fnc_queryRequest). The client's classname and day count are ignored.
private _src = remoteExecutedOwner;
private _caller = (allPlayers select { owner _x isEqualTo _src }) param [0, objNull];
private _realUID = if (_src isEqualTo 0) then { "" } else { getPlayerUID _caller };
private _san = { (format ["%1", _this]) splitString "\'""" joinString "" };
// [uid] -> today's tier row, or [] when the gift was already taken (or the write failed). The UPDATE's own
// `AND lb_claimed = 0` is the authority: two claims racing each other cannot both see rowcount 1.
private _claim = {
    params ["_uid"];
    private _r = ["UPDATE players SET lb_claimed = 1 WHERE playerid = %s AND lb_claimed = 0 RETURNING lb_days", [_uid]] call DB_fnc_asyncExec;
    if !((_r param [0, 0]) isEqualTo 1 && {(_r param [1, 0]) isEqualTo 1}) exitWith { [] };
    private _days = ((_r param [2, []]) param [0, []]) param [0, -1];
    if (_days isEqualType "") then { _days = parseNumber _days; };
    ["getTierData", _days] call AP_fnc_loginBonusCfg
};

switch (_caseType) do {case "giveCar": {_data params [["_uid", "", [""]], ["_unit", objNull, [objNull]], ["_class", "", [""]]];
        if (_src != 0) then { _uid = _realUID; };
        _uid = _uid call _san;
        if (_uid isEqualTo "") exitWith {};
        ([_uid] call _claim) params [["_tier", -1], ["_loot", []], "", "", ["_isVehicle", false]];
        if (!_isVehicle) exitWith {
            ["-SEC-", _caller, format ["loginBonus giveCar refused for %1: no unclaimed vehicle tier today (tier %2, client asked for '%3')", _uid, _tier, _class call _san]] call APS_fnc_logIt;
        };
        _class = _loot param [0, ""];
        private _type = switch (true) do {case (_class isKindOf "Air"):  { "Air" };
            case (_class isKindOf "Ship"): { "Ship" };
            default { "Car" };};
        private _plate = round (random [100000, 550000, 999999]);
        // active=0 -> sits in the garage; alive=1; empty inventory
        [format ["INSERT INTO %1 (side, classname, type, pid, alive, active, inventory, color, plate, fuel, damage, alarm) VALUES ('civ', '%2', '%3', '%4', '1', '0', '[]', '0', '%5', '100', '0', '0')", "vehicles", _class, _type, _uid, _plate]] call DB_fnc_asyncQuery;
        diag_log format ["[LooneyBin][loginBonus] gave %1 a %2 (garage)", _uid, _class];};
    case "updatePlayerData": {_data params [["_uid", "", [""]]];
        if (_src != 0) then { _uid = _realUID; };
        _uid = _uid call _san;
        if (_uid isEqualTo "") exitWith {};
        // lb_days is NOT written from here any more: it came from the client, which could set its own streak.
        ([_uid] call _claim) params [["_tier", -1], ["_loot", []]];
        // New Drachma tiers are paid HERE, off the claim, through the non-whitelisted ndCreditSrv -- the client
        // no longer asks APS_fnc_ndSRV for a "loginbonus" credit (that reason is refused there now).
        if ((_loot param [0, ""]) isEqualTo "newdrachma" && {!isNull _caller}) then {
            [_caller, (_loot param [1, 0]) toFixed 4, "loginbonus"] call APS_fnc_ndCreditSrv;
        };
        diag_log format ["[LooneyBin][loginBonus] %1 claimed day-%2 bonus (%3)", _uid, _tier, ["already claimed", "ok"] select (_loot isNotEqualTo [])];};
    default {diag_log format ["[LooneyBin][loginBonusSRV] unhandled case: %1", _this];};};
