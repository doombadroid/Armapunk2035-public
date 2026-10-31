/*
    APS_fnc_atmSkimSRV  (LooneyBin, owner 2026-07-16) -- ATM SKIMMER backend, POSITION-KEYED.
    A $50k rebel item ("atmskimmer") planted on a PHYSICAL ATM machine siphons 10% of every deposit/withdraw at
    that ATM to the planter. Persists across restart. A second skimmer on a rigged ATM takes it over (REPLACE).
    Cops scroll the ATM -> "Remove ATM Skimmer" for a $200k bounty. NPC bankers = no ATM = never skimmed.

    Altis ATMs are TERRAIN objects: an object ref does NOT survive remoteExec (arrives <NULL-object> on the
    server), so the whole system is keyed by the ATM's rounded world position. State = HashMap (key -> ownerUID),
    authoritative copy in localNamespace "AP_atmSkimSrv"; AP_atmSkim is a display copy publicVariable'd to clients
    (they read it for the skim + the cop's remove action) and is never read back here. DB atm_skimmers persists it.

    Modes (client -> server, remoteExec allowedTargets=2):
      ["apply",  pos, 0,   player]   plant/steal (client already consumed the item)
      ["remove", pos, 0,   player]   cop removes it -> $200k reward (skimmer live >= 5 min, once per cop per 10 min)
      ["credit", pos, amt]           a victim transacted -> pay the ATM's owner (owner read SERVER-side; capped per planter)
      The acting player is ALWAYS the remoteExec sender; the `player` slot is only read on server-internal calls.
      ["sync"]                       (re)broadcast AP_atmSkim (called by clients at join for JIP)
      ["load"]                       boot: load AP_atmSkim from the DB + broadcast
*/
if (!isServer) exitWith {};
params [["_mode", "", [""]], ["_pos", [0,0,0], [[]]], ["_amount", 0, [0]], ["_caller", objNull, [objNull]]];
// The AUTHORITATIVE map lives in localNamespace, which no network write can reach; AP_atmSkim is only the published
// display copy. (A client `publicVariableServer "AP_atmSkim"` used to rewrite skimmer ownership on the server itself.)
// Every other piece of server state below (ages, budgets, cooldowns) is in localNamespace for the same reason.
if (isNil {localNamespace getVariable "AP_atmSkimSrv"}) then { localNamespace setVariable ["AP_atmSkimSrv", createHashMap]; };
private _srv = localNamespace getVariable "AP_atmSkimSrv";
private _pub = { AP_atmSkim = +_srv; publicVariable "AP_atmSkim"; };
// owner 2026-09-26 SECURITY (audit TONa-0-1): apply/remove used to PREFER the payload _caller over the real sender
// (frame anyone as planter; cop plants "as" a friend then removes for $200k), and credit trusted any client with any
// amount (plant anywhere, then credit 999999 into your own bankacc in a loop). The actor is now the remoteExec
// sender only; the payload unit is honoured for server-internal calls alone. A malformed pos is refused up front,
// because a distance check on it would error to nil and an `if (nil) exitWith` does not exit.
if (!(_pos isEqualTypeAll 0) || {count _pos < 2}) exitWith {};
if (isRemoteExecuted) then {
    private _rc = (allPlayers select { owner _x isEqualTo remoteExecutedOwner }) param [0, objNull];
    if (!isNull _caller && {_caller isNotEqualTo _rc}) then {
        ["-SEC-", _rc, format ["BLOCKED atmSkim %1 impersonation: claimed %2", _mode, _caller]] call APS_fnc_logIt;};
    _caller = _rc;};
