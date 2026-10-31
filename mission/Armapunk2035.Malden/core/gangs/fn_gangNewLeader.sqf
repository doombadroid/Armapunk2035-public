#include "..\..\macro.h"
disableSerialization;
if !((AP_gang_data select 2) isEqualTo 1) exitWith {["You are not the leader.", "basic"] spawn AP_fnc_handleMessage;};
if ((lbCurSel 9621) isEqualTo - 1) exitWith {["You failed to select someone to transfer to!", "basic"] spawn AP_fnc_handleMessage;};
private _unit = parseSimpleArray(getSelData(9621));
_unit params[["_playerID", "", [""]], ["_name", "", [""]]];
if (_playerID isEqualTo getPlayerUID player) exitWith {["You are already the leader!", "basic"] spawn AP_fnc_handleMessage;};
if (_playerID isEqualTo "") exitWith {["An error occured.", "basic"] spawn AP_fnc_handleMessage};
private _action = [format["You are about to transfer leadership over to %1.<br/>By transferring leadership you will no longer be in control of the gang unless ownership is transferred back. This will also transfer over the gang house that is currently in use on ALL servers.", (_unit select 1)], "Transfer Gang Leadership", "Transfer", "Cancel"] call BIS_fnc_guiMessage;
if (_action) then {private _gangID = AP_gang_data select 0;
    private _gangName = AP_gang_data select 1;
    private _onlineMembers = [_gangID] call AP_fnc_getOnlineMembers;
    private _newLeader = playableUnits param[playableUnits findIf {getPlayerUID _x isEqualTo _playerID}, objNull];
    private _group = group player; [[player, 2, _gangID, _gangName, player, 2], "APS_fnc_updateGangMem", 2] spawn AP_fnc_MP;
    if (isNull _newLeader) then {[[player, 1, _gangID, _gangName, _playerID, 1], "APS_fnc_updateGangMem", false] spawn AP_fnc_MP;} else {
        [[player, 2, _gangID, _gangName, _newLeader, 1], "APS_fnc_updateGangMem", false] spawn AP_fnc_MP;
        if (_group getVariable["gang_id", -64] isEqualTo(AP_gang_data select 0)) then {_group selectLeader _newLeader; [
                [_newLeader, _group], "AP_fnc_clientGangLeader", _onlineMembers] spawn AP_fnc_MP;};};
    ["Transferring Leadership...", "basic"] spawn AP_fnc_handleMessage;
    } else {["Transfer of leadership cancelled.", "basic"] spawn AP_fnc_handleMessage;
    };