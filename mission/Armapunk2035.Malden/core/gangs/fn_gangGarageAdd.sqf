params["_selectedVehicleData", ["_fromDeck", false, [false]]];
if (!_fromDeck && {(lbCurSel 100151) isEqualTo - 1}) exitWith {
    ["You did not select a vehicle to send to your garage!", "basic"] spawn AP_fnc_handleMessage;};
_selectedVehicleData params["_classname", "_plate", "_color", "_insured", "_mods", "_vehWear", "_customPlate"];
AP_gang_data params[["_myGangID", -1, [0]], ["_myGangName", "", [""]], ["_myGangRank", 5, [0]]];
if !(_myGangRank <= 3) exitWith {["You must be a rank 1-3 in a gang to use this feature", "basic"] spawn AP_fnc_handleMessage;};
_vehWear params["_currentVehDamage", "_currentVehFuelPercent", "_currentVehArmour"];
private _vehicleDisplayName = [configFile >> "CfgVehicles" >> _classname] call BIS_fnc_displayName;
private _vehCfgRow = ["getVehicleRowParsed", "", _classname] call AP_fnc_vehicleConfig;
if (isNil "_vehCfgRow") exitWith {["Error, send this message to a developer", "basic"] spawn AP_fnc_handleMessage;};
if (_vehCfgRow isEqualTo[]) exitWith {["Error, send this message to a developer", "basic"] spawn AP_fnc_handleMessage;};
private _sendPrice = (_vehCfgRow param[8, 25000]) * 0.35;
if (AP_atmcash < _sendPrice) exitWith {
    ["You can't afford to to move your vehicle into your gang garage!", "basic"] spawn AP_fnc_handleMessage;};
AP_garageCount = -1; [[AP_gang_data param[0, 0], player, getPlayerUID player], "APS_fnc_gangGarageCount", 2] spawn AP_fnc_MP;
waitUntil {uiSleep 0.01;
    (AP_garageCount isNotEqualTo - 1)};
if (AP_garageCount >= (call AP_maxGarageVeh)) exitWith {
    [format["You have %1 out of %2 max vehicles allowed in your gang garage.", AP_garageCount, (call AP_maxGarageVeh)], "basic"] spawn AP_fnc_handleMessage;
};
if (!_fromDeck) then {
    private _action = [format["Do you wish to send your %1 to your gang garage? This is a irreversible process and it will cost you $%2.", _vehicleDisplayName, [_sendPrice] call AP_fnc_numberText], format["Send to %1's Gang Garage", _myGangName], "Yes", "No"] call BIS_fnc_guiMessage;
    if !(_action) exitWith {["You chose not to send your vehicle to your gang garage!", "basic"] spawn AP_fnc_handleMessage;};
};
AP_atmcash = AP_atmcash - _sendPrice;
AP_atmcashCacheB = ((AP_atmcash / 4) + 11);
[1] call AP_fnc_ClupdatePartial;
[format["Attempting to send your %1 to %2's gang garage", _vehicleDisplayName, _myGangName], "basic"] spawn AP_fnc_handleMessage; [
    [_myGangID, player, getPlayerUID player, _plate, _vehicleDisplayName, _myGangName], "APS_fnc_gangGarageAddSRV", 2] spawn AP_fnc_MP;
if (!_fromDeck) then { lbDelete[100151, lbCurSel 100151]; closeDialog 0; };