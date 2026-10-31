disableSerialization;
params["_control", "_index"];
private _data = parseSimpleArray(_control lbData _index);
if ((_data select 0) isEqualTo "") exitWith {};
_data params["_classname", "_plate", "_color", "_insured", "_mods", "_vehWear", "_customPlate"];
AP_gang_data params[["_myGangID", -1, [0]], ["_myGangName", "", [""]], ["_myGangRank", -1, [0]]];
private _display = findDisplay 100150;
private _vehicleTitle = _display displayCtrl 100152;
private _detailsText = _display displayCtrl 100153;
private _sellButton = _display displayCtrl 100154;
private _getButton = _display displayCtrl 100155;
private _modButton = _display displayCtrl 100156;
private _repairRefuelButton = _display displayCtrl 100169;
private _toGangGarageButton = _display displayCtrl 100170;
private _enableToGarage = ((_myGangID isNotEqualTo - 1) && (_myGangRank <= 3) && (AP_effSide isEqualTo civilian));
_sellButton ctrlEnable true;
_getButton ctrlEnable true;
_modButton ctrlEnable true;
_repairRefuelButton ctrlEnable true;
_toGangGarageButton ctrlEnable false;
if (_enableToGarage) then {_toGangGarageButton ctrlEnable true;
    _toGangGarageButton ctrlShow true;} else {_toGangGarageButton ctrlEnable false;
    _toGangGarageButton ctrlShow false;};
private _talentRequired = ["talentCheck", "", _classname] call AP_fnc_vehicleConfig;
if (_talentRequired isEqualTo "") then {_getButton buttonSetAction "[] spawn AP_fnc_vehicleGaragePull;";} else {
    _getButton buttonSetAction(format['["You require the %1 talent before being able to pull this vehicle from your garage.","basic"] spawn AP_fnc_handleMessage', _talentRequired]);
}; {_x ctrlEnable!(_index isEqualTo - 1)}
forEach[_sellButton, _getButton];
_sellButton buttonSetAction "[] spawn AP_fnc_vehicleGarageSell;";
// SECURITY: buttonSetAction COMPILES on click -- never format _data (holds the user-set plate) into it; a
// metachar plate past the client charset guard would execute as SQF. Stash + reference instead.
uiNamespace setVariable ["AP_vehGrgSel", _data];
_modButton buttonSetAction "[uiNamespace getVariable ['AP_vehGrgSel', []]] spawn AP_fnc_garageModMenu;";
_repairRefuelButton buttonSetAction "[uiNamespace getVariable ['AP_vehGrgSel', []]] spawn AP_fnc_vehicleGarageRepairRefuel;";
_toGangGarageButton buttonSetAction "[uiNamespace getVariable ['AP_vehGrgSel', []]] spawn AP_fnc_gangGarageAdd;";
private _skin = ["colorname", _classname, _color] call AP_fnc_vehicleTextures;
private _vehInfo = [_classname] call AP_fnc_fetchVehInfo;
private _vehCfgRow = ["getVehicleRowParsed", "", _classname] call AP_fnc_vehicleConfig;
private _vehSellPrice = _vehCfgRow select 8;
private _vehGarageFee = _vehCfgRow select 9;
private _vehTrunkSpace = _vehCfgRow select 10;
private _message = parseText format["<t size='0.40'>&#160;</t><br/><img image='%2' size='1.15'/> | %1 - %3", _vehInfo select 3, _vehInfo select 2, _plate];
_vehicleTitle ctrlSetStructuredText _message;
if (count _mods < 9) then {private _toAdd = 9 - (count _mods);
    for [{_x = 1}, {_x <= _toAdd}, {_x = _x + 1}] do {_mods pushBack 0;};};
_vehTrunkSpace = _vehTrunkSpace + (_mods select 1);
private _details = ""; {_x params["_title", "_value"];
    _details = _details + format["%1: %2<br/><t size='0.25'>&#160;</t><br/>", _title, _value];}
forEach[["License plate", if (_customPlate isEqualTo "") then {_plate} else {_customPlate
}], ["Garage Fee", format["<t color='#8cff9b'>$%1</t>", [_vehGarageFee] call AP_fnc_numberText]], ["Sale Price", format["<t color='#8cff9b'>$%1</t>", [_vehSellPrice] call AP_fnc_numberText]], ["Max Speed", format["%1 km/h", _vehInfo select 8]], ["Passenger Seats", (([_classname, true] call BIS_fnc_crewCount) - 1)], ["Trunk Capacity", _vehTrunkSpace], ["Fuel Capacity", format["%1 [%2%3 Full]", _vehInfo select 12, ((_vehWear select 1) * 100) toFixed 1, "%"]], ["Armor Rating", format["%1 [%2%3 Damage]", _vehInfo select 9, ((_vehWear select 0) * 100) toFixed 1, "%"]], ["Vehicle Alarm",
if ((_mods select 0) isEqualTo 0) then {"No"} else {"Yes"}], ["Paint", if !(_skin isEqualTo "") then {_skin} else {"Default"}]];
_detailsText ctrlSetStructuredText parseText("<t size='0.90'>" + _details + "</t>");