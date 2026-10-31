params[["_type", "self", [""]], ["_source", nil, [objNull, nil]], ["_unit", player, [objNull]]];
if ((vehicle player isKindOf "Steerable_Parachute_F") || !(vest player isEqualTo "V_HarnessOGL_brn")) exitWith {};
if ((player getVariable["AP_surrendered", false]) && {_type isEqualTo "self"}) exitWith {
    ["The detonator isn't up in the air bro.", "basic"] spawn AP_fnc_handleMessage;};
if ((player getVariable["AP_restrained", false]) && {_type isEqualTo "self"}) exitWith {
    ["You can't reach the detonator to join Allah!", "basic"] spawn AP_fnc_handleMessage;};
// owner 2026-06-19 (#401): no detonating from jail (defensive -- the vest is now confiscated on jail entry/release,
// but block self-detonation while serving time regardless of how the vest got there).
if (((AP_is_arrested param [0, 0]) isEqualTo 1) && {_type isEqualTo "self"}) exitWith {
    ["You can't reach the detonator behind bars.", "basic"] spawn AP_fnc_handleMessage;};
if ((_type isEqualTo "self") && {!(isNull objectParent player)}) exitWith {
    ["You cannot detonate your vest from within a vehicle.", "basic"] spawn AP_fnc_handleMessage;};
if (!((animationState player find "halofreefall") isEqualTo - 1) && (_type isEqualTo "self")) exitWith {
    ["You cannot reach the detonator if you're free falling!", "basic"] spawn AP_fnc_handleMessage;};
private _pos =
if (surfaceIsWater(getPosATL player)) then {getPosASL player} else {getPosATL player};
if (_type isEqualTo "self" && {_pos select 2 > 25 || (getPos player) select 2 > 4}) exitWith {
    ["You cannot detonate your vest when not on the ground.", "basic"] spawn AP_fnc_handleMessage;};
if (_type isEqualTo "shot" && {(getPosATL player) select 2 > 20}) exitWith {private _plb_dmg = vehicle player;
    _plb_dmg setDamage 1; [
        [0, format["%1 was shot by %2 causing their suicide vest to explode!", profileName, name _source]], "AP_fnc_broadcast", -2, false, false] spawn AP_fnc_MP;
    AP_dead_gear set[5, ""];};
removeVest player;
if ((_type isEqualTo "shot") && !(isNull objectParent player)) then {_unit = vehicle player};
// owner 2026-07-24: bigger blast that levels a shed from the outside.
//
// ROOT CAUSE of the earlier "no explosion, I just die": the custom mission-side CfgAmmo subclass
// (AP_vestBlast) is NOT spawnable -- createVehicle returned "Cannot create non-ai vehicle
// 'AP_vestBlast'" (client RPT, this line). createVehicle needs a GAME/addon-defined class; a
// mission-config ammo class can't be instantiated (same family of limitation as the Ifrit turret
// override), so a single ammo's damage can't be scaled here. Instead STACK three vanilla Bo_GBU12_LGB
// bombs -- the codebase's proven explosion (fn_loveBombSRV / fn_ignitionBombSRV / fn_eventIceCreamSRV),
// and the same warhead the vest originally used as Bo_Mk82. Three overlapping detonations ~= 3x damage
// and the shed's structure takes all three hits. Spawned +2m up (motorless bombs detonate on the short
// fall to ground -- no rocket-motor slam needed) with a small spread so the whole shed footprint is
// covered. TUNE: bump the loop count if a tougher shed survives.
private _boomPos = getPosATL _unit;
for "_i" from 1 to 3 do {"Bo_GBU12_LGB" createVehicle (_boomPos vectorAdd [(_i - 2) * 0.6, 0, 2]);};
private _damageRadius = 10;
private _nearVehicles = nearestObjects[_unit, ["Car", "Truck", "Air", "Ship"], _damageRadius]; {_x setDamage 1;}
forEach _nearVehicles;
private _plb_dmg = player;
if (alive player) then {_plb_dmg setDamage 1;};
AP_dead_gear set[5, ""];
if (_type isEqualTo "self") then {[[1, player], "APS_fnc_wantedAdd", false, false] spawn AP_fnc_MP; [
        [0, format["%1 has detonated their suicide vest.", profileName]], "AP_fnc_broadcast", -2, false, false] spawn AP_fnc_MP;};
if (_type isEqualTo "shot") then {[
        [0, format["%1 was shot by %2 causing their suicide vest to explode!", profileName, name _source]], "AP_fnc_broadcast", -2, false, false] spawn AP_fnc_MP;
    if (group player isEqualTo group _source) then {[[2, player], "APS_fnc_wantedAdd", false, false] spawn AP_fnc_MP;};};
private _copCount = count(allPlayers select {side _x isEqualTo west && ((_x distance _unit) < 15)});
if (_copCount > 0) then {["civ_cops_vested", _copCount] call AP_fnc_statArrUpdate;};
["suivest", 1] call AP_fnc_statArrUpdate;
player setVariable["AP_suicideVestDeath", true, true]; [
    ["-SUICIDEVEST-", _unit, (name _unit), format["detonated their suicide vest (%1), POS: %2.", _type, (getPos _unit)]], "APS_fnc_logIt", 2, false, false] spawn AP_fnc_MP;