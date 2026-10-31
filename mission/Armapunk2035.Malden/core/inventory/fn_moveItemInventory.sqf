#include "..\..\macro.h"
params["_isVirtual", "_isUp"];
disableSerialization;
if (!AP_didServerRespond) exitWith {["Awaiting server response, try again in a few seconds...", "basic"] spawn AP_fnc_handleMessage};
private _lbSelected = lbCurSel 4502;
if (_lbSelected isEqualTo - 1) exitWith {};
private _playerItemSelected = getSelData(4502);
if (_playerItemSelected isEqualTo "") exitWith {};
private _vehPos = getPos AP_trunk_vehicle;
private _playerPos = getPos player;
if (_vehPos distance _playerPos > 10) exitWith {["You are too far away!", "basic"] spawn AP_fnc_handleMessage;
    closeDialog 0;};
private _trunkDetails =
if (_isVirtual) then {(AP_trunk_vehicle getVariable["AP_vinv", [[], 0]]);} else {(AP_trunk_vehicle getVariable["AP_pinv", [[], 0]]);
};
private _trunkInv = _trunkDetails select 0;
private _trunkWeight = _trunkDetails select 1;
private _trunkLength = count _trunkInv;
if (((_lbSelected isEqualTo 0) && _isUp) || ((_lbSelected isEqualTo(_trunkLength - 1)) && !(_isUp))) exitWith {};
private _arrayItemSelected = _trunkInv select _lbSelected;
private _newTrunkInventory = [];
_newTrunkInventory =
if (_isUp) then {private _newInv = _trunkInv select[0, _lbSelected - 1];
    _newInv append[(_trunkInv select _lbSelected)];
    _newInv append[(_trunkInv select(_lbSelected - 1))];
    _newInv append(_trunkInv select[_lbSelected + 1, (_trunkLength - (_lbSelected + 1))]);
    _newInv;} else {private _newInv = _trunkInv select[0, _lbSelected];
    _newInv append[(_trunkInv select _lbSelected + 1)];
    _newInv append[(_trunkInv select(_lbSelected))];
    _newInv append(_trunkInv select[_lbSelected + 2, (_trunkLength - (_lbSelected + 1))]);
    _newInv;};
if (count _newTrunkInventory isEqualTo 0) exitWith {};
if (_isVirtual) then {AP_trunk_vehicle setVariable["AP_vinv", [_newTrunkInventory, _trunkWeight]];
    [AP_trunk_vehicle, AP_is_virtual] call AP_fnc_refreshInventory;} else {
    AP_trunk_vehicle setVariable["AP_pinv", [_newTrunkInventory, _trunkWeight]];
    [AP_trunk_vehicle, AP_is_virtual] call AP_fnc_refreshInventory;};
if (_isUp) then {lbSetCurSel[4502, _lbSelected - 1];} else {lbSetCurSel[4502, _lbSelected + 1];};
AP_movedItem = true;