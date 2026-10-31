params[["_typeMod", -1, [0]], ["_comboCtrl", controlNull], ["_selectedIndex", -1]];
if (_typeMod isEqualTo - 1) exitWith {};
if (_selectedIndex isEqualTo - 1) exitWith {};
disableSerialization;
private _plb_display = findDisplay 100210;
private _costText = _plb_display displayCtrl 100162;
private _cost = 0;
private _setValue = 0;
private _exit = false;
if (_typeMod in [0, 1, 2, 4, 5, 6, 7, 8]) then {private _vehModConfig = [] call AP_fnc_vehicleModConfig;
    private _modArray = _vehModConfig select _typeMod;
    _modArray params["_id", "_text", "_optionsArray"];
    if (_selectedIndex > ((count _optionsArray) - 1)) exitWith {_exit = true;};
    private _optionsSelected = _optionsArray select _selectedIndex;
    _optionsSelected params["_optionText", "_optionValue", "_optionPrice"];
    private _result = call {if ((AP_modShopMods select _typeMod) isEqualTo _optionValue) exitWith {};
        if (true) exitWith {_cost = _optionPrice;};};
    _setValue = _optionValue;};
if (_exit) exitWith {};
if (_typeMod isEqualTo 11) then {   // AUTOPILOT (config entry 9, shop/changes index 11)
    private _optionsArray = (([] call AP_fnc_vehicleModConfig) select 9) select 2;
    if (_selectedIndex > ((count _optionsArray) - 1)) exitWith { _exit = true; };
    (_optionsArray select _selectedIndex) params ["_apText", "_apValue", "_apPrice"];
    // MOTORIST Autopilot Certified waives the AUTOPILOT (value 1) only. owner 2026-07-21: slot 9 now also
    // offers 2 = Analog Retrofit ($45k, rips the computer out) -- the talent must not waive that one too.
    // Already-fitted value stays free so re-opening the menu doesn't re-charge for what you own.
    _cost = if ((201 in AP_side_talents && {_apValue isEqualTo 1}) || {(AP_modShopMods select 11) isEqualTo _apValue}) then { 0 } else { _apPrice };
    _setValue = _apValue;};
if (_typeMod isEqualTo 3) then {private _availableHorns = [1] call AP_fnc_hornCfg;
    private _hornID = _comboCtrl lbValue _selectedIndex;
    if !(_hornID isEqualTo(AP_modShopMods select 3)) then {private _index = _availableHorns findIf {(_x select 0) isEqualTo _hornID};
        private _hornCost = (_availableHorns select _index) select 2;
        _cost = _hornCost;} else {_cost = 0;};
    _setValue = _hornID;};
if (_typeMod isEqualTo 9) then {private _skinID = _comboCtrl lbValue _selectedIndex;
    if !(_skinID isEqualTo(AP_modShopMods select 5)) then {_cost = 2500;} else {_cost = 0;};
    _setValue = _skinID;};
AP_modShopChanges set[_typeMod, _setValue];
AP_modShopCosts set[_typeMod, _cost];
private _total = 0; {_total = _total + _x}
forEach AP_modShopCosts;
_costText ctrlSetText format["$%1", [_total] call AP_fnc_numberText];
switch (_typeMod) do {case 0: {};
    case 1: {};
    case 2: {};
    case 3: {};
    case 4: {};
    case 5: {};
    case 6: {};
    case 7: {};
    default {};};