 
private["_vehicle","_plate","_uid","_query","_sql","_dbInfo"]; 
_vehicle = [_this,0,ObjNull,[ObjNull]] call BIS_fnc_param; 
if(isNull _vehicle) exitWith {};  
// SECURITY (audit 2026-09-26): CfgRE-whitelisted (allowedTargets=2) and it deletes DB rows + world objects, with no
// caller check -- any client could erase or garage-dupe ANY vehicle. The only legitimate CLIENT caller is the cop
// SEIZE in fn_impoundAction ([_vehicle,"seize"], cop within 7m); the Killed EH (fn_vehicleCreate / fn_restoreVehicles)
// and fn_cleanup call it server-internally (remoteExecutedOwner 0 = trusted). So a remote call must be a seize by an
// on-duty cop standing at the vehicle. FLAT top-level exitWith (a nested one would only leave its then-block).
private _vdSrc = remoteExecutedOwner;
private _vdCaller = if (_vdSrc isEqualTo 0) then { objNull } else { (allPlayers select { owner _x isEqualTo _vdSrc }) param [0, objNull] };
if (_vdSrc isNotEqualTo 0 && {!(([_this,1,"",[""]] call BIS_fnc_param) isEqualTo "seize") || {!(_vdCaller call APS_fnc_isDutyCop)} || {(_vdCaller distance _vehicle) > 15}}) exitWith {
    ["-SEC-", _vdCaller, format ["BLOCKED vehicleDead on %1 (only an on-duty cop seizing within 15m may call it)", typeOf _vehicle]] call APS_fnc_logIt;};
 
// owner 2026-06-19 (#406): read AP_dbInfo (the 2020 client / garage-pull var) first, falling back to legacy
// dbInfo. This ONLY read "dbInfo", which garage-pulled vehicles (fn_vehicleGaragePull/gangGaragePull set only
// AP_dbInfo) never have -> count 0 -> exited BEFORE deleteVehicle. So a cop SEIZE paid out (copSplit) but the
// vehicle was never removed ("seize completes + pays but doesn't seize the ifrit"). Restored-after-restart
// vehicles set dbInfo and worked; freshly-pulled ones didn't. deleteVehicle now ALWAYS runs.
_dbInfo = _vehicle getVariable["AP_dbInfo",[]];
if (count _dbInfo == 0) then { _dbInfo = _vehicle getVariable["dbInfo",[]]; };
// SECURITY (audit 2026-09-26): AP_dbInfo/dbInfo are PUBLIC vars any client can rewrite, and uid/plate are formatted
// into SQL below. A real uid is a Steam64 (or gang id) digit string and a plate is a number -- anything else is forged,
// so skip the DB work entirely (the wreck/seize handling at the bottom still runs).
if (count _dbInfo >= 2 && {(_dbInfo select 1) isEqualType 0} && {((toArray format ["%1", _dbInfo select 0]) findIf {_x < 48 || _x > 57}) isEqualTo -1}) then {_uid = _dbInfo select 0;
_plate = _dbInfo select 1;
// owner 2026-06-21 (Ebola vehicle-loss report): if this vehicle was RESTORED by the restart and died within 60s of
// that respawn, it almost certainly clipped a building/terrain on restore (the restore re-spawns at the EXACT parked
// position with NO building-overlap check -> embeds -> dies the moment the 20s damage shield lifts). Do NOT delete
// the owner's vehicle for OUR restore bug -- GARAGE it (active=0) + repair (damage=0) so they keep it and re-pull it.
// Normal deaths (not restored, >60s old, or insured) fall through to the unchanged delete path below.
private _restoredAt = _vehicle getVariable ["AP_restoredAt", -99999];
// owner 2026-06-21 (#453 sub-path): widened 60 -> 300s. A restored vehicle embedded in a building takes damage
// only after the 20s shield lifts and can tip/cook off slowly, dying PAST 60s -> it fell through to DELETE = the
// "orcas keep disappearing" tail. 5 min comfortably covers slow restore-collision deaths; an uninsured vehicle
// dying within 5 min of a restart is almost always our restore bug, not legit gameplay -> GARAGE it, don't delete.
// audit 2026-09-26: only a DEAD vehicle gets this rescue. On a live one (a seize) it set active=false while the car
// was still in the world = the owner could pull a second copy, or keep a seized car.
if ((!alive _vehicle) && {(_restoredAt > -99999) && {(serverTime - _restoredAt) < 300}} && {!(_vehicle getVariable ["insured", false])}) then {
[format ["UPDATE vehicles SET active = false, damage='0' WHERE pid='%1' AND plate='%2'", _uid, _plate]] call DB_fnc_asyncQuery;
diag_log format ["[LooneyBin][veh] restore-collision death (<60s) -> GARAGED+repaired, not deleted: plate=%1 uid=%2", _plate, _uid];}
else {if (!(_vehicle getVariable ["insured", false])) then {
    // audit 2026-09-26 (mints2): the wreck-ledger entry is what lets APS_fnc_recoverWreck put this row back. Filed only
    // when the DELETE really removed this vehicle's row (owner + plate + class), so a client-spawned vehicle stamped
    // with a fresh plate, or a car sold from the garage while still out, dies with nothing to recover. A cop SEIZE files
    // nothing either: the car is gone as a penalty, and a forged wreck of it must not bring it back.
    private _del = [_plate, _uid, typeOf _vehicle] call DB_fnc_deleteVehicle;
    if ((_del param [0, 0]) isEqualTo 1 && {(_del param [1, 0]) > 0} && {(_this param [1, ""]) isNotEqualTo "seize"}) then {
        (localNamespace getVariable ["AP_wreckLedger", createHashMap]) set [format ["%1|%2", _uid, _plate], toLower typeOf _vehicle];
    };};};};

// owner 2026-07-04: leave the wreck on the map for 40min (players can SEE + recover it with a Wreckage
// Recovery Kit) instead of vanishing the instant it's destroyed. Only EXPLICIT removals -- cop seize/impound,
// which pass reason "seize" -- delete right away. Natural deaths (the Killed EH passes no reason string) get
// stamped as a lingering wreck; the idle-cleanup loop (fn_cleanup dead-branch) removes it once 40min elapse.
// (Killed EH _this select 1 is the killer OBJECT -> fails the [""] typecheck -> reason "" -> lingers. Good.)
private _reason = [_this,1,"",[""]] call BIS_fnc_param;
if (_reason isEqualTo "seize") then {deleteVehicle _vehicle;} else {_vehicle setVariable ["AP_wreckDeadAt", serverTime, true];
    _vehicle setVariable ["AP_isWreck", true, true];};