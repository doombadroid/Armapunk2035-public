AP_modShopVehicle params[["_classname", "", [""]], ["_plate", -2, [0]]];
private _startMods = AP_modShopMods;
private _endMods = AP_modShopChanges;
private _modCosts = AP_modShopCosts;
private _updateMods = +_endMods;
_updateMods resize 9;
_updateMods pushBack (_endMods param [11, 0]);   // autopilot rides mods slot 9
private _customPlate = _endMods select 10;
if (_customPlate isEqualTo "" && !(_startMods select 10 isEqualTo "")) then {_customPlate = _startMods select 10;};
if (_classname isEqualTo "" || _plate isEqualTo - 2) exitWith {};
if (_startMods isEqualTo[] || _endMods isEqualTo[] || _modCosts isEqualTo[]) exitWith {};
if (_modCosts isEqualTo[0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]) exitWith {};
if (_startMods isEqualTo _endMods) exitWith {};
private _cost = 0; {_cost = _cost + _x;}
forEach _modCosts;
if !([_cost] call AP_fnc_debitCard) exitWith {};
if (_cost >= 3500) then {[6] call AP_fnc_ClupdatePartial;};
private _idx = AP_garageData findIf {_plate in _x};
(AP_garageData select _idx) set[10, _updateMods];
(AP_garageData select _idx) set[8, _endMods select 9];
(AP_garageData select _idx) set[12, _endMods select 10]; [
    [getPlayerUID player, _classname, _plate, _updateMods, _endMods select 9, _customPlate], "APS_fnc_updateVehicleMods", 2] call AP_fnc_MP;
closeDialog 0;