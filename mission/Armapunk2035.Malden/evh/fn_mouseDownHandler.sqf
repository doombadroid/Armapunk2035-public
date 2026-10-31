#include "..\macro.h"
if (AP_hornCooldown > time) exitWith {};
params["_ctrl", "_code"];
private _vehicle = vehicle player;
if (isNull objectParent player || dialog || visibleMap || !(driver _vehicle isEqualTo player)) exitWith {};
private _handled = false;
private _delay = 5;
private _sound = "";
private _vehicleClassname = typeOf _vehicle;
if (_code isEqualTo 0) then {if (AP_effSide isEqualTo west && {(call AP_copLevel) >= 5} && {
        _vehicleClassname in ["B_MRAP_01_F", "I_MRAP_03_F", "O_MRAP_02_F", "O_APC_Wheeled_02_rcws_v2_F"]} && {
        (((_vehicle getVariable["AP_mods", [0, 0, 0, 0, 0, 0, 0, 0, 0]]) select 3) isEqualTo 0)}) exitWith {_sound = "airhorn";
        _delay = 3;
        _handled = true;};
    if (AP_effSide isEqualTo independent && {(call AP_medicLevel) >= 3} && {
        _vehicleClassname in ["O_Truck_03_medical_F", "I_MRAP_03_F", "O_Truck_03_fuel_F"]} && {
        (((_vehicle getVariable["AP_mods", [0, 0, 0, 0, 0, 0, 0, 0, 0]]) select 3) isEqualTo 0)}) exitWith {_sound = "medicAirhorn";
        _handled = true;};
    if ((_vehicleClassname isEqualTo "C_Hatchback_01_sport_F") && {("lc3_lee_" in (getObjectTextures _vehicle param[0, ""]))}) exitWith {
        _sound = "dixiehorn";
        _delay = 4;
        _handled = true;};
    if !(((_vehicle getVariable["AP_mods", [0, 0, 0, 0, 0, 0, 0, 0, 0]]) select 3) isEqualTo 0) exitWith {
        private _horn = _vehicle getVariable["AP_mods", [0, 0, 0, 0, 0, 0, 0, 0, 0]] select 3;
        private _hornArray = [2, _horn] call AP_fnc_hornCfg;
        if (_hornArray isEqualTo - 1) exitWith {_handled = false;};
        _sound = _hornArray select 4;
        _delay = _hornArray select 5;
        if !(_sound isEqualTo "") then {_handled = true;};};};
if (_handled) then {private _horn = (weapons _vehicle) param[0, ""];
    if ("horn" in (toLower _horn)) then {_vehicle removeWeaponGlobal _horn};
    private _toSend = (allPlayers - [allDeadMen]) select {(_x distance player) <= 650}; [
        [_vehicle, _sound], "AP_fnc_horn", _toSend] spawn AP_fnc_MP;
    AP_hornCooldown = time + _delay;};
_handled