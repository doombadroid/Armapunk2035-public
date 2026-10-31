params["_unit", "_role", "_vehicle", "_turret"];
// owner 2026-06-23: a RESTRAINED prisoner can't exit the car they're being TRANSPORTED in -- snap them back. Was:
// only a LOCKED car blocked it (engine), so they hopped out of UNLOCKED ones and ran. AP_transporting is set when
// a cop "Put in Vehicle" (fn_putInVeh) and CLEARED by the cop's "Pull out of vehicle" (fn_pullOutVeh) BEFORE the
// eject -> legit extraction still works; only a SELF-eject (escape) is snapped back. Skip if the vehicle is dead so
// an explosion-eject doesn't teleport them into a wreck. moveInCargo (instant) -> minimal flicker.
if ((_unit getVariable ["AP_restrained", false]) && {_unit getVariable ["AP_transporting", false]} && {alive _vehicle}) exitWith {
    _unit moveInCargo _vehicle;
    titleText ["You're restrained -- you can't get out.", "PLAIN"];
    titleFadeOut 3;};
AP_nextAlert = diag_tickTime + 10;
if (_role isEqualTo "driver") then {[_vehicle, 900] call AP_fnc_setVehicleIdle;};
[] call AP_fnc_updateViewDistance;
if ((_vehicle isKindOf "Air") && (currentWeapon player == "launch_RPG7_F")) then {player action["WeaponOnBack", player];};
private _isFrit = typeOf _vehicle isEqualTo "O_MRAP_02_F";
_vehicle removeEventHandler["Killed", 0];