if (isRemoteExecuted && {(toLower _mode) isEqualTo "load"}) exitWith {};   // boot-only (server init.sqf)
private _san = { (format ["%1", _this]) splitString "\'""" joinString "" };   // strip \ ' " (SQL-safety, matches gangBank)
private _key = format ["%1_%2", round (_pos param [0, 0]), round (_pos param [1, 0])];
// a real ATM at _pos: the client action's own test (class list or "atm_0" model name), run against the server's
// objects + terrain, plus the client-local map rows the server has no object for (APS_fnc_mapLoad's localNamespace
// snapshot: the old allLocalMapEntities global was client-overwritable, so a forged ATM row passed this anywhere).
private _isAtm = {private _atmStr = { private _s = toLower _this; (_s in ["land_mattaust_atm", "land_atm"]) || {(_s find "atm_0") >= 0} };   // Land_Atm_0x_F, *_malden_F, atm_0x*.p3d
    (((nearestObjects [_pos, [], 3]) + (nearestTerrainObjects [_pos, [], 3, false, true])) findIf { !(_x isKindOf "CAManBase") && {((typeOf _x) call _atmStr) || {(str _x) call _atmStr}} }) > -1   // str of a unit carries its player name + group id
    || {((localNamespace getVariable ["APS_mapEntities", []]) findIf { ((_x param [0, "", [""]]) call _atmStr) && {((_x param [1, [0,0,0], [[]]]) distance2D _pos) < 3} }) > -1}};

// credit a UID's bank: online -> live HUD/session bump + durable DB write; offline -> DB only (comp/mailbox lesson)
private _fnPay = {params ["_uid", "_amt"];
    if (_uid isEqualTo "" || {_amt <= 0}) exitWith {};
    private _su = _uid call _san;
    [format ["UPDATE players SET bankacc = bankacc + %1 WHERE playerid='%2'", _amt, _su]] spawn DB_fnc_asyncQuery;
    private _p = (allPlayers select { getPlayerUID _x isEqualTo _uid }) param [0, objNull];
    if (!isNull _p) then { [["atm", "add", _amt], "AP_fnc_uC", _p, false] spawn AP_fnc_MP; };};

