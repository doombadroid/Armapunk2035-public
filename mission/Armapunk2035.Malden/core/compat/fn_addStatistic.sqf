// AP_fnc_addStatistic (LooneyBin, owner 2026-07-17: was a no-op stub -- session stat counters never ticked).
// Increment the player's stat-buffer slot _index by _value, client-side. Callers remoteExec [index,value] here
// (server/init.sqf login + gang, fn_monitorCaptures). Mirrors the increment in AP_fnc_statArrUpdate:636 --
// respects the singleevh double-buffer (AP_useStatBuffer) so buffered flushes + live reads both see it.
params [["_index", -1, [0]], ["_value", 0, [0]]];
if (!hasInterface || {_index < 0}) exitWith {};
if (!isNil "AP_useStatBuffer" && {AP_useStatBuffer}) then {
    AP_stats_dirty set [_index, (AP_stats_dirty getOrDefault [_index, 0]) + _value];   // delta -> flush buffer
    AP_stats_live  set [_index, (AP_stats_live  getOrDefault [_index, 0]) + _value];   // absolute -> live reads
} else {if (!isNil "APV_tempStats" && {_index < count APV_tempStats}) then {
        APV_tempStats set [_index, (APV_tempStats select _index) + _value];};};
