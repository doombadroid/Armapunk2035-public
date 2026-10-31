// AP_fnc_finishDispatch -- LooneyBin: dispatch-resolved receiver (restored 2026-06-11).
// Server remoteExecs [ _id, _success ] to west when a crime event concludes. Notifies officers of the
// outcome. The crime marker is a local timed marker (mil_warning, 10 min TTL) and expires on its own.
params [["_id", 0, [0]], ["_success", false, [false]]];
if (side player != west) exitWith {};
private _msg = if (_success) then { "MaxSec resolved the incident successfully." } else { "The incident concluded -- suspect(s) got away." };
systemChat format["--- DISPATCH UPDATE: %1 ---", _msg];
[_msg, "basic"] spawn AP_fnc_handleMessage;
