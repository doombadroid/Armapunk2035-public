params[["_amount", 0, [0]]];
private _amount = round _amount;
if !(AP_effSide isEqualTo west) exitWith {};
private _toSend = allPlayers select {!(_x getVariable["AP_unitCopRole", ""] isEqualTo "")};
[player, _amount] remoteExec["AP_fnc_addPrestige", _toSend];
if (AP_copRole isEqualTo "" || isNil "AP_prestige" || !(AP_session_completed)) exitWith {};
AP_prestige = AP_prestige + (_amount * 0.4);
systemChat format["You've earned %1 prestige.", (_amount * 0.4)];
[16] call AP_fnc_ClupdatePartial;