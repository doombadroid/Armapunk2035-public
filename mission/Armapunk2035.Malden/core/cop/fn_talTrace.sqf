// Altis Life game mechanic — fictional in-game "quickhack" ability, game logic only
/*
    File: fn_talTrace.sqf  (AP_fnc_talTrace)
    LooneyBin 2026-07-20: receives an ICE TRACE ping on an officer's TAL visor (talos.md).
    Passive -- no wedge. Wearing the goggles IS the capability, the way a radio call just arrives.
    Gives a compass bearing, a distance and a fading marker: WHERE and WHAT, never WHO.
*/
if (isRemoteExecuted && {remoteExecutedOwner != 2}) exitWith {};   // server-origin only: CfgRE allowedTargets limits the target, never the sender
params [["_pos", [], [[]]], ["_label", "ILLEGAL SIGNAL", [""]]];
if (_pos isEqualTo []) exitWith {};
if !(AP_effSide isEqualTo west) exitWith {};

// Quest hook: the MaxSec half of the same mechanic -- an intrusion picked up on
// the TAL grid. Cop-side, so TAL OS quests have something to count.
["action", "icetraced", 1] spawn AP_fnc_handleQuest;

private _dist = round (player distance _pos);
private _dir  = player getDir _pos;
private _card = ["N","NNE","NE","ENE","E","ESE","SE","SSE","S","SSW","SW","WSW","W","WNW","NW","NNW","N"] select (round (_dir / 22.5));

private _m = createMarkerLocal [format ["tal_ice_%1_%2", round diag_tickTime, floor random 9999], _pos];
_m setMarkerTypeLocal "hd_warning";
_m setMarkerColorLocal "ColorOrange";
_m setMarkerTextLocal format ["ICE TRACE -- %1", _label];
[_m] spawn { uiSleep 45; deleteMarkerLocal (_this select 0); };

[format ["<t color='#f0a01e' size='1.15'>ICE TRACE</t><br/>%1 detected<br/><t color='#dbe4ee'>%2 m %3</t> <t color='#7d8b9e'>-- marked for 45s</t>", _label, _dist, _card], "basic"] spawn AP_fnc_handleMessage;
playSound "taskAssigned";
