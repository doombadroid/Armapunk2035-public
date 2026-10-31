params["_data"];
_data params[["_classname", "", [""]], "_plate", "_color", "_insured", ["_mods", [0, 0, 0, 0, 0, 0, 0, 0, 0], [[]]
], ["_vehWear", [0, 0, 0], [[]]], ["_customPlate", "", [""]]];
["AP_garageMods"] call AP_fnc_createDialog;
disableSerialization;
waitUntil {uiSleep 0.01;
    !isNull(findDisplay 100210)};
private _plb_display = findDisplay 100210;
private _currentMods = _plb_display displayCtrl 100151;
private _trunkCombo = _plb_display displayCtrl 100152;
private _skinCombo = _plb_display displayCtrl 100153;
private _hornCombo = _plb_display displayCtrl 100154;
private _handlingCombo = _plb_display displayCtrl 100155;
private _licensePlate = _plb_display displayCtrl 100157;
private _licenseText = _plb_display displayCtrl 100158;
private _saveButton = _plb_display displayCtrl 100160;
private _backButton = _plb_display displayCtrl 100161;
private _costText = _plb_display displayCtrl 100162;
private _nitrousCombo = _plb_display displayCtrl 100170;
private _pStorageCombo = _plb_display displayCtrl 100171;
private _hardenedLocksCombo = _plb_display displayCtrl 100172;
private _trackerCombo = _plb_display displayCtrl 100173;
private _alarmCombo = _plb_display displayCtrl 100174;
private _doorCombo = _plb_display displayCtrl 100175;
private _doorText = _plb_display displayCtrl 100176;
private _autopilotCombo = _plb_display displayCtrl 100177;
private _allComboCtrls = [_alarmCombo, _trunkCombo, _handlingCombo, _hornCombo, _nitrousCombo, _trackerCombo, _pStorageCombo, _hardenedLocksCombo, _doorCombo, _autopilotCombo]; {
    _x ctrlEnable false;}
forEach _allComboCtrls;
_costText ctrlSetText "$0";
if (count _mods < 9) then {private _toAdd = 9 - (count _mods);
    for [{_x = 1}, {_x <= _toAdd}, {_x = _x + 1}] do {_mods pushBack 0;};};
// owner 2026-07-12: AUTOPILOT rides mods slot 9. Extract it so the legacy color(9)/plate(10)
// shop indices survive, then re-append as shop index 11 (mods 0-8, color 9, plate 10, autopilot 11).
private _autopilotMod = _mods param [9, 0];
_mods resize 9;
_mods params["_vehAlarm", "_trunkMod", "_handlingMod", "_hornMod", "_nitrousMod", "_trackerMod", "_pStorageMod", "_lockpickMod", "_doorsMod"];
_mods pushBack _color;
_mods pushBack _customPlate;
_mods pushBack _autopilotMod;   // shop index 11
AP_modShopVehicle = [_classname, _plate];
AP_modShopMods = +_mods;
AP_modShopChanges = +_mods;
AP_modShopCosts = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0];
private _fillVals = (_mods select [0, 9]) + [0, 0, _autopilotMod];   // config idx 9 (autopilot) reads shop idx 11
private _vehModConfig = [] call AP_fnc_vehicleModConfig; {private _index = _forEachIndex;
    _x params["_id", "_text", "_optionsArray"];
    if !(_optionsArray isEqualTo[]) then {private _comboCtrl = _allComboCtrls select _index;
        private _curVal = if (_index isEqualTo 9) then { _fillVals select 11 } else { _fillVals select _index }; {
            _x params["_optionText", "_optionValue", "_optionPrice"];
            _comboCtrl lbAdd _optionText;
            _comboCtrl lbSetValue[_forEachIndex, _optionValue];
            if (_curVal isEqualTo _optionValue) then {_comboCtrl lbSetCurSel _forEachIndex;};}
        forEach _optionsArray;};}
forEach _vehModConfig;
private _availableHorns = [1] call AP_fnc_hornCfg; {
    _hornCombo lbAdd format["%1 - $%2", _x select 1, [_x select 2] call AP_fnc_numberText];
    _hornCombo lbSetValue[_forEachIndex, _x select 0];}
forEach _availableHorns;
private _sideFlag =
switch (AP_effSide) do {case west: {"cop"};
    case independent: {"med"};
    case civilian: {"civ"};}; private _availTextures = [];
_availTextures = ["modTextures", _classname, _sideFlag] call AP_fnc_vehicleTextures; {_skinCombo lbAdd(_x select 1);
    _skinCombo lbSetValue[_forEachIndex, (_x select 0)];}
forEach _availTextures;
_licensePlate ctrlAddEventHandler["KeyUp", {params["_control"];
    disableSerialization;
    private _plb_display = ctrlParent _control;
    private _costText = _plb_display displayCtrl 100162;
    private _saveButton = _plb_display displayCtrl 100160;
    private _licensePlate = ctrlText _control;
    if ([_licensePlate] call AP_fnc_checkPlate) then {AP_modShopCosts set[10, 2500];
        _saveButton ctrlEnable true;} else {AP_modShopCosts set[10, 0];
        _saveButton ctrlEnable false;};
    if (_licensePlate isEqualTo "") then {AP_modShopCosts set[10, 0];
        _saveButton ctrlEnable true;};
    AP_modShopChanges set[10, _licensePlate];
    private _total = 0; {_total = _total + _x}
    forEach AP_modShopCosts;
    _costText ctrlSetText format["$%1", [_total] call AP_fnc_numberText];}];
