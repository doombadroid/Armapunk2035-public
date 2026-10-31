/*
    APS_fnc_setCleanTime  (LooneyBin: per-object idle/despawn marker)
    2020 client args : [_object, _time]  — mark a SINGLE object for delayed cleanup.

    THE BUG (fixed): the old passthrough ran `_this call APS_fnc_cleanup` — the 2017 GLOBAL cleanup
    sweep, which ignores the args and deletes every alive idleTime=0 vehicle with no owner/Trunk. Since
    fn_prepareVehicle -> fn_setVehicleIdle -> here runs on EVERY bought/pulled vehicle, that sweep nuked
    the just-spawned car ~0.1s after createVehicle (object vanished, DB row survived). The "split second"
    disappearing car.

    Now: vehicles get an idleTime stamp so the periodic APS_fnc_cleanup garages them once idle past its
    delay (and re-stamps on each get-out via setVehicleIdle); non-vehicles (spray cans, spike strips,
    dropped containers) get a plain despawn after _time.
*/
params [["_obj", objNull, [objNull]], ["_time", 900, [0]]];
if (isNull _obj) exitWith {};
// owner 2026-07-24 SECURITY (audit): CfgRE allowedTargets=2, and for anything that is not a
// Car/Air/Ship this unconditionally deleteVehicle's whatever object the client names, after a
// client-chosen delay -- no caller check, no ownership, no class limit, and a delay of 0 makes it an
// instant remote delete. That reaches persistent, valuable world objects: placed mining rigs, house
// furniture, fed gold briefcases, jewelry loot.
// A class allowlist would be brittle -- the legitimate callers pass campfires, chopped trees, ground
// weapon holders, boomboxes, med crates and spray objects. Instead refuse the PERSISTENCE-MARKED objects,
// which no legitimate caller sets, so this cannot false-positive on a real call. Also floor the delay for
// client calls (every real caller uses 120-900) so it can never be an instant delete.
private _src = remoteExecutedOwner;   // 0 == server-internal = trusted
if (_src isNotEqualTo 0) then {private _protected = (_obj getVariable ["AP_furniture", false])
        || {_obj getVariable ["AP_cryptoRig", false]}
        || {!((_obj getVariable ["AP_houseID", -1]) isEqualTo -1)}
        || {!((_obj getVariable ["AP_homeOwner", ""]) isEqualTo "")};
    if (_protected) then {
        ["-SEC-", objNull, format ["BLOCKED setCleanTime despawn of a protected object (%1) requested by owner %2", typeOf _obj, _src]] call APS_fnc_logIt;
        _obj = objNull;   // signal; the guard below exits the function
    } else {_time = _time max 60;};};
if (isNull _obj) exitWith {};

if (_obj isKindOf "Car" || _obj isKindOf "Air" || _obj isKindOf "Ship") exitWith {_obj setVariable ["idleTime", time, true];};

// Non-vehicle: despawn after _time if still present.
[_obj, _time] spawn {params ["_o", "_t"];
    uiSleep _t;
    if (!isNull _o) then { deleteVehicle _o; };};
