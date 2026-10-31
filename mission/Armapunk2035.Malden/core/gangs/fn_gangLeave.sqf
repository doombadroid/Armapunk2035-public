private _action = ["Are you sure you want to leave your gang?", "Leave Gang", "Leave", "Cancel"] call BIS_fnc_guiMessage;
if !(_action) exitWith {};
if ((AP_gang_data select 2) isEqualTo 1) exitWith {
    ["You cannot leave the gang as acting leader! Please appoint a new leader or disband the gang instead.", "basic"] spawn AP_fnc_handleMessage;
};
if !(isNil {(group player) getVariable "gang_id"}) then {[player] joinSilent(createGroup [civilian, true]);}; [
    [player, 2, AP_gang_data select 0, AP_gang_data select 1, player, -1], "APS_fnc_updateGangMem", 2] call AP_fnc_MP;
deleteMarkerLocal AP_gangBldgMark;
AP_gang_data = [];
AP_gangBuilding = [objNull, []];
AP_gangBldgMark = "";
player setVariable["gang_data", nil, true];
["Leaving gang...", "basic"] spawn AP_fnc_handleMessage;
closeDialog 0;