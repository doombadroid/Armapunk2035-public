if (isRemoteExecuted && {remoteExecutedOwner != 2}) exitWith {};   // server-origin only: CfgRE allowedTargets limits the target, never the sender
params[["_garageArr", [], [[]]]];
disableSerialization;
// DECK ROUTE: when the deck garage asked for this data there is no dialog
// 100150 and never will be -- the waitUntil below would hang this spawn
// forever. Adopt the rows and push the deck channel instead.
if ((missionNamespace getVariable ["AP_deckApps", true]) && {isNull (findDisplay 100150)}) exitWith {
    private _notMine = _garageArr findIf { !((getPlayerUID player) isEqualTo (_x select 4)) };
    if (_notMine isNotEqualTo -1) exitWith {
        ["The garage data returned is not yours! Please try again...", "basic"] spawn AP_fnc_handleMessage; };
    AP_garageData = _garageArr;
    private _c = uiNamespace getVariable ["WEBUI_ctrl", controlNull];
    if (!isNull _c) then { [_c, "garage", (["data"] call AP_fnc_deckGarage)] call webui_fnc_push; };
};
waitUntil {!isNull(findDisplay 100150)};
if (_garageArr isEqualTo[]) exitWith {ctrlSetText[100152, "No Vehicles Found..."];};
private _display = findDisplay 100150;
private _vehicleList = _display displayCtrl 100151;
private _vehicleTitle = _display displayCtrl 100152;
private _detailsText = _display displayCtrl 100153;
private _sellButton = _display displayCtrl 100154;
private _getButton = _display displayCtrl 100155;
private _modButton = _display displayCtrl 100156;
private _repairRefuelButton = _display displayCtrl 100169;
private _toGangGarageButton = _display displayCtrl 100170;
lbClear _vehicleList;
_sellButton ctrlEnable false;
_getButton ctrlEnable false;
_modButton ctrlEnable false;
_repairRefuelButton ctrlEnable false;
_toGangGarageButton ctrlEnable false;
_toGangGarageButton ctrlShow false;
private _exit = false;
private "_temp"; {if !((getPlayerUID player) isEqualTo(_x select 4)) exitWith {_exit = true;};
    private _vehInfo = [_x select 2] call AP_fnc_fetchVehInfo;
    private _index = _vehicleList lbAdd(_vehInfo select 3);
    _temp = [_x select 2, _x select 7, _x select 8, _x select 9, _x select 10, _x select 11, _x select 12];
    _vehicleList lbSetData[_index, str _temp];
    _vehicleList lbSetPicture[_index, _vehInfo select 2];
    _vehicleList lbSetValue[_index, _x select 0];}
forEach _garageArr;
if (_exit) exitWith {["The garage data returned is not yours! Please try again...", "basic"] spawn AP_fnc_handleMessage;
    closeDialog 0;};
AP_garageData = _garageArr;