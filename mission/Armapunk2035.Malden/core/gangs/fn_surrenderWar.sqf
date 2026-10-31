private _enemyGang = parseNumber(lbData[9581, lbCurSel 9581]);
if (AP_gang_data isEqualTo[]) exitWith {};
if !(_enemyGang in AP_gang_wars) exitWith {};
["Ending the gang war...", "basic"] spawn AP_fnc_handleMessage;
closeDialog 0; [[AP_gang_data select 0, _enemyGang, false], "APS_fnc_updateWar", 2] spawn AP_fnc_MP;