_alarmCombo ctrlAddEventHandler["LBSelChanged", {[0, _this select 0, _this select 1] call AP_fnc_garageModComboChange;}];
_trunkCombo ctrlAddEventHandler["LBSelChanged", {[1, _this select 0, _this select 1] call AP_fnc_garageModComboChange;}];
_handlingCombo ctrlAddEventHandler["LBSelChanged", {[2, _this select 0, _this select 1] call AP_fnc_garageModComboChange;}];
_hornCombo ctrlAddEventHandler["LBSelChanged", {[3, _this select 0, _this select 1] call AP_fnc_garageModComboChange;}];
_nitrousCombo ctrlAddEventHandler["LBSelChanged", {[4, _this select 0, _this select 1] call AP_fnc_garageModComboChange;}];
_trackerCombo ctrlAddEventHandler["LBSelChanged", {[5, _this select 0, _this select 1] call AP_fnc_garageModComboChange;}];
_pStorageCombo ctrlAddEventHandler["LBSelChanged", {[6, _this select 0, _this select 1] call AP_fnc_garageModComboChange;}];
_hardenedLocksCombo ctrlAddEventHandler["LBSelChanged", {[7, _this select 0, _this select 1] call AP_fnc_garageModComboChange;}];
_doorCombo ctrlAddEventHandler["LBSelChanged", {[8, _this select 0, _this select 1] call AP_fnc_garageModComboChange;}];
_skinCombo ctrlAddEventHandler["LBSelChanged", {[9, _this select 0, _this select 1] call AP_fnc_garageModComboChange;}];
private _vehName = ([_classname] call AP_fnc_fetchVehInfo) select 3;
private _curAlarm =
switch (_vehAlarm) do {case 0: {"No Alarm System"};
    case 1: {"Basic Alarm"};
    default {"N/A"};}; private _curTrunk =
switch (_trunkMod) do {case 0: {"Base Storage"};
    case 50: {"+50 Storage"};
    case 75: {"+75 Storage"};
    case 100: {"+100 Storage"};
    default {"N/A"};}; private _curHandling =
switch (_handlingMod) do {case 0: {"Stock Handling"};
    case 1: {"Suspension Mod"};
    case 2: {"Brakes and Suspension"};
    default {"N/A"};}; private _curHorn = (_availableHorns param[_availableHorns findIf {(_x select 0) isEqualTo _hornMod
}, "Stock Horn"]) param[1, "Stock Horn"];
if !(_classname isKindOf "Car") then {{private _idx = _x lbAdd "Unmodifiable";
        _x lbSetCurSel _idx;}
    forEach[_hornCombo, _handlingCombo, _nitrousCombo];
    _skinCombo ctrlEnable true;
    _trunkCombo ctrlEnable true;
    _hardenedLocksCombo ctrlEnable true;
    _alarmCombo ctrlEnable true;
    _trackerCombo ctrlEnable true;} else {_alarmCombo ctrlEnable true;
    _hornCombo ctrlEnable true;
    _licensePlate ctrlEnable true;
    _handlingCombo ctrlEnable true;
    _skinCombo ctrlEnable true;
    _trunkCombo ctrlEnable true;
    _nitrousCombo ctrlEnable true;
    _trackerCombo ctrlEnable true;
    _hardenedLocksCombo ctrlEnable true;
    if (_customPlate != "") then {_licensePlate ctrlSetText _customPlate;};};
if (_classname in ["O_T_LSV_02_unarmed_F", "B_T_LSV_01_unarmed_F"]) then {_doorCombo ctrlEnable true;} else {_doorCombo ctrlShow false;
    _doorText ctrlShow false;};
// owner 2026-07-12: autopilot module -- every GROUND vehicle (the enable branches above predate this combo)
_autopilotCombo ctrlEnable (_classname isKindOf "LandVehicle");
if (AP_effSide isEqualTo independent) then {_skinCombo ctrlEnable false;
    _trunkCombo ctrlEnable false;};
private _customPlate =
if !(_classname isKindOf "Car") then {_plate} else {if (_customPlate isEqualTo "") then {"No Custom Plate"} else {_customPlate}};
private _currentSkin = ["colorname", _classname, _color] call AP_fnc_vehicleTextures;
_currentMods ctrlSetStructuredText parseText format["<t align='center'>%1</t><br/><br/><t size='0.85'>Storage: %2<br/>Paint: %3<br/>Horn: %4<br/>Handling: %5<br/>Alarm: %6<br/>Plate Text: %7</t>", _vehName, _curTrunk,
if (_currentSkin isEqualTo "") then {
    "Default"} else {_currentSkin}, _curHorn, _curHandling, _curAlarm, if (_customPlate isEqualTo "") then {"No Cu"} else {_customPlate}];
_saveButton buttonSetAction "[] call AP_fnc_garageBuyMods;";