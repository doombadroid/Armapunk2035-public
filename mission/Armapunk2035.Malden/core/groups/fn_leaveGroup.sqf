/*
    Re-plumbed 2026-08-12: takes an optional flag so a caller with its own screen
    open is not thrown back into the native group menu.

    Leaving as the LAST member deletes the group -- that is what "disband" means
    here; there is no separate function for it.
*/
params [["_direct", false, [false]]];
private _index = randomized_life_group_list findIf {AP_my_gang in _x};
if (_index isEqualTo - 1) exitWith {AP_my_gang = objNull;};
(randomized_life_group_list select _index) params["_name", "_group", "_locked", "_ownerID", "_password"];
openMap false;
AP_lastGroup = group player;
if (_ownerID isEqualTo(getPlayerUID player)) then {private _units = units group player;
    private _newOwner = _units param[_units findIf {!(_x isEqualTo player)}, objNull];
    if !(isNull _newOwner) then {randomized_life_group_list set[_index, [_name, _group, _locked, getPlayerUID _newOwner, _password]];
        publicVariable "randomized_life_group_list"; [[_newOwner, _group], "AP_fnc_clientGroupLeader", _newOwner] spawn AP_fnc_MP;
    } else {randomized_life_group_list deleteAt _index;
        publicVariable "randomized_life_group_list";};};
AP_my_gang = objNull;
if (rank player != "PRIVATE") then {player setRank "PRIVATE";};
[player] joinSilent(createGroup [civilian, true]);
if (isNil {(group player) getVariable "gang_id"} && !(AP_gang_data isEqualTo[])) then {AP_action_in_use = true;
    [] spawn AP_fnc_initGang;
    ["You have left your group. Rejoining your gangs default group.", "basic"] spawn AP_fnc_handleMessage;} else {
    ["You have left your group.", "basic"] spawn AP_fnc_handleMessage;};
if (!_direct) then { ["Group"] call AP_fnc_deckOpenApp; };