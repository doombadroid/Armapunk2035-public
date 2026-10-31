/*
    Re-plumbed 2026-08-12 for the web deck.

    The native function is two dialogs deep: with no password prompt open it reads
    the selection from listbox 2521 and, if the group is LOCKED, stashes it in
    AP_targetGroup and opens prompt 2540; reopened with 2540 up it reads the
    typed password from 2543 and compares. Neither branch can be driven from a
    page.

    A direct caller passes both at once:

        [] call AP_fnc_joinGroup;                       // native, unchanged
        ["Wreckers", "hunter2"] call AP_fnc_joinGroup;  // deck

    The rules are the same ones the native branches enforce -- passive mode is
    blocked, an unlocked group needs no password, a locked one needs an exact
    non-empty match, and admins bypass the lock exactly as before.
*/
params [["_nameIn", "", [""]], ["_passIn", "", [""]]];
disableSerialization;
if !(AP_effSide isEqualTo civilian) exitWith {["Only civilians can use squads.", "basic"] spawn AP_fnc_handleMessage;};

if (_nameIn isNotEqualTo "") exitWith {
    if (AP_passiveModeJIP) exitWith {
        ["You cannot join a group while in passive mode! You can disable it on your phone (Y).", "basic"] spawn AP_fnc_handleMessage;};
    private _index = [_nameIn, randomized_life_group_list] call AP_fnc_index;
    if (_index isEqualTo -1) exitWith {["Couldn't find that group.", "basic"] spawn AP_fnc_handleMessage;};
    (randomized_life_group_list select _index) params ["_name", "_group", "_locked", "_ownerID", "_password"];
    if (isNull _group) exitWith {["Group is not valid", "basic"] spawn AP_fnc_handleMessage;};
    private _open = (call AP_adminLevel >= 5) || {!_locked};
    if (!_open && {!(_passIn isEqualTo _password && {_passIn isNotEqualTo ""})}) exitWith {
        ["Incorrect password.", "basic"] spawn AP_fnc_handleMessage;};
    [player] join _group;
    AP_my_gang = _group;
    [format ["You have joined the group: %1", _name], "basic"] spawn AP_fnc_handleMessage;
    _name spawn {uiSleep 0.5;
        private _units = (units group player) apply {getPlayerUID _x};
        [["-GROUP-", player, (profileName), format ["joined the group named: %1. Members: %2", _this, _units]],
            "APS_fnc_logIt", 2] call AP_fnc_MP;};
    true
};

if (isNull(findDisplay 2540)) then {private _dialog = findDisplay 2520;
    private _gangs = _dialog displayCtrl 2521;
    private _sel = lbCurSel _gangs;
    private _data = _gangs lbData _sel;
    if (AP_passiveModeJIP) exitWith {
        ["You cannot join a group while in passive mode! You can disable it on your phone (Y).", "basic"] spawn AP_fnc_handleMessage;};
    private _index = [_data, randomized_life_group_list] call AP_fnc_index;
    if (_index isEqualTo - 1) exitWith {["Couldn't find that group.", "basic"] spawn AP_fnc_handleMessage;};
    private _gang = randomized_life_group_list select _index;
    _gang params["_name", "_group", "_locked", "_ownerID", "_password"];
    if !(isNull _group) then {if ((call AP_adminLevel >= 5) || !(_locked)) then {[player] join _group;
            AP_my_gang = _group;
            [format["You have joined the group: %1", _name], "basic"] spawn AP_fnc_handleMessage;
            [] spawn AP_fnc_groupMenu;} else {AP_targetGroup = _gang;
            ["groupMenuPassword"] spawn AP_fnc_createDialog;};
        _name spawn {uiSleep 0.5;
            private _units = (units group player) apply {getPlayerUID _x}; [
                ["-GROUP-", player, (profileName), format["joined the group named: %1. Members: %2", _this, _units]], "APS_fnc_logIt", 2] call AP_fnc_MP;
        };} else {["Group is not valid", "basic"] spawn AP_fnc_handleMessage;};} else {private _dialog = findDisplay 2540;
    private _password = ctrlText 2543;
    AP_targetGroup params["_name", "_group", "_locked", "_ownerID", "_groupPassword"];
    if !(isNull _group) then {if (_password == _groupPassword && _password != "") then {closeDialog 0;
            [player] join _group;
            AP_my_gang = _group;
            [format["You have joined the group: %1", _name], "basic"] spawn AP_fnc_handleMessage;
            _name spawn {uiSleep 0.5;
                private _units = (units group player) apply {getPlayerUID _x}; [
                    ["-GROUP-", player, (profileName), format["joined the passworded group named: %1. Members: %2", _this, _units]], "APS_fnc_logIt", 2] call AP_fnc_MP;
            };} else {["Incorrect password.", "basic"] spawn AP_fnc_handleMessage;
            [] spawn AP_fnc_groupMenu;};} else {["Group is not valid", "basic"] spawn AP_fnc_handleMessage;};};