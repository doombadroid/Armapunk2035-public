// AP_fnc_startPrisonBreak (LooneyBin compat) -- MIRROR of server/AP_server/core/jail/fn_startPrisonBreak.sqf
// FIX 2026-07-18 (compat-stub shadow): this file shipped as a reverse-drift no-op stub
// (`if (true) exitWith {};`). Because the mission ALSO registers AP_fnc_startPrisonBreak, the no-op
// SHADOWED the real @AP_server impl on the server (mission CfgFunctions wins) -> every
// server-internal call silently did nothing -> the prison-break event never actually ran: no jail alarm, no broadcast, no red 'Break in Progress' marker, no dispatch/MaxTac.
// Restored to the real impl. The isServer guard makes it a safe no-op on clients (which lack
// the server-authoritative vars); all real callers are server-internal. Keep in sync w/ the twin.
if (!isServer) exitWith {};
 
private["_unit","_jailId","_start","_soundOn","_dispatch"]; 
 
_unit = [_this,0,Objnull,[Objnull]] call BIS_fnc_param; 
_jail = [_this,1,1,[1]] call BIS_fnc_param; 
_npc = [_this,2,Objnull,[Objnull]] call BIS_fnc_param; 
 
if (isNull _unit || isNull _npc) exitWith {}; 
 
_soundOn = createSoundSource ["Sound_Alarm", getMarkerPos "jail_marker2", [], 0]; 
_start = time;
private _holdAnchor = getPosATL _unit;   // owner 2026-06-23: 500m hold radius anchored where the break started (the laptop) -- old check was _unit distance _npc with _npc=_unit = always 0 (never enforced)
 
"corrections" setMarkerText "Prison [Break in Progress]"; 
"corrections" setMarkerColor "ColorRed"; 
 
[[0, format["%1 has initiated a prison break!", name _unit]],"AP_fnc_broadcast",civilian,false] spawn AP_fnc_MP; 
[[[0,1,2], format["%1 has initiated a prison break!", name _unit]],"AP_fnc_broadcast",west,false] spawn AP_fnc_MP; 

// owner 2026-07-29: cops got one 15 s federaleventcop popup for a ten-minute event, which told them it
// started and nothing else. fn_handleMessage already carries a "prison_break" style -- a red bar that
// DRAINS over exactly (60 * 10), which is this window's length -- and NOTHING in the tree used it. It was
// built for this feature and left unwired. This is the readout, not a new UI.
[["The prison's security system has been compromised -- the gate is open.", "prison_break"],"AP_fnc_handleMessage",west,false] spawn AP_fnc_MP; 
 
AP_prison_inProgress = true; 
publicVariable "AP_prison_inProgress"; 
 
_dispatch = ceil (random 9000); 
[_dispatch, "Prison Break", 5000, 3, 4, getMarkerPos "jail_marker2", ""] spawn AP_fnc_createDispatch; 
 
if (AP_maxtac_instance == 0) then {AP_maxtac_instance = _dispatch;
[_npc] spawn {_npc = _this select 0;
sleep 35; 
_units = []; 
{ if (side _x == civilian && _x distance _npc < 300 && !(primaryWeapon _x == "" && handgunWeapon _x == "")) then { _units pushBack _x }; } forEach allPlayers; 
_maxtacPos = switch (worldName) do {
case "Altis": { [["Police HQ",[17465,13274,0]],["Naval East",[17295,13938,0]],["Naval West",[16317.1,12838.3,0]],["North Pyrgos",[16676.9,13045.3,0]],["Halo Jump",[16473.2,13648.3,1500]]] }; 
case "Tanoa": { [["Farmstead",[11421,11110,0]],["Cliffside",[10717,11732,0]],["Road Fork",[10669,11582,0]],["North Pyrgos",[11229,11644,7.5]],["Halo Jump",[11110,11500,2000]]] }; 
case "Stratis": { [["Hill Camp",[6594,5328,0]],["Lighthouse",[6597,5170,0]],["Crossroads",[6018,4941,0]],["Construction",[6029,5618,0]]] }; 
case "Australia": { [["Garage",[29267,17515,0]],["Farmstead",[30603,17885,0]],["Willcania PD",[31413,16913,0]],["Lumber Mill",[28958,16570,0]]] }; 
}; 
// owner 2026-07-29: the switch above has Altis/Tanoa/Stratis/Australia, NO Malden case and NO default,
// so _maxtacPos is nil on this map and fn_maxtacDispatch:50 then evaluates `(_locations select 0) select 1`
// on it. The bank's equivalent table (fn_bankDrillVault.sqf:93) has a default; this one does not. Four
// real Malden insertion positions are an open item in TODO.md -- until they land, skip MaxTac and SAY SO
// rather than letting the event die on a nil. A silent cap reads as "covered" when it is not.
if (isNil "_maxtacPos" || {!(_maxtacPos isEqualType [])} || {_maxtacPos isEqualTo []}) exitWith {
    diag_log format ["[maldenPrison] no MaxTac insertion table for world '%1' -- MaxTac not deployed for this prison break", worldName];
};
if(AP_activeMAXTAC || !AP_prison_inProgress || count _units < 2) exitWith {}; 
[count _units, _maxtacPos, getMarkerPos "jail_marker2"] spawn AP_fnc_maxtacDispatch;};};
 
