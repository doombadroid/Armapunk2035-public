#include "..\..\macro.h"
if (scriptAvailable(60)) exitWith {["You can only request backup once every minute"] spawn AP_fnc_handleMessage;};
private _message = "Officer is requesting backup at their location!";
private _playerName = name player; [[0, player, call AP_copLevel, _message], "APS_fnc_handleDispatch", false] call AP_fnc_MP;
["You have requested backup!", "basic"] spawn AP_fnc_handleMessage;