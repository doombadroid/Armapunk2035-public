params["", "", "", ["_target", objNull, [objNull]]];
private _unit = cursorTarget;
if (_target isEqualTo player) then {_unit = player};
if (isNull _unit || !(_unit isKindOf "CAManBase") || !(isPlayer _unit) || !(alive _unit)) exitWith {
    ["Not a valid target for first aid kit.", "basic"] spawn AP_fnc_handleMessage};
if (player distance _unit > 6 || AP_action_in_use) exitWith {};
if ([_unit] call AP_fnc_healBlocked) exitWith {
    if (_unit isEqualTo player) then {
        ["The bandages won't hold. Something in your system is fighting the treatment.", "basic"] spawn AP_fnc_handleMessage;
    } else {
        [format["The bandages won't hold on %1. Something in their system is fighting the treatment.", name _unit], "basic"] spawn AP_fnc_handleMessage;
    };
};
if !(isNull objectParent player) exitWith {["You can't first aid from within a vehicle.", "basic"] spawn AP_fnc_handleMessage};
if ("medic" in (toLower(animationState player))) exitWith {
    ["You are currently already using a first aid kit!", "basic"] spawn AP_fnc_handleMessage;};
if (toLower(animationState player) in ["amovpercmstpsnonwnondnon_amovpknlmstpsnonwnondnon", "amovpercmstpsraswpstdnon_amovpknlmstpsraswpstdnon", "amovpercmstpsraswrfldnon_amovpknlmstpsraswrfldnon", "amovpknlmstpsraswlnrdnon_amovpknlmstpsnonwnondnon"]) exitWith {};
AP_action_in_use = true;
private _success = false;
private _text = format["First Aiding %1", name _unit];
disableSerialization;
5 cutRsc["AP_progress", "PLAIN"];
private _ui = uiNamespace getVariable["AP_progress", displayNull];
private _progress = _ui displayCtrl 38201;
private _pgText = _ui displayCtrl 38202;
_pgText ctrlSetText format["%2 (1%1)...", "%", _text];
_progress progressSetPosition 0.01;
private _cP = 0.01;
player forceWalk true;
private _animation =
switch (true) do {case ((_unit isEqualTo player) && (stance player isEqualTo "PRONE")): {"AinvPpneMstpSlayWnonDnon_medic"};
    case (_unit isEqualTo player): {"Medic"};
    default {"MedicOther"};}; if (_animation isEqualTo "AinvPpneMstpSlayWnonDnon_medic") then {player playMoveNow _animation} else {
    player playActionNow _animation;};
private _delay = 0.073;
private _disallowedAnimationStates = ["aovrpercmstpsraswrfldf", "AovrPercMrunSrasWrflDf", "aovrpercmstpsraswpstdf"] apply {toLower _x};
for "_i"
from 0 to 1 step 0 do {uiSleep _delay;
    _cP = _cP + 0.01;
    _progress progressSetPosition _cP;
    _pgText ctrlSetText format["%3 (%1%2)...", round(_cP * 100), "%", _text];
    if (!alive player || !alive _unit) exitWith {};
    if !(isNull objectParent player) exitWith {player action["Eject", vehicle player]};
    if (isWeaponDeployed player) exitWith {};
    if (player getVariable["AP_downed", false]) exitWith {};
    if (player distance _unit > 7) exitWith {};
    if ((toLower(animationState player)) in _disallowedAnimationStates) exitWith {};
    if (_cP >= 1) exitWith {_success = true;};
    if !(AP_action_in_use) exitWith {};}; player forceWalk false;
AP_action_in_use = false;
5 cutText["", "PLAIN"];
if !(_success) exitWith {player switchMove "stop";
    ["First Aid Failed.", "basic"] spawn AP_fnc_handleMessage;};
private _useFirstAidKit =
switch (true) do {case (AP_copRole in ["all", "medic"] && 21 in AP_cop_talents && (call AP_copLevel >= 4)): {false};
    case (AP_copRole in ["all", "medic"] && {14 in AP_cop_talents}): {(random 10) < 7.5};
    case (AP_copRole in ["all", "scd"] && {32 in AP_cop_talents}): {(random 10) < 7.5};
    case (116 in AP_side_talents && call(AP_medicLevel) >= 4 && floor(random 3) isEqualTo 0): {false};
    case (452 in AP_completedLifetimeQuests && AP_effSide isEqualTo civilian): {(random 10) < 2.5};
    case (10 in AP_infamy_talents && license_civ_rebel): {(random 10) < 2.5};
    default {true};}; if (_useFirstAidKit && {!([false, "firstAidKit", 1] call AP_fnc_handleInv)}) exitWith {
    ["You don't have a first aid to give!", "basic"] spawn AP_fnc_handleMessage;};
private _damage =
if ((damage _unit) >= 0.25) then {0.25} else {damage _unit};
private _plb_dmg = _unit;
if (_unit isEqualTo player) then {_plb_dmg setDamage _damage;
    titleText["You gave yourself a first aid heal", "PLAIN"];} else {_plb_dmg setDamage _damage;
    titleText[format["You gave %1 a first aid heal.", name _unit], "PLAIN DOWN"]; [
        [2, format["%1 has given you a first aid heal.", profileName]], "AP_fnc_broadcast", _unit] spawn AP_fnc_MP;};
[] call AP_fnc_hudUpdate;
["use", "fak", 1] spawn AP_fnc_handleQuest;
if (AP_effSide isEqualTo independent) then {AP_side_exp = AP_side_exp + 5;
    15 call AP_fnc_medicEarn;   // TT prestige
};
if (AP_effSide isEqualTo west && AP_copRole in ["all", "medic", "scd"] && player != _unit) then {[20] spawn AP_fnc_earnPrestige};