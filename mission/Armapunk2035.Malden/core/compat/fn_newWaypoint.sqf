// AP_fnc_newWaypoint -- LooneyBin: dispatch waypoint receiver (restored 2026-06-11).
// Server APS_fnc_setWaypoint remoteExecs [ _pos, _remove ] to a single officer (used by the CAD
// dispatcher to point a unit at an active crime). Drops/clears one personal objective marker.
params [["_pos", [0,0,0], [[]]], ["_remove", false, [false]]];
if (side player != west) exitWith {};
deleteMarkerLocal "AP_dispatch_wp";
if (_remove) exitWith { systemChat "Dispatch waypoint cleared."; };
private _m = createMarkerLocal ["AP_dispatch_wp", _pos];
_m setMarkerTypeLocal "mil_objective";
_m setMarkerColorLocal "colorBLUFOR";
_m setMarkerTextLocal "Dispatch Waypoint";
systemChat "Dispatch has assigned you a waypoint.";
