 
// owner 2026-07-28: RETURNS A BOOLEAN -- true only once it has committed (AP_bank_inProgress set,
// dispatch minted, siren up, marker up, robber-recruitment loop running), false from every refusal
// above that point. APS_fnc_maldenFedSRV case "gate" now waits on that answer before it opens the gate
// or advances the phase: the order used to be the other way round, so a refusal here (most dangerously
// the tenured-cop gate, which TODO.md says goes back to 6 at public launch) left the Reserve open at
// phase 1 with no alarm at all. Every exit path below must therefore yield a value, and the file must
// end in `true`. The only other caller is APS_fnc_fedRobbery, a passthrough whose own callers spawn it
// through AP_fnc_MP and discard the result, so nothing else is affected by the new return.
private["_unit","_ret","_dispatch"];
_unit = [_this,0,Objnull,[Objnull]] call BIS_fnc_param;
if (isNull _unit) exitWith {false};
if (AP_bank_inProgress) exitWith {false};
// owner 2026-06-13: SERVER-AUTHORITATIVE cop gate. The 6-cop requirement was CLIENT-ONLY (fn_openGate /
// fn_openVault via AP_fnc_policeRequired). A client whose AP_betaZeroCops hadn't synced yet reads the
// getVariable default (TRUE = waived) and bolt-cuts in with 1 cop online -> the reserve "pops". Re-check
// here so the robbery can never START understaffed regardless of client state. Honors the beta waiver.
// NOTE: flat top-level exitWith (NOT nested in a then{} -- that would only exit the block, not the fn).
// owner 2026-06-19: fed cop req lowered 6->0 for beta (server-authoritative gate). Restore `< 0` to `< 6` at public launch.
// owner 2026-06-22 (#496): TENURED cop count (anti soft-log). Threshold still beta-waived to <0; restore to <6 at public launch.
// owner 2026-07-27: Malden testing -- cop requirement 0. Restore to < 6 at public launch.
// owner 2026-07-27: the threshold now lives in ONE place, _reqCops, and the refusal message is FORMATTED
// from it instead of restating it. That text has already drifted twice -- it said "fewer than 6" against a
// threshold of 0, was corrected to "fewer than 1" when the threshold went to 1 (de8c6ce), and went stale
// again the moment 9db3a65 put the threshold back to 0. Restoring at public launch is now a change to the
// number below and nothing else. Same idiom as fn_convoyRobbery, fn_jewelryEmporiumSRV, fn_loonyBinSRV.
private _reqCops = 6;   // launch.md 2e: restored 2026-09-07
if ((([] call AP_fnc_tenuredCops) < _reqCops) && {!(localNamespace getVariable ["AP_betaZeroCops", false])}) exitWith {
    [[2, format ["The Federal Reserve is too well-guarded to rob with fewer than %1 police officer(s) online.", _reqCops]], "AP_fnc_broadcast", _unit, false] spawn AP_fnc_MP;
    false
};
// owner 2026-06-16 (#302): server-authoritative one-event-at-a-time gate. The client check (activeFederalEvent)
// has a window (fed flag only flips here, ~10s after a 105s breach), so a 2nd event could slip in. Refuse here.
if (["fed"] call APS_fnc_fedEventActive) exitWith {
    [[2, "Another major crime is already in progress -- the Federal Reserve alarm does not engage."], "AP_fnc_broadcast", _unit, false] spawn AP_fnc_MP;
    false
};

AP_bank_robbers = [];
AP_bank_inProgress = true;
publicVariable "AP_bank_inProgress";
// owner 2026-07-27: the AP_fed_robbed pair that stood here is gone -- APS_fnc_maldenFedSRV's
// _fnc_setState is the ONLY writer of that flag now, and it sets it in lockstep with the phase.

_dispatch = ceil (random 9000);
// owner 2026-07-28: park the id server-side so the ONE ending can close it. APS_fnc_maldenFedSRV case
// "reset" is what concludes a Malden Fed, and it had no way to reach this local -- so MaxSec were
// briefed on an incident that was never resolved, unlike every other heist in the build. Server-only;
// the reset clears it back to -1 once it has sent AP_fnc_finishDispatch.
AP_fedDispatch = _dispatch;
[_dispatch, "Reserve Robbery", 10000, 2, 7, getMarkerPos "fed_reserve", ""] spawn AP_fnc_createDispatch;
 
