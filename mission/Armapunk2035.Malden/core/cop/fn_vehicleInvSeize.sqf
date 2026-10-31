params[["_civVehicle", objNull, [objNull]]];
if (isNull _civVehicle) exitWith {};
if !(alive _civVehicle) exitWith {};
private _isTent =
if (typeOf _civVehicle in ["Land_TentA_F", "Land_TentDome_F", "B_CargoNet_01_ammo_F"]) then[{true}, {false}];
private _vehText =
if !(_isTent) then[{"vehicle"}, {"container"}];
if !(_civVehicle isKindOf "Air" || _civVehicle isKindOf "Ship" || _civVehicle isKindOf "LandVehicle" || _isTent) exitWith {};
private _civVehicleSide = _civVehicle getVariable["AP_side", ""];
if (_civVehicleSide isEqualTo "cop") exitWith {
    ["You cannot seize the trunk of a police vehicle! Take this vehicle back to an HQ to seize items into evidence!", "basic"] spawn AP_fnc_handleMessage;
};
private _usedBy = _civVehicle getVariable["AP_veh_in_use", objNull];
if (_usedBy isNotEqualTo objNull) exitWith {["This vehicle's trunk is in use!", "basic"] spawn AP_fnc_handleMessage;};
private _activeTrunk = _civVehicle getVariable["AP_activeTrunk", objNull];
if (_activeTrunk isNotEqualTo objNull) exitWith {["This vehicle's trunk is in use!", "basic"] spawn AP_fnc_handleMessage;};
private _allPhyItems = [getWeaponCargo _civVehicle, getItemCargo _civVehicle, getBackpackCargo _civVehicle, getMagazineCargo _civVehicle] select {
    _x isNotEqualTo[[], []]};
private _allVirItems = _civVehicle getVariable["AP_vinv", [[], 0]];
// owner 2026-06-21 (#438 "seize sometimes takes binos"): the body-seize paths (fn_seizeToVehicle / fn_seizePlayerIllegalAction)
// exempt binoculars, but this TRUNK seize didn't -- weaponCargo treats a binocular/rangefinder as a weapon, so one stored in
// the trunk got confiscated. Exempt the binocular family so it stays in the civ's trunk.
private _weapons = (weaponCargo _civVehicle) select { !(_x in ["Binocular", "Rangefinder", "Laserdesignator", "Integrated_NVG_F"]) };
private _magazines = magazineCargo _civVehicle;
private _wepItems = []; {for "_i"
    from 1 to 3 do {if ((_x select _i) != "") then {_wepItems = _wepItems + [_x select _i]};}; if ((_x select 4 select 0) != "") then {
        _wepItems = _wepItems + [_x select 4 select 0];};}
forEach weaponsItemsCargo _civVehicle;
private _bpWeps = []; {_bpWeps = _bpWeps + (WeaponsItemsCargo _x);}
forEach(everyBackpack _civVehicle);
private _bpItems = []; {for "_i"
    from 0 to 3 do {if ((_x select _i) != "") then {_bpItems = _bpItems + [_x select _i]};}; if ((_x select 4 select 0) != "") then {
        _bpItems = _bpItems + [_x select 4 select 0];};}
forEach _bpWeps; {_bpItems = _bpItems + (magazineCargo _x);
    _bpItems = _bpItems + (itemCargo _x);}
forEach(everyBackpack _civVehicle);
private _clothes = []; {if (getNumber(missionConfigFile >> "CfgWeights" >> _x select 0 >> "illegal") isEqualTo 1) then {
        _clothes pushBack(_x select 0);};}
forEach(everyContainer _civVehicle);
private _nearVehicles = nearestObjects[_civVehicle, ["Car", "Air", "Ship"], 30];
private _copVehicle = _nearVehicles param[_nearVehicles findIf {
    _x getVariable["AP_side", ""] isEqualTo "cop" && !(_x getVariable["AP_mobileHeadQuartersTruckLocked", false])}, objNull];
