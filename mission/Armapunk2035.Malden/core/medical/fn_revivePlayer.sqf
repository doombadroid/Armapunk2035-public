#include "..\..\macro.h"
if (scriptAvailable(3)) exitWith {["Wait a bit before attempting to revive again!", "basic"] spawn AP_fnc_handleMessage;};
private _target = cursorObject;
if (isNull _target || !(_target isKindOf "CAManBase") || AP_action_in_use) exitWith {};
// owner 2026-09-16 (body drag) SYMMETRIC INTERLOCK: a body is either being revived or being dragged, never
// both. Whichever started first holds it; the other is refused with a message. The sub-second race is
// resolved in the revive's favour: the drag's watchdog re-checks AP_reviving and self-releases. Admin/drone/
// hospital revives, which bypass this file, are covered by a detach guard in fn_revived. attachedTo is the
// truth for "being dragged", but only a LIVING CAManBase holder is a dragger: a corpse left welded to a chair
// or parkour helper (ClutterCutter) by a death mid-attach must stay revivable. The defib actions keep their
// conditions so the player sees this message.
// owner 2026-09-16: and only a REAL drag -- the holder must be the object the public AP_draggedBy flag names
// (fn_dragBody publishes it before the attach). A corpse still welded to an escorter is not a drag and stays
// revivable (fn_revived's detach guard pulls it off). A revive that slips in while the flag is still in
// transit is the sub-second race above: the drag's watchdog lets go as "revive-won".
private _dragHolder = attachedTo _target;
private _dragFlag = _target getVariable ["AP_draggedBy", []];
if (!(isNull _dragHolder) && {_dragHolder isKindOf "CAManBase"} && {alive _dragHolder}
    && {_dragFlag isEqualType []} && {(_dragFlag param [0, objNull]) isEqualTo _dragHolder}) exitWith {["That body is being moved -- the dragger must release it first", "basic"] spawn AP_fnc_handleMessage;};
private _revivable = _target getVariable["AP_revivable", false] || ((_target getVariable["AP_group", grpNull] isEqualTo group player) && !(isNull(_target getVariable["AP_group", grpNull])));
if !(_revivable) exitWith {};
if (_target getVariable["AP_reviving", player] != player) exitWith {
    ["Someone else is already reviving this person", "basic"] spawn AP_fnc_handleMessage;};
if (player distance _target > 5 || !(isNull objectParent player)) exitWith {};
if (isWeaponDeployed player) then {player playMove "";};
if (time < (player getVariable["AP_next_revive", -1000])) exitWith {
    [format["You cannot revive someone so soon after being revived yourself. You must wait %1 seconds.", round((player getVariable["AP_next_revive", -1000]) - time)], "basic"] spawn AP_fnc_handleMessage;
};
if (AP_effSide isEqualTo civilian && (time < (profileNamespace getVariable["AP_recent_revive", [0, 0]] select 1))) exitWith {
    [format["You have recently revived someone! Your defibrillators need time to recharge! They should be ready in %1 seconds.", (profileNamespace getVariable["AP_recent_revive", [0, 0]] select 1) - time], "basic"] spawn AP_fnc_handleMessage;
};
if (time < (_target getVariable["AP_next_revive", -1000]) && !(((AP_effSide isEqualTo independent) && (call AP_medicLevel >= 5)) || (call AP_copLevel >= 6 && AP_copRole in ["all", "medic"] && 22 in AP_cop_talents))) exitWith {
    [format["The victim was recently revived and cannot be revived again for %1 seconds.", (_target getVariable["AP_next_revive", -1000]) - time], "basic"] spawn AP_fnc_handleMessage;
};
private _targetName = _target getVariable["AP_name", "Unknown"];
private _text = format["Reviving %1", _targetName];
AP_action_in_use = true;
_target setVariable["AP_reviving", player, true];
disableSerialization;
5 cutRsc["AP_progress", "PLAIN"];
private _ui = uiNamespace getVariable "AP_progress";
private _progress = _ui displayCtrl 38201;
private _pgText = _ui displayCtrl 38202;
_pgText ctrlSetText format["%2 (1%1)...", "%", _text];
_progress progressSetPosition 0.01;
private _cP = 0.01;
private _success = false;
private _sleep =
switch (true) do {case (120 in AP_side_talents && call(AP_medicLevel) >= 4): {0.1};
    case (AP_effSide isEqualTo independent): {0.15};
    case (AP_copRole in ["all", "medic"] && {18 in AP_cop_talents}): {0.15};
    case (AP_copRole in ["all", "scd"] && {33 in AP_cop_talents}): {0.15};
    default {0.2};}; if (AP_effSide isEqualTo civilian && 458 in AP_completedLifetimeQuests) then {_sleep = _sleep * 0.85;};
