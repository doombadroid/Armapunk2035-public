/*
    APS_fnc_createTimeTrialVehSRV  (LooneyBin -- implemented from stub 2026-06-09)
    Time trials race vehicle. Client (core/civilian/fn_timeTrial.sqf, civTimeTrials NPC) sends
    [player, courseId] after setting its own AP_timeTrialActive=true (car/pos/dir are looked up HERE).
    Spawns the race car, keys it to the racer, deletes it when the trial ends (AP_timeTrialActive
    false), the racer leaves/dies, or after 30 min.
*/
params [["_racer", objNull, [objNull]], ["_id", -1, [0]]];
if (isNull _racer) exitWith {};
// owner 2026-07-24 SECURITY (audit: timeTrialSRV was an unauthenticated money printer). The payout fn had
// no proof a trial ever happened, because the only "am I racing" flag (AP_timeTrialActive) is set by the
// CLIENT (see the header above) and is therefore forgeable. Record a SERVER-side, non-public start token
// here -- the one place a trial can legitimately begin -- which APS_fnc_timeTrialSRV requires and then
// consumes, making the payout single-use per spawned vehicle. Also require the caller to be the racer.
private _src = remoteExecutedOwner;   // 0 == server-internal = trusted
private _caller = if (_src isEqualTo 0) then { objNull } else { (allPlayers select { owner _x isEqualTo _src }) param [0, objNull] };
if (_src isNotEqualTo 0 && {isNull _caller || {_caller isNotEqualTo _racer}}) exitWith {
    ["-SEC-", _caller, format ["BLOCKED createTimeTrialVeh for someone else (racer=%1)", getPlayerUID _racer]] call APS_fnc_logIt;};
// owner 2026-09-26 SECURITY (audit gpscivmed-0-1): the client used to send the classname, position and heading, so
// any client could make the server spawn ANY vehicle (tanks, armed jets) ANYWHERE, keyed to itself, with no cooldown.
// It now sends only the course id; car, spot and heading come from the course table (AP_fnc_timeTrialCfg is a
// mission fn, compiled on the server too). One start per 30 s per UID, and never onto an occupied start.
private _cfg = [["getTimeTrialByID", _id] call AP_fnc_timeTrialCfg] param [0, [], [[]]];
if (_cfg isEqualTo []) exitWith {};
_cfg params ["", ["_carCFG", "", [""]], ["_carPos", [0,0,0], [[]]], ["_carD", 0, [0]]];
private _ttCd = format ["AP_ttCd_%1", getPlayerUID _racer];
if (serverTime < (localNamespace getVariable [_ttCd, 0]) || {(nearestObjects [_carPos, ["LandVehicle", "Air", "Ship"], 4]) isNotEqualTo []}) exitWith {
    _racer setVariable ["AP_timeTrialActive", false, true];   // the client waits on this flag -> it fails out cleanly
    [["Time trial unavailable -- the start is occupied, or you started one moments ago.", "basic"], "AP_fnc_handleMessage", _racer, false, false] spawn AP_fnc_MP;};
localNamespace setVariable [_ttCd, serverTime + 30];
localNamespace setVariable [format ["AP_ttRun_%1", getPlayerUID _racer], [_id, serverTime]];   // localNamespace: no client publicVariable can forge it; [course, start]
private _veh = _carCFG createVehicle _carPos;
_veh setPosATL _carPos;
_veh setDir _carD;
_veh lock 0;
_veh setVariable ["AP_timeTrialVeh", true, true];
_veh setVariable ["AP_vehOwners", [[getPlayerUID _racer, name _racer]], true];
_veh setVariable ["owner", getPlayerUID _racer, true];   // cleanup-sweep spare
_veh setFuel 1;
[_veh, _racer] spawn {params ["_veh", "_racer"];
    private _endAt = serverTime + 1800;
    waitUntil { uiSleep 5;
        isNull _veh || {!alive _veh} || {isNull _racer} || {!alive _racer} ||
        {!(_racer getVariable ["AP_timeTrialActive", false])} || {serverTime > _endAt} };
    if (!isNull _veh) then { deleteVehicle _veh; };};
diag_log format ["[LooneyBin][timeTrial] %1 spawned for %2", _carCFG, getPlayerUID _racer];