if (isNull _copVehicle) exitWith {
    [format["There aren't any nearby police vehicles to seize this %1's illegal items into!", _vehText], "basic"] spawn AP_fnc_handleMessage;
};
if !(alive _copVehicle) exitWith {
    [format["You cannot seize items into a %1 which has been destroyed!", _vehText], "basic"] spawn AP_fnc_handleMessage;};
// owner 2026-06-18 (#363 concurrent-seize money dupe): acquire the seize lock on the SERVER (atomic) -- the old
// client-side AP_seizing check+set raced, letting two cops both seize the same vehicle and double-pay copSplit.
AP_seizeAcquired = -1;
[[_civVehicle, "acquire"], "APS_fnc_seizeLock", 2, false, true] spawn AP_fnc_MP;
private _seizeLockWait = time + 5;
waitUntil { (AP_seizeAcquired != -1) || (time > _seizeLockWait) };
if (AP_seizeAcquired != 1) exitWith {
    [format["This %1 inventory is already being seized!", _vehText], "basic"] spawn AP_fnc_handleMessage;};
(_civVehicle getVariable["AP_vinv", [[], 0]]) params["_civItems", "_civWeight"];
(_copVehicle getVariable["AP_vinv", [[], 0]]) params["_copItems", "_copWeight"];
private _seizeValue = 0;
private _illegalItems = ["getIllegalItems"] call AP_fnc_virtItemCfg;
private _illegalExempt =
if (SRV_governorData param[3, false]) then {AP_governorLegalisableItems} else {[]};
private _virtualFound = false;   // owner 2026-06-16 (#300): did we strip any illegal VIRTUAL item? (independent of _seizeValue, which the drug-runner/supply-plane branches zero out after their flat payout)
private _newCivItems = +_civItems;
private _newCopItems = +_copItems; {_x params["_var", "_val"];
    private _index = _illegalItems findIf {(_x select 0) isEqualTo _var};
    if (!(_index isEqualTo - 1) && !(_var in _illegalExempt)) then {_virtualFound = true;
        _seizeValue = _seizeValue + (_val * ((_illegalItems select _index) select 1));
        _newCivItems = _newCivItems - [_x];
        private _copItemIndex = _newCopItems findIf {(_x select 0) isEqualTo _var};
        if (_copItemIndex isEqualTo - 1) then {_newCopItems pushBack _x;} else {
            private _oldVal = (_newCopItems select _copItemIndex) select 1;
            (_newCopItems select _copItemIndex) set[1, _oldVal + _val];};
        private _itemWeight = ["getItemWeight", _var] call AP_fnc_virtItemCfg;
        _civWeight = _civWeight - (_itemWeight * _val);
        _copWeight = _copWeight + (_itemWeight * _val);};}
forEach _civItems;
if (_civVehicle getVariable["AP_drugrunning", false]) then {_seizeValue = 10000;
    _civVehicle setVariable["AP_drugrunning", false, true];
    _civVehicle setVariable["AP_canSeize", true, true]; [[player, _seizeValue], "APS_fnc_copSplit", 2] spawn AP_fnc_MP;
    [floor(_seizeValue / 10)] spawn AP_fnc_earnPrestige;
    [0, format["A drug plane was searched and $%1 worth of drugs / contraband has been taken into evidence.", [_seizeValue] call AP_fnc_numberText]] remoteExec["AP_fnc_broadcast", -2];
    _seizeValue = 0;};
if (_civVehicle getVariable["AP_supplyPlane", false]) then {_seizeValue = _seizeValue + 10000;
    _civVehicle setVariable["AP_supplyPlane", false, true];
    _civVehicle setVariable["AP_canSeize", true, true]; [[player, _seizeValue], "APS_fnc_copSplit", 2] spawn AP_fnc_MP;
    [floor(_seizeValue / 10)] spawn AP_fnc_earnPrestige;
    [0, format["The Supply Plane cargo container was searched and $%1 worth of drugs / contraband has been taken into evidence.", [_seizeValue] call AP_fnc_numberText]] remoteExec["AP_fnc_broadcast", -2];
    _seizeValue = 0;};
