params[["_dpID", -1, [0]], ["_npcObj", objNull, [objNull]]];
if (_dpID isEqualTo - 1 || isNull _npcObj) exitWith {};
if !(_npcObj isEqualTo AP_dp_end) exitWith {["You are not at the correct delivery mission npc!", "basic"] spawn AP_fnc_handleMessage;};
if !(AP_delivery_inProg) exitWith {["You are not on a delivery right now!", "basic"] spawn AP_fnc_handleMessage;};
if !(AP_delivery_type in [1, 2, 3, 4]) exitWith {};
if (!(AP_delivery_type in [3, 4]) && {isNull AP_delivery_object}) exitWith {
    ["Your cargo to deliver seems to have been lost or has disappeared...", "basic"] spawn AP_fnc_handleMessage;};
if (AP_delivery_type in [1, 2] && {(AP_delivery_object distance _npcObj) > 30}) exitWith {
    ["Your cargo is too far away from me! Please move the cargo container closer.", "basic"] spawn AP_fnc_handleMessage;};
if (AP_delivery_type in [1, 2] && {((getPos AP_delivery_object) select 2) > 0.15}) exitWith {
    ["Your cargo is too high in the air, please bring it closer to the ground.", "basic"] spawn AP_fnc_handleMessage;};
if (AP_delivery_type in [1, 2] && {!(isNull(ropeAttachedTo AP_delivery_object))}) exitWith {
    ["Your container is still attached to the vehicle, please release it first.", "basic"] spawn AP_fnc_handleMessage;};
if !(isNull AP_delivery_object) then {deleteVehicle AP_delivery_object;
    AP_delivery_object = objNull;};
private _distance = AP_dp_start distance(getPos AP_dp_end);
private _payOut = round(0.3 * _distance);
private _payIncrease = 1;
if (32 in AP_side_talents) then {_payIncrease = _payIncrease + 0.10;};
if (AP_delivery_type isEqualTo 3 && {125 in AP_side_talents}) then {_payIncrease = _payIncrease + 0.15;};
if (AP_delivery_type isEqualTo 1 && {33 in AP_side_talents}) then {_payIncrease = _payIncrease + 0.20;};
if (AP_delivery_type isEqualTo 2 && {34 in AP_side_talents}) then {_payIncrease = _payIncrease + 0.25;};
_payOut = (_payOut * _payIncrease);
private _timeToDeliver = [(time - AP_delivery_StartTime), "MM:SS", true] call BIS_fnc_secondsToString;
["DeliverySucceeded", [format["You have earned $%1.", [_payOut] call AP_fnc_numberText]]] call BIS_fnc_showNotification;
if (127 in AP_side_talents) then {
    [format["You have completed the delivery mission in %1 Minutes %2 seconds! You have recieved $%3 for your delivery efforts! Due to your talent configuration half the payment has been sent to your bank account and the other half is on-hand.", _timeToDeliver select 0, _timeToDeliver select 1, [_payOut] call AP_fnc_numberText]] spawn AP_fnc_handleMessage;
    AP_atmcash = round(AP_atmcash + round(_payOut / 2)) max 0;
    AP_atmcashCacheB = ((AP_atmcash / 4) + 11);
    AP_cash = round(AP_cash + round(_payOut / 2)) max 0;
    AP_cashCacheB = ((AP_cash / 4) + 9);} else {
    [format["You have completed the delivery mission in %1 Minutes %2 seconds! You have recieved $%3 for your delivery efforts!", _timeToDeliver select 0, _timeToDeliver select 1, [_payOut] call AP_fnc_numberText]] spawn AP_fnc_handleMessage;
    AP_cash = round(AP_cash + _payOut) max 0;
    AP_cashCacheB = ((AP_cash / 4) + 9);};
[6] call AP_fnc_ClupdatePartial;
AP_side_exp = AP_side_exp + 25;
AP_cur_task setTaskState "Succeeded";
player removeSimpleTask AP_cur_task;
["action", "dpmission", 1] call AP_fnc_handleQuest; [
    ["-DPMISSION-", player, (profileName), format["completed a Delivery Mission (%1) from %2 to %3 in %4 Mins %5 Seconds and recieved $%6", AP_delivery_type, AP_dp_start, (getPos AP_dp_end), _timeToDeliver select 0, _timeToDeliver select 1, [_payOut] call AP_fnc_numberText]], "APS_fnc_logIt", 2, false, false] spawn AP_fnc_MP;
AP_delivery_inProg = false;
AP_dp_start = [0, 0, 0];
AP_dp_end = objNull;
AP_delivery_object = objNull;
AP_delivery_type = -1;
AP_delivery_StartTime = -1;
AP_delivery_EndTime = -1;
AP_cur_task = taskNull;
AP_last_sold = time;