params[["_vehicle", objNull, [objNull]]];
private _vehicleClassname = typeOf _vehicle;
private _vehicleDisplayName = getText(configFile >> "CfgVehicles" >> _vehicleClassname >> "displayName");
if (isNull _vehicle) exitWith {};
if !(typeOf _vehicle in ["Land_TentA_F", "Land_TentDome_F"]) exitWith {};
// owner 2026-06-18 (#363 concurrent-seize money dupe): acquire the seize lock on the SERVER (atomic) -- the old
// client-side AP_seizing check+set raced, letting two cops both seize the same tent and double-pay copSplit.
AP_seizeAcquired = -1;
[[_vehicle, "acquire"], "APS_fnc_seizeLock", 2, false, true] spawn AP_fnc_MP;
private _seizeLockWait = time + 5;
waitUntil { (AP_seizeAcquired != -1) || (time > _seizeLockWait) };
if (AP_seizeAcquired != 1) exitWith {
    [format["This %1 inventory is already being seized!", _vehicleDisplayName], "basic"] spawn AP_fnc_handleMessage;};
(_vehicle getVariable["AP_vinv", [[], 0]]) params["_tentItems", "_tentWeight"];
private _seizeValue = 0;
private _illegalItems = ["getIllegalItems"] call AP_fnc_virtItemCfg;
private _illegalExempt =
if (SRV_governorData param[3, false]) then {AP_governorLegalisableItems} else {[]};
private _newTentItems = +_tentItems; {_x params["_var", "_val"];
    private _index = _illegalItems findIf {(_x select 0) isEqualTo _var};
    if (!(_index isEqualTo - 1) && !(_var in _illegalExempt)) then {
        _seizeValue = _seizeValue + (_val * ((_illegalItems select _index) select 1));
        _newTentItems = _newTentItems - [_x];
        private _itemWeight = ["getItemWeight", _var] call AP_fnc_virtItemCfg;
        _tentWeight = _tentWeight - (_itemWeight * _val);};}
forEach _tentItems;
private _isSuccess = false;
if (_seizeValue > 0) then {disableSerialization;
    5 cutRsc["AP_progress", "PLAIN"];
    private _display = uiNameSpace getVariable["AP_progress", displayNull];
    private _progressBar = _display displayCtrl 38201;
    private _progressText = _display displayCtrl 38202;
    AP_action_in_use = true;
    private _increment = 1;
    private _totalTime = 20;
    private _currentPoint = 0;
    private _loopDelay = _totalTime / floor(100 / _increment);
    private _text = format["Seizing %1 Inventory", _vehicleDisplayName];
    private _startCount = 0;
    _progressBar progressSetPosition _startCount;
    _progressText ctrlSetText format["%1 (%2%3)", _text, _startCount, "%"];
    private _duration = 20;
    private _animation = "AinvPknlMstpSnonWnonDnon_medic_1";
    [_animation, _duration] spawn AP_fnc_handleAnim;
    _isSuccess =
    for "_i"
    from 0 to 1 step 0 do {uiSleep _loopDelay;
        if (isNull _progressBar) exitWith {
            [2, format["You failed to seize the %1 inventory.", _vehicleDisplayName]] call AP_fnc_broadcast;
            false};
        _currentPoint = (progressPosition _progressBar) + (_increment / 100);
        _progressBar progressSetPosition _currentPoint;
        _progressText ctrlSetText format["%1 (%2%3)", _text, round(_currentPoint * 100), "%"];
        if (_currentPoint >= 1) exitWith {true};
        if ((speed player) >= 2) exitWith {
            [2, format["You failed to seize the %1 inventory.", _vehicleDisplayName]] call AP_fnc_broadcast;
            false};
        if !((vehicle player) isEqualTo player) exitWith {
            [2, format["You failed to seize the %1 inventory.", _vehicleDisplayName]] call AP_fnc_broadcast;
            false};
        if (player getVariable["AP_downed", false] || player getVariable["AP_restrained", false]) exitWith {
            [2, format["You failed to seize the %1 inventory.", _vehicleDisplayName]] call AP_fnc_broadcast;
            false};
        if ((!AP_action_in_use) || (!alive player) || ((player distance _vehicle) >= 5)) exitWith {
            [2, format["You failed to seize the %1 inventory.", _vehicleDisplayName]] call AP_fnc_broadcast;
            false};
        false;}; AP_action_in_use = false;
    [] spawn AP_fnc_handleAnim;
    5 cutText["", "PLAIN"];
    if (_isSuccess) then {if (_seizeValue > 0) then {_vehicle setVariable["AP_vinv", [_newTentItems, _tentWeight], true];
            private _rank = [west, player] call AP_fnc_getRankString; [
                [0, format["A %1 was searched by %2%3 and $%4 worth of drugs / contraband were taken into police evidence.", _vehicleDisplayName, _rank, profileName, [_seizeValue] call AP_fnc_numberText]], "AP_fnc_broadcast", -2, false, false] spawn AP_fnc_MP;
            [
                ["-SEIZE-", player, (profileName), format["seized $%1 worth of drugs / contraband from a %2, POS: %3", [_seizeValue] call AP_fnc_numberText, _vehicleDisplayName, (getPosATL _vehicle)]], "APS_fnc_logIt", 2, false, false] spawn AP_fnc_MP;
            [floor(_seizeValue / 10)] spawn AP_fnc_earnPrestige; [[player, _seizeValue], "APS_fnc_copSplit", 2] spawn AP_fnc_MP;};
        titleText[format["The illegal items from this %1 have been seized into the nearest HQs evidence locker.", _vehicleDisplayName], "PLAIN"];
    };} else {[format["Nothing illegal to seize in this %1.", _vehicleDisplayName], "basic"] spawn AP_fnc_handleMessage;};
[[_vehicle, "release"], "APS_fnc_seizeLock", 2, false, true] spawn AP_fnc_MP;   // #363: release the server-held seize lock