if ((lbCurSel 9621) isEqualTo - 1) exitWith {["You must select a player first.", "basic"] spawn AP_fnc_handleMessage;};
private _selectedData = parseSimpleArray(lbData[9621, lbCurSel 9621]);
if (_selectedData isEqualTo[]) exitWith {};
if !(AP_gang_data param[2, -1] isEqualTo 1) exitWith {};
_selectedData params["_newOwnerPID", "_newOwnerName"];
private _action = [format["Are you sure you want to tranfer gang ownership to %1? Any current gang house will not transfer to the new gang owner.", _newOwnerName], "Tranfer Gang Ownership?", "Yes", "No"] call BIS_fnc_guiMessage;
closeDialog 0;
if !(_action) exitWith {};
private _onlineMembers = [AP_gang_data select 0] call AP_fnc_getOnlineMembers;
private _newOwner = allPlayers param[allPlayers findIf {_newOwnerPID isEqualTo(getPlayerUID _x)}, objNull]; [
    [getPlayerUID player, _newOwnerPID], "APS_fnc_transferGangOwnerSRV", 2] spawn AP_fnc_MP;
if !(isNull(AP_gangBuilding select 0)) then {[
        [AP_gangBuilding select 0, AP_gang_data select 0], "AP_fnc_removeGangHouse", _onlineMembers] spawn AP_fnc_MP; [
        [AP_gangBuilding select 0, AP_gang_data select 0], "APS_fnc_removeGangHouseSRV", 2] spawn AP_fnc_MP;}; [
    [], "AP_fnc_gangSetOwner", _newOwner] spawn AP_fnc_MP;
AP_gang_data set[2, 2];
[format["You have transferred gang ownership to %1.", _newOwnerName], "basic"] spawn AP_fnc_handleMessage;