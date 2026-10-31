/*
    File: fn_ndCreditSrv.sqf  (APS_fnc_ndCreditSrv)
    LooneyBin 2026-07-23: SERVER-INTERNAL trusted New Drachma credit. Used by systems that computed the
    amount themselves (mining rigs, and any future server-side payout). Deliberately NOT registered in
    CfgRE.hpp -> a client cannot remoteExec it (mode=1 whitelist blocks it), so there is no rate cap and
    no owner check to fool. Call it only via a direct server-side `call`.

      [_player, "<amtStr>", "<reason>"] call APS_fnc_ndCreditSrv;

    Return: BOOL, true only once the credit has landed and been confirmed by
    re-select. ArmaQuest's payMoney profile capability (core/quests/fn_aqProfile.sqf)
    relies on this: a `true` that did not pay would read as a completed quest
    with no reward, which is the worst outcome that system can produce. Every
    PRE-EXISTING caller (mining rigs, deck loot) already ignores the return
    value, so making it truthful is backwards-compatible.
*/
params [["_pl", objNull, [objNull]], ["_amt", "", [""]], ["_reason", "srv", [""]]];
if (!isServer) exitWith { false };   // belt-and-suspenders: only ever runs on the server
if (isNull _pl) exitWith { false };
if (!(_amt regexMatch "\d{1,14}(\.\d{1,4})?") || {_amt isEqualTo "0"}) exitWith {
    diag_log format ["[LooneyBin][ND] ndCreditSrv bad amount '%1' (%2)", _amt, _reason]; false};
private _uid = getPlayerUID _pl;
if !(_uid regexMatch "\d{17}") exitWith { false };
// localNamespace (mints audit 2026-09-26): as a mission global a client publicVariable could clear the lock and
// interleave a credit with a debit, which reads as a successful debit that never happened.
private _ndLocks = localNamespace getVariable "AP_ndLocks";
if (isNil "_ndLocks") then { _ndLocks = createHashMap; localNamespace setVariable ["AP_ndLocks", _ndLocks]; };
private _t0 = diag_tickTime;
waitUntil { !(_ndLocks getOrDefault [_uid, false]) || {diag_tickTime - _t0 > 8} };
if (_ndLocks getOrDefault [_uid, false]) exitWith { diag_log format ["[LooneyBin][ND] ndCreditSrv lock bail %1", _uid]; false };
_ndLocks set [_uid, true];
[format ["UPDATE players SET new_drachma = new_drachma + %1 WHERE playerid='%2'", _amt, _uid], 2] call DB_fnc_asyncQuery;
private _row = [format ["SELECT new_drachma FROM players WHERE playerid='%1'", _uid], 2] call DB_fnc_asyncQuery;
_ndLocks set [_uid, false];
private _new = "";
if (_row isEqualType [] && {(_row param [0, ""]) isEqualType ""}) then { _new = _row select 0; };
if (_new isEqualTo "") exitWith { diag_log format ["[LooneyBin][ND] ndCreditSrv reselect failed %1", _uid]; false };
diag_log format ["[LooneyBin][ND] creditSrv +%1 (%2) -> %3 = %4", _amt, _reason, _uid, _new];
[[_new, _reason, _amt], "AP_fnc_ndSync", _pl, false] spawn AP_fnc_MP;
true
