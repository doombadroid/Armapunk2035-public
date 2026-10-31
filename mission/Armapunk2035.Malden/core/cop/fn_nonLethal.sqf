if !(AP_effSide isEqualTo west) exitWith {};
private _lethalState = player getVariable["AP_nonlethal", false];
player setVariable["AP_nonlethal", !(_lethalState), true];
private _text =
if (_lethalState) then {"lethals"} else {"non-lethals"};
[format["You switched to %1.", _text], "basic"] spawn AP_fnc_handleMessage;
private _curWep = currentWeapon player;
private _curAmmo = player ammo _curWep;
player setAmmo[_curWep, 0];
uiSleep 0.5;
player setAmmo[_curWep, _curAmmo];