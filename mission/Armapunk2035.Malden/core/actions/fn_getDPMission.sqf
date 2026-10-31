params[["_dpID", -1, [0]], ["_type", -1, [0]], ["_npcObj", objNull, [objNull]]];
if (_dpID isEqualTo - 1 || _type isEqualTo - 1 || isNull _npcObj) exitWith {};
if (AP_delivery_inProg) exitWith {
    ["You're currently on a delivery! Complete that delivery and come back!", "basic"] spawn AP_fnc_handleMessage;};
if (time < (AP_last_sold + 2)) exitWith {["Please try again in a few seconds.", "basic"] spawn AP_fnc_handleMessage};
private _typeText =
switch (_type) do {case 1: {"Ground Cargo Shipment"};
    case 2: {"Air Shipment"};
    case 3: {"Small Parcel"};
    case 4: {"Organ Transplant"}}; private _requirement = "truck that can load containers like an Offroad or Hemmt Transport";
if (_type isEqualTo 2) then {_requirement = "heavy lift helicopter like the Taru to lift the container";};
private _exit = false;
if (_type in [1, 2]) then {
    private _confirm = [format["<t align='center'>The %1 delivery mission requires a %2. Would you like to continue?</t>", _typeText, _requirement], "Special Vehicle Required!", "Yes", "No"] call BIS_fnc_guiMessage;
    if !(_confirm) exitWith {_exit = true;};};
if (_exit) exitWith {["You have decided to cancel the delivery mission.", "basic"] spawn AP_fnc_handleMessage;};
private _availablePoints = [];
private _deliveryPoint = -1;
private _dpSpawn = format["dp_%1_spawn", _dpID];
for "_i"
from 1 to 26 do {if !(_i isEqualTo _dpID) then {_availablePoints pushBack _i;};}; _deliveryPoint = selectRandom _availablePoints;
if (_deliveryPoint isEqualTo - 1) exitWith {};
if !(isNull AP_delivery_object) then {deleteVehicle AP_delivery_object;};
private _action = true;
private _nearVehicles = nearestObjects[getMarkerPos _dpSpawn, ["Car", "Truck", "Air", "Ship"], 10];
if (count _nearVehicles > 0) then {
    _action = ["<t align='center'>There appears to be a vehicle near the Delivery Point. It is recommended that you press cancel and move the vehicle away before beginning this mission. Continue anyway?</t>", "Vehicle Nearby!", "Continue", "Cancel"] call BIS_fnc_guiMessage;
};
if !(_action) exitWith {
    ["You have canceled the mission. Move the nearby vehicle and retry the mission", "basic"] spawn AP_fnc_handleMessage;};
if (AP_delivery_inProg) exitWith {
    ["You're currently on a delivery! Complete that delivery and come back!", "basic"] spawn AP_fnc_handleMessage;};
AP_delivery_inProg = true;
AP_delivery_type = _type;
AP_dp_end = missionNamespace getVariable format["dp_%1", _deliveryPoint];
AP_dp_start = (getPos _npcObj);
AP_delivery_StartTime = time;
AP_delivery_object = objNull;
AP_cur_task = player createSimpleTask[format["Deliver the %1 to Delivery Point %2.", _typeText, _deliveryPoint]];
AP_delivery_EndTime = time + (floor(((AP_dp_start distance(getPos AP_dp_end)) * (2.2 / 1000)) * 60));
switch (_type) do {case 1: {AP_delivery_EndTime = time + (floor(((AP_dp_start distance(getPos AP_dp_end)) * (2.2 / 1000)) * 60));
            if (AP_delivery_EndTime < (time + 300)) then {AP_delivery_EndTime = time + 300;};
            // owner 2026-07-13: Slow Poke (72) pruned -- deliveries use base time.
            AP_delivery_object = "Land_CargoBox_V1_F"
            createVehicle(getMarkerPos _dpSpawn);
            AP_delivery_object enableRopeAttach true;
            [AP_delivery_object, (AP_delivery_EndTime - time)] call AP_fnc_setVehicleIdle;
            AP_cur_task setSimpleTaskDescription[format["You are to deliver this Ground Cargo Shipment, using a truck which can haul it, to Delivery Point %1 within %2 minutes. Unload the parcel at the destination when you arrive.", _deliveryPoint, floor((AP_delivery_EndTime - time) / 60)], "Delivery Job", "Delivery Job"];
        };
    case 2: {AP_delivery_EndTime = time + (floor(((AP_dp_start distance(getPos AP_dp_end)) * (1.2 / 1000)) * 60));
            if (AP_delivery_EndTime < (time + 180)) then {AP_delivery_EndTime = time + 180;};
            // owner 2026-07-13: Slow Poke (72) pruned -- deliveries use base time.
            AP_delivery_object = "Land_Cargo10_brick_red_F"
            createVehicle(getMarkerPos _dpSpawn);
            AP_delivery_object setMass 2600;
            AP_delivery_object enableRopeAttach true;
            [AP_delivery_object, (AP_delivery_EndTime - time)] call AP_fnc_setVehicleIdle;
            [AP_delivery_object, (floor(((AP_dp_start distance(getPos AP_dp_end)) * (1.2 / 1000)) * 60))] call AP_fnc_setVehicleIdle;
            AP_cur_task setSimpleTaskDescription[format["You are to deliver this Air Shipment, using a powerful Helicopter, to Delivery Point %1 within %2 minutes. Drop the shipment at the destination when you arrive.", _deliveryPoint, floor((AP_delivery_EndTime - time) / 60)], "Delivery Job", "Delivery Job"];
        };
    case 3: {AP_delivery_EndTime = time + (floor(((AP_dp_start distance(getPos AP_dp_end)) * (1.8 / 1000)) * 60));
            if (AP_delivery_EndTime < (time + 300)) then {AP_delivery_EndTime = time + 300;};
            // owner 2026-07-13: Slow Poke (72) pruned -- deliveries use base time.
            AP_delivery_object = objNull;
            AP_cur_task setSimpleTaskDescription[format["Deliver this Small Parcel to Delivery Point %1 within %2 minutes.", _deliveryPoint, floor((AP_delivery_EndTime - time) / 60)], "Delivery Job", "Delivery Job"];
        };
    case 4: {AP_delivery_EndTime = time + (floor(((AP_dp_start distance(getPos AP_dp_end)) * (2.2 / 1000)) * 60));
            if (AP_delivery_EndTime < (time + 300)) then {AP_delivery_EndTime = time + 300;};
            AP_delivery_object = objNull;
            AP_cur_task setSimpleTaskDescription[format["Deliver this Human Organ to Delivery Point %1 within %2 minutes.", _deliveryPoint, floor((AP_delivery_EndTime - time) / 60)], "Delivery Job", "Delivery Job"];
        };}; AP_cur_task setSimpleTaskDestination(getPos AP_dp_end);
