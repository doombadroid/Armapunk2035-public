if (isRemoteExecuted && {remoteExecutedOwner != 2}) exitWith {};   // server-origin only: CfgRE allowedTargets limits the target, never the sender
params[["_bagPos", [0, 0, 0], [[]]], ["_loggerName", "", [""]]];
private _marker = createMarkerLocal[format["bounty_bodybag_%1", (str _bagPos)], _bagPos];
_marker setMarkerShapeLocal "ICON";
_marker setMarkerTypeLocal "mil_dot";
_marker setMarkerColorLocal "ColorOrange";
_marker setMarkerTextLocal "Fugitive Bodybag";
private _dir = call {private _heading = (player getDir _bagPos);
    if (_heading >= 338) exitWith {"North"};
    if (_heading <= 23) exitWith {"North"};
    if (_heading <= 68) exitWith {"North East"};
    if (_heading <= 113) exitWith {"East"};
    if (_heading <= 158) exitWith {"South East"};
    if (_heading <= 203) exitWith {"South"};
    if (_heading <= 248) exitWith {"South West"};
    if (_heading <= 293) exitWith {"West"};
    if (_heading <= 338) exitWith {"North West"};"heading some unknown direction";};
if (player distance2D _bagPos <= 50) then {
    [format["%1 has combat logged, their bodybag is %2 meters away and %3 from you.", _loggerName, player distance _bagPos, _dir], "shortwarning"] spawn AP_fnc_handleMessage;
};
uiSleep 60;
deleteMarkerLocal _marker;