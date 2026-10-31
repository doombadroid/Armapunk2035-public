/*
    File: fn_suiteDoorSync.sqf  (AP_fnc_suiteDoorSync)
    Luxe Suites 2026-08-06 -- push a suite's front-door lock state to every machine.
    CfgRE allowedTargets = 1 (server -> clients).

        [_oid, _floor, _locked, "<ownerUid>"] remoteExec

    Sets ap_doorLocked on the floor's FRONT door leaf only. The lock hook already
    exists in lux_doors.sqf, which refuses to open a leaf carrying that variable;
    this function is the only thing that sets it, so lock state has exactly one
    writer.

    Interior doors (bath, bedroom) are never touched -- a floor's three doors are
    front/bath/bedroom in that order, so the front door is flat index (floor-2)*3
    within the instance's block.

    LIFECYCLE NOTE: lux_doors.sqf owns the leaves, the flat array and the open/close
    animation. This function reads that array and sets one variable on one leaf. It
    must never re-place, re-order or delete leaves, or the two systems will fight
    over the same lifecycle.
*/
if (isRemoteExecuted && {remoteExecutedOwner != 2}) exitWith {};   // server-origin only: CfgRE allowedTargets limits the target, never the sender
params [["_oid", "", [""]], ["_floor", 0, [0]], ["_locked", true, [true]], ["_owner", "", [""]]];
if (_oid isEqualTo "" || {_floor < 2} || {_floor > 30}) exitWith {};
if (isNil "AP_LUXDOOR_LEAVES") exitWith {};          // doors not wired on this machine yet

// Which instance? The oid carries the tower's rounded position, so match the leaf
// block whose building sits there. Instances are appended to the flat array in
// wiring order, 88 leaves each.
private _towerKey = _oid select [3, (_oid find "F") - 3];
private _base = -1;
{
    if (([_x] call AP_fnc_suiteTowerKey) isEqualTo _towerKey) exitWith {
        // lux_doors.sqf stamps each instance's slice offset on its own building
        _base = _x getVariable ["ap_luxDoorBase", -1];
    };
} forEach (call AP_fnc_suiteTowers);
if (_base < 0) exitWith {};

private _idx = [_floor, _base] call AP_fnc_suiteFrontDoorIdx;
if (_idx < 0 || {_idx >= count AP_LUXDOOR_LEAVES}) exitWith {};
private _leaf = (AP_LUXDOOR_LEAVES select _idx) param [0, objNull];
if (isNull _leaf) exitWith {};

_leaf setVariable ["ap_doorLocked", _locked, false];   // local: every machine runs this
_leaf setVariable ["AP_suiteOid", _oid, false];
// the tenant uid rides WITH the lock state: AP_fnc_suiteMayOpen reads it off the
// leaf, so access never depends on a client-side cache being warm
_leaf setVariable ["ap_suiteOwner", _owner, false];
