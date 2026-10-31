if !(isNull objectParent player) exitWith {
    ["Your arm isn't long enough to operate the pump from inside the vehicle.", "basic"] spawn AP_fnc_handleMessage};
private _vehicles = nearestObjects[_this select 0, ["Air", "Car", "Ship", "Armored"], 25];
if (_vehicles isEqualTo[]) exitWith {["No vehicles were found within 25 meters.", "basic"] spawn AP_fnc_handleMessage};
private _vehicle = _vehicles select 0;
if (fuel _vehicle isEqualTo 1) exitWith {["Your vehicle can't hold more gas!", "basic"] spawn AP_fnc_handleMessage};
if (isEngineOn _vehicle) exitWith {["Turn off your vehicle before refuelling!", "basic"] spawn AP_fnc_handleMessage};
private _capacity = getNumber(configFile >> "CfgVehicles" >> typeOf _vehicle >> "fuelCapacity");
private _litres = 0;
private _cost = 0;
private _fuelLevel = fuel _vehicle;
private _delay =
if (_vehicle isKindOf "Air") then {0.5 / 3} else {0.5};
disableSerialization;
5 cutRsc["AP_progress", "PLAIN"];
private _ui = uiNamespace getVariable "AP_progress";
private _progress = _ui displayCtrl 38201;
private _pgText = _ui displayCtrl 38202;
private _text = format["Cost: $%1 | %2/%3 litres", 0, round(_capacity * _fuelLevel), _capacity];
_pgText ctrlSetText format["%2 (1%1)...", "%", _text];
private _cP =
if (_fuelLevel > 0) then {_fuelLevel / 1} else {0.01};
_progress progressSetPosition _cP;
AP_action_in_use = true;
private _success = true;
private _tick = 0;
while {_fuelLevel < 1}
do {uiSleep _delay;
    _litres = _litres + 1;
    _cost = _cost + 6;
    if (AP_atmcash < _cost) exitWith {_success = false};
    _tick = 1 / _capacity;
    _fuelLevel = _fuelLevel + _tick;
    if (_fuelLevel > 1) then {_fuelLevel = 1};
    _text = format["Cost: $%1 | %2/%3 litres", [_cost] call AP_fnc_numberText, round(_capacity * _fuelLevel), _capacity];
    _cP = _cP + _tick;
    _progress progressSetPosition _cP;
    _pgText ctrlSetText format["%3 (%1%2)...", round(_cP * 100), "%", _text];
    if (speed player > 1) exitWith {};
    if (player distance(_this select 0) > 5) exitWith {};
    if !(AP_action_in_use) exitWith {};}; 5 cutText["", "PLAIN"];
AP_action_in_use = false;
if !(local _vehicle) then {[[_vehicle, _fuelLevel], "AP_fnc_setFuel", _vehicle] spawn AP_fnc_MP;} else {_vehicle setFuel _fuelLevel;};
if (_success) then {
    [format["<t align='center' color='#cec25b'>Litres: %1</t><br/><t align='center' color='#cec25b'>Cost: $%2</t><br/><t align='center' color='#cec25b'>Filled: %3%4</t><br/><br/><t align='center' color='#00FF00'>Refueling completed</t>", _litres, [_cost] call AP_fnc_numberText, round(_fuelLevel * 100), "%"], "basic"] spawn AP_fnc_handleMessage;
    AP_atmcash = AP_atmcash - _cost;
    AP_atmcashCacheB = ((AP_atmcash / 4) + 11);
    [1] call AP_fnc_ClupdatePartial;} else {["You cannot afford more gas!", "basic"] spawn AP_fnc_handleMessage;};