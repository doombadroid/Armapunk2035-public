params[["_building", objNull, [objNull]]];
AP_gang_data params[["_myGangID", -1, [0]], ["_myGangName", "", [""]], ["_myGangRank", -1, [0]]];
if !(_myGangRank isEqualTo 1) exitWith {
    ["You are not the gang leader and can not perform this action!", "basic"] spawn AP_fnc_handleMessage;};
if !((_building getVariable["AP_homeOwner", ""]) isEqualTo(getPlayerUID player)) exitWith {
    ["You are not the owner of this building and can not set it to be a gang house!", "basic"] spawn AP_fnc_handleMessage;};
if !((AP_gang_data select 3) isEqualTo[0, 0, 0]) exitWith {["You already have a gang house!", "basic"] spawn AP_fnc_handleMessage;};
if !((AP_gangBuilding select 1) isEqualTo[]) exitWith {["You already have a gang house!", "basic"] spawn AP_fnc_handleMessage;};
if ((_building getVariable["AP_houseID", -1]) isEqualTo - 1) exitWith {};
AP_action_in_use = true;
private _action = ["Are you sure you want to make this your gang building? Gang members will be able to spawn here and access certain building functions if you set this as your gang building.", "Convert to Gang Building?", "Convert", "Cancel"] call BIS_fnc_guiMessage;
AP_action_in_use = false;
if !(_action) exitWith {
    ["You have chosen not to make this building a gang building at this time...", "basic"] spawn AP_fnc_handleMessage;};
["Establishing this house to a gang building...", "basic"] spawn AP_fnc_handleMessage;
AP_gangBuilding = [_building, getPosATL _building];
AP_gang_data set[3, getPosATL _building];
// owner 2026-06-17 (#324): mark the gang HQ green for the LEADER too. setGangHouseForMembers (below) only
// runs for the OTHER online members (- [player]); nothing marked the leader, so the leader saw only their
// blue owned-house marker ("normal house"). Same marker name the relog path (fn_initGang) uses so a later
// relog replaces it cleanly.
deleteMarkerLocal AP_gangBldgMark;
deleteMarkerLocal (format ["phouse_gang_%1", _myGangID]);
AP_gangBldgMark = createMarkerLocal [format ["phouse_gang_%1", _myGangID], getPosATL _building];
AP_gangBldgMark setMarkerTextLocal "Gang Building";
AP_gangBldgMark setMarkerColorLocal "ColorGreen";
AP_gangBldgMark setMarkerTypeLocal "mil_end"; [[player, _building, _myGangID], "APS_fnc_addGangHouse", 2] call AP_fnc_MP;
private _onlineMembers = ([_myGangID] call AP_fnc_getOnlineMembers) - [player]; [
    [_building, _myGangID], "AP_fnc_setGangHouseForMembers", _onlineMembers] spawn AP_fnc_MP;