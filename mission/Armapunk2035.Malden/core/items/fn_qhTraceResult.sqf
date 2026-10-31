// Altis Life game mechanic — fictional in-game "quickhack" ability, game logic only
/*
    File: fn_qhTraceResult.sqf  (AP_fnc_qhTraceResult)
    Server hands the traced position back here: a 20s marker + bearing on the intruder.
*/
if (isRemoteExecuted && {remoteExecutedOwner != 2}) exitWith {};   // server-origin only: CfgRE allowedTargets limits the target, never the sender
params [["_pos", [], [[]]]];
if (_pos isEqualTo []) exitWith { ["Trace lost -- the signal was rerouted.", "basic"] spawn AP_fnc_handleMessage; };
private _m = createMarkerLocal [format ["qh_trace_%1", round diag_tickTime], _pos];
_m setMarkerTypeLocal "hd_warning";
_m setMarkerColorLocal "ColorRed";
_m setMarkerTextLocal "TRACED INTRUDER";
[_m] spawn { uiSleep 20; deleteMarkerLocal (_this select 0); };
private _dir = player getDir _pos;
private _card = ["N","NE","E","SE","S","SW","W","NW","N"] select (round (_dir / 45));
[format ["<t color='#c9e21a' size='1.15'>TRACE COMPLETE</t><br/>Intruder <t color='#dbe7e0'>%1 m %2</t> <t color='#7f918a'>-- marked 20s</t>", round (player distance _pos), _card], "basic"] spawn AP_fnc_handleMessage;
