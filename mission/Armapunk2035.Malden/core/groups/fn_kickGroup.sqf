/*
    Re-plumbed 2026-08-12 for the web deck. The target used to come only from
    listbox 2621, which stores a VARIABLE NAME that resolves to the unit.

        [] call AP_fnc_kickGroup;                  // native, unchanged
        ["76561198..."] call AP_fnc_kickGroup;     // deck, by uid
*/
params [["_uidIn", "", [""]]];
private _direct = _uidIn isNotEqualTo "";
disableSerialization;
private _data = if (_direct) then {
    allPlayers param [allPlayers findIf { (getPlayerUID _x) isEqualTo _uidIn }, objNull]
} else {
    missionNamespace getVariable (lbData[2621, lbCurSel 2621])
};
if (isNull _data) exitWith {["That player is not here.", "basic"] spawn AP_fnc_handleMessage};
if (_data isEqualTo player) exitWith {["You can't kick yourself", "basic"] spawn AP_fnc_handleMessage};
private _index = randomized_life_group_list findIf {AP_my_gang in _x};
if (_index isEqualTo - 1) exitWith {};
(randomized_life_group_list select _index) params["_name", "_group", "_locked", "_ownerID", "_password"];
if ((getPlayerUID _data) isEqualTo _ownerID) then {
    randomized_life_group_list set[_index, [_name, _group, _locked, getPlayerUID player, _password]];
    publicVariable "randomized_life_group_list";}; [[_data, _group], "AP_fnc_clientGroupKick", _data] spawn AP_fnc_MP;
// the native menu reopens itself; a direct caller has its own screen open
if (!_direct) then { [] spawn AP_fnc_groupManagement; };