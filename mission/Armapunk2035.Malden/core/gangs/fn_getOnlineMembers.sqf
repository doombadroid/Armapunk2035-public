params[["_gangID", 0, [0]]];
if (_gangID isEqualTo 0) exitWith {["Failed to fetch online members.", "basic"] spawn AP_fnc_handleMessage; [];};
playableUnits select {(_x getVariable["gang_data", [-1]] select 0) isEqualTo _gangID};