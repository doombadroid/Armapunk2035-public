if (AP_effSide isEqualTo civilian && !(30 in AP_side_talents)) exitWith {
    ["You don't have the talent to work with such weaponry.", "basic"] spawn AP_fnc_handleMessage;};
if (isNull objectParent player) exitWith {
    ["You have to be inside the vehicle gunner seat to use this.", "basic"] spawn AP_fnc_handleMessage;};
if !(typeOf(vehicle player) in ["B_G_Offroad_01_armed_F", "O_LSV_02_armed_F", "I_C_Offroad_02_LMG_F", "O_MRAP_02_F", "I_MRAP_03_F"]) exitWith {
    ["The ammunition does not fit this vehicles weapons.", "basic"] spawn AP_fnc_handleMessage;};
if !([false, "vammo", 1] call AP_fnc_handleInv) exitWith {};
disableSerialization;
5 cutRsc["AP_progress", "PLAIN"];
private _text = "Reloading vehicle weapon...";
private _ui = uiNamespace getVariable "AP_progress";
private _progress = _ui displayCtrl 38201;
private _pgText = _ui displayCtrl 38202;
_pgText ctrlSetText format["%2 (1%1)...", "%", _text];
_progress progressSetPosition 0.01;
private _cP = 0.01;
private _success = false;
AP_action_in_use = true;
for "_i"
from 0 to 1 step 0 do {uiSleep 0.09;
    _cP = _cP + 0.01;
    _progress progressSetPosition _cP;
    _pgText ctrlSetText format["%3 (%1%2)...", round(_cP * 100), "%", _text];
    if (_cP >= 1) exitWith {_success = true;};
    if (player == (vehicle player)) exitWith {};
    if (!alive player) exitWith {};
    if (!AP_action_in_use) exitWith {};}; 5 cutText["", "PLAIN"];
AP_action_in_use = false;
if !(_success) exitWith {};
AP_side_exp = AP_side_exp + 20;
_vehicle = (vehicle player);
if ((typeOf _vehicle) in ["O_MRAP_02_F", "I_MRAP_03_F"]) then {private _turret =
    if (typeOf _vehicle == "O_MRAP_02_F") then {[-1]} else {[0]};
    private _emptySmoke =
    if (typeOf _vehicle == "O_MRAP_02_F") then {((magazinesAllTurrets _vehicle) select 0) select 2;} else {
        ((magazinesAllTurrets _vehicle) select 1) select 2;};
    if (_emptySmoke isEqualTo 0) then {_vehicle setVehicleAmmoDef 1;
        _vehicle addMagazineTurret["SmokeLauncherMag", _turret];} else {for "_i"
        from 0 to 1 do {_vehicle addMagazineTurret["SmokeLauncherMag", _turret];};};
    ["Vehicle smokes have been reloaded.", "basic"] spawn AP_fnc_handleMessage;} else {
    if ((typeOf _vehicle) isEqualTo "B_G_Offroad_01_armed_F") then {private _vehMag = ((magazinesAllTurrets _vehicle) select 0) select 0;
        _vehicle setVehicleAmmo 0;
        _vehicle setVehicleAmmo 1;
        for "_i"
        from 1 to 3 do {_vehicle addMagazineTurret[_vehMag, [0]];};} else {_vehicle setVehicleAmmoDef 1;};
    ["Vehicle weapons have been reloaded.", "basic"] spawn AP_fnc_handleMessage;};