if (isNull AP_holding_barrel) exitWith {["You are not holding a barrel!", "basic"] spawn AP_fnc_handleMessage};
AP_holding_barrel attachTo[player, [0, 1, 0.5]];
detach AP_holding_barrel;
AP_holding_barrel = objNull;
player forceWalk false;