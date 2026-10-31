params["", "", "", ["_target", objNull, [objNull]]];
private _unit = cursorTarget;
if (_target isEqualTo player) then {_unit = player};
if (damage player < 0.25 && ((player getVariable["AP_can_revive", -1000]) > time)) exitWith {
    [format["Because you have been revived recently, you cannot bloodbag for another %1 seconds", (player getVariable["AP_can_revive", time]) - time], "basic"] spawn AP_fnc_handleMessage;
};
if (isNull _unit || !(_unit isKindOf "CAManBase") || !(isPlayer _unit) || !(alive _unit)) exitWith {
    ["Not a valid target for blood bag.", "basic"] spawn AP_fnc_handleMessage};
if (player distance _unit > 6 || AP_action_in_use) exitWith {};
if ([_unit] call AP_fnc_healBlocked) exitWith {
    if (_unit isEqualTo player) then {
        ["Your blood won't take it. Something in your system is fighting the transfusion.", "basic"] spawn AP_fnc_handleMessage;
    } else {
        [format["%1's blood won't take it. Something in their system is fighting the transfusion.", name _unit], "basic"] spawn AP_fnc_handleMessage;
    };
};

if ((vehicle player) isKindOf "Air" && {(driver (vehicle player)) isEqualTo player}) exitWith {["You cannot use a bloodbag in the pilot seat of an aircraft"] spawn AP_fnc_handleMessage};
if ((vehicle player) isKindOf "Air" && {[player] call AP_fnc_isUnitCopilot}) exitWith {["You cannot use a bloodbag in the co-pilot seat of an aircraft"] spawn AP_fnc_handleMessage};

AP_action_in_use = true;
private _success = false;
private _text = format["Giving transfusion to %1", name _unit];
disableSerialization;
5 cutRsc["AP_progress", "PLAIN"];
private _ui = uiNamespace getVariable["AP_progress", displayNull];
private _progress = _ui displayCtrl 38201;
private _pgText = _ui displayCtrl 38202;
_pgText ctrlSetText format["%2 (1%1)...", "%", _text];
_progress progressSetPosition 0.01;
private _cP = 0.01;
player forceWalk true;
private _inVehicle = !(isNull objectParent player);
private _animation =
switch (true) do {case (_inVehicle): {""};
    // LooneyBin owner 2026-07-04: allow bloodbag while prone for everyone, mirroring the FAK.
    // Dropped the per-side quest/talent unlock gate (468/469/802/803/cop-talent 34) so being PRONE
    // alone plays the prone transfusion animation instead of forcing the player up into the kneeling default.
    case (stance player isEqualTo "PRONE"): {"AinvPpneMstpSnonWnonDnon_G01"};
    default {"AinvPknlMstpSnonWnonDnon_medic_1"};}; if (_animation isEqualTo "AinvPpneMstpSnonWnonDnon_G01") then {
    player playMoveNow "AinvPpneMstpSlayWnonDnon_medic";} else {[_animation, 1.5] spawn AP_fnc_handleAnim;};
private _multiplier =
switch (true) do {case (119 in AP_side_talents): {0.25};
    case (118 in AP_side_talents): {0.5};
    case (117 in AP_side_talents): {0.8};
    case (AP_copRole in ["all", "medic"] && {17 in AP_cop_talents}): {0.5};
    case (AP_copRole in ["all", "medic"] && {16 in AP_cop_talents}): {0.75};
    case (AP_copRole in ["all", "medic"] && {15 in AP_cop_talents}): {0.85};
    case (AP_copRole in ["all", "scd"] && {31 in AP_cop_talents && !(_unit isEqualTo player)}): {0.75};
    default {1};}; if (468 in AP_completedLifetimeQuests && AP_effSide isEqualTo civilian) then {_multiplier = _multiplier - 0.15;};
if (802 in AP_completedLifetimeQuests && AP_effSide isEqualTo independent) then {_multiplier = _multiplier - 0.10;};
if (12 in AP_infamy_talents && license_civ_rebel) then {_multiplier = _multiplier - 0.15;};
if (13 in AP_infamy_talents && license_civ_rebel) then {_multiplier = _multiplier - 0.10;};
private _delay = 0.2 * _multiplier;
for "_i"
from 0 to 1 step 0 do {uiSleep _delay;
    _cP = _cP + 0.01;
    _progress progressSetPosition _cP;
    _pgText ctrlSetText format["%3 (%1%2)...", round(_cP * 100), "%", _text];
    if (!alive player || !alive _unit) exitWith {};
    if (isWeaponDeployed player) exitWith {};
    if (player getVariable["AP_downed", false]) exitWith {};
    if (player distance _unit > 7) exitWith {};
    if (_cP >= 1) exitWith {_success = true;};
    if !(AP_action_in_use) exitWith {};}; AP_action_in_use = false;
player forceWalk false;
if !(_animation isEqualTo "AinvPpneMstpSnonWnonDnon_G01" && !(_inVehicle)) then {[] spawn AP_fnc_handleAnim;};
5 cutText["", "PLAIN"];
player playActionNow "stop";
if !(_success) exitWith {["Transfusion failed.", "basic"] spawn AP_fnc_handleMessage;
    if (_animation isEqualTo "AinvPpneMstpSnonWnonDnon_G01" && !(_inVehicle)) then {player switchMove "stop"};};
private _useBloodBag =
switch (true) do {case (AP_copRole in ["all", "medic"] && 21 in AP_cop_talents && (call AP_copLevel >= 4)): {false};
    case (AP_copRole in ["all", "medic"] && {14 in AP_cop_talents}): {(random 10) < 7.5};
    case (AP_copRole in ["all", "scd"] && {32 in AP_cop_talents}): {(random 10) < 7.5};
    case (116 in AP_side_talents && call(AP_medicLevel) >= 4 && floor(random 3) isEqualTo 0): {false};
    case (11 in AP_infamy_talents && license_civ_rebel): {(random 10) < 2.5};
    default {true};}; if (_useBloodBag && {!([false, "bloodbag", 1] call AP_fnc_handleInv)}) exitWith {
    ["You don't have a bloodbag to give!", "basic"] spawn AP_fnc_handleMessage;};
private _damage = 0;
private _plb_dmg = _unit;
["bloodbag", 1] call AP_fnc_statArrUpdate;
if (_unit isEqualTo player) then {_plb_dmg setDamage _damage;
    titleText["You give yourself a blood transfusion.", "PLAIN DOWN"];
    ["action", "bloodbagself", 1] spawn AP_fnc_handleQuest;} else {_plb_dmg setDamage _damage;
    titleText[format["You gave %1 a blood transfusion.", name _unit], "PLAIN DOWN"]; [
        [0, format["%1 has given you a blood transfusion.", profileName]], "AP_fnc_broadcast", _unit] spawn AP_fnc_MP;
    ["action", "bloodbagothers", 1] spawn AP_fnc_handleQuest;};
[] call AP_fnc_hudUpdate;
if (AP_effSide isEqualTo independent) then {AP_side_exp = AP_side_exp + 5;
    25 call AP_fnc_medicEarn;   // TT prestige
};
if (AP_effSide isEqualTo west && AP_copRole in ["all", "medic", "scd"] && player != _unit) then {[100] spawn AP_fnc_earnPrestige
};