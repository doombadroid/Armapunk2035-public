params[["_unit", objNull, [objNull]], ["_harvest", false]];
if (isNull _unit || !(AP_effSide isEqualTo civilian) || !(_unit isKindOf "CAManBase") || alive _unit) exitWith {};
if ((currentWeapon player) in ["", "Binocular", "Rangefinder", "hgun_Pistol_Signal_F"] && !_harvest) exitWith {};
if (player distance _unit > 2.5) exitWith {};
// owner 2026-06-23: city/populated-area protection REMOVED for organ harvesting + execution -- both can now be
// done anywhere (incl. near the city & civ spawns). (NOTE: scalp harvest, fn_harvestScalp, still carries the guard.)
if (_harvest && !(AP_inv_skinningknife >= 1)) exitWith {
    ["You need a skinning knife to harvest organs.", "basic"] spawn AP_fnc_handleMessage;};
if (_harvest && (time < (profileNamespace getVariable["AP_recent_organ", [0, 0]] select 1))) exitWith {
    [format["You can only harvest organs every 15 minutes! %1 minutes remaining.", ceil(((profileNamespace getVariable["AP_recent_organ", [0, 0]] select 1) - time) / 60)], "basic"] spawn AP_fnc_handleMessage;
};
if (_unit getVariable["AP_executing", player] != player) exitWith {
    ["Someone else is already executing this person!", "basic"] spawn AP_fnc_handleMessage;};
private _checkDebugPlayer = allPlayers param[allPlayers findIf {(_unit getVariable["AP_steamid", ""]) isEqualTo(getPlayerUID _x)
}, objNull];
if (!(_checkDebugPlayer distance(getMarkerPos "respawn_civilian") < 1000) || (isNull _checkDebugPlayer)) exitWith {};
private _targetName = _unit getVariable["AP_name", "Unknown"];
_unit setVariable["AP_executing", player, true];
disableSerialization;
5 cutRsc["AP_progress", "PLAIN"];
private _text =
if (_harvest) then {format["Harvesting %1's organs", _targetName]} else {format["Executing %1", _targetName]};
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
if (_harvest) then {[[54, player], "APS_fnc_wantedAdd", false, false] spawn AP_fnc_MP;
    // owner 2026-06-24: COP corpse -> CIRCUMCISE -> a NAMED, tradable foreskin item foreskin_<uid> ("<name>'s
    // Foreskin"), registered server-side (the displayed name is resolved from the DB, never client-supplied).
    // CIVILIAN corpse -> Harvest Organs (manflesh). The scroll action is side-gated in fn_setupActions (Circumcise
    // shows on cops, Harvest Organs on civs); this branch matches so a mis-targeted call still does the right thing.
    if ((_unit getVariable ["AP_wasCop", false]) || {side _unit isEqualTo west}) then {
        private _vuid = format ["%1", _unit getVariable ["AP_steamid", ""]];
        if (_vuid isEqualTo "") then { _vuid = "unknown"; };
        private _fclass = format ["foreskin_%1", _vuid];
        // optimistic LOCAL registry add so virtItemCfg resolves the item for the immediate grant; the server call
        // below persists it + broadcasts the authoritative (DB-resolved) name to every client.
        private _reg = missionNamespace getVariable ["AP_foreskinReg", []];
        if ((_reg findIf { (_x select 0) isEqualTo _vuid }) == -1) then {_reg pushBack [_vuid, _targetName];
            missionNamespace setVariable ["AP_foreskinReg", _reg];};
        if !([true, _fclass, 1] call AP_fnc_handleInv) exitWith {
            ["You had no room for the foreskin.", "basic"] spawn AP_fnc_handleMessage;};
        [[_vuid], "APS_fnc_registerForeskin", 2, false, false] spawn AP_fnc_MP;
        [format ["You circumcised %1 and pocketed their Foreskin.", _targetName], "basic"] spawn AP_fnc_handleMessage;
        profileNameSpace setVariable ["AP_recent_organ", [AP_instance_id, time + 900]]; [
            ["-EXECUTE-", player, profileName, format ["circumcised %1 (%2), POS: %3", _targetName, _vuid, getPosATL _unit]], "APS_fnc_logIt", 2, false, false] spawn AP_fnc_MP;
    } else {["manflesh", 1] call AP_fnc_statArrUpdate;
        if !([true, "manflesh", 1] call AP_fnc_handleInv) exitWith {
            ["You had no room for the organs.", "basic"] spawn AP_fnc_handleMessage;};
        [format ["You harvested %1's organs", _targetName], "basic"] spawn AP_fnc_handleMessage;
        profileNameSpace setVariable ["AP_recent_organ", [AP_instance_id, time + 900]]; [
            ["-EXECUTE-", player, profileName, format ["harvested the organs of %1 (%2), POS: %3", _targetName, _unit getVariable ["AP_steamid", ""], getPosATL _unit]], "APS_fnc_logIt", 2, false, false] spawn AP_fnc_MP;
    };} else {[[53, player], "APS_fnc_wantedAdd", false, false] spawn AP_fnc_MP;
    [format["You executed %1", _targetName], "basic"] spawn AP_fnc_handleMessage;
    ["action", "execute", 1] call AP_fnc_handleQuest;
    // Crusader board: "Reckoning". Split onto its own line rather than appended to
    // the handleQuest statement -- the next token here opens the logIt array, and
    // this is exactly the "embedded in a larger expression" case fn_handleQuest.sqf
    // warns a blind sweep would break.
    ["action", "execute", 1] call aq_fnc_event;
    [
        ["-EXECUTE-", player, profileName, format["excecuted %1 (%2), POS: %3", _targetName, _unit getVariable["AP_steamid", ""], getPosATL _unit]], "APS_fnc_logIt", 2, false, false] spawn AP_fnc_MP;
}; [[], "AP_fnc_doRespawn", _unit] spawn AP_fnc_MP;
A_stats_civExecutes = A_stats_civExecutes + 1;