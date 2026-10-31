params[["_pardonUID", "", [""]]];
disableSerialization;
if (((player getVariable["AP_surrendered", false]) || (player getVariable["AP_downed", false]) || (player getVariable["AP_restrained", false])) && ((call AP_adminLevel) <= 2)) exitWith {
    ["How could you possibly pardon someone right now?", "basic"] spawn AP_fnc_handleMessage;};
private _unit = objNull;
private _exit = false;
private _bountyPrice = 0;
if (((getPlayerUID player) isEqualTo(SRV_governorData param[0, "GovUID"])) && !(AP_effSide isEqualTo west) && ((call AP_adminLevel) <= 2)) then {
    if (AP_govClientData param[3, false]) exitWith {_exit = true};};
if (_exit) exitWith {["As the governor, you may only pardon once per world session!", "basic"] spawn AP_fnc_handleMessage;};
if (_pardonUID isEqualTo "") then {private _display = findDisplay 2400;
    if (isNull _display) exitWith {_exit = true;};
    private _wantedList = _display displayCtrl 2402;
    private _wantedAmount = _display displayCtrl 2404;
    if ((lbCurSel _wantedList) isEqualTo - 1) exitWith {_exit = true;};
    private _wantedData = _wantedList lbData(lbCurSel _wantedList);
    private _wantedData = parseSimpleArray _wantedData;
    _bountyPrice = parseNumber(ctrlText _wantedAmount);
    if !(_wantedData isEqualType[]) exitWith {_exit = true;};
    if !(_wantedData params["_name", "_unitUID"]) exitWith {_exit = true;};
    _pardonUID = _unitUID;};
private _players = allPlayers;
private _unit = _players param[_players findIf {(getPlayerUID _x) isEqualTo _pardonUID}, objNull];
if (isNull _unit) exitWith {_exit = true;};
if (_bountyPrice isEqualTo 0) then {_bountyPrice = _unit getVariable["AP_wantedAmt", 0]};
if (_exit) exitWith {closeDialog 0;};
if (((getPlayerUID player) isEqualTo _pardonUID) && ((call AP_adminLevel) <= 2)) exitWith {
    ["You cannot pardon yourself. Corruption only goes so far!", "basic"] spawn AP_fnc_handleMessage;};
private _action = [format["Are you sure you want to pardon %1 with a bounty of $%2?", name _unit, [_bountyPrice] call AP_fnc_numberText], "Pardon Selected Player?", "Pardon", "Cancel"] call BIS_fnc_guiMessage;
if (_action) then {closeDialog 0;
    if ((getPlayerUID player) isEqualTo(SRV_governorData param[0, ""]) && !(AP_effSide isEqualTo west)) exitWith {[
            ["recievePardon", [player, getPlayerUID player, profileName]], "AP_fnc_govPardon", _unit] call AP_fnc_MP;
        [format["You are attempting to pardon %1, please wait while they accept or decline your offer.", [name _unit] call AP_fnc_cleanName]] spawn AP_fnc_handleMessage;
        AP_govClientData set[3, true];
        [21] call AP_fnc_ClupdatePartial;}; [[_pardonUID], "APS_fnc_wantedPardon", 2] call AP_fnc_MP; [
        [0, format["%1 has been pardoned by %2", [name _unit] call AP_fnc_cleanName, [profileName] call AP_fnc_cleanName]], "AP_fnc_broadcast", -2] call AP_fnc_MP;
    [
        ["-PARDON-", player, profileName, format["pardoned %1 (%2) with a bounty of $%3.", name _unit, _pardonUID, _bountyPrice]], "APS_fnc_logIt", 2, false, false] spawn AP_fnc_MP;
    [["action", "getpardonbycop", 1], "AP_fnc_handleQuest", _unit] spawn AP_fnc_MP;
    ["action", "pardon", 1] call AP_fnc_handleQuest;
    private _bountyHunters = allPlayers select {!(((_x getVariable["AP_myBounties", []]) findIf {_pardonUID in _x}) isEqualTo - 1)};
    if !(_bountyHunters isEqualTo[]) then {[_pardonUID, false] remoteExec["AP_fnc_removeBounty", _bountyHunters];};
    if (AP_allPointsBulletin param[1, "hehe"] isEqualTo _pardonUID) then {AP_allPointsBulletin = [];
        publicVariable "AP_allPointsBulletin";};};