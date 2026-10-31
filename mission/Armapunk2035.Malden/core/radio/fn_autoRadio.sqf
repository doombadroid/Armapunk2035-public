/*
    fn_autoRadio.sqf  (AP_fnc_autoRadio) -- Q toggles the radio for the vehicle you are DRIVING. The station
    content comes from the SERVER station-master (APS_fnc_radioSRV -> AP_radioNow), so this just flips the car's
    AP_radioOn + ensures a station is set. It plays no sound (that's AP_fnc_radioListen) and runs no loop, so
    the radio KEEPS PLAYING after the driver leaves -- it only stops when a driver toggles it off (Q) or the car is
    stored/destroyed (the car object goes away with AP_radioOn). Only the driver can toggle/change station.
*/
private _veh = vehicle player;
if (_veh isEqualTo player) exitWith { ["Get in a vehicle to use the radio.", "basic"] spawn AP_fnc_handleMessage; };
if (_veh isKindOf "Air") exitWith { ["No radio in aircraft.", "basic"] spawn AP_fnc_handleMessage; };   // Q/R are flight controls
if !(driver _veh isEqualTo player) exitWith { ["Only the driver controls the radio.", "basic"] spawn AP_fnc_handleMessage; };

private _on = !(_veh getVariable ["AP_radioOn", false]);
if (isNil { _veh getVariable "AP_radioStation" }) then { _veh setVariable ["AP_radioStation", 0, true]; };
_veh setVariable ["AP_radioOn", _on, true];
[if (_on) then { "Radio ON" } else { "Radio OFF" }, "info"] spawn AP_fnc_handleMessage;
