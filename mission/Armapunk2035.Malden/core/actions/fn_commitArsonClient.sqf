params[["_houseObj", objNull, [objNull]]];
if !(SRV_HousesSetup) exitWith {
    ["The server is still initializing houses... please standby and try again later", "basic"] spawn AP_fnc_handleMessage;};
if (isNull _houseObj) exitWith {["Something went wrong, this house is not an object!"] spawn AP_fnc_handleMessage;};
if (_houseObj getVariable["AP_restricted_house", false]) exitWith {
    ["This house cannot be burned down.", "basic"] spawn AP_fnc_handleMessage;};
if (side player != civilian) exitWith {["I am pretty sure you should not be using this.", "basic"] spawn AP_fnc_handleMessage;};
if !(alive _houseObj) exitWith {["Whats the point in setting a broken house on fire? Go look somewhere else"] spawn AP_fnc_handleMessage;
};
if (player distance _houseObj > 10) exitWith {
    ["You can't light a fire from this far away!, you do not have the force!"] spawn AP_fnc_handleMessage;};
if (_houseObj in SRV_houseOnFire) exitWith {
    ["You are burning to a crisp, get out of here! This house is already on fire"] spawn AP_fnc_handleMessage;};
if (count SRV_houseOnFire >= 5) exitWith {
    ["There is too many housefires ongoing right now, give the fire brigade a break will ya!"] spawn AP_fnc_handleMessage;};
if !([false, "arsonistkit", 1] call AP_fnc_handleInv) exitWith {
    ["You don't have an arsonist kit in your inventory!"] spawn AP_fnc_handleMessage;};
disableSerialization;
5 cutRsc["AP_progress", "PLAIN"];
private _text = "Lighting a fire";
private _ui = uiNamespace getVariable "AP_progress";
private _progress = _ui displayCtrl 38201;
private _pgText = _ui displayCtrl 38202;
_pgText ctrlSetText format["%2 (1%1)...", "%", _text];
_progress progressSetPosition 0.01;
private _cP = 0.01;
private _success = false;
AP_action_in_use = true; [["Acts_TerminalOpen", 30, "switchMove", player], "AP_fnc_handleAnim", (allPlayers select {
        (_x distance player) <= 100})] spawn AP_fnc_MP;
for "_i"
from 0 to 1 step 0 do {uiSleep 0.12;
    _cP = _cP + 0.01;
    _progress progressSetPosition _cP;
    _pgText ctrlSetText format["%3 (%1%2)...", round(_cP * 100), "%", _text];
    if (_cP >= 1) exitWith {_success = true;};
    if (speed player > 0) exitWith {["You have failed commiting arson due to movement."] spawn AP_fnc_handleMessage;};
    if !(alive player) exitWith {};
    if !(alive _houseObj) exitWith {};
    if !(AP_action_in_use) exitWith {};};
["", 0 , "switchMove", player] spawn AP_fnc_handleAnim;
5 cutText["", "PLAIN"];
AP_action_in_use = false;
if (count SRV_houseOnFire >= 5) then {
    ["There are too many housefires ongoing right now, give the fire brigade a break will ya!"] spawn AP_fnc_handleMessage;
    _success = false;};
if !(_success) exitWith {[true, "arsonistkit", 1] call AP_fnc_handleInv;};
AP_side_exp = AP_side_exp + 20;
["action", "commitarson", 1] call AP_fnc_handleQuest; [[79, player], "APS_fnc_wantedAdd", 2] spawn AP_fnc_MP; [
    ["initArson", [_houseObj]], "APS_fnc_medicFireSRV", 2] spawn AP_fnc_MP;