AP_cur_task setTaskState "Assigned";
player setCurrentTask AP_cur_task;
["DeliveryAssigned", [format["Deliver this package to DP %1.", _deliveryPoint]]] call BIS_fnc_showNotification; [
    ["-DPMISSION-", player, (profileName), format["started a dp mission from %3(%1) to %4(%2).", AP_dp_start, (getPos AP_dp_end), _dpID, _deliveryPoint]], "APS_fnc_logIt", 2, false, false] spawn AP_fnc_MP;
[] spawn {disableSerialization;
    8 cutRsc["dp_timer", "PLAIN"];
    private _color = [0.36, 0.14, 0.69, 1];
    private _display = uiNamespace getVariable "dp_timer";
    private _timer = _display displayCtrl 38311;
    _timer ctrlSetTextColor _color;
    while {AP_delivery_inProg}
    do {if (isNull _display) then {8 cutRsc["dp_timer", "PLAIN"];
            _display = uiNamespace getVariable "dp_timer";
            _timer = _display displayCtrl 38312;
            _timer ctrlSetTextColor _color;};
        if !(AP_delivery_inProg) exitWith {};
        if (round(AP_delivery_EndTime - time) < 1) exitWith {};
        _timer ctrlSetText format["%1", [(AP_delivery_EndTime - time), "MM:SS"] call BIS_fnc_secondsToString];
        uiSleep 0.09;}; 8 cutText["", "PLAIN"];};
uiSleep 1;
[] spawn {
    (findDisplay 12 displayCtrl 51) ctrlAddEventHandler["Draw", "(_this select 0) drawLine [getPos player,getPos AP_dp_end,[0,0,1,1]];"];
    while {
        AP_delivery_inProg && alive player && time <= AP_delivery_EndTime && (AP_delivery_type in [3, 4] || !isNull AP_delivery_object)
    }
    do {uiSleep 1;
        if (vehicle player != player) then {AP_dp_vehicle = vehicle player};}; waitUntil {uiSleep 1;
        !alive player;
        if !(AP_delivery_inProg) exitWith {true};
        if (time >= AP_delivery_EndTime) exitWith {true};
        if (AP_delivery_type in [1, 2] && isNull AP_delivery_object) exitWith {true};};
    (findDisplay 12 displayCtrl 51) ctrlRemoveAllEventHandlers "Draw";
    if (AP_delivery_inProg) then {AP_cur_task setTaskState "Failed";
        player removeSimpleTask AP_cur_task;
        AP_delivery_inProg = false;
        8 cutText["", "PLAIN"];
        switch (true) do {case !(alive player): {
                    ["DeliveryFailed", ["You failed to deliver the package because you died."]] call BIS_fnc_showNotification;};
            case (time >= AP_delivery_EndTime): {
                    ["DeliveryFailed", ["Your package is late. You've failed!"]] call BIS_fnc_showNotification;};
            case (isNull AP_delivery_object): {
                    ["DeliveryFailed", ["Your cargo has been lost. You've failed!"]] call BIS_fnc_showNotification;};
            default {["DeliveryFailed", ["You've failed to deliver the package!"]] call BIS_fnc_showNotification;};
        }; if !(isNull AP_delivery_object) then {deleteVehicle AP_delivery_object;
            AP_delivery_object = objNull;};
        AP_dp_start = [0, 0, 0];
        AP_dp_end = objNull;
        AP_delivery_object = objNull;
        AP_delivery_inProg = false;
        AP_delivery_type = -1;
        AP_delivery_StartTime = -1;
        AP_delivery_EndTime = -1;
        AP_cur_task = taskNull;};};