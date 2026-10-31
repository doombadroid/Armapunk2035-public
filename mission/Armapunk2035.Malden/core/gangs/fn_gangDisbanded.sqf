if (isRemoteExecuted && {remoteExecutedOwner != 2}) exitWith {};   // server-origin only: CfgRE allowedTargets limits the target, never the sender
params[["_gangID", 0, [0]]];
if (_gangID isEqualTo 0) exitWith {};
if !(isNull(findDisplay 9620)) then {closeDialog 0};
if ((AP_gang_data select 2) isEqualTo 1) then {AP_action_in_use = false;};
["Your gang has been disbanded!", "shortwarning"] spawn AP_fnc_handleMessage;
if !(isNil {(group player) getVariable "gang_id"}) then {private _group = group player;
    [player] joinSilent(createGroup [civilian, true]);
    if (units _group isEqualTo[]) then {deleteGroup _group;};};
player setVariable["gang_data", nil, true];
deleteMarkerLocal AP_gangBldgMark;
AP_gang_data = [];
AP_gangBuilding = [objNull, []];
AP_gangBldgMark = "";
AP_gang_talents = [];
AP_gang_exp = 0;