// owner 2026-07-29: MALDEN = 600 s, the gate hack's 10-minute window. This is no longer a HOLD -- the
// hacker cracked a gate and is free to walk away -- so the timer is the whole of the event. Australia
// keeps 600 and the rest keep 800 because their trigger is still the (callerless) laptop upload.
// MUST match the participant bar's _dur in initPlayerLocal.sqf; there is no shared source to read,
// because SRV_prisonData carries the START time and not the duration.
_breakTimer = switch (worldName) do { case "Australia": { 600 }; case "Malden": { 600 }; default { 800 } };
[[1, format["You've initiated a prison break. Stay within 500 meters for %1 minutes and do not enter a vehicle.", _breakTimer / 60]],"AP_fnc_broadcast",_unit,false] spawn AP_fnc_MP; 
// owner 2026-07-29: the gate hack replaces the hold OUTRIGHT -- this is not a second branch. The only
// caller of the hold semantics was AP_fnc_doPrisonBreak, which has no callers of its own, so no live
// path depends on the 500 m anchor and there is no "laptop mode" left to preserve.
// THREE logged bugs die with the old condition (all in TODO.md under 2026-07-28):
//   1. ORPHANED THREAD. It watched the BREAKER, not SRV_prisonData, so after a cop stop this script ran
//      on to re-broadcast its own failure message and re-restore the marker. Watching slot 1 ends the
//      thread when the event ends.
//   2. THE ALARM LEAK. _soundOn is a LOCAL deleted only at the deleteVehicle below. Because all three end
//      paths (expiry, disarm, the 1200 s watchdog) now fall through to it, the siren can no longer
//      outlive the event. No published handle is needed -- this condition IS the fix.
//   3. THE DEAD RESTRAINED CHECK. `_unit getVariable ["restrained", false]` read a variable name nothing
//      in the tree ever sets; this codebase uses AP_restrained. It goes with the clause.
// `param`, never `select`, on SRV_prisonData: it is seeded 2-element and select on a missing slot yields
// nil, which would halt this thread rather than end the break.
waitUntil {sleep 2; ((time - _start) > _breakTimer)
    || (missionNamespace getVariable ["AP_prisonDisarmed", false])
    || !(SRV_prisonData param [1, false])};
 
_criminals = []; 
{ if (side _x == civilian && !(_x getVariable ["prisoner",false]) && _x distance (getMarkerPos "corrections") < 100) then {_criminals pushBack _x}; } forEach allPlayers; 
 
// owner 2026-07-29: matches the condition above clause for clause. Either the window ran its full length
// undisarmed with the event still active, or it did not. The breaker's own state is deliberately absent:
// he cracked a gate ten minutes ago and may be dead, arrested or on the far side of the island, and none
// of that should decide whether the prisoners get their offer.
if (((time - _start) > _breakTimer)
    && !(missionNamespace getVariable ["AP_prisonDisarmed", false])
    && (SRV_prisonData param [1, false])) then {
[[[0,1], "You have successfully completed a prison break!"],"AP_fnc_broadcast",_unit,false] spawn AP_fnc_MP; 
if (worldName != "Australia") then { [[name _unit,_jail],"AP_fnc_prisonBreakQuery",true,false] spawn AP_fnc_MP; }; 
[[_dispatch, false],"AP_fnc_finishDispatch",west,false] spawn AP_fnc_MP; {
[[_unit],"AP_fnc_prisonBreaker",_x,false] spawn AP_fnc_MP;} forEach _criminals;}
else {[[[0,1], "You have failed the prison break and nobody made it out."],"AP_fnc_broadcast",_unit,false] spawn AP_fnc_MP;
[[[0,1,2], format["The prison break has been quelled!"]],"AP_fnc_broadcast",west,false] spawn AP_fnc_MP; 
[[_dispatch, true],"AP_fnc_finishDispatch",west,false] spawn AP_fnc_MP;};
 
