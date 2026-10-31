params[["_removeButton", controlNull, [controlNull]]];
disableSerialization;
if ((player getVariable["AP_surrendered", false]) || (player getVariable["AP_downed", false]) || (player getVariable["AP_restrained", false])) exitWith {
    ["How could you possibly remove a charge right now?", "basic"] spawn AP_fnc_handleMessage;};
private _plb_menuReset = {closeDialog 0;
    };
private _display = ctrlParent _removeButton;
if (isNull _display) exitWith {[] call _plb_menuReset};
private _wantedList = _display displayCtrl 2402;
private _bountyPrice = _display displayCtrl 2404;
private _chargesList = _display displayCtrl 2405;
private _removeInput = _display displayCtrl 2406;
private _button1 = _display displayCtrl 2408;
private _button2 = _display displayCtrl 2409;
private _button3 = _display displayCtrl 2410; {if (ctrlShown _x) then {_x ctrlEnable false}}
forEach[_button1, _button2, _button3, _removeInput, _removeButton];
private _wantedSelected = lbCurSel _wantedList;
if (_wantedSelected isEqualTo - 1) exitWith {[] call _plb_menuReset};
private _wantedData = _wantedList lbData _wantedSelected;
private _wantedData = parseSimpleArray _wantedData;
if !(_wantedData isEqualType[]) exitWith {[] call _plb_menuReset};
if !(_wantedData params["_name", "_unitUID", "_charges", "_bounty"]) exitWith {[] call _plb_menuReset;};
if (((getPlayerUID player) isEqualTo _unitUID) && ((call AP_adminLevel) <= 2)) exitWith {
    ["You cannot remove your own charges. Corruption only goes so far!", "basic"] spawn AP_fnc_handleMessage;};
private _chargeSelected = lbCurSel _chargesList;
if (_chargeSelected isEqualTo - 1) exitWith {[] call _plb_menuReset};
private _currentChargeID = _chargesList lbData _chargeSelected;
private _currentChargeCount = _chargesList lbValue _chargeSelected;
private _currentChargeTitle = ["getChargeName", _currentChargeID] call AP_fnc_wantedChargesConfig;
private _amount = round(parseNumber(ctrlText _removeInput));
if (_amount isEqualTo 0) exitWith {[] call _plb_menuReset};
private _amount =
if ((_currentChargeCount - _amount) < 0) then {_currentChargeCount} else {_amount};
private _unit = allPlayers param[allPlayers findIf {(getPlayerUID _x) isEqualTo _unitUID}, objNull];
private _unitName =
if (isNull _unit) then {_name} else {name _unit}; [
    [_unitUID, _name, _currentChargeID, _amount], "APS_fnc_wantedRemoveCharge", 2] call AP_fnc_MP; [
    ["-DROPCHARGE-", player, (profileName), format["removed %1 count(s) of %2 from %3 (%4).", _amount, _currentChargeTitle, _unitName, _unitUID]], "APS_fnc_logIt", 2, false, false] spawn AP_fnc_MP;