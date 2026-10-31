if (isRemoteExecuted && {remoteExecutedOwner != 2}) exitWith {};   // server-origin only: CfgRE allowedTargets limits the target, never the sender
params[["_vehicle", objNull, [objNull]]];
if (isNull _vehicle) exitWith {};
private _wheels = count(configFile >> "CfgVehicles" >> typeOf _vehicle >> "Wheels");
private _wheelPop = "";
for "_i"
from 1 to _wheels do {_wheelPop = format["wheel_%1_%2_steering", floor(random[1, 2, 3]), ceil(random(_wheels / 2))];
    _vehicle setHit[_wheelPop, 1];};