deleteVehicle _soundOn; 
"corrections" setMarkerText format["%1 Maximum Security Prison", worldName]; 
"corrections" setMarkerColor "ColorWEST"; 
 
AP_lastPrison = time; 
publicVariable "AP_lastPrison"; 
AP_prison_inProgress = false;
publicVariable "AP_prison_inProgress";
// owner 2026-07-28: ARM the 15-minute cross-heist SRV_lastRobbery lockout. THIS is the path that
// genuinely ends a prison break, and until now it armed nothing. 12791fd put the prison's end arm in
// APS_fnc_handlePrisonBreak's 1200 s watchdog, which is DEAD CODE: the deferred slot-1 clear below sits
// BELOW the if/else above and so runs on the success branch AND the failure branch alike, and the
// waitUntil above returns as soon as the breaker dies, is restrained, boards a vehicle or leaves 500 m --
// so SRV_prisonData slot 1 is false by ~872 s at the latest, the watchdog's own waitUntil short-circuits
// on it and its `then {}` never executes. Net effect before this line existed: a break that COMPLETED,
// and a break the breaker abandoned or died out of, armed NOTHING; only an explicit cop stop (case 2)
// ever armed. Both of those consumed the prison and are a heist that really ran, so both arm now.
// PLACEMENT: below the if/else, exactly like the slot-1 clear below it, so one write covers the success
// branch and the failure branch instead of two that could drift apart.
// NO REFUSAL CAN REACH IT. AP_fnc_startPrisonBreak is NOT listed in CfgRE.hpp and that file is
// mode = 1 (whitelist), so no client can remoteExec it at all; its only caller in the whole tree is
// the `[_unit, 1, _unit] spawn AP_fnc_startPrisonBreak` at APS_fnc_handlePrisonBreak:170 (grep that
// expression rather than trusting the number -- case 1 moves), which sits at the bottom of case 1
// below all five of that case's guards and below the authz sentinel. This file's own `if (isNull _unit || isNull _npc) exitWith {}` is a FLAT top-level
// statement that leaves the FUNCTION, so a null-unit call stops well above here. Belt and braces, the
// latch below is opened in exactly ONE place -- case 1's SRV_prisonData stamp, below every guard -- so a
// run that was never legitimately accepted reads it shut and arms NOTHING.
// NO DOUBLE-ARM: the cop stop (case 2) and the 1200 s watchdog test and close the same latch, and there
// is NO suspension point between the read and the write below (no sleep/uiSleep/waitUntil, and
// publicVariable does not yield), so under SQF's cooperative scheduler the check-and-set is atomic --
// two end paths cannot both observe it open. First end wins, the other two become no-ops.
// FRESH BOOT: the latch is seeded TRUE at init.sqf:280 and every reader defaults it TRUE, so nothing
// here can fire before a break has actually been started.
// `if (!...) then {}` and deliberately NOT exitWith, even though this is the file's top level: the
// deferred slot-1 clear and the MaxTac deactivate below MUST still run.
if (!(missionNamespace getVariable ["AP_prisonEndArmed", true])) then {
    AP_prisonEndArmed = true;
    SRV_lastRobbery = serverTime;
    publicVariable "SRV_lastRobbery";
};
// owner 2026-06-19 (#342): also clear the NEW server gate SRV_prisonData[1]. The case-1 start-gate in
// APS_fnc_handlePrisonBreak reads SRV_prisonData[1], but this completion only reset the legacy
// AP_prison_inProgress -> the gate stayed TRUE until the 20-min watchdog cap, so a NEW break was blocked
// for up to 20 min after a finished one ("prison break not working after a successful prison break").
// owner 2026-06-21 (#481 "release didn't let me out"): DEFER this clear ~70s. It fired in the SAME frame as the
// release above (AP_fnc_prisonBreaker sets AP_breakout, the Yes/No escape dialog goes out), but the client
// release gate (fn_jailMe.sqf:98) needs SRV_prisonData[1] AND AP_breakout true together, the jail loop ticks
// ~1s, and the escape dialog allows ~65s to click Yes -> clearing it instantly killed the AND before the
// prisoner could leave. Delay it so the release window + a late click work, then clear so a NEW break can start
// (preserves the #342 fix above -- just 70s instead of the old 20-min watchdog cap, not instant).
if (!isNil "SRV_prisonData") then { [] spawn { uiSleep 70; SRV_prisonData set [1, false]; publicVariable "SRV_prisonData"; }; };
 
if (AP_maxtac_instance == _dispatch) then {_dispatch spawn {sleep 300;
if (AP_maxtac_deployed && AP_maxtac_instance == _this) then {[] call AP_fnc_maxtacDeactivate;};};};