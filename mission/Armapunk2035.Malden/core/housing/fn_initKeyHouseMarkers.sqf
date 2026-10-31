/*
    AP_fnc_initKeyHouseMarkers  (LooneyBin: owner 2026-06-23)
    Draw green "(Key)" map markers for houses this client holds a key to. Positions are computed + filtered
    server-side by APS_fnc_sendKeyHouses (the client never decides what it can see). Local markers only;
    cleared + redrawn each call so a relog/refresh never stacks duplicates.

    args: [ [[pos, oid], ...] ]
*/
if (isRemoteExecuted && {remoteExecutedOwner != 2}) exitWith {};   // server-origin only: CfgRE allowedTargets limits the target, never the sender
params [["_houses", [], [[]]]];
// clear any prior key-house markers so a refresh does not stack duplicates
{if ((_x find "pkeyhouse_") isEqualTo 0) then { deleteMarkerLocal _x };} forEach allMapMarkers; {
    _x params [["_pos", [], [[]]], ["_oid", -1]];
    if (_pos isEqualTo []) then { continue };
    private _m = createMarkerLocal [format ["pkeyhouse_%1", _oid], _pos];
    _m setMarkerTextLocal "House (Key)";
    _m setMarkerColorLocal "ColorGreen";
    _m setMarkerTypeLocal "mil_dot";} forEach _houses;
