disableSerialization;
params["_control", "_index"];
private _data = parseSimpleArray(_control lbData _index);
if ((_data select 0) isEqualTo "") exitWith {};
_data params["_classname", "_plate", "_color", "_insured", "_mods", "_vehWear", "_customPlate"];
AP_gang_data params[["_myGangID", -1, [0]], ["_myGangName", "", [""]], ["_myGangRank", -1, [0]]];
private _display = findDisplay 10300;
private _vehicleList = _display displayCtrl 10301;
private _vehicleTitle = _display displayCtrl 10302;
private _detailsText = _display displayCtrl 10303;
private _getButton = _display displayCtrl 10304;
private _repairButton = _display displayCtrl 10305;
private _displayTitle = _display displayCtrl 10306;
private _destroyButton = _display displayCtrl 10307;
_repairButton ctrlEnable false;
_getButton ctrlEnable false;
_destroyButton ctrlEnable(_myGangRank isEqualTo 1);
private _talentRequired = ["talentCheck", "", _classname] call AP_fnc_vehicleConfig;
if (_talentRequired isEqualTo "") then {_getButton buttonSetAction "[] spawn AP_fnc_gangGaragePull;";} else {
    _getButton buttonSetAction(format['["You require the %1 talent before being able to pull this vehicle from your garage.","basic"] spawn AP_fnc_handleMessage', _talentRequired]);
};
// owner 2026-06-23: gang vehicle PULL is restricted to ranks R1-R3 (1/2/3); R4 & R5 cannot pull -> grey out the
// GET button for them (destroy is already gated to R1 above). Repair/refuel stays available to every rank. The
// hard gate lives in fn_gangGaragePull (this is just UX). _myGangRank: 1 = leader (top) .. 5 = recruit (lowest).
_repairButton ctrlEnable !(_index isEqualTo - 1);
_getButton ctrlEnable (!(_index isEqualTo - 1) && {_myGangRank <= 3});
// SECURITY: buttonSetAction COMPILES its string on click. Do NOT format _data (contains the user-set plate) into
// it -- a metachar plate that bypassed the client charset guard would run as SQF (Lystic compile-RCE class).
// Stash the selected-vehicle data in uiNamespace and reference it instead (one selection live at a time).
uiNamespace setVariable ["AP_gangGrgSel", _data];
_repairButton buttonSetAction "[uiNamespace getVariable ['AP_gangGrgSel', []]] spawn AP_fnc_gangGarageRepairRefuel;";
_destroyButton buttonSetAction "[uiNamespace getVariable ['AP_gangGrgSel', []]] spawn AP_fnc_gangGarageDestroy;";
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