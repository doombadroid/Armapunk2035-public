/*
    fn_invite2Gang.sqf  (AP_fnc_invite2Gang) -- send a gang invitation.

    Two callers, ONE set of rules (re-plumbed 2026-08-14, same reason as
    fn_giveMoney):
        [] call AP_fnc_invite2Gang;             // native invite dialog 9550's listbox
        ["Exact Name"] call AP_fnc_invite2Gang; // web deck (fn_deckOpen "gangInvite")

    Returns true only when an invitation was actually sent.
*/
// Default objNull, NOT "": the native caller passes no arguments at all, and it
// has to land in the dialog branch.
params [["_who", objNull, [objNull, ""]]];
private _fromDialog = !(_who isEqualType "");

if ((AP_gang_data param [2, 5]) > 3) exitWith {
    ["You are not of proper rank to invite people to the gang!", "basic"] spawn AP_fnc_handleMessage; false};

private _playerToInvite = objNull;
if (_fromDialog) then {
    // Native path: the listbox stores a VARIABLE NAME, not a uid.
    if (!isNull(findDisplay 9550)) then {
        disableSerialization;
        private _varName = lbData[9555, lbCurSel 9555];
        if (_varName isNotEqualTo "") then {
            private _unit = missionNamespace getVariable _varName;
            if (!isNil "_unit" && {_unit isEqualType objNull}) then { _playerToInvite = _unit };
        };
    };
} else {
    // Deck path: an exact display name typed into the page. Match on the cleaned
    // name, which is what the roster shows, and case-insensitively -- players do
    // not type their friends' capitalisation.
    private _target = toLower (trim _who);
    if (_target isNotEqualTo "") then {
        _playerToInvite = allPlayers param [
            allPlayers findIf { _x isNotEqualTo player && {(toLower ([name _x] call AP_fnc_cleanName)) isEqualTo _target} },
            objNull];
    };
};

if (isNull _playerToInvite) exitWith {
    ["Could not find player to send invitation to. They may have disconnected.", "basic"] spawn AP_fnc_handleMessage;
    if (_fromDialog) then { closeDialog 0 };
    false};
if !((_playerToInvite getVariable["gang_data", []]) isEqualTo[]) exitWith {
    ["The player you selected is already in a gang!", "basic"] spawn AP_fnc_handleMessage;
    if (_fromDialog) then { closeDialog 0 };
    false};

[format["Sending gang invite to %1...", name _playerToInvite], "basic"] spawn AP_fnc_handleMessage;
if (_fromDialog) then { closeDialog 0 }; [
    [player, profileName, AP_gang_data, [AP_gang_talents, AP_gang_exp], AP_gangBuilding], "AP_fnc_gangInvite", _playerToInvite] spawn AP_fnc_MP;
true
