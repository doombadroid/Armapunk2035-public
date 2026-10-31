/*
    fn_gangRenamed.sqf  (AP_fnc_gangRenamed)  -- Armapunk 2035 2026-08-14

    Server -> every ONLINE member after APS_fnc_gangRenameSRV commits a rename.
    Args: [_gangID, _newName, _newFunds]

    The name lives in three places on a client: AP_gang_data (what every gang
    screen reads), the published `gang_data` object variable (what other clients
    read for the gangs-online roster), and whatever dialog happens to be open.
    A member who never hears about the rename keeps showing the old name AND
    sends it back on their next gang op, so all three are updated here.
*/
if (isRemoteExecuted && {remoteExecutedOwner != 2}) exitWith {};   // server-origin only: CfgRE allowedTargets limits the target, never the sender
params [["_gangID", -1, [0, -1, ""]], ["_name", "", [""]], ["_funds", -1, [0]]];
if (AP_gang_data isEqualTo [] || {_name isEqualTo ""}) exitWith {};
// The gang id can be cached as a number on one side and a string on the other
// (receiveGangs leaves select-0 un-parsed) -- compare as text, as fn_gangBank does.
if !((format ["%1", AP_gang_data param [0, -1]]) isEqualTo (format ["%1", _gangID])) exitWith {};

AP_gang_data set [1, _name];
player setVariable ["gang_data", AP_gang_data, true];
if (_funds >= 0) then { AP_gang_funds = _funds; };

// Native gang dialog, if it is the thing that is open.
disableSerialization;
if (!isNull(findDisplay 9550)) then { ctrlSetText[9522, format["Gang Management - %1", _name]] };

[format["Your gang is now called %1.", _name], "basic"] spawn AP_fnc_handleMessage;
