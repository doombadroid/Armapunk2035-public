/*
    File: fn_mapEditAudit.sqf  (APS_fnc_mapEditAudit)
    One row per accepted map edit.

    The editor rewrites the world for everyone, so "who moved the bank" has to be
    answerable from the database rather than from whoever happened to be reading
    the RPT that day.

    Server-local. No CfgRE entry: nothing may call this remotely.
*/
params [["_uid", "", [""]], ["_op", "", [""]], ["_target", "", [""]], ["_detail", "", [""]]];
if (!isServer || {_uid isEqualTo ""}) exitWith {};
[
    "INSERT INTO map_edit_log (world, author_uid, op, target, detail) VALUES (%s,%s,%s,%s,%s)",
    1, false, [worldName, _uid, _op, _target, _detail]
] call DB_fnc_asyncQuery;