if (14 in AP_infamy_talents && license_civ_rebel) then {_sleep = _sleep * 0.85;};
["AinvPknlMstpSnonWnonDr_medic0", 9] spawn AP_fnc_handleAnim;
for "_i"
from 0 to 1 step 0 do {uiSleep _sleep;
    _cP = _cP + 0.01;
    _progress progressSetPosition _cP;
    _pgText ctrlSetText format["%3 (%1%2)...", round(_cP * 100), "%", _text];
    _revivable = _target getVariable["AP_revivable", false] || ((_target getVariable["AP_group", grpNull] isEqualTo group player) && !(isNull(_target getVariable["AP_group", grpNull])));
    if (AP_isDowned || !(alive player) || !(AP_action_in_use) || isWeaponDeployed player) exitWith {};
    if (player getVariable["AP_restrained", false]) exitWith {};
    if (player distance _target > 4 || isNull _target) exitWith {};
    if !(_revivable) exitWith {};
    if (isNull(_target getVariable["AP_reviving", objNull])) exitWith {
        ["This person can no longer be saved", "basic"] spawn AP_fnc_handleMessage;};
    if (_target getVariable["AP_reviving", objNull] != player) exitWith {
        ["Someone else is already reviving this person.", "basic"] spawn AP_fnc_handleMessage;};
    if (_cP >= 1) exitWith {_success = true;};}; 5 cutText["", "PLAIN"];
AP_action_in_use = false;
_target setVariable["AP_reviving", nil, true];
if !(_success) exitWith {private _anim =
    switch (true) do {case (currentWeapon player isEqualTo ""): {"amovpknlmstpsnonwnondnon"};
        case (currentWeapon player isKindOf["Rifle", configFile >> "CfgWeapons"]): {"amovpknlmstpsraswrfldnon"};
        default {"amovpknlmstpsraswpstdnon"};}; player switchMove _anim;
    player setVariable["AP_inAnim", false];};
[] spawn AP_fnc_handleAnim;
private _nextRevive =
if (121 in AP_side_talents) then {time + 60} else {time + 240};
private _defibChargeTime =
switch (true) do {case (AP_effSide isEqualTo independent): {300};
    case (AP_copRole in ["all", "medic"] && {19 in AP_cop_talents}): {240};
    case (15 in AP_infamy_talents && license_civ_rebel): {240};
    default {360};}; profileNameSpace setVariable["AP_recent_revive", [AP_instance_id, time + _defibChargeTime]];
if (isNull(AP_medicAcceptedCorpse param[1, objNull])) then {private _reviveReward =
    if ((_target getVariable["AP_faction", civilian] isEqualTo independent) && AP_effSide isEqualTo independent) then {
        (call AP_revive_fee)} else {(call AP_revive_fee) + 1000};
    if (AP_effSide isEqualTo west) then {_reviveReward = (call AP_revive_fee);};
    if (AP_effSide isNotEqualTo independent) then {AP_atmcash = AP_atmcash + _reviveReward;
        AP_atmcashCacheB = ((AP_atmcash / 4) + 11);
        titleText[format["You have revived %1 and received $%2 for rendering aid.", _targetName, [_reviveReward] call AP_fnc_numberText], "PLAIN"];
    } else {private _partners = [];
        if !(AP_medPartners isEqualTo[]) then {_partners = [7, objNull] call AP_fnc_medicPartners;};
        if (_partners isEqualTo[]) then {AP_atmcash = AP_atmcash + _reviveReward;
            AP_atmcashCacheB = ((AP_atmcash / 4) + 11);
            titleText[format["You have revived %1 and received $%2 for rendering aid.", _targetName, [_reviveReward] call AP_fnc_numberText], "PLAIN"];
        } else {_reviveReward = round(_reviveReward / ((count _partners) + 1));
            AP_atmcash = AP_atmcash + _reviveReward;
            AP_atmcashCacheB = ((AP_atmcash / 4) + 11);
            titleText[format["You have revived %1 and received $%2 for rendering aid.", _targetName, [_reviveReward] call AP_fnc_numberText], "PLAIN"];
            [[_partners, _reviveReward], "APS_fnc_medicSplit", 2] spawn AP_fnc_MP; [
                [format["You have received %1 for a revive performed by %2.", [_reviveReward] call AP_fnc_numberText, profileName]], "AP_fnc_handleMessage", _partners] call AP_fnc_MP;
        };};
    private _xpReward =
    if (AP_effSide isEqualTo independent) then {50} else {30};
    AP_side_exp = AP_side_exp + _xpReward;
    [1] call AP_fnc_ClupdatePartial;
    // LooneyBin: TT prestige points — medics earn them per revive (spend in the AEMT prestige menu)
    if (AP_effSide isEqualTo independent) then {
        250 call AP_fnc_medicEarn;   // owner 2026-06-13 (#158): route through medicEarn so it notifies (was a silent +250)
    };}; [[player, false, false, false, _nextRevive], "AP_fnc_revived", _target] spawn AP_fnc_MP;
if (_target getVariable["AP_lowtime", false]) then {AP_newPlyrRev = AP_newPlyrRev + 1;};
uiSleep 0.6;
player reveal _target;
_target setVariable["AP_requestAcceptor", [objNull, ""], true];
if (AP_effSide isEqualTo west && AP_copRole in ["all", "medic", "scd"]) then {[500] spawn AP_fnc_earnPrestige};
["defibs", 1] call AP_fnc_statArrUpdate;
switch (AP_effSide) do {case civilian: {A_stats_civRevives = A_stats_civRevives + 1};
    case independent: {A_stats_medRevives = A_stats_medRevives + 1;};
    default {};};
["revived", "player", 1 ] spawn AP_fnc_handleQuest;
if (side _target == west) then {["revived", "cop", 1] spawn AP_fnc_handleQuest;};
if (side _target == civilian) then {["revived", "civilian", 1] spawn AP_fnc_handleQuest;};
