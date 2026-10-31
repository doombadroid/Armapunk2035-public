params[["_vehicle", objNull, [objNull]]];
if (player distance _vehicle > 8) exitWith {};
private _crew = crew _vehicle;
private _toPull = 0; {if !(alive _x) then {private _plb_pos = (vehicle _x) modelToWorld[-2, 0, 0];
        _x setPos _plb_pos;} else {
        if ((_x getVariable["AP_restrained", false]) || (_x getVariable["AP_downed", false]) || AP_effSide isEqualTo west || ((AP_effSide isEqualTo civilian) && {
            cursorTarget in AP_vehicles})) then {_x setVariable["AP_transporting", nil, true];
            _x setVariable["AP_escorting", nil, true]; [["pullout", _x], "APS_fnc_victimSRV", 2, false, false] spawn AP_fnc_MP;
            _toPull = _toPull + 1;};}}
forEach _crew;
if (_toPull isEqualTo 0) then {["There is nobody in this vehicle who you're able to remove!", "basic"] spawn AP_fnc_handleMessage;};