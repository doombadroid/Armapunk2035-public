if !(isNil "flip_active") exitWith {};
params[["_car", objNull, [objNull]]];
if (player distance _car > 8) exitWith {};
private _dir = vectorUp _car;
if !(_car isKindOf "Car" || _car isKindOf "Air") exitWith {
    ["Uhh, bro... That's not something you want to flip, trust me.", "basic"] spawn AP_fnc_handleMessage;};
flip_active = true;
if ((_dir select 2 < 0.8) || (_dir select 1 < 0.8)) then {
    ["Stand clear, the vehicle will unflip in 5 seconds.", "basic"] spawn AP_fnc_handleMessage;
    uiSleep 5;
    _car allowDamage false;
    if (count((getPosATL _car) nearEntities[["Car", "Air", "Ship"], 3]) > 1) exitWith {
        ["Move away other vehicles before unflipping this vehicle!", "basic"] spawn AP_fnc_handleMessage;}; [
        [_car], "APS_fnc_flipVehicle", 2] spawn AP_fnc_MP;
    uiSleep 3;
    _car allowDamage true;} else {["Car is not upside down.", "basic"] spawn AP_fnc_handleMessage;};
flip_active = nil;