switch (toLower _mode) do {

    case "apply": {private _unit = _caller;
        if (isNull _unit) exitWith {};
        private _uid = getPlayerUID _unit;
        if (_uid isEqualTo "") exitWith {};
        // civ-only device (the client gates on AP_effSide civilian); also stops a cop planting to farm his own bounty
        if ((_unit call APS_fnc_isDutyCop) || {_unit call APS_fnc_isDutyMed}) exitWith {};
        if ((_unit distance2D _pos) > 6 || {!(call _isAtm)}) exitWith {
            ["-SEC-", _unit, format ["BLOCKED atmSkim apply: no ATM at %1 within reach (%2 m away)", _key, round (_unit distance2D _pos)]] call APS_fnc_logIt;};
        private _prev = _srv getOrDefault [_key, ""];
        // REPLACE: a new skimmer on top cancels the old one out and takes over.
        _srv set [_key, _uid];
        call _pub;
        // BANK ICE (owner 2026-07-21): stamp when this skimmer went live, so a skimmer left running too long
        // trips an escalating, PRECISE trace on the planter (see the "credit" case).
        private _ageMap = localNamespace getVariable ["AP_atmSkimAge", createHashMap];
        _ageMap set [_key, serverTime];
        localNamespace setVariable ["AP_atmSkimAge", _ageMap];
        [format ["INSERT INTO atm_skimmers (atm_key, owner_uid) VALUES ('%1','%2') ON CONFLICT (atm_key) DO UPDATE SET owner_uid = EXCLUDED.owner_uid", _key call _san, _uid call _san]] spawn DB_fnc_asyncQuery;
        if (_prev isNotEqualTo "" && {_prev isNotEqualTo _uid}) then {
            private _pp = (allPlayers select { getPlayerUID _x isEqualTo _prev }) param [0, objNull];
            if (!isNull _pp) then { [["Someone found your ATM skimmer and replaced it with their own. You're cut off.", "basic"], "AP_fnc_handleMessage", _pp, false, false] spawn AP_fnc_MP; };
        };
        [["<t color='#e88b2d'>SKIMMER PLANTED</t> -- you now siphon 10%% of every transaction at this ATM. It survives restarts. Watch for cops.", "info"], "AP_fnc_handleMessage", _unit, false, false] spawn AP_fnc_MP;
        ["-ATMSKIMMER-", _unit, name _unit, format ["planted skimmer at %1 (prev owner %2)", _key, _prev]] call APS_fnc_logIt;};

    case "remove": {private _unit = _caller;
        if (isNull _unit) exitWith {};
        if !(_unit call APS_fnc_isDutyCop) exitWith {};                      // cops only
        if ((_unit distance2D _pos) > 6) exitWith {};                        // must be at the machine (client gates at 3 m)
        private _owner = _srv getOrDefault [_key, ""];
        if (_owner isEqualTo "") exitWith {};                                // nothing to remove (anti double-reward)
        if (_owner isEqualTo getPlayerUID _unit) exitWith {                  // planted as a civ, clocked on, cashing your own bounty
            ["-SEC-", _unit, format ["BLOCKED atmSkim remove: own skimmer at %1", _key]] call APS_fnc_logIt;};
        _srv deleteAt _key;
        call _pub;
        [format ["DELETE FROM atm_skimmers WHERE atm_key='%1'", _key call _san]] spawn DB_fnc_asyncQuery;
        // Bounded bounty (audit TONa-0-1): the item is client-side, so a civ plants free and a duty-cop friend removes,
        // repeat, on any of ~30 keys per ATM. Pay only for a skimmer live >= 5 min (DB-restored = no stamp = old) and
        // at most once per cop per 10 min; otherwise the skimmer still comes off, unpaid.
        private _bAge = serverTime - ((localNamespace getVariable ["AP_atmSkimAge", createHashMap]) getOrDefault [_key, -1e9]);
        private _bCd = "AP_skimBountyCd_" + getPlayerUID _unit;
        private _bPay = 0;
        if (_bAge >= 300 && {serverTime >= (localNamespace getVariable [_bCd, 0])}) then { localNamespace setVariable [_bCd, serverTime + 600]; _bPay = 200000; };
        [getPlayerUID _unit, _bPay] call _fnPay;                             // cop bounty (owner just loses future skim); 0 = no-op
        [[if (_bPay > 0) then {"<t color='#3aa0ff'>SKIMMER REMOVED</t> -- you pulled a skimming device off this ATM. $200,000 reward wired to your account."} else {"<t color='#3aa0ff'>SKIMMER REMOVED</t> -- no bounty on this one (freshly planted, or you were paid for one in the last 10 minutes)."}, "info"], "AP_fnc_handleMessage", _unit, false, false] spawn AP_fnc_MP;
        ["-ATMSKIMMER-", _unit, name _unit, format ["cop removed skimmer at %1 (was %2, age %3 s) for $%4", _key, _owner, round (_bAge min 99999), _bPay]] call APS_fnc_logIt;};

    case "credit": {
        private _owner = _srv getOrDefault [_key, ""];                     // owner from the server-only map (client can't redirect)
        if (_owner isEqualTo "") exitWith {};
        // the crediting client must be a real player standing at this machine (the deck Bank app can stay open a
        // few steps away), and never the planter: honest clients skip the skim on their own skimmer.
        if (isRemoteExecuted && {isNull _caller || {(_caller distance2D _pos) > 25}}) exitWith {};
        if (_owner isEqualTo getPlayerUID _caller) exitWith {
            ["-SEC-", _caller, format ["BLOCKED atmSkim self-credit of $%1 at %2", _amount, _key]] call APS_fnc_logIt;};
        // The amount is still the victim's client figure (bank money is client-side; there is no server deposit
        // path to compute it in), so bound it: at most $300k per PLANTER per 60 s = 3% of one max $9,999,999 txn.
        // Keyed on the owner UID, not _key: _key is the client's rounded pos, so ~30 keys fit around one ATM.
        // ponytail: fixed window, not rolling -- up to 2x across a window edge; fine for a cap.
        private _bKey = "AP_skimBudget_" + _owner;
        (localNamespace getVariable [_bKey, [0, 0]]) params ["_bT0", "_bUsed"];
        if ((serverTime - _bT0) > 60) then { _bT0 = serverTime; _bUsed = 0; };
        private _amt = ((round _amount) min 300000) min (300000 - _bUsed);   // per-call clamp too (defence in depth)
        if !(_amt > 0) exitWith {};
        localNamespace setVariable [_bKey, [_bT0, _bUsed + _amt]];
        [_owner, _amt] call _fnPay;
        // BANK ICE (owner 2026-07-21, Skim Daemon counter): a skimmer left running past its payout window
        // (>20 min) starts throwing PRECISE traces -- the bank's ICE has locked onto it. Escalates the silent
        // 30% area-ping into a located fix on the planter, so greed past the safe window gets you caught.
        private _ageMap = localNamespace getVariable ["AP_atmSkimAge", createHashMap];
        private _placed = _ageMap getOrDefault [_key, serverTime];
        if ((serverTime - _placed) > 1200) then {private _icekey = "AP_skimIceCd_" + _key;
            if (serverTime >= (localNamespace getVariable [_icekey, 0])) then {localNamespace setVariable [_icekey, serverTime + 90];
                private _plr = allPlayers param [allPlayers findIf { getPlayerUID _x isEqualTo _owner }, objNull];
                private _fix = if (!isNull _plr) then { getPosATL _plr } else { _pos };   // planter if online, else the ATM
                { [[_fix, "SKIMMER TRACE", "ColorRed", true], "AP_fnc_talMarker", _x, false] spawn AP_fnc_MP; } forEach (allPlayers select { _x call APS_fnc_isDutyCop });
                [["<t size='1.15' color='#4aa3ff'>BANK ICE</t> -- a long-running skimmer has been traced to a location.", "copalert"], "AP_fnc_handleMessage", west, false, false] spawn AP_fnc_MP;
                if (!isNull _plr) then { [["<t color='#ff3b1e'>ICE ON YOU</t> -- your skimmer's been up too long. The bank just traced it to your position.", "warning"], "AP_fnc_handleMessage", _plr, false, false] spawn AP_fnc_MP; };
                ["-ATMSKIM-", objNull, "SERVER", format ["BANK ICE precise trace on planter %1 at ATM %2", _owner, _key]] call APS_fnc_logIt;
            };};
        // SILENT ALARM (owner 2026-07-21, Skim Daemon spec): 30% per skimmed transaction the machine
        // phones home. The VICTIM is told nothing -- that is what makes it silent; MaxSec gets a
        // located ping and the planter is warned their box is hot. Throttled per ATM so a busy machine
        // can't spam the net. Rolled here because only the server knows the true skim happened.
        if (random 1 < 0.30) then {private _akey = "AP_skimAlarmCd_" + _key;
            if (serverTime >= (localNamespace getVariable [_akey, 0])) then {localNamespace setVariable [_akey, serverTime + 120];
                private _loc = (nearestLocations [_pos, ["NameCityCapital", "NameCity", "NameVillage", "NameLocal"], 3000]) param [0, locationNull];
                private _town = if (isNull _loc) then { "an outlying area" } else { text _loc };
                [[format ["Bank fraud alert -- a tampered ATM reported a skimmed transaction in %1.", _town], "copalert"], "AP_fnc_handleMessage", west, false, false] spawn AP_fnc_MP;
                private _plr = allPlayers param [allPlayers findIf { getPlayerUID _x isEqualTo _owner }, objNull];
                if (!isNull _plr) then {
                    [["<t color='#ff3b1e'>SKIMMER EXPOSED</t> -- that machine tripped a fraud alert. MaxSec knows the area.", "warning"], "AP_fnc_handleMessage", _plr, false, false] spawn AP_fnc_MP;
                };
                ["-ATMSKIM-", objNull, "SERVER", format ["silent alarm tripped at ATM %1 (%2), planter %3", _key, _town, _owner]] call APS_fnc_logIt;
            };};};

    case "sync": { call _pub; };                                            // JIP: a joiner asks for the current map

    case "load": {
        // a client broadcast of the display copy (forged owners) is overwritten at once with the real map
        "AP_atmSkim" addPublicVariableEventHandler { ["sync"] call APS_fnc_atmSkimSRV; };
        [_srv, _pub] spawn {params ["_srv", "_pub"];
            // QUOTE both cols: DB_fnc_asyncQuery mode 2 call-compiles the result, so a bare atm_key like
            // 14045_18756 parses as 14045 then _18756 (undefined) -> "Missing ]" -> the load aborts + skimmers
            // never restore across restart. (Same QUOTE-on-read rule as economySRV/foreskins/mres.)
            private _rows = ["SELECT atm_key, owner_uid FROM atm_skimmers", 2, true] call DB_fnc_asyncQuery;
            if (isNil "_rows" || {!(_rows isEqualType [])}) exitWith {};
            private _n = 0; {_x params [["_k", ""], ["_u", ""]];
                if (_k isNotEqualTo "" && {_u isNotEqualTo ""}) then { _srv set [_k, _u]; _n = _n + 1; };} forEach _rows;
            call _pub;
            diag_log format ["[LooneyBin][atmSkimmer] loaded %1 skimmer(s) from DB", _n];};};};
