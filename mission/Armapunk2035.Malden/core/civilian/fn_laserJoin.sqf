if !(AP_effSide isEqualTo civilian) exitWith {
    ["You can't play laser tag while on duty! GET TO WORK!", "basic"] spawn AP_fnc_handleMessage};
["You have joined the laser tag queue. The next game will start any time within the next few minutes. Stay nearby or joining will fail!", "basic"] spawn AP_fnc_handleMessage;
player setVariable["AP_laserPos", getPosATL player, true];
AP_old_group = group player; [[player], "APS_fnc_laserQueue", 2] spawn AP_fnc_MP;