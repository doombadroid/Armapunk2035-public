params[["_doRequest", false, [false]]];
if (time < (player getVariable["AP_next_revive", -1000])) then {
    titleText[format["You were recently revived and cannot be revived again for %1 seconds.", ceil((player getVariable["AP_next_revive", -1000]) - time)], "PLAIN"];
};
if !(AP_corpse getVariable["AP_revivable", false]) then {AP_corpse setVariable["AP_revivable", true, true];
    AP_corpse setVariable["AP_faction", AP_effSide, true];};
private _toSend = (allPlayers - [allDeadMen] - [player]) select {
    (side _x isEqualTo west && _x getVariable["AP_unitCopRole", ""] in ["medic", "all"]) || side _x isEqualTo independent};
if (_doRequest) then {
    private _action = ["You are going to request Trauma Team to your location. Are you sure you want to continue?", "Request TT", "Yes", "No"] call BIS_fnc_GUIMessage;
    if !(_action) exitWith {}; [[player, AP_corpse], "AP_fnc_sendRequestToMedic", _toSend] spawn AP_fnc_MP;};
[_doRequest] spawn {params["_doRequest"];
    private _requestBtn = (findDisplay 7300) displayCtrl 7303;
    private _allowBtn = (findDisplay 7300) displayCtrl 7306;
    if (_doRequest) then {player setVariable["AP_medRequest", true];
        _requestBtn ctrlEnable false;};
    _allowBtn ctrlEnable false;
    uiSleep(2 * 60);
    player setVariable["AP_medRequest", false];
    _requestBtn ctrlEnable true;
    _allowBtn ctrlEnable true;};
