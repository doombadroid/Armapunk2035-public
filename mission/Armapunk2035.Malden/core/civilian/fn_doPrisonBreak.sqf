#include "..\..\macro.h"
if (scriptAvailable(5)) exitWith {["Please don't spam Prison Breaks!", "basic"] spawn AP_fnc_handleMessage;};
params[["_target", objNull, [objNull]]];
if (AP_action_in_use) exitWith {systemChat "You are already performing an action.";};
if !(AP_effSide isEqualTo civilian) exitWith {};
if ([] call AP_fnc_activeFederalEvent) exitWith {
    ["There is already another Federal Event happening.", "basic"] spawn AP_fnc_handleMessage;};
// owner 2026-07-28, REVERTED: _ignoreTenure back to FALSE (= tenure ENFORCED). bb571bc opted this caller out
// on one stated ground -- "APS_fnc_handlePrisonBreak has no cop gate to be in parity with, so the prison break
// was never diverging". That ground is gone: the same commit as this line gives that fn the tenuredCops +
// AP_betaZeroCops gate the sibling heists carry. Left opted out, this would count every cop online while the
// server counts only cops on duty >= AP_copTenureReq (300s), so one freshly-on-duty officer would green-light
// the job here, charge the player wanted id 14 on :57 -- which fires BEFORE the server call on :58 -- and stand
// him through the whole 30-second upload for the server to refuse it. That is exactly the divergence fc17562
// closed, running the wrong way. Args 2 and 3 are the existing defaults written out because SQF params are
// positional; the 4th is now omitted so it takes policeRequired's own strict default. Same on the post-upload
// re-check below. The gas station and the evidence armory keep their opt-out -- they still have no server-side
// cop gate to be in parity with.
if !([(SRV_prisonData select 2), false, true] call AP_fnc_policeRequired) exitWith {};
if (player getVariable["AP_restrained", false] || player getVariable["AP_downed", false] || player getVariable["AP_arrested", false]) exitWith {};
private _prisonerCount = count(allPlayers select {side _x isEqualTo civilian && _x getVariable["AP_arrested", false]});
if (_prisonerCount isEqualTo 0) exitWith {["A prison break requires prisoners to be in the prison.", "basic"] spawn AP_fnc_handleMessage;
};
if (serverTime - (SRV_prisonData select 0) < 1800) exitWith {
    ["This prison is on lockdown. Try again in a few minutes.", "basic"] spawn AP_fnc_handleMessage;};
if ((currentWeapon player) in ["", "Binocular", "Rangefinder", "hgun_Pistol_Signal_F"]) exitWith {
    ["The prison guards will not be very intimidated by an unarmed civilian!", "basic"] spawn AP_fnc_handleMessage;};
if (SRV_prisonData select 1) exitWith {["There is already a prison break in progress!", "basic"] spawn AP_fnc_handleMessage;};
if ((player distance _target) > 10) exitWith {
    ["You need to stay near the laptop to complete the virus upload!", "basic"] spawn AP_fnc_handleMessage;};
