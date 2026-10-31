params[["_vehicle", objNull, [objNull]], ["_time", 900, [0]]];
if (isNull _vehicle) exitWith {};
if !(_vehicle isKindOf "Car" || _vehicle isKindOf "Ship" || _vehicle isKindOf "Air" || _vehicle isKindOf "Tank") exitWith {};   // owner 2026-07-23: + Tank (Nyx)
if (AP_idleVehicleCache isEqualTo[]) exitWith {AP_idleVehicleCache pushBack[_vehicle, serverTime]; [
        [_vehicle, _time], "APS_fnc_setCleanTime", 2] spawn AP_fnc_MP;};
private _exit = false; {_x params["_cachedVehicle", "_lastTimeReset"];
    if (_cachedVehicle isEqualTo _vehicle) exitWith {_exit = true;
        private _resetThreshold = 90;
        if ((serverTime - _lastTimeReset) >= _resetThreshold) then {[[_vehicle, _time], "APS_fnc_setCleanTime", 2] spawn AP_fnc_MP;
            _x set[1, serverTime];};};}
forEach AP_idleVehicleCache;
if (_exit) exitWith {};
AP_idleVehicleCache pushBack[_vehicle, serverTime]; [[_vehicle, _time], "APS_fnc_setCleanTime", 2] spawn AP_fnc_MP;
[] spawn {{_x params["_cachedVehicle"];
        if (isNull _cachedVehicle) then {deleteVehicle _cachedVehicle;
            AP_idleVehicleCache deleteAt _forEachIndex;};
        uiSleep 0.3;}
    forEach AP_idleVehicleCache;};