// owner 2026-07-29: the hold is anchored on the PRISON GATE now, not a laptop. Malden has no laptop prop,
// and AP_fnc_doPrisonBreak -- the only thing that ever passed one -- has no callers anywhere in the tree.
// Read the PUBLISHED gate rather than trusting an argument: core/fn_setupActions.sqf:2 is
// `private _plb_obj=player;`, so every action registered there attaches to the PLAYER and an
// argument-passed target would BE the player -- every distance gate below would silently measure 0.
private _target = missionNamespace getVariable ["AP_prisonGateIn", objNull];
if (isNull _target) exitWith {["The prison security system cannot be reached.", "basic"] spawn AP_fnc_handleMessage;};
if !(AP_effSide isEqualTo west) exitWith {};
if !(SRV_prisonData param [1, false]) exitWith {["There is no prison break to stop!", "basic"] spawn AP_fnc_handleMessage;};
if !(isNull objectParent player) exitWith {};
if ((player distance _target) > 12) exitWith {
    ["You need to stay at the prison gate to finish restoring the security system!", "basic"] spawn AP_fnc_handleMessage;};
if (player getVariable["AP_restrained", false] || player getVariable["AP_downed", false]) exitWith {};
disableSerialization;
5 cutRsc["AP_progress", "PLAIN"];
private _ui = uiNameSpace getVariable "AP_progress";
private _success = false;
private _progress = _ui displayCtrl 38201;
private _pgText = _ui displayCtrl 38202;
_pgText ctrlSetText "Restoring Security System";
_progress progressSetPosition 0.01;
private _cP = 0.01;
for "_i"
from 0 to 1 step 0 do {uiSleep 0.3;
    _cP = _cP + 0.01;
    _progress progressSetPosition _cP;
    _pgText ctrlSetText format["Restoring Security System... (%1%2)", round(_cP * 100), "%"];
    if (_cp >= 1) exitWith {_success = true};
    if (!alive player || player getVariable["AP_restrained", false] || player getVariable["AP_downed", false]) exitWith {};
    if ((player distance _target) > 12) exitWith {
        ["You need to stay at the prison gate to finish restoring the security system!", "basic"] spawn AP_fnc_handleMessage;};
    if !(SRV_prisonData param [1, false]) exitWith {["There is no prison break to stop!", "basic"] spawn AP_fnc_handleMessage;};
}; 5 cutText["", "PLAIN"];
if !(_success) exitWith {};
if !(SRV_prisonData param [1, false]) exitwith {["There is no prison break to stop!", "basic"] spawn AP_fnc_handleMessage;};
// owner 2026-07-29: route through APS_fnc_prisonGateSRV "disarm" instead of handlePrisonBreak case 2.
// Case 2's ENTIRE server-side check is `side _caller isEqualTo west` -- no distance, no rank, no object --
// so the 12 m and the 30 s above lived ONLY here, in the client, and one cop could cancel the event from
// the far side of the map. "disarm" re-derives the caller from remoteExecutedOwner and re-checks alive /
// west / not restrained / not downed / not in a vehicle / within 15 m of the gate, then sets the latch and
// re-locks the outer gate. It ends the event too, so this is not a second cancel path.
["You have restored the security system to the Prison!", "basic"] spawn AP_fnc_handleMessage;
[["disarm"], "APS_fnc_prisonGateSRV", 2] spawn AP_fnc_MP;
["action", "stopprison", 1] spawn AP_fnc_handleQuest;