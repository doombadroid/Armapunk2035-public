params[["_unit", objNull, [objNull]]];
if (AP_effSide isEqualTo west) exitWith {["Police can't rob stores! Damned crooked cops.", "basic"] spawn AP_fnc_handleMessage;};
if (_unit getVariable["AP_robProgress", false]) exitWith {["This store is already being robbed!", "basic"] spawn AP_fnc_handleMessage;};
if !(alive player) exitWith {};
private _lastRobbed = _unit getVariable["AP_lastRobbed", -2000];
if ((time - _lastRobbed) < 1800) exitWith {
    ["This location was recently robbed and cannot be robbed again so soon.", "basic"] spawn AP_fnc_handleMessage;};
// owner 2026-06-17 (#333): require >=1 police online to rob a gas station. Gas was the ONE crime that never
// called AP_fnc_policeRequired, so it stayed robbable with zero cops even though the beta zero-cop waiver is
// off (init.sqf:535). Matches how every federal event gates. policeRequired prints its own "need N cops" msg.
// owner 2026-07-28: 4th arg _ignoreTenure = true -- count every cop online, not just the ones on duty 300s+.
// The tenure count exists so the client agrees with a SERVER cop gate; APS_fnc_srvRobStore has no cop gate at
// all, so there was never anything here to diverge from and the tenure rule was pure extra difficulty. Args 2
// and 3 are the existing defaults spelled out because SQF params are positional.
if !([1, false, true, true] call AP_fnc_policeRequired) exitWith {};
titleText["Stay near this store for at least 1 minute and 5 minutes for MAX payout! You can leave earlier for a much smaller payout.", "PLAIN"];
private _nearestLocation = text(nearestLocations[player, ["NameCityCapital", "NameCity"], 3000] select 0);
[_nearestLocation] spawn {params["_nearestLocation"];
    if (46 in AP_side_talents) then {private _random = random(60 * 2);
        uiSleep _random;};
    if !(alive player) exitWith {};
    playSound3D["A3\Sounds_F\sfx\alarm_independent.wss", player]; [
        [1, format["A gas station is being robbed by %1!", profileName]], "AP_fnc_broadcast", [civilian, independent], false, false] spawn AP_fnc_MP;
    [
        [format["A gas station is being robbed by %1 near %2.", profileName, _nearestLocation], "copalert"], "AP_fnc_handleMessage", west, false, false] spawn AP_fnc_MP;
};
_unit setVariable["AP_lastRobbed", time, true];
_unit setVariable["AP_robProgress", true, true];
AP_use_atm = false; [[player, _unit], "APS_fnc_srvRobStore", 2] spawn AP_fnc_MP; [
    [18, player], "APS_fnc_wantedAdd", false, false] spawn AP_fnc_MP;
disableSerialization;
5 cutRsc["AP_progress", "PLAIN"];
private _text = "Robbing Store";
private _ui = uiNamespace getVariable "AP_progress";
private _progress = _ui displayCtrl 38201;
private _pgText = _ui displayCtrl 38202;
_pgText ctrlSetText format["%2 (1%1)...", "%", _text];
_progress progressSetPosition 0.01;
private _cP = 0.01;
private _success = true;
private _started = time;
for "_i"
from 0 to 1 step 0 do {uiSleep 1;
    _cP = _cP + 0.003333;
    _progress progressSetPosition _cP;
    _pgText ctrlSetText format["%3 (%1%2)...", round(_cP * 100), "%", _text];
    if (_cP >= 1) exitWith {};
    if !(isNull objectParent player) exitWith {};
    if (player getVariable["AP_restrained", false]) exitWith {_success = false;};
    if (player getVariable["AP_downed", false]) exitWith {_success = false;};
    if ((player distance _unit) > 15) exitWith {};}; 5 cutText["", "PLAIN"]; [
    [format["The gas station near %1 is no longer being robbed.", _nearestLocation], "copalert"], "AP_fnc_handleMessage", west] spawn AP_fnc_MP;
_unit setVariable["AP_robProgress", false, true];
[] spawn {uiSleep 300;
    AP_use_atm = true;};
if (_success) then {private _duration = (time - _started) / 60;
    private _cash = round(_duration * 1500);
    if !(AP_gang_data param[0, -44] isEqualTo((zaros_flag getVariable["AP_turf_data", []]) param[0, -33])) then {
        _cash = selectMin[5000, _cash]};
    if (39 in AP_side_talents) then {_cash = round(_cash * (random[1, 1.1, 1.2]))};
    if (_duration < 1) exitWith {["You failed to get any cash!", "basic"] spawn AP_fnc_handleMessage;};
    // Dirty Money (owner 2026-06-13): stores pay DIRTY money (launder via Y-menu after 5 min).
    // owner 2026-06-14 (#197): removed the flat `_cash = 5000` override -- it clobbered the duration +
    // talent-39 (%) + turf scaling computed above, so every rob paid exactly 5k regardless of skill/time.
    // _cash now carries the scaled value (round(_duration*1500), min(5000) off-turf, +10-20% w/ talent 39,
    // uncapped on owned Zaros turf). Still paid as `bank_money` (dirty) below -- only the AMOUNT scales now.
    ["action", "robgasstation", 1] call AP_fnc_handleQuest;
    [format["You have robbed the store of $%1 in dirty money!", [_cash] call AP_fnc_numberText], "basic"] spawn AP_fnc_handleMessage;
    [true, "bank_money", _cash] call AP_fnc_handleInv;
    AP_dirtyMoneyTime = time;
    ["gasrob", 1] call AP_fnc_statArrUpdate;
    ["gasrobmoney", _cash] call AP_fnc_statArrUpdate;
    ["action", "robstore", 1] spawn AP_fnc_handleQuest;
    // Crusader board: "The Collection" is counted by the SERVER's robbery clock
    // (APS_fnc_robStore -> APS_fnc_aqFact), not here. The handleQuest line above
    // stays -- it is a no-op and removing it would only make the next verb rewiring
    // harder to find.
    [15, true] call AP_fnc_addInfamy;} else {["You failed to rob the store!", "basic"] spawn AP_fnc_handleMessage;};