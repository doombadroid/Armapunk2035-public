#include "..\..\macro.h"
if (scriptAvailable(30)) exitWith {["Please wait a bit before locking the group!", "basic"] spawn AP_fnc_handleMessage;};
private _index = [AP_my_gang, randomized_life_group_list] call AP_fnc_index;
if (_index isEqualTo - 1) exitWith {};
private _gang = randomized_life_group_list select _index;
_gang params["_name", "_group", "_locked", "_ownerID", "_password"];
switch (true) do {case (player == leader(group player)): {
            randomized_life_group_list set[_index, [_name, _group, true, _ownerID, _password]];
            publicVariable "randomized_life_group_list";
            ctrlEnable[2626, true];
            ctrlEnable[2627, false];};
    case (getPlayerUID player == _ownerID): {randomized_life_group_list set[_index, [_name, _group, true, _ownerID, _password]];
            publicVariable "randomized_life_group_list";
            ctrlEnable[2627, false];
            ctrlEnable[2626, true];};};
[] spawn AP_fnc_groupManagement;