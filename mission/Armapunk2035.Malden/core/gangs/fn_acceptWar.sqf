disableSerialization;
private _enemyGang = parseNumber(lbData[9581, lbCurSel 9581]);
if (AP_gang_data isEqualTo[]) exitWith {};
if !(_enemyGang in AP_gang_challenges) exitWith {};
["Accepting war challenge...", "basic"] spawn AP_fnc_handleMessage;
closeDialog 0; [[AP_gang_data select 0, _enemyGang, true], "APS_fnc_updateWar", 2] spawn AP_fnc_MP;