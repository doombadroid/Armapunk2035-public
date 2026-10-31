if (isRemoteExecuted && {remoteExecutedOwner != 2}) exitWith {};   // server-origin only: CfgRE allowedTargets limits the target, never the sender
params[["_gang1", -1, [0]], ["_gang2", -1, [0]], ["_status", false, [false]]];
private _gang = _gang1;
if (AP_gang_data isEqualTo[] || _gang1 isEqualTo - 1 || _gang2 isEqualTo - 1) exitWith {};
if ((AP_gang_data select 0) isEqualTo _gang) then {_gang = _gang2};
AP_gang_challenges deleteAt(AP_gang_challenges findIf {_x isEqualTo _gang});
if (_status) then {
    ["<t color='#FF0000' size='1.5' align='center'>New Gang War</t><br/><t color='#FFFFFF'>Your gang is now involved with a new gang war! Watch your back!", "basic"] spawn AP_fnc_handleMessage;
    AP_gang_wars pushBackUnique _gang;} else {
    ["<t color='#FF0000' size='1.5' align='center'>War Ended</t><br/><t color='#FFFFFF'>One of your gang's wars has ended.", "basic"] spawn AP_fnc_handleMessage;
    AP_gang_wars deleteAt(AP_gang_wars find _gang);};
if !(isNull(findDisplay 9580)) then {[] spawn AP_fnc_gangWarsMenu};