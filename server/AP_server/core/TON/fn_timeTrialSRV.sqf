/*
    APS_fnc_timeTrialSRV  (LooneyBin -- implemented 2026-06-09; the passthrough fed
    [player, raceId, carCFG, timer] into the 2017 group-race system (AP_racers) -> time-trial
    finishes paid nothing.)  Client (core/civilian/fn_timeTrial.sqf) sends [player, _id, _carCFG, _timer]
    on a completed run. Payout scales gently with course id; the trial vehicle cleans itself up via
    APS_fnc_createTimeTrialVehSRV's watchdog when AP_timeTrialActive drops.
*/
params [["_racer", objNull, [objNull]], ["_id", 0, [0]], ["_carCFG", "", [""]], ["_timer", 0, [0]]];
if (isNull _racer) exitWith {};
// owner 2026-07-24 SECURITY (audit: unauthenticated money printer). This is CfgRE-whitelisted
// allowedTargets=2 and used to validate NOTHING but isNull _racer -- no proof a trial was ever run, no
// cooldown, no caller check -- so any client could remoteExec it in a loop for $20,000-$45,000 a call and
// could bill the payout to any player object it passed. Gating on AP_timeTrialActive would NOT fix it:
// that flag is set by the CLIENT (see fn_createTimeTrialVehSRV's header) and is forgeable.
// Fix: (1) the caller must BE the racer; (2) a server-side start token, written only by
// APS_fnc_createTimeTrialVehSRV when it actually spawns the trial vehicle, must exist; (3) the token is
// CONSUMED here, so a spawn pays exactly once. server-internal (_src == 0) still passes.
private _src = remoteExecutedOwner;   // 0 == server-internal = trusted
private _caller = if (_src isEqualTo 0) then { objNull } else { (allPlayers select { owner _x isEqualTo _src }) param [0, objNull] };
if (_src isNotEqualTo 0 && {isNull _caller || {_caller isNotEqualTo _racer}}) exitWith {
    ["-SEC-", _caller, format ["BLOCKED timeTrial payout billed to someone else (racer=%1)", getPlayerUID _racer]] call APS_fnc_logIt;};
// owner 2026-09-26 (audit gpscivmed-0-1): the token is [course id, serverTime at spawn]. Pay the SERVER-recorded course
// (the client _id picked the top $45k tier), and only after a real run's worth of time: the course's straight-line
// length at 100 m/s (360 km/h) -- no trial car gets near it, and it kills spawn-then-claim-at-once.
// ponytail: derived floor; add a per-course minimum to timeTrialCfg if it ever needs tuning.
private _ttKey = format ["AP_ttRun_%1", getPlayerUID _racer];
private _run = localNamespace getVariable [_ttKey, []];   // localNamespace: a client publicVariableServer cannot write it
localNamespace setVariable [_ttKey, nil];   // consume: one payout (or one refused claim) per spawned trial vehicle
if !(_run isEqualTypeParams [0, 0]) exitWith {
    ["-SEC-", _racer, format ["BLOCKED timeTrial payout with no server-recorded run (id %1)", _id]] call APS_fnc_logIt;};
_run params ["_runId", "_runT0"];
private _wps = ([["getTimeTrialByID", _runId] call AP_fnc_timeTrialCfg] param [0, [], [[]]]) param [4, [], [[]]];
private _len = 0;
for "_i" from 1 to ((count _wps) - 1) do { _len = _len + (((_wps select (_i - 1)) select 2) distance2D ((_wps select _i) select 2)); };
if ((serverTime - _runT0) < (_len / 100)) exitWith {
    ["-SEC-", _racer, format ["BLOCKED timeTrial payout: course %1 claimed after %2s, minimum %3s", _runId, round (serverTime - _runT0), round (_len / 100)]] call APS_fnc_logIt;};
_racer setVariable ["AP_timeTrialActive", false, true];
private _payout = 20000 + ((_runId max 0) min 10) * 2500;
[["cash", "add", _payout], "AP_fnc_uC", _racer, false, false] spawn AP_fnc_MP;
[[format ["Time trial complete in %1s -- you earned $%2!", _timer, [_payout] call AP_fnc_numberText], "basic"], "AP_fnc_handleMessage", _racer, false, false] spawn AP_fnc_MP;
["-RACE-", _racer, format ["finished time trial %1 (%2) in %3s (server %4s), paid $%5", _runId, _carCFG, _timer, round (serverTime - _runT0), _payout]] call APS_fnc_logIt;
