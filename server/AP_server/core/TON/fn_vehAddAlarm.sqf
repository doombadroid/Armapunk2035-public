/*
    APS_fnc_vehAddAlarm  (LooneyBin)
    client args: [player, vehOwnerUID, plate]
    Persist a car alarm on the owner's vehicle.
*/
params [["_player",objNull,[objNull]],["_owner","",[""]],["_plate",-1,[0]]];
if (_owner == "" || _plate < 0) exitWith {};
// owner 2026-06-23 SECURITY (security.md §2.3 — SQLi): the client _owner was interpolated RAW into the UPDATE.
// NEEDS OWNER REVIEW: _owner is the vehicle's real owner from AP_vehOwners (fn_alarm.sqf:41), which can
// differ from the caller for shared/gang/key-held vehicles -- so we CANNOT safely force it to the caller's own
// uid without breaking the legit "alarm a car you have keys to" case. Escape-only here (kills injection);
// there is no ownership/key re-check, so a scripter can still flip alarm='1' on an arbitrary plate (low
// impact -- cosmetic alarm flag). _plate forced numeric (params type [0]) -> round into SQL.
private _san = { (format ["%1", _this]) splitString "\'""" joinString "" };
[format ["UPDATE vehicles SET alarm = true WHERE pid='%1' AND plate='%2'", _owner call _san, round _plate]] call DB_fnc_asyncQuery;
