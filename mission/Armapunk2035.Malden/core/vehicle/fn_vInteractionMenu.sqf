if !(dialog) then {["genericInteractionMenu"] call AP_fnc_createDialog;};
disableSerialization;
params[["_curTarget", objNull, [objNull]]];
if (isNull _curTarget || !alive _curTarget) exitWith {closeDialog 0;};
_isVehicle =
if ((_curTarget isKindOf "landVehicle") || (_curTarget isKindOf "Ship") || (_curTarget isKindOf "Air")) then {true} else {false};
if (!_isVehicle) exitWith {closeDialog 0;};
private _display = findDisplay 37400;
private _title = _display displayCtrl 37401;
private _Btn1 = _display displayCtrl 37450;
private _Btn2 = _display displayCtrl 37451;
private _Btn3 = _display displayCtrl 37452;
private _Btn4 = _display displayCtrl 37453;
private _Btn5 = _display displayCtrl 37454;
private _Btn6 = _display displayCtrl 37455;
AP_vInact_curTarget = _curTarget;
_title ctrlSetText "Vehicle Interaction Menu";
_Btn1 ctrlSetText "Repair Vehicle";
_Btn1 buttonSetAction "[AP_vInact_curTarget] spawn AP_fnc_repairTruck;";
if ("ToolKit" in (items player) && (damage _curTarget < 1)) then {_Btn1 ctrlEnable true;} else {_Btn1 ctrlEnable false;};
if (AP_effSide isEqualTo west) then {_Btn2 ctrlSetText "Registration";
    _Btn2 buttonSetAction "[AP_vInact_curTarget] spawn AP_fnc_searchVehAction;";
    _Btn3 ctrlSetText "Search Vehicle";
    _Btn3 buttonSetAction "[AP_vInact_curTarget] spawn AP_fnc_vehicleInvSearch;";
    _Btn4 ctrlSetText "Pullout Players";
    _Btn4 buttonSetAction "[AP_vInact_curTarget] spawn AP_fnc_pulloutAction;";
    if (count crew _curTarget isEqualTo 0) then {_Btn4 ctrlEnable false;};
    if !(typeOf _curTarget in ["O_MRAP_02_F", "I_C_Offroad_02_LMG_F", "O_LSV_02_armed_F", "B_G_Offroad_01_armed_F"]) then {
        _Btn5 ctrlSetText "Impound Vehicle";
        _Btn5 buttonSetAction "[false, AP_vInact_curTarget] spawn AP_fnc_impoundAction;";} else {_Btn5 ctrlSetText "Seize Vehicle";
        _Btn5 buttonSetAction "[true, AP_vInact_curTarget] spawn AP_fnc_impoundAction;";};
    if (_curTarget isKindOf "Ship") then {_Btn6 ctrlSetText "Push Boat";
        _Btn6 buttonSetAction "[] spawn AP_fnc_pushObject; closeDialog 0;";
        if (_curTarget isKindOf "Ship" && {local _curTarget} && {count crew _curTarget isEqualTo 0}) then {_Btn6 ctrlEnable true;} else {
            _Btn6 ctrlEnable false};} else {
        if (typeOf(_curTarget) in ["C_Kart_01_Blu_F", "C_Kart_01_Red_F", "C_Kart_01_Fuel_F", "C_Kart_01_Vrana_F"]) then {
            _Btn6 ctrlSetText "Get In Kart";
            _Btn6 buttonSetAction "player moveInDriver AP_vInact_curTarget; closeDialog 0;";
            if (count crew _curTarget isEqualTo 0 && {canMove _curTarget} && {locked _curTarget isEqualTo 0}) then {_Btn6 ctrlEnable true;
            } else {_Btn6 ctrlEnable false};} else {_Btn6 ctrlSetText "Unflip Vehicle";
            _Btn6 buttonSetAction "[cursorTarget] spawn AP_fnc_flip; closeDialog 0;";
            if (count crew _curTarget isEqualTo 0 && {canMove _curTarget}) then {_Btn6 ctrlEnable false;} else {_Btn6 ctrlEnable true;};};
    };} else {if (_curTarget isKindOf "Ship") then {_Btn2 ctrlSetText "Push Boat";
        _Btn2 buttonSetAction "[] spawn AP_fnc_pushObject; closeDialog 0;";
        if (_curTarget isKindOf "Ship" && {local _curTarget} && {count crew _curTarget isEqualTo 0}) then {_Btn2 ctrlEnable true;} else {
            _Btn2 ctrlEnable false};} else {
        if (typeOf(_curTarget) in ["C_Kart_01_Blu_F", "C_Kart_01_Red_F", "C_Kart_01_Fuel_F", "C_Kart_01_Vrana_F"]) then {
            _Btn2 ctrlSetText "Get In Kart";
            _Btn2 buttonSetAction "player moveInDriver AP_vInact_curTarget; closeDialog 0;";
            if (count crew _curTarget isEqualTo 0 && {canMove _curTarget} && {locked _curTarget isEqualTo 0}) then {_Btn2 ctrlEnable true;
            } else {_Btn2 ctrlEnable false};} else {_Btn2 ctrlSetText "Unflip Vehicle";
            _Btn2 buttonSetAction "[cursorTarget] spawn AP_fnc_flip; closeDialog 0;";
            if (count crew _curTarget isEqualTo 0 && {canMove _curTarget}) then {_Btn2 ctrlEnable false;} else {_Btn2 ctrlEnable true;};};
    };
    if (typeOf _curTarget == "O_Truck_03_device_F") then {_Btn3 ctrlSetText "Mine from device";
        _Btn3 buttonSetAction "[AP_vInact_curTarget] spawn AP_fnc_deviceMine";
        if (!(objNull isEqualTo(cursorObject getVariable["AP_mining", objNull])) || !local _curTarget && {_curTarget in AP_vehicles
        }) then {_Btn3 ctrlEnable false;} else {_Btn3 ctrlEnable true;};} else {_Btn3 ctrlShow false;};
    _Btn4 ctrlShow false;
    _Btn5 ctrlShow false;
    _Btn6 ctrlShow false;};