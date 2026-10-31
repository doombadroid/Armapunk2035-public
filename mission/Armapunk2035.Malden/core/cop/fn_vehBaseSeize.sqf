params[["_vehicle", objNull, [objNull]]];
if (isNull _vehicle) exitWith {};
if !(alive _vehicle) exitWith {["Couldn't search the vehicle.", "basic"] spawn AP_fnc_handleMessage;};
// #363: the "already being seized?" check + lock are now SERVER-authoritative (acquired below via
// APS_fnc_seizeLock) -- the old client-side check that lived here raced. See the acquire block lower down.
private _usedBy = _vehicle getVariable["AP_veh_in_use", objNull];
if (_usedBy isNotEqualTo objNull) exitWith {["This vehicle's trunk is in use!", "basic"] spawn AP_fnc_handleMessage;};
private _activeTrunk = _vehicle getVariable["AP_activeTrunk", objNull];
if (_activeTrunk isNotEqualTo objNull) exitWith {["This vehicle's trunk is in use!", "basic"] spawn AP_fnc_handleMessage;};
private _isTent =
if (typeOf _vehicle in ["Land_TentA_F", "Land_TentDome_F", "B_CargoNet_01_ammo_F", "B_CargoNet_01_ammo_F"]) then[{true}, {false}];
if !(_vehicle isKindOf "Air" || _vehicle isKindOf "Ship" || _vehicle isKindOf "LandVehicle" || _isTent) exitWith {};
private _vehText =
if !(_isTent) then[{"vehicle"}, {"container"}];
// owner 2026-06-18 (#363 concurrent-seize money dupe): acquire the seize lock on the SERVER (atomic). The old
// client-side AP_seizing check+set raced -- two cops both passed it before the public setVariable propagated,
// both ran the 20s seize, and APS_fnc_copSplit fired twice = everyone paid double. Only the cop the server
// hands the lock to proceeds; the loser is told it's already being seized.
AP_seizeAcquired = -1;
[[_vehicle, "acquire"], "APS_fnc_seizeLock", 2, false, true] spawn AP_fnc_MP;
private _seizeLockWait = time + 5;
waitUntil { (AP_seizeAcquired != -1) || (time > _seizeLockWait) };
if (AP_seizeAcquired != 1) exitWith {["This vehicle inventory is already being seized!", "basic"] spawn AP_fnc_handleMessage;};
private _allPhyItems = [getWeaponCargo _vehicle, getItemCargo _vehicle, getBackpackCargo _vehicle, getMagazineCargo _vehicle] select {
    _x isNotEqualTo[[], []]};
private _allVirItems = _vehicle getVariable["AP_vinv", [[], 0]];
(_vehicle getVariable["AP_vinv", [[], 0]]) params["_items", "_weight"];
private _weapons = WeaponCargo _vehicle;
private _magazines = MagazineCargo _vehicle;
private _illegalValue = 0;
private _illegalItems = ["getIllegalItems"] call AP_fnc_virtItemCfg;
private _idx = -1;
private _seizedVirt = []; {_x params["_var", "_val"];
    _idx = _illegalItems findIf {_x select 0 == _var};
    if !(_idx isEqualTo - 1) then {_seizedVirt pushBack _x;
        _illegalValue = _illegalValue + (_val * ((_illegalItems select _idx) select 1));
        _items = _items - [_x];
        _weight = _weight - (_val * (["getItemWeight", _var] call AP_fnc_virtItemCfg));};}
forEach _items;
private _multiplier =
switch (true) do {case (107 in AP_side_talents): {1.3};
    case (106 in AP_side_talents): {1.2};
    case (105 in AP_side_talents): {1.1};
    default {1};}; _illegalValue = _illegalValue * _multiplier;
