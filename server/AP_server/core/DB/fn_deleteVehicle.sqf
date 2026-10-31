
// [plate, pid, class] call DB_fnc_deleteVehicle -> DB_fnc_asyncExec's reply ([1, rowcount, rows] / [0, msg]), or [] when
// refused. Server-only (not in CfgRE); its one caller is APS_fnc_vehicleDead, which files a wreck-ledger entry only
// when the row count says a row really went (audit 2026-09-26, mints2).
if ("AP_server_training" call DB_fnc_flag) exitWith {[]};
params [["_vid", -1, [0]], ["_pid", "", [""]], ["_class", "", [""]]];
if (_vid == -1 || {_pid == ""} || {_class == ""}) exitWith {[]};
// SECURITY (audit 2026-09-26): _pid arrives from a vehicle's PUBLIC AP_dbInfo (client-rewritable). A real pid is a
// Steam64 UID: digits only. Parameterised below as well.
if ((toArray _pid) findIf {_x < 48 || _x > 57} isNotEqualTo -1) exitWith {diag_log format ["[DBGUARD] deleteVehicle REFUSED non-numeric pid %1 (plate %2)", _pid select [0, 40], _vid]; []};
// The class is part of the key: AP_dbInfo is client-stampable, so without it a wreck of one class stamped with the
// plate of another class's row deleted that row, and the ledger then let the wreck's class be recovered in its place.
["DELETE FROM vehicles WHERE plate = %s::integer AND pid = %s AND lower(classname) = lower(%s)", [_vid, _pid, _class]] call DB_fnc_asyncExec
