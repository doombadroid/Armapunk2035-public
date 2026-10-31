params [["_deckNet", "", [""]]];
private _fromDeck = _deckNet isNotEqualTo "";
if (!_fromDeck && {(lbCurSel 39402) isEqualTo - 1}) exitWith {["You didn't select a vehicle to claim.", "basic"] spawn AP_fnc_handleMessage;};
private _zarosOwner = AP_gang_data param[0, -99] isEqualTo(zaros_flag getVariable["AP_turf_data", [-44]] select 0);
private _claimPrice =
if (_zarosOwner) then {0} else {
    if (_fromDeck) then {
        private _o = objectFromNetId _deckNet;
        private _row = ["getVehicleRow", "", typeOf _o] call AP_fnc_vehicleConfig;
        private _side = switch (_o getVariable ["AP_side", -1]) do { case "cop": {1}; case "med": {2}; default {0} };
        if ((_row select 8) isEqualType []) then {(_row select 8) select _side} else {_row select 8}
    } else { lbValue[39402, lbCurSel 39402] }};
private _vehicle = if (_fromDeck) then {_deckNet} else {lbData[39402, lbCurSel 39402]};
_vehicle = objectFromNetId _vehicle;
if !(_vehicle getVariable["AP_canChop", true]) exitWith {
    ["You cannot claim this vehicle as it's not registered with the DMV!", "basic"] spawn AP_fnc_handleMessage;};
if !(_vehicle getVariable["AP_side", ""] isEqualTo "civ") exitWith {
    ["This vehicle cannot be claimed.", "basic"] spawn AP_fnc_handleMessage;};
if (_vehicle getVariable["AP_vehIsMaxTac", false]) exitWith {["This MaxTac vehicle cannot be claimed.", "basic"] spawn AP_fnc_handleMessage;};
if (_vehicle getVariable["AP_vehIsFirefighter", false]) exitWith {
    ["This TT firefighting vehicle cannot be claimed.", "basic"] spawn AP_fnc_handleMessage;};
if (_vehicle getVariable["AP_vehicleAirdrop", false]) exitWith {
    ["This airdropped vehicle cannot be claimed.", "basic"] spawn AP_fnc_handleMessage;};
if (typeOf _vehicle isEqualTo "I_Plane_Fighter_04_F") exitWith {
    ["This air vehicle cannot be claimed.", "basic"] spawn AP_fnc_handleMessage;};
private _action = [format["Do you wish to claim this vehicle for $%1?", [_claimPrice] call AP_fnc_numberText], "Claim Vehicle", "Yes", "No"] call BIS_fnc_guiMessage;
if !(_action) exitWith {};
if (player distance(_vehicle) > 25) exitWith {["The vehicle is too far away.", "basic"] spawn AP_fnc_handleMessage;};
if (_vehicle getVariable["AP_dbInfo", []] isEqualTo[]) exitWith {["Failed to find vehicle data.", "basic"] spawn AP_fnc_handleMessage;};
(_vehicle getVariable["AP_dbInfo", []]) params[["_vehicleOwnerUID", "", [""]], ["_vehiclePlateID", 0, [0]], ["_isGang", false, [false]]];
if (isNull _vehicle) exitWith {};
if (AP_atmcash < _claimPrice) exitWith {["You don't have enough money to claim this vehicle.", "basic"] spawn AP_fnc_handleMessage;};
if !(_vehicle getVariable["AP_side", -1] isEqualTo "civ") exitWith {
    ["This vehicle cannot be claimed.", "basic"] spawn AP_fnc_handleMessage;};
if (_vehicleOwnerUID isEqualTo(getPlayerUID player)) exitWith {["This vehicle is already yours.", "basic"] spawn AP_fnc_handleMessage;};
if (_vehicle getVariable["AP_gettingClaimed", false]) exitWith {
    ["Someone is already claiming this vehicle.", "basic"] spawn AP_fnc_handleMessage;};
_vehicle setVariable["AP_gettingClaimed", true, true];
closeDialog 0;
disableSerialization;
5 cutRsc["AP_progress", "PLAIN"];
private _ui = uiNamespace getVariable "AP_progress";
private _text = "Claiming vehicle...";
private _progress = _ui displayCtrl 38201;
private _pgText = _ui displayCtrl 38202;
_pgText ctrlSetText format["%2 (1%1)...", "%", _text];
_progress progressSetPosition 0.01;
private _cP = 0.01;
AP_action_in_use = true;
private _success = false;
private _startPos = getPosASL player;
for "_i"
from 0 to 1 step 0 do {uiSleep 0.6;
    _cP = _cP + 0.01;
    _progress progressSetPosition _cP;
    _pgText ctrlSetText format["%3 (%1%2)...", round(_cP * 100), "%", _text];
    if !(alive player) exitWith {};
    if !(alive _vehicle) exitWith {};
    if !(isNull objectParent player) exitWith {};
    if (player distance2D _startPos > 2) exitWith {};
    if (player distance2D _vehicle > 22) exitWith {};
    if (player getVariable["AP_downed", false]) exitWith {};
    if (player getVariable["AP_surrendered", false]) exitWith {};
    if (player getVariable["AP_restrained", false]) exitWith {};
    if !(AP_action_in_use) exitWith {};
    if (_cp >= 1) exitWith {_success = true;};}; 5 cutText["", "PLAIN"];
AP_action_in_use = false;
_vehicle setVariable["AP_gettingClaimed", false, true];
if !(_success) exitWith {["The claiming process was interrupted.", "basic"] spawn AP_fnc_handleMessage;};
private _keyHolders = (_vehicle getVariable["AP_vehOwners", [["", ""]]]) apply {_x select 0};
private _toSend = (allPlayers select {(getPlayerUID _x) in _keyHolders}) - [player]; [
    [_vehicle], "AP_fnc_removeVehKey", _toSend] spawn AP_fnc_MP; [
    [_toSend, _vehicle, 3], "APS_fnc_keyManagement", 2] spawn AP_fnc_MP;
AP_atmcash = AP_atmcash - _claimPrice;
AP_atmcashCacheB = ((AP_atmcash / 4) + 11);
[1] call AP_fnc_ClupdatePartial; [[player, _vehicle, _claimPrice], "APS_fnc_vehOwnerSwap", 2] spawn AP_fnc_MP;
uiSleep 1;
AP_vehicles pushBackUnique _vehicle;
titleText[format["You have claimed this vehicle for a price of $%1", [_claimPrice] call AP_fnc_numberText], "PLAIN"];
["vehclaim", 1] call AP_fnc_statArrUpdate;
if (typeOf _vehicle isEqualTo "O_MRAP_02_F") then {["claim", "ifrit", 1] call AP_fnc_handleQuest;};