if (isRemoteExecuted && {remoteExecutedOwner != 2}) exitWith {};   // server-origin only: CfgRE allowedTargets limits the target, never the sender
params[["_group", grpNull, [grpNull]], ["_gangName", "", [""]], ["_gangID", -1, [0]]];
if (_group isEqualTo grpNull || _gangName isEqualTo "" || _gangID isEqualTo - 1) exitWith {};
AP_gang_data = [_gangID, _gangName, 1, [0, 0, 0]];
AP_gang_talents = [];
AP_gang_exp = 0;
player setVariable["gang_data", AP_gang_data, true];
[format["Congratulations! You have created the gang %1!", _gangName], "basic"] spawn AP_fnc_handleMessage;
AP_atmcash = AP_atmcash - 25000;
AP_atmcashCacheB = ((AP_atmcash / 4) + 11);