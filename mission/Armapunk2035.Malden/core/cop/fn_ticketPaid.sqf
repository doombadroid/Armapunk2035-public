if (isRemoteExecuted && {remoteExecutedOwner != 2}) exitWith {};   // server-origin only: CfgRE allowedTargets limits the target, never the sender
params[["_value", 5, [0]], ["_unit", objNull, [objNull]], ["_cop", objNull, [objNull]]];
if (isNull _unit || {_unit != AP_ticket_unit}) exitWith {};
if (isNull _cop || {_cop != player}) exitWith {};
AP_atmcash = AP_atmcash + _value;
AP_atmcashCacheB = ((AP_atmcash / 4) + 11);