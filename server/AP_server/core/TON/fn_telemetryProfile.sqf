/*
    File: fn_telemetryProfile.sqf  (APS_fnc_telemetryProfile)
    Once-per-session client profile (TELEMETRY_SPEC.md § Phase 2 D), sent by AP_fnc_telemetryBeat
    after its first beat, via AP_fnc_MP -> remoteExecCall (CfgRE.hpp allowedTargets = 2).

        [resW, resH, fov, buildNumber, branch, language]

    Same identity rule as the beat (AP_fnc_telemetryCaller, never the payload). The two strings
    become label values, so they go through AP_fnc_telemetrySanitize ([A-Za-z0-9_.-], 32 chars)
    and nowhere else; the numbers are clamped. Keys land in the client's entry alongside the beat
    keys and are reported by the 5 s job as ap_client_res_w/h, ap_client_fov, ap_client_build
    and ap_client_info{branch,lang}.

    Runs unscheduled (remoteExecCall) and does no I/O: one hashMap write.
*/
if (!isServer) exitWith {};
params [["_resW", 0, [0]], ["_resH", 0, [0]], ["_fov", 0, [0]], ["_build", 0, [0]], ["_branch", "", [""]], ["_lang", "", [""]]];
if (isNil "AP_fnc_telemetryCaller") exitWith {};

private _who = call AP_fnc_telemetryCaller;
if (_who isEqualTo []) exitWith {};
_who params ["_uid", "_name", "_machine"];

if (isNil "AP_telemetry_clients") then { AP_telemetry_clients = createHashMap; };
private _e = AP_telemetry_clients getOrDefault [_uid, createHashMap];
_e set ["name", _name];
_e set ["machine", _machine];
if !("t" in _e) then { _e set ["t", diag_tickTime]; };
_e set ["res_w",  (_resW  max 0) min 16384];
_e set ["res_h",  (_resH  max 0) min 16384];
_e set ["fov",    (_fov   max 0) min 10];
_e set ["build",  (_build max 0) min 1e9];
_e set ["branch", [_branch] call AP_fnc_telemetrySanitize];
_e set ["lang",   [_lang]   call AP_fnc_telemetrySanitize];
AP_telemetry_clients set [_uid, _e];
