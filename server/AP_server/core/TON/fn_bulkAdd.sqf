/*
    APS_fnc_bulkAdd  (LooneyBin -- implemented 2026-06-09; the passthrough pushed [uid,name,crimes]
    into the 2017 DB write-queue as if it were a save packet -> a connecting criminal's standing
    charges were never re-registered on the server wanted list.)
    Client (fn_initCiv on spawn) sends [uid, name, A_stats_crimes] (slot 0 = total bounty value,
    slots 1.. = per-charge counts). Rebuild their wanted entry if they're not already listed.
*/
params [["_uid", "", [""]], ["_name", "", [""]], ["_crimesArr", [], [[]]]];
// owner 2026-06-23 SECURITY (security.md §2.2/§2.3): self-only. Caller = fn_initCiv (a civ re-registering THEIR
// OWN standing charges on spawn -- passes getPlayerUID player). Ungated, any civ could remoteExec
// [victimUID, name, crimes] to fabricate a wanted entry on anyone. Require subject UID == the real caller's UID
// (remoteExecutedOwner, non-spoofable); server-internal passes. _uid/_name reach SQL via DB_fnc_insertWanted
// (whose KRON_Replace is undefined on the dedi server, §2.3) -- strip quotes here.
private _src = remoteExecutedOwner;
private _caller = if (_src isEqualTo 0) then { objNull } else { (allPlayers select { owner _x isEqualTo _src }) param [0, objNull] };
private _callerUID = getPlayerUID _caller;
private _san = { (format ["%1", _this]) splitString "\'""" joinString "" };
_uid = _uid call _san;  _name = _name call _san;
if (_src isNotEqualTo 0 && {_uid isNotEqualTo _callerUID}) exitWith { ["-SEC-", _caller, format ["BLOCKED bulkAdd by %1 on %2", _callerUID, _uid]] call APS_fnc_logIt; };
if (_uid isEqualTo "" || {count _crimesArr < 2}) exitWith {};
private _wl = localNamespace getVariable "APS_wantedList";
if (([_uid, _wl] call AP_fnc_index) isNotEqualTo -1) exitWith {};   // already wanted
// TONa-0-7: this used to trust slot 0 as the bounty (a $1e9 self-registration APS_fnc_wantedBounty then paid),
// loop each raw count (1e8 = a server stall + a 1e8-entry DB write) and look jail times up one slot off
// (getChargeTimes is packed, so ids after the 49/69-71 gaps shifted too). APS_fnc_wantedSyncList already
// rebuilds an entry from clamped counts x the charge table; use that one copy, then persist what it built.
[_uid, _name, _crimesArr] call APS_fnc_wantedSyncList;
private _i = _wl findIf { (_x param [1, ""]) isEqualTo _uid };
if (_i isEqualTo -1) exitWith {};
(_wl select _i) params ["", "", "_crimes", "_bounty", "_jail"];
[_name, _uid, _crimes, _bounty, _jail] spawn DB_fnc_insertWanted;
diag_log format ["[LooneyBin][wanted] re-registered %1 (%2): %3 charge(s), bounty %4", _name, _uid, count _crimes, _bounty];
