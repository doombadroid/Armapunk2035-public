// owner 2026-07-21: the 14 hardcoded camera positions moved to the shared AP_cctvCams registry
// (configuration.sqf) so the civilian Eye Spy quickhack hijacks the SAME cameras. Indices 0-13 are
// unchanged, so the cop scroll-menu that passes literal indices still lines up exactly.
params[["_camera", -2, [0]]];
if (_camera isEqualTo - 2) exitWith {};
if (_camera isEqualTo - 1) exitWith {AP_trafficCam cameraEffect["terminate", "back"];
    camDestroy AP_trafficCam;
    AP_trafficCam = nil;
    player switchCamera cameraView;
    ["Security Camera Closed.", "basic"] spawn AP_fnc_handleMessage;};
private _cam = AP_cctvCams param [_camera, []];
if (_cam isEqualTo []) exitWith {};
_cam params ["_pos", "_dir", "_tilt"];
AP_trafficCam = "camera"
camCreate _pos;
AP_trafficCam camSetFov 0.7;
AP_trafficCam setDir _dir;
[AP_trafficCam, _tilt, 0] call BIS_fnc_setPitchBank;
AP_trafficCam camCommit 0;
AP_trafficCam switchCamera "INTERNAL";
["Press 4 to close the camera.", "basic"] spawn AP_fnc_handleMessage;