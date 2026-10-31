if (isRemoteExecuted && {remoteExecutedOwner != 2}) exitWith {};   // server-origin only: CfgRE allowedTargets limits the target, never the sender
params[["_source", objNull, [objNull]]];
if (isNull _source) exitWith {};
_source say3D "Tazersound";