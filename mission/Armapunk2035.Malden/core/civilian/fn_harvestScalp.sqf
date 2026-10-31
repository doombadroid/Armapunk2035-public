params[["_unit", objNull, [objNull]]];
if (isNull _unit || !(AP_effSide isEqualTo civilian) || !(_unit isKindOf "CAManBase") || alive _unit) exitWith {};
if (player distance _unit > 2.5) exitWith {};
if (([500] call AP_fnc_nearTown) && !((player distance(getMarkerPos "execute_exempt_01") < 4) || (player distance(getMarkerPos "execute_exempt_02") < 5) || (player distance(getMarkerPos "execute_exempt_03") < 4) || (player distance(getMarkerPos "execute_exempt_04") < 3) || (player distance(getMarkerPos "bankMarker") < 250))) exitWith {
    ["You cannot execute someone so close to a populated area.", "basic"] spawn AP_fnc_handleMessage;};
if !(AP_inv_skinningknife >= 1) exitWith {["You need a skinning knife to harvest someones scalp.", "basic"] spawn AP_fnc_handleMessage;
};
if (_unit getVariable["AP_executing", player] != player) exitWith {
    ["Someone else is already executing this person!", "basic"] spawn AP_fnc_handleMessage;};
if (time < (profileNamespace getVariable["AP_recent_scalp", [0, 0]] select 1)) exitWith {
    [format["You can only someones scalp every 15 minutes! %1 minutes remaining.", ceil(((profileNamespace getVariable["AP_recent_scalp", [0, 0, ""]] select 1) - time) / 60)], "basic"] spawn AP_fnc_handleMessage;
};
if !((profileNamespace getVariable["AP_recent_scalp", [0, 0, ""]] select 2) isEqualTo "") exitWith {
    ["You must sell the scalp you already have!", "basic"] spawn AP_fnc_handleMessage;};
private _checkDebugPlayer = allPlayers param[allPlayers findIf {(_unit getVariable["AP_steamid", ""]) isEqualTo(getPlayerUID _x)
}, objNull];
if (!(_checkDebugPlayer distance(getMarkerPos "respawn_civilian") < 1000) || (isNull _checkDebugPlayer)) exitWith {};
private _targetName = _unit getVariable["AP_name", "Unknown"];
_unit setVariable["AP_executing", player, true];
disableSerialization;
5 cutRsc["AP_progress", "PLAIN"];
private _text = format["Scalping %1's Head", _targetName];
private _ui = uiNamespace getVariable "AP_progress";
private _progress = _ui displayCtrl 38201;
private _pgText = _ui displayCtrl 38202;
_pgText ctrlSetText format["%2 (1%1)...", "%", _text];
_progress progressSetPosition 0.01;
private _cP = 0.01;
private _success = false;
AP_action_in_use = true;
player playMoveNow "AinvPknlMstpSnonWnonDnon_medic1";
systemChat _text;
for "_i"
from 0 to 1 step 0 do {uiSleep 0.038;
    _cP = _cP + 0.01;
    _progress progressSetPosition _cP;
    _pgText ctrlSetText format["%3 (%1%2)...", round(_cP * 100), "%", _text];
    if (isNull _unit) exitWith {};
    if (alive _unit) exitWith {};
    if (player getVariable["AP_downed", false] || player getVariable["AP_restrained", false]) exitWith {};
    if !(isNull(_unit getVariable["AP_reviving", objNull])) exitWith {};
    if (isWeaponDeployed player) exitWith {};
    if (player distance _unit > 3) exitWith {};
    if (!AP_action_in_use) exitWith {};
    if (isNull(_unit getVariable["AP_executing", objNull])) exitWith {
        ["This person can no longer be executed", "basic"] spawn AP_fnc_handleMessage;};
    if (_unit getVariable["AP_executing", objNull] != player) exitWith {
        ["Someone else is already executing this person.", "basic"] spawn AP_fnc_handleMessage;};
    if (_cP >= 1) exitWith {_success = true;};}; 5 cutText["", "PLAIN"];
AP_action_in_use = false;
player switchMove "";
_unit setVariable["AP_executing", nil, true];
if (isNull _unit || !(_success)) exitWith {};
if !([true, "humanscalp", 1] call AP_fnc_handleInv) exitWith {["You had no room for the scalp.", "basic"] spawn AP_fnc_handleMessage;};
[format["You harvested %1's scalp", _targetName], "basic"] spawn AP_fnc_handleMessage;
profileNameSpace setVariable["AP_recent_scalp", [AP_instance_id, time + 900, _targetName]]; [
    ["-EXECUTE-", player, profileName, format["harvested the scalp of %1 (%2), POS: %3", _targetName, _unit getVariable["AP_steamid", ""], getPosATL _unit]], "APS_fnc_logIt", 2, false, false] spawn AP_fnc_MP;
[[], "AP_fnc_doRespawn", _unit] spawn AP_fnc_MP;
player playMove "AinvPknlMstpSlayWrflDnon";
titleText[format["You picked up %1's Scalp! Turn it in at a drug dealer to reap your reward.", _targetName], "PLAIN"];