if !(isNull objectParent player) exitWith {};
if (SRV_lastRobbery > (serverTime - (60 * 15))) exitWith {
    [2, format["Security is high due to a recent robbery and you cannot start the prison break. Try again in %1 minute(s).", ceil((SRV_lastRobbery - (serverTime - (60 * 15))) / 60)]] call AP_fnc_broadcast
};
AP_action_in_use = true;
disableSerialization;
5 cutRsc["AP_progress", "PLAIN"];
private _ui = uiNameSpace getVariable "AP_progress";
private _success = false;
private _progress = _ui displayCtrl 38201;
private _pgText = _ui displayCtrl 38202;
_pgText ctrlSetText "Uploading Virus";
_progress progressSetPosition 0.01;
private _cP = 0.01;
for "_i"
from 0 to 1 step 0 do {if (random(100) >= 50) then {uiSleep 0.35;} else {uiSleep 0.25;};
    _cP = _cP + 0.01;
    _progress progressSetPosition _cP;
    _pgText ctrlSetText format["Uploading virus... (%1%2)", round(_cP * 100), "%"];
    if (_cp >= 1) exitWith {_success = true;};
    if (!alive player || player getVariable["AP_restrained", false] || player getVariable["AP_downed", false]) exitWith {};
    if ((player distance _target) > 10) exitWith {
        ["You need to stay near the laptop to complete the virus upload!", "basic"] spawn AP_fnc_handleMessage;};
    if !(isNull objectParent player) exitWith {};
    if (SRV_prisonData select 1) exitWith {["There is already a prison break in progress!", "basic"] spawn AP_fnc_handleMessage;};
}; 5 cutText["", "PLAIN"];
if !(_success) exitWith {AP_action_in_use = false;};
if (SRV_prisonData select 1) exitWith {["There is already a prison break in progress!", "basic"] spawn AP_fnc_handleMessage;
    AP_action_in_use = false;};
if !([(SRV_prisonData select 2), false, true] call AP_fnc_policeRequired) exitWith {AP_action_in_use = false;};   // tenure ENFORCED again -- see the pre-check at the top
["The virus has been uploaded into the Prison security system and is infecting the network. The prisoners will be able to escape once the breach completes (~13 minutes). Keep the police away from the computer terminal!", "basic"] spawn AP_fnc_handleMessage;
AP_action_in_use = false;
if (SRV_prisonData select 1) exitWith {["There is already a prison break in progress!", "basic"] spawn AP_fnc_handleMessage;};
[[14, player], "APS_fnc_wantedAdd", false, false] spawn AP_fnc_MP;   // owner 2026-06-15 (#232): charge "Prison Break" (id 14) for STARTING the break -- was never applied
[[1, player, getPlayerUID player, group player], "APS_fnc_handlePrisonBreak", 2] spawn AP_fnc_MP;
// owner 2026-06-23: STANDARD AP_progress bar for the breach HOLD (was just a text message before). Same kind
// as repair/bulk processing (cutRsc "AP_progress", ctrls 38201/38202, fixed-rate loop). Purely VISUAL -- it does
// NOT set AP_action_in_use, so the breaker can still fight/reload; the server (APS_fnc_startPrisonBreak) stays
// authoritative for the actual breach. _holdTime MUST match that fn's _breakTimer (Altis 800 / Australia 600).
[_target] spawn {params ["_laptop"];
    private _holdTime = if (worldName == "Australia") then { 600 } else { 800 };
    disableSerialization;
    5 cutRsc ["AP_progress", "PLAIN"];
    private _ui = uiNamespace getVariable "AP_progress";
    private _progress = _ui displayCtrl 38201;
    private _pgText = _ui displayCtrl 38202;
    private _text = "Prison breach in progress";
    private _delay = _holdTime / 100;
    private _cP = 0;
    _progress progressSetPosition 0;
    _pgText ctrlSetText format ["%1 (0%2)...", _text, "%"];
    for "_i" from 0 to 1 step 0 do {uiSleep _delay;
        _cP = _cP + 0.01;
        _progress progressSetPosition _cP;
        _pgText ctrlSetText format ["%3 (%1%2)...", round (_cP * 100), "%", _text];
        if (_cP >= 1) exitWith {};
        if (!alive player || {player getVariable ["AP_restrained", false]} || {player getVariable ["AP_downed", false]}) exitWith {};
        if !(isNull objectParent player) exitWith {};                 // entered a vehicle
        if (!isNull _laptop && {(player distance2D _laptop) > 500}) exitWith {};   // walked >500m from the laptop (matches the server hold)
        if !(SRV_prisonData param [1, false]) exitWith {};            // breach completed, or a cop stopped it
    };
    5 cutText ["", "PLAIN"];};