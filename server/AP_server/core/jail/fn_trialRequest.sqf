 
private["_unit","_jailId","_start","_soundOn","_dispatch"]; 
 
_unit = [_this,0,Objnull,[Objnull]] call BIS_fnc_param; 
_amount = [_this,1,1,[1]] call BIS_fnc_param; 
 
if (isNull _unit || AP_trial_inprogress) exitWith {}; 
 
AP_trial_inprogress = true; 
publicVariable "AP_trial_inprogress"; 
 
// LooneyBin: announce the active trial to all clients (blocks duplicate requests + lets civs register as
// jurors), and record the defendant so they can't re-request a trial this restart.
SRV_trialData = [_unit,[],[],true,false,false,name _unit];
publicVariable "SRV_trialData";
SRV_trialPreviousDefenders pushBackUnique (getPlayerUID _unit);
publicVariable "SRV_trialPreviousDefenders";
_startTime = time;
AP_trial_jury = [];
AP_trial_jury_invites = []; 
_juryPool = []; {if (side _x == civilian && _x distance (getMarkerPos "jail_marker2") > 70) then { _juryPool pushBack _x; };
} forEach allPlayers; 
 
while {(count AP_trial_jury_invites) < 30 && (count _juryPool) > 0} do {_randomGuy = _juryPool call BIS_fnc_selectRandom;
if (!(_randomGuy in AP_trial_jury_invites)) then {AP_trial_jury_invites pushBack _randomGuy;
_juryPool = _juryPool - [_randomGuy];};};
 {[["juryInviteToTrial",[_unit]],"AP_fnc_trialSystem",_x,false] spawn AP_fnc_MP;} forEach AP_trial_jury_invites;
 
waitUntil { time - _startTime > 160 || (count AP_trial_jury) == 12 || isNull _unit }; 
 
if ((count AP_trial_jury) > 3 && !isNull _unit) then {[_unit,_amount] call AP_fnc_trialBegin;}
else {AP_trial_inprogress = false;
publicVariable "AP_trial_inprogress";
// LooneyBin: trial cancelled (too few jurors signed in) -- clear the active-trial broadcast.
SRV_trialData = [objNull,[],[],false,false,false,""];
publicVariable "SRV_trialData"; {_reward = 2000;
[[[0,2], format["The trial for which you were summoned has been cancelled.  The convicted will serve their sentence.  You have been awarded $%1 for answering your Summons.",[_reward] call AP_fnc_numberText]],"AP_fnc_broadcast",_x,false] spawn AP_fnc_MP; 
[["atm","add",_reward],"AP_fnc_uC",_x,false] spawn AP_fnc_MP; 
AP_jury_registered = nil; 
(_x getVariable ["ownerID", -1]) publicVariableClient "AP_jury_registered";} forEach AP_trial_jury;
 
if(isNull _unit) exitWith {};  
[[[0,2], "Your request for a trial was denied. Enjoy your stay!"],"AP_fnc_broadcast",_unit,false] spawn AP_fnc_MP;};