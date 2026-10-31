/*
    APS_fnc_copUAVSRV  (LooneyBin, owner 2026-06-25) -- MaxSec Captain+ deployable UCAV (the uav05 virtual item).
    The client (AP_fnc_copUAV) consumed the item + sent [_dir]. We spawn B_UAV_05_F (UCAV Sentinel -- a fixed-wing
    JET, so it must spawn AIRBORNE, not on the ground) ~70m in front of the caller, give it an autonomous WEST crew so
    the cop's UAV terminal can connect, and mark it OWNED so the idle-vehicle cleanup sweep won't reap it.
    Caller derived from the non-spoofable remoteExecutedOwner. NOTE (beta): the Captain+ gate is client-side (shop
    listing + the use-action both require copLevel>=6); the server only validates WEST here. Tighten with a server-side
    rank check at the public-launch CfgRE hardening pass (see launch.md / loonybin-cfgre-rce-deferred).
*/
params [["_dir", 0, [0]]];
private _src = remoteExecutedOwner;
if (_src isEqualTo 0) exitWith {};
private _caller = (allPlayers select { owner _x isEqualTo _src }) param [0, objNull];
if (isNull _caller) exitWith {};
if !(_caller call APS_fnc_isDutyCop) exitWith { ["-SEC-", _caller, "BLOCKED copUAVSRV (caller not west)"] call APS_fnc_logIt; };
// anti-spam: one UAV per caller per 20s
private _now = diag_tickTime;
if ((_now - (_caller getVariable ["AP_lastUAV", -999])) < 20) exitWith {};
_caller setVariable ["AP_lastUAV", _now];

// spawn AIRBORNE ~70m in front of the caller, ~120m up -- it's a jet, it has to be flying
private _fp = _caller getPos [70, _dir];
private _spawnPos = [_fp select 0, _fp select 1, 120];
private _uav = createVehicle ["B_UAV_05_F", _spawnPos, [], 0, "FLY"];
_uav setDir _dir;
_uav setVelocity [(sin _dir) * 80, (cos _dir) * 80, 0];   // forward thrust so the jet stays airborne
createVehicleCrew _uav;                                    // autonomous WEST crew -> the cop's terminal can connect
_uav setVariable ["AP_vehOwners", [[getPlayerUID _caller, name _caller]], true];   // Check Registration
_uav setVariable ["owner", getPlayerUID _caller, true];    // mark owned -> idle-cleanup sweep won't reap it mid-flight
_uav setVariable ["AP_side", "cop", true];
_uav setVariable ["AP_copUAV", true, true];
["-COPUAV-", _caller, format ["deployed MaxSec UCAV B_UAV_05_F at %1", _spawnPos]] call APS_fnc_logIt;
