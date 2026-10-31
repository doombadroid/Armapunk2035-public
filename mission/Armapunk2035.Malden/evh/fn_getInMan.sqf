params["_unit", "_role", "_vehicle", "_turret"];
if ((_role isEqualTo "driver")) then {[_vehicle, 900] call AP_fnc_setVehicleIdle;
    // LoonyBin: silent top-left tip on taking the driver seat (trunk-persistence reminder).
    ["Vehicle inventory saves when garaged, illegal drugs do not.", "basic"] spawn AP_fnc_handleMessage;};
[] call AP_fnc_updateViewDistance;
if !(isNull AP_holding_barrel) then {[] call AP_fnc_dropOil};
if ((AP_is_arrested param [0,0]) isEqualTo 1) exitWith {moveOut player;};
if (player getVariable["AP_surrendered", false]) exitWith {moveOut player;};
if (AP_effSide isEqualTo civilian && {_vehicle getVariable["AP_side", ""] == "med"}) exitWith {if (_vehicle isKindOf "Air") then {
        _vehicle enableCopilot false;};
    if (driver _vehicle isEqualTo player || ([player] call AP_fnc_isUnitCopilot)) then {moveOut player;
        ["Only trained Medical and Fire personnel are able to operate this vehicle!", "basic"] spawn AP_fnc_handleMessage;};};
private _isFrit = typeOf _vehicle isEqualTo "O_MRAP_02_F";
if ((_vehicle getVariable["AP_mentalTruck", false]) && (_vehicle getVariable["AP_mentalCarLocked", true])) exitWith {moveOut player;
    ["The Loony Bin Truck can't be driven whilst the tomb is locked, slacker!", "basic"] spawn AP_fnc_handleMessage;};
if ((_vehicle getVariable["AP_mobileHeadQuartersTruckLocked", false])) exitWith {moveOut player;
    ["The mobile headquarters can not be moved whilst it is deployed", "basic"] spawn AP_fnc_handleMessage;};
if ((_vehicle getVariable["AP_timeTrialVehicle", false]) && (_vehicle getVariable["AP_vehOwners", []]) isNotEqualTo[]) then {
    if (((_vehicle getVariable["AP_vehOwners", []] param[0]) param[0]) != getPlayerUID player) exitWith {moveOut player;
        ["This is not your time trial vehicle! Get your own!", "basic"] spawn AP_fnc_handleMessage;};
    if (((_vehicle getVariable["AP_vehOwners", []] param[0]) param[0]) == getPlayerUID player && !(player getVariable["AP_timeTrialActive", false])) exitWith {
        moveOut player;
        ["You have already finished or failed your time trial, this vehicle is in a 'destructive' state", "basic"] spawn AP_fnc_handleMessage;
    };};
if (AP_inEvent && !((typeOf _vehicle) isEqualTo "Steerable_Parachute_F")) exitWith {moveOut player;
    ["You cannot enter vehicles during an admin event.", "basic"] spawn AP_fnc_handleMessage;};
if (AP_action_in_use) exitWith {moveOut player;
    ["You can't get in while doing something else!", "basic"] spawn AP_fnc_handleMessage;};
if (typeOf _vehicle isEqualTo "C_Tractor_01_F") then {[_vehicle] spawn AP_fnc_tractorMine;};
if (_vehicle isKindOf "Air" && AP_inv_goldbar > 0 && !((player getVariable["AP_restrained", false]) && !(player getVariable["AP_civRestrained", false]))) then {
    moveOut player;
    ["You may not enter an air vehicle while carrying gold bars. They're too heavy!", "basic"] spawn AP_fnc_handleMessage;};
if (headgear player == "H_PilotHelmetHeli_O" && !(_vehicle isKindOf "Air")) exitWith {removeHeadgear player;};
_vehicle addEventHandler["Killed", {params["_vehicle"];
    [_vehicle] spawn {params["_vehicle"];
        waitUntil {uiSleep 1;
            (speed _vehicle isEqualTo 0) && !(alive _vehicle)};
        uiSleep 5;
        if (AP_corpse in (crew _vehicle)) then {AP_corpse moveOut _vehicle;};};}];
[_vehicle] spawn {params["_vehicle"];
    private _metersDrove = 0;
    while {!(isNull _vehicle) && (alive _vehicle) && (player in (crew _vehicle)) && !(AP_isDead)}
    do {private _startPos = (getPosATL _vehicle);
        uiSleep 1;
        if ((isNull _vehicle) || !(alive _vehicle) || !(player in (crew _vehicle)) || (AP_isDead)) exitWith {};
        private _endPos = (getPosATL _vehicle);
        _metersDrove = _metersDrove + (_startPos distance2D _endPos);}; if (_metersDrove isNotEqualTo 0) then {
        ["distancedrove", _metersDrove] call AP_fnc_statArrUpdate;};};
AP_dynamicMap_lastVehicle = _vehicle;
[_vehicle] spawn AP_fnc_dynamicMapVehicleFix;