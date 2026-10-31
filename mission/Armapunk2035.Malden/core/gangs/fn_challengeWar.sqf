disableSerialization;
if (AP_gang_data isEqualTo[]) exitWith {
    ["You are not currently a member of a gang. You must create one or receive an invitation", "basic"] spawn AP_fnc_handleMessage;
    closeDialog 0};
if ((AP_gang_data select 2) > 3) exitWith {["You are not of sufficient rank within your gang.", "basic"] spawn AP_fnc_handleMessage;
    closeDialog 0};
if (time < AP_gang_war_next) exitWith {
    ["You may only challenge a gang to war once every 5 minutes!", "basic"] spawn AP_fnc_handleMessage};
if (isNull(findDisplay 9580)) exitWith {systemChat "INVALID GANG UI"};
if (lbCurSel 9581 isEqualTo - 1) exitWith {["You need to select a gang to challenge", "basic"] spawn AP_fnc_handleMessage};
private _enemyGangID = parseNumber(lbData[9581, lbCurSel 9581]);
private _toSend = allPlayers select {(_x getVariable["gang_data", [-1]] select 0) isEqualTo _enemyGangID}; [
    [player, AP_gang_data select 0, AP_gang_data select 1], "AP_fnc_warChallenged", _toSend] spawn AP_fnc_MP;
AP_gang_war_next = time + 300;
["A war challenge has been sent to all online members of the gang!", "basic"] spawn AP_fnc_handleMessage;