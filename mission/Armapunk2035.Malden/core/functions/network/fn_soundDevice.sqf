params[["_vehicle", objNull, [objNull]]];
if (isNull _vehicle) exitWith {};
for "_i"
from 0 to 1 step 0 do {if (isNull _vehicle || !alive _vehicle) exitWith {};
    if (objNull isEqualTo(_vehicle getVariable["AP_mining", objNull])) exitWith {};
    _vehicle say3D "Device_disassembled_loop";
    uiSleep 28.6;};