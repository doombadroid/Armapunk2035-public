// AP_fnc_gangMembersReceive (LooneyBin): server pushes THIS gang's member rows here so the
// gang menu / gang-ATM menu's `waitUntil AP_gangMembersList_ready` completes.
// _this = [[playerid, name, gangrank], ...] from DB_fnc_queryGangMembers.
if (isRemoteExecuted && {remoteExecutedOwner != 2}) exitWith {};   // server-origin only: CfgRE allowedTargets limits the target, never the sender
private _members = _this;
if (isNil "_members" || {!(_members isEqualType [])}) then { _members = []; };
AP_gangMembersList = _members;
AP_gangMembersList_ready = true;
