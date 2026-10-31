#include "..\..\macro.h"
if (scriptAvailable(60)) exitWith {["You can only request a superior once every minute"] spawn AP_fnc_handleMessage;};
private _message = "Officer is requesting a higher up at their location!";
private _playerName = name player; [[1, player, call AP_copLevel, _message], "APS_fnc_handleDispatch", false] call AP_fnc_MP;
["You've sent a higher up request!", "basic"] spawn AP_fnc_handleMessage;