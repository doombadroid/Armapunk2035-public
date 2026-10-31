/*
    Re-plumbed 2026-08-12 for the web deck, same shape as fn_kickGroup.

        [] call AP_fnc_setGroupLeader;                 // native
        ["76561198..."] call AP_fnc_setGroupLeader;    // deck, by uid

    The leader-only check below is untouched and runs for both callers.
*/
params [["_uidIn", "", [""]]];
private _direct = _uidIn isNotEqualTo "";
disableSerialization;
private _data = if (_direct) then {
    allPlayers param [allPlayers findIf { (getPlayerUID _x) isEqualTo _uidIn }, objNull]
} else {
    missionNamespace getVariable ((findDisplay 2620 displayCtrl 2621) lbData (lbCurSel 2621))
};
if (isNull _data) exitWith {["That player is not here.", "basic"] spawn AP_fnc_handleMessage};
private _index = [AP_my_gang, randomized_life_group_list] call AP_fnc_index;
if (_index isEqualTo - 1) exitWith {};
if (leader(group player) != player) exitWith {["You don't have the ability to do that.", "basic"] spawn AP_fnc_handleMessage;};
_gang = randomized_life_group_list select _index;
_gang params["_name", "_group", "_locked", "_ownerID", "_password"];
randomized_life_group_list set[_index, [_name, _group, _locked, getPlayerUID _data, _password]];
publicVariable "randomized_life_group_list";
_group selectLeader _data; [[_data, _group], "AP_fnc_clientGroupLeader", _data, false] spawn AP_fnc_MP;
player setRank "PRIVATE";
if (!_direct) then { [] spawn AP_fnc_groupManagement; };