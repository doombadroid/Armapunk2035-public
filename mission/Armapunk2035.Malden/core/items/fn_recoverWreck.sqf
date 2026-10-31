// LooneyBin owner 2026-07-04: Wreckage Recovery Kit -- scroll a WRECK to send it back to its OWNER's garage.
// Uses the exact same progress bar + duration as the medic's Clear Wreckage (fn_medicDeleteVeh). Consumes 1
// kit on success; the server (APS_fnc_recoverWreck) does the DB garage-insert + removes the wreck.
params [["_vehicle", objNull, [objNull]]];
// owner 2026-07-05: DB-visible trace (the server RPT is block-buffered / unreadable live). Logs every attempt to
// the `log` table so we can see EXACTLY where recovery dies without an in-game repro.
[["-WRECKKIT-", player, profileName, format ["client start: veh=%1 alive=%2 dbInfoP=%3 dbInfoL=%4 kit=%5", typeOf _vehicle, alive _vehicle, _vehicle getVariable ["AP_dbInfo", []], _vehicle getVariable ["dbInfo", []], missionNamespace getVariable ["AP_inv_wreckkit", -1]]], "APS_fnc_logIt", 2, false, false] spawn AP_fnc_MP;
if (alive _vehicle) exitWith { ["That vehicle isn't wrecked.", "basic"] spawn AP_fnc_handleMessage; };
if (AP_action_in_use) exitWith { ["You are currently already doing something!", "basic"] spawn AP_fnc_handleMessage; };
// owner 2026-07-05: removed the fragile `_vehicle isEqualTo cursorObject` re-check. The scroll-action condition
// already validated this exact wreck, and re-reading cursorObject AFTER the action fires silently misses on large
// wrecks (a Blackfish wreck's center points at a gap/interior -> cursorObject != _vehicle -> silent exit, no kit
// used, nothing happens). The passed _vehicle IS the validated target; trust it.
if (isNil "AP_inv_wreckkit" || {AP_inv_wreckkit < 1}) exitWith { ["You need a Wreckage Recovery Kit.", "basic"] spawn AP_fnc_handleMessage; };
// owner 2026-07-04: only wrecks with an ownership record (AP_dbInfo/dbInfo, set at garage-pull) can be returned
// to a garage. Bail BEFORE the progress bar + kit consume so a kit is never wasted on an un-recoverable wreck.
private _wdb = _vehicle getVariable ["AP_dbInfo", []];
if (count _wdb == 0) then { _wdb = _vehicle getVariable ["dbInfo", []]; };
if (count _wdb < 2) exitWith { ["This wreck has no ownership record -- it can't be recovered.", "basic"] spawn AP_fnc_handleMessage; };

private _vehicleName = getText (configFile >> "CfgVehicles" >> (typeOf _vehicle) >> "displayName");
AP_action_in_use = true;
private _text = format ["Recovering %1", _vehicleName];
5 cutRsc ["AP_progress", "PLAIN"];
private _ui = uiNameSpace getVariable "AP_progress";
private _progress = _ui displayCtrl 38201;
private _pgText = _ui displayCtrl 38202;
_pgText ctrlSetText format ["%2 (1%1)...", "%", _text];
_progress progressSetPosition 0.01;
private _cP = 0.01;
private _success = false;
private _pos = getPos player;
for "_i" from 0 to 1 step 0 do {uiSleep 0.2;
    _cP = _cP + 0.02;
    _progress progressSetPosition _cP;
    _pgText ctrlSetText format ["%3 (%1%2)...", round (_cP * 100), "%", _text];
    // owner 2026-07-15 (live trace, TheFreshRyan x13 attempts, 0 reached the server): standing ON a big
    // settling wreck (Blackfish hull) makes player speed spike >2 and getPos drift in 3D, so the old
    // `speed > 2` + 3D `distance > 4` guards killed the bar on the FIRST tick -- silently. Speed guard
    // dropped (distance is the real anti-walk-away check), drift measured in 2D with more slack, and
    // every abort now SAYS so instead of the bar just vanishing.
    if (player distance2D _pos > 8) exitWith { ["Recovery interrupted -- stay by the wreck.", "basic"] spawn AP_fnc_handleMessage; };
    if (AP_isDowned || player getVariable ["AP_restrained", false] || !alive player) exitWith { ["Recovery interrupted.", "basic"] spawn AP_fnc_handleMessage; };
    if !(AP_action_in_use) exitWith { ["Recovery interrupted.", "basic"] spawn AP_fnc_handleMessage; };
    if !(isNull objectParent player) exitWith { ["Recovery interrupted -- get out of the vehicle.", "basic"] spawn AP_fnc_handleMessage; };
    if (isNull _vehicle) exitWith { ["The wreck is already gone.", "basic"] spawn AP_fnc_handleMessage; };   // another player recovered it
    if (_cP >= 1) exitWith { _success = true; };};
5 cutText ["", "PLAIN"];
AP_action_in_use = false;
if !(_success) exitWith {};
if (isNull _vehicle || {alive _vehicle}) exitWith {};

// consume one kit (fails safe if it vanished mid-progress)
if !([false, "wreckkit", 1] call AP_fnc_handleInv) exitWith { ["You need a Wreckage Recovery Kit.", "basic"] spawn AP_fnc_handleMessage; };

[["-WRECKKIT-", player, profileName, format ["client -> server: veh=%1 dbInfo=%2 (progress done, kit consumed, calling APS_fnc_recoverWreck)", typeOf _vehicle, _vehicle getVariable ["AP_dbInfo", _vehicle getVariable ["dbInfo", []]]]], "APS_fnc_logIt", 2, false, false] spawn AP_fnc_MP;
[[_vehicle], "APS_fnc_recoverWreck", 2] spawn AP_fnc_MP;
[format ["You recovered the %1 to its owner's garage.", _vehicleName], "basic"] spawn AP_fnc_handleMessage;