private _isSuccess = false;
if ((_seizeValue > 0) || (count(_weapons + _magazines + _wepItems + _bpItems + _clothes) > 0)) then {disableSerialization;
    5 cutRsc["AP_progress", "PLAIN"];
    private _display = uiNameSpace getVariable["AP_progress", displayNull];
    private _progressBar = _display displayCtrl 38201;
    private _progressText = _display displayCtrl 38202;
    AP_action_in_use = true;
    private _increment = 1;
    private _totalTime = 20;
    private _currentPoint = 0;
    private _loopDelay = _totalTime / floor(100 / _increment);
    private _text = "Seizing Vehicle Inventory";
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
        if ((!AP_action_in_use) || (!alive player) || ((player distance _civVehicle) >= 5) || (player distance _copVehicle > 30)) exitWith {
            [2, format["You failed to seize the %1 inventory.", _vehText]] call AP_fnc_broadcast;
            false};
        private _usedBy = _civVehicle getVariable["AP_veh_in_use", objNull];
        if (_usedBy isNotEqualTo objNull) exitWith {["This vehicle's trunk is in use!", "basic"] spawn AP_fnc_handleMessage;
            false;};
        private _activeTrunk = _civVehicle getVariable["AP_activeTrunk", objNull];
        if (_activeTrunk isNotEqualTo objNull) exitWith {["This vehicle's trunk is in use!", "basic"] spawn AP_fnc_handleMessage;
            false;};
        false;}; AP_action_in_use = false;
    [] spawn AP_fnc_handleAnim;
    5 cutText["", "PLAIN"];
    if (_isSuccess) then {{_copVehicle addItemCargoGlobal[_x, 1];}
        forEach(_weapons + _magazines + _wepItems + _bpItems + _clothes);
        clearWeaponCargoGlobal _civVehicle;
        clearMagazineCargoGlobal _civVehicle;
        clearItemCargoGlobal _civVehicle; {clearWeaponCargoGlobal _x;
            clearMagazineCargoGlobal _x;
            clearItemCargoGlobal _x;}
        forEach everyBackpack _civVehicle;
        // owner 2026-06-16 (#300): ALWAYS strip the seized illegal virtual items from the vehicle's AP_vinv
        // when any were found -- NOT gated on _seizeValue, which the drug-runner / supply-plane branches reset
        // to 0 after their flat payout (so a drug-runner caught at e.g. sparkdust kept the drugs in the trunk).
        if (_virtualFound) then {_civVehicle setVariable["AP_vinv", [_newCivItems, _civWeight], true];
            _copVehicle setVariable["AP_vinv", [_newCopItems, _copWeight], true];};
        if (_seizeValue > 0) then {private _rank = [west, player] call AP_fnc_getRankString; [
                [0, format["A %1 was searched by %2%3 and $%4 worth of drugs / contraband were taken into police custody.", getText(configFile >> "CfgVehicles" >> typeOf _civVehicle >> "displayName"), _rank, profileName, [_seizeValue] call AP_fnc_numberText]], "AP_fnc_broadcast", -2, false, false] spawn AP_fnc_MP;
            if (_seizeValue >= 5000) then {_civVehicle setVariable["AP_canSeize", true, true];};};
        titleText[format["The illegal items from this %1 have been seized into the nearest police vehicle. The items can be placed into evidence from any Police HQ.", _vehText], "PLAIN"];
        [
            ["-SEIZE-", player, (profileName), format["seized $%1 worth of drugs / contraband from a %2, POS: %3. All Virtual items: %4, All Physical items: %5", [_seizeValue] call AP_fnc_numberText, (getText(configFile >> "CfgVehicles" >> (typeOf _civVehicle) >> "displayName")), (getPosATL _civVehicle), _allVirItems, _allPhyItems]], "APS_fnc_logIt", 2, false, false] spawn AP_fnc_MP;
    };} else {[format["Nothing illegal to seize in this %1.", _vehText], "basic"] spawn AP_fnc_handleMessage;};
[[_civVehicle, "release"], "APS_fnc_seizeLock", 2, false, true] spawn AP_fnc_MP;   // #363: release the server-held seize lock