private _isSuccess = false;
if ((_illegalValue > 0) || (count(_weapons + _magazines) > 0)) then {disableSerialization;
    5 cutRsc["AP_progress", "PLAIN"];
    private _display = uiNameSpace getVariable["AP_progress", displayNull];
    private _progressBar = _display displayCtrl 38201;
    private _progressText = _display displayCtrl 38202;
    AP_action_in_use = true;
    private _increment = 1;
    private _totalTime = 20;
    private _currentPoint = 0;
    private _loopDelay = _totalTime / floor(100 / _increment);
    private _text = format["Seizing %1 Inventory", _vehText];
    private _startCount = 0;
    _progressBar progressSetPosition _startCount;
    _progressText ctrlSetText format["%1 (%2%3)", _text, _startCount, "%"];
    private _duration = 20;
    private _animation = "AinvPknlMstpSnonWnonDnon_medic_1";
    [_animation, _duration] spawn AP_fnc_handleAnim;
    _isSuccess =
    for "_i"
    from 0 to 1 step 0 do {uiSleep _loopDelay;
        if (isNull _progressBar) exitWith {[2, format["You failed to seize the %1 inventory.", _vehText]] call AP_fnc_broadcast;
            false};
        _currentPoint = (progressPosition _progressBar) + (_increment / 100);
        _progressBar progressSetPosition _currentPoint;
        _progressText ctrlSetText format["%1 (%2%3)", _text, round(_currentPoint * 100), "%"];
        if (_currentPoint >= 1) exitWith {true};
        if ((speed player) >= 2) exitWith {[2, format["You failed to seize the %1 inventory.", _vehText]] call AP_fnc_broadcast;
            false};
        if !((vehicle player) isEqualTo player) exitWith {
            [2, format["You failed to seize the %1 inventory.", _vehText]] call AP_fnc_broadcast;
            false};
        if (player getVariable["AP_downed", false] || player getVariable["AP_restrained", false]) exitWith {
            [2, format["You failed to seize the %1 inventory.", _vehText]] call AP_fnc_broadcast;
            false};
        if ((!AP_action_in_use) || (!alive player) || ((player distance _vehicle) >= 5)) exitWith {
            [2, format["You failed to seize the %1 inventory.", _vehText]] call AP_fnc_broadcast;
            false};
        private _usedBy = _vehicle getVariable["AP_veh_in_use", objNull];
        if (_usedBy isNotEqualTo objNull) exitWith {["This vehicle's trunk is in use!", "basic"] spawn AP_fnc_handleMessage;
            false;};
        private _activeTrunk = _vehicle getVariable["AP_activeTrunk", objNull];
        if (_activeTrunk isNotEqualTo objNull) exitWith {["This vehicle's trunk is in use!", "basic"] spawn AP_fnc_handleMessage;
            false;};
        false;}; AP_action_in_use = false;
    [] spawn AP_fnc_handleAnim;
    5 cutText["", "PLAIN"];
    if (_isSuccess) then {private _dice = random 100;
        private _vehicleOwners = _vehicle getVariable["AP_vehOwners", [[getPlayerUID player, profileName]]];
        private _evidenceTruck = ((_vehicleOwners param[0, ["123", "yes"]]) param[0, "123"]) isEqualTo "000000000";
        if (!_isTent && !_evidenceTruck) then {if (_dice > 75) then {[[_seizedVirt, 2], "APS_fnc_evidenceAppend", 2] spawn AP_fnc_MP;
            } else {[[_weapons, 1], "APS_fnc_evidenceAppend", 2] spawn AP_fnc_MP;};};
        clearWeaponCargoGlobal _vehicle;
        clearMagazineCargoGlobal _vehicle;
        clearItemCargoGlobal _vehicle;
        if (_illegalValue > 0) then {private _rank = "MaxSec Officer "; [
                [0, format["A %1 was searched by %2%3 and $%4 worth of drugs / contraband were seized into evidence.", (getText(configFile >> "CfgVehicles" >> (typeOf _vehicle) >> "displayName")), _rank, (profileName), [_illegalValue] call AP_fnc_numberText]], "AP_fnc_broadcast", -2, false, false] spawn AP_fnc_MP;
            [floor(_illegalValue / 10)] spawn AP_fnc_earnPrestige; [[player, _illegalValue], "APS_fnc_copSplit", 2] spawn AP_fnc_MP;
            _vehicle setVariable["AP_vinv", [_items, _weight], true];
            if ((_illegalValue >= 5000) && !(_vehicle getVariable["AP_side", ""] isEqualTo "cop")) then {
                _vehicle setVariable["AP_canSeize", true, true];};
            ["action", "seizevehiclevalue", _illegalValue] call AP_fnc_handleQuest;};
        titleText[format["You have seized the weapons and items from this %1.", _vehText], "PLAIN"]; [
            ["-SEIZE-", player, (profileName), format["seized $%1 worth of drugs / contraband from a %2, POS: %3. All Virtual items: %4, All Physical items: %5 ", [_illegalValue] call AP_fnc_numberText, (getText(configFile >> "CfgVehicles" >> (typeOf _vehicle) >> "displayName")), (getPosATL _vehicle), _allVirItems, _allPhyItems]], "APS_fnc_logIt", 2, false, false] spawn AP_fnc_MP;
    };} else {[format["Nothing illegal in this %1.", _vehText], "basic"] spawn AP_fnc_handleMessage;};
[[_vehicle, "release"], "APS_fnc_seizeLock", 2, false, true] spawn AP_fnc_MP;   // #363: release the server-held seize lock