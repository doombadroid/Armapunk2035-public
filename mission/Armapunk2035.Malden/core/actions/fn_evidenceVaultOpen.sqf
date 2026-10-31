params["_target", "_caller", "_actionId", "_arguments"];
if !(AP_effSide isEqualTo civilian) exitWith {["You must be a civilian!", "basic"] spawn AP_fnc_handleMessage;};
if ((SRV_evidence_status select 1) || !(SRV_evidence_status select 0)) exitWith {
    ["You must hack the electric fence first.", "basic"] spawn AP_fnc_handleMessage;};
if (AP_evidence_dome getVariable["AP_vaultBreached", false]) exitWith {
    ["The vault is already breached..", "basic"] spawn AP_fnc_handleMessage;};
if (AP_inv_demoCharge <= 0) exitWith {["You need a demo charge to breach.", "basic"] spawn AP_fnc_handleMessage;};
// LooneyBin: the "armory_vault" marker does not exist in this mission (getMarkerPos -> [0,0,0],
// nearestObject hunted at the map corner and the breach charge spawned in the sea). Use the dome's
// known position (same anchor as fn_evidenceSystems case 2 / the server laptop block).
AP_evidence_dome = nearestObject[[20898.6, 19221.7, 0.00143909], "Land_Dome_Big_F"];
disableSerialization;
5 cutRsc["AP_progress", "PLAIN"];
private _display = uiNameSpace getVariable["AP_progress", displayNull];
private _progressBar = _display displayCtrl 38201;
private _progressText = _display displayCtrl 38202;
AP_action_in_use = true;
private _increment = 1;
private _totalTime = 30;
private _currentPoint = 0;
private _loopDelay = _totalTime / floor(100 / _increment);
private _text = "Breaching Evidence Lockup";
private _startCount = 0;
_progressBar progressSetPosition _startCount;
_progressText ctrlSetText format["%1 (%2%3)", _text, _startCount, "%"];
private _duration = 20;
private _animation = "AinvPknlMstpSnonWnonDnon_medic_1";
[_animation, _duration] spawn AP_fnc_handleAnim;
private _isSuccess =
for "_i"
from 0 to 1 step 0 do {uiSleep _loopDelay;
    if (isNull _progressBar) exitWith {["You have failed to breach the vault.", "basic"] spawn AP_fnc_handleMessage;
        false};
    _currentPoint = (progressPosition _progressBar) + (_increment / 100);
    _progressBar progressSetPosition _currentPoint;
    _progressText ctrlSetText format["%1 (%2%3)", _text, round(_currentPoint * 100), "%"];
    if (_currentPoint >= 1) exitWith {true};
    if ((speed player) >= 2) exitWith {["You have failed to breach the vault.", "basic"] spawn AP_fnc_handleMessage;
        false};
    if !(isNull objectParent player) exitWith {["You have failed to breach the vault.", "basic"] spawn AP_fnc_handleMessage;
        false};
    if (!AP_action_in_use || !alive player) exitWith {["You have failed to breach the vault.", "basic"] spawn AP_fnc_handleMessage;
        false};
    false;}; AP_action_in_use = false;
[] spawn AP_fnc_handleAnim;
5 cutText["", "PLAIN"];
if (_isSuccess) then {AP_evidence_dome setVariable["AP_vaultBreached", true, true];
    ["Stand back! The breach charge is set!", "basic"] spawn AP_fnc_handleMessage;
    playSound "bombarm";
    [false, "demoCharge", 1] call AP_fnc_handleInv;
    uiSleep 5;
    private _plb_dmg = "ModuleExplosive_DemoCharge_F"
    createVehicle(getPosATL AP_evidence_dome);
    uiSleep 0.5;
    _plb_dmg setDamage 1;
    AP_evidence_dome setVariable["bis_disabled_Door_3", 0, true];
    AP_evidence_dome animate["door_3_rot", 1];
    private _groupMems = (units group _caller) apply {[getPlayerUID _x, name _x]}; [
        [0, 1, 2], "The evidence lockup vault has been breached!"] remoteExec["AP_fnc_broadcast", west]; [
        [_groupMems], "APS_fnc_evidenceTruck", 2, false, false] spawn AP_fnc_MP;};