[_dispatch] spawn {private ["_dispatch"];
_dispatch = _this select 0; 
sleep 35; 
if (count AP_bank_robbers < 2 || !AP_bank_inProgress || AP_activeMAXTAC) exitWith {}; 
if (AP_maxtac_instance == 0) then {AP_maxtac_instance = _dispatch;
switch (worldName) do {
case "Altis": { [count AP_bank_robbers, [["Power Plant",[16144,16108,0]],["Air HQ",[15566,17584,0]],["Telos East",[16591,17153,0]],["Telos North",[16144,17455,0]],["Forest",[15800.9,16715.3,0]]], getMarkerPos "fed_reserve"] spawn AP_fnc_maxtacDispatch; }; 
case "Australia": { [count AP_bank_robbers, [["Pine Gap",[19453,23959,0]],["Oasis",[18482,24382,0]],["Bridge",[21699,24097,0]],["North Ridge",[19369,25625,0]]], getMarkerPos "fed_reserve"] spawn AP_fnc_maxtacDispatch; }; 
};};};
 
[_dispatch] spawn {private ["_newRobbers","_activeRobbers","_dispatch"];
_dispatch = _this select 0; 
// owner 2026-07-28: KILL THE PREVIOUS SIREN BEFORE MINTING A NEW ONE. AP_fedAlarmSound is a single
// handle and the reset deletes exactly what it points at, so overwriting it without deleting first
// ORPHANS the old sound source: nothing holds a reference to it any more, the reset deletes only the
// newer one, and the orphan howls over the Reserve until the next restart. A second commit with no
// intervening reset is all it takes -- and the veto's stale-flag trap (APS_fnc_maldenFedSRV case
// "gate") was one way to reach exactly that state. Deleting here is safe: if a robbery really were
// live, this function has already exited at the AP_bank_inProgress check at the top.
private _oldSiren = missionNamespace getVariable ["AP_fedAlarmSound", objNull];
if (!isNull _oldSiren) then { deleteVehicle _oldSiren;
    diag_log "[maldenFed] deleted an orphaned alarm siren before starting a new one"; };
// owner 2026-07-27: `fed_alarm` was an Altis mission.sqm object and does not exist on Malden --
// reading `position` off an undefined variable HALTS the script, which is what killed this thread.
_soundOn = createSoundSource ["Sound_Alarm", AP_FED_CENTRE, [], 0];
// owner 2026-07-27: publish the siren handle so the event's reset can delete it when the robbery ends.
// The end-detector loop that used to delete it was removed because it competed with the reset task itself.
AP_fedAlarmSound = _soundOn;
publicVariable "AP_fedAlarmSound";
deleteMarker "robberyMarker";
createMarker ["robberyMarker", AP_FED_CENTRE];
"robberyMarker" setMarkerShape "ICON"; 
"robberyMarker" setMarkerType "mil_dot"; 
"robberyMarker" setMarkerColor "ColorRed"; 
"robberyMarker" setMarkerText "Robbery in Progress"; 
while {AP_bank_inProgress} do {sleep 30;
_newRobbers = []; 
_activeRobbers = 0; {
if(alive _x && {!(_x call APS_fnc_isDutyCop)} && {_x distance getMarkerPos "fed_reserve" < 200} && {!(_x getVariable["restrained",false])} && {getPosATL _x select 2 < 20}) then { 
_activeRobbers = _activeRobbers + 1; 
if(!(_x in AP_bank_robbers)) then {_newRobbers pushBack _x; AP_bank_robbers pushBack _x};};} forEach allPlayers;
 
if (_activeRobbers == 0) then {
    // owner 2026-07-27: the ENDING moved to APS_fnc_maldenFedSRV's sweep (two-empty-sweeps rule).
    // What used to be here re-locked three Altis object lists that are empty on this map, set the
    // 15-minute SRV_lastRobbery cooldown the Malden Fed deliberately does not use, and cleared
    // AP_bank_inProgress -- all of it now belongs to case "reset". This loop only recruits robbers.
}
else {if (count _newRobbers > 0) then {publicVariable "AP_bank_robbers"; {
[5, _x] call APS_fnc_wantedAdd;   // owner 2026-06-15 (#240/#232): was the LEGACY name-based call [_x,["Bank Robbery",10000],600] -- incompatible with the rewritten id-based wanted system, so the added charge's name wouldn't resolve -> players got "1 charge of Error". Now id 5 = "Federal Reserve Robbery" for every robber the alarm catches.
} forEach _newRobbers;};};};};
 
[[[0,1,2],"The alarm at the FEDERAL RESERVE has been activated! Police officers, respond immediately."],"AP_fnc_broadcast",west,false] spawn AP_fnc_MP;
true