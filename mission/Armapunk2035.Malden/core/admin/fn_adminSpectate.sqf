if ((call AP_adminLevel) <= 1) exitWith {closeDialog 0};
["Initialize", [player]] call BIS_fnc_EGSpectator;
systemChat "You are now spectating. Press F8 to stop spectating."; [
    ["-ADMINACTION-", player, profileName, "entered Eden Specate."], "APS_fnc_logIt", 2] spawn AP_fnc_MP;
waituntil {!isNull(findDisplay 60492)};
private _playerList = (findDisplay 60492) displayCtrl 43109;
private _listPosition = ctrlPosition _playerList;
_playerList ctrlSetPosition[_listPosition select 0, _listPosition select 1, _listPosition select 2, (_listPosition select 3) / 1.01];
SPEC_EXIT = (findDisplay 60492) displayAddEventHandler["KeyDown", {params["_ctrl", "_code", "_shift", "_ctrlKey", "_alt"];
    if (_code isEqualTo 66) then {(findDisplay 60492) displayRemoveEventHandler["KeyDown", SPEC_EXIT];
        ["Terminate", [player]] call BIS_fnc_EGSpectator;
        systemChat "You have stopped spectating.";};
    false;}];
if !(isNull(findDisplay 12900)) then {(findDisplay 12900) closeDisplay 0};