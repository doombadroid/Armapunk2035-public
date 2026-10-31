params[["_target", player], ["_caller", player], ["_actionID", 0], ["_useExplosive", false]];
private _safe = cursorTarget;
if !(AP_effSide isEqualTo civilian) exitWith {};
// Available from the moment the vault starts cycling, so the countdown is prep time rather than
// standing around: a safe opened early simply has its briefcase appear inside it when the clock ends.
if (((missionNamespace getVariable ["SRV_maldenFed", [0]]) param [0, 0]) < 2) exitWith {
    [2, "The safes are sealed until the vault starts cycling."] call AP_fnc_broadcast};
// owner 2026-07-28: THREE dead cooldown gates removed from this file, and the whole cooldown story for
// the Malden Fed is now the phase gate directly above plus slot 4 of SRV_maldenFed (read by
// fn_openGate, which is the only way in).
//   * the 60-minute AP_fed_robbed[1] lockout that stood here, and the police-requirement gate below
//     it, were both keyed on !(AP_fed_robbed select 0). APS_fnc_maldenFedSRV's _fnc_setState is the
//     only writer of that flag now and sets it to (phase > 0), so it is TRUE for the whole of phase >= 2
//     and both conditions were unreachable -- anything below phase 2 has already exited above.
//   * SRV_lastRobbery > serverTime - 15 min. That variable is written by ONE thing now, the bank drill
//     (fn_bankDrillVault), and the Fed's own entry points -- the gate and the dome -- dropped the check
//     when they were rewritten. Only the safes kept it, and the scroll conditions never mirrored it. So
//     after any bank job a crew could breach the gate, crack the dome, wait out the ten minutes, watch
//     ten briefcases spawn, and then have every single safe refuse with "Security is high due to a
//     recent robbery" while the police closed in. The action offered itself and then said no.
// owner 2026-07-27: the Altis talent-43 "explosives" requirement is dropped on Malden -- the charge in
// the crew's inventory is the whole gate now, so a character with no talents at all can blow a safe.
if ((AP_inv_demoCharge <= 0) && _useExplosive) exitWith {[2, "You need a demolition charge to do this."] call AP_fnc_broadcast};
if !((vehicle player) isEqualTo player) exitWith {[2, "You cannot do this from within a vehicle."] call AP_fnc_broadcast};
if (["fed"] call AP_fnc_activeFederalEvent) exitWith {
    ["There is already another Federal Event happening.", "basic"] spawn AP_fnc_handleMessage;};
// The target is the object under the cursor, captured at the top of the file (fn_cyberdeckLaunch relies
// on that too), tested against the server's resolved list instead of a class. Both the nearestObjects
// sweep that used to stand here and the typeOf test after it named Land_Research_house_V1_F /
// Land_Research_HQ_F, neither of which exists on Malden, so this function could never find a safe.
// AP_fedSafes is publicVariable'd at boot and holds exactly the ten ring buildings, so membership is
// exact and needs no class name -- and objNull is not in it, which covers "aiming at nothing" as well.
if !(_safe in (missionNamespace getVariable ["AP_fedSafes", []])) exitWith {
    [2, "That is not a Reserve safe."] call AP_fnc_broadcast};
if ((_safe getVariable["AP_vaultlocked", 1]) isEqualTo 0) exitWith {[2, "The safe is already unlocked."] call AP_fnc_broadcast};
// The Altis "the dome must already be open" precondition that stood here is gone, superseded by the
// phase >= 2 gate at the top. It read AP_vaultlocked off the nearest dome, which on Malden only
// clears at phase 3, so keeping it would have made the ten-minute countdown useless as preparation
// time (maldenfed.md 3.3: both routes are available from phase 2) -- the scroll action would have
// offered itself and then refused. Its 30 m radius barely reached the outer safe doors anyway.
private _selectionNames = (selectionNames _safe) select {(_x find "door") >= 0};
// The scroll condition used to require a door selection within 2.75 m, which happened to guarantee this
// list was non-empty; it now tests list membership and range instead, so the guarantee is gone. Without
// this exit, a class that names no "door" selection makes the next line `select 0` an empty array --
// nil -- and the function dies on the selectionPosition after it with no message to the player at all.
if (_selectionNames isEqualTo []) exitWith {
    [2, "You cannot find a way into this safe."] call AP_fnc_broadcast};
private _closestSafeDoor = _selectionNames select 0; {private _distance = player distance(_safe modelToWorld(_safe selectionPosition _x));
    if ((_distance) < (player distance(_safe modelToWorld(_safe selectionPosition _closestSafeDoor)))) then {_closestSafeDoor = _x};}
forEach _selectionNames;
private _closestSafeDoorPos = (_safe modelToWorld(_safe selectionPosition _closestSafeDoor));
if ((_useExplosive) && (AP_inv_demoCharge <= 0)) exitWith {[2, "You need a demolition charge to do this."] call AP_fnc_broadcast};
if ((player distance _closestSafeDoorPos) >= 3) exitWith {[2, "You are not close enough to the safe door."] call AP_fnc_broadcast};
if (AP_action_in_use) exitWith {};
AP_action_in_use = true;
private _isSuccess = false;
if (!_useExplosive) then {
    // owner 2026-07-18: safe crack = Cyberdeck SEQUENCE BREACH (the "car hacking menu"), 6-slot buffer (diff 2)
    private _r = [6] call AP_fnc_cyberdeckSeq;
    _isSuccess = (_r isEqualTo 1);
    if (_r isEqualTo 0) then { [2, "You failed to crack the safe security locks."] call AP_fnc_broadcast; };
    AP_action_in_use = false;};
if (_useExplosive) then {disableSerialization;
5 cutRsc["AP_progress", "PLAIN"];
private _display = uiNameSpace getVariable["AP_progress", displayNull];
private _progressBar = _display displayCtrl 38201;
private _progressText = _display displayCtrl 38202;
AP_action_in_use = true;
private _increment = 1;
private _totalTime =
if !(_useExplosive) then {25   // LooneyBin fed rework v2: inner-building drill = 25s. Demo = 10s plant + grenade boom.
} else {10};
private _currentPoint = 0;
private _loopDelay = _totalTime / floor(100 / _increment);
private _text =
if !(_useExplosive) then {"Cracking safe security locks"} else {"Planting a demolition charge"};
private _startCount = 0;
_progressBar progressSetPosition _startCount;
_progressText ctrlSetText format["%1 (%2%3)", _text, _startCount, "%"];
private _duration =
if (_useExplosive) then {5.882} else {20};
private _animation =
if (_useExplosive) then {"AinvPknlMstpSnonWnonDnon_medic_1"} else {"AinvPknlMstpSnonWnonDnon_medic_1"};
[_animation, _duration] spawn AP_fnc_handleAnim;
_isSuccess =
for "_i"
from 0 to 1 step 0 do {uiSleep _loopDelay;
    if (isNull _progressBar) exitWith {[2, "You have failed to hack the safe."] call AP_fnc_broadcast;
        false};
    _currentPoint = (progressPosition _progressBar) + (_increment / 100);
    _progressBar progressSetPosition _currentPoint;
    _progressText ctrlSetText format["%1 (%2%3)", _text, round(_currentPoint * 100), "%"];
    if (_currentPoint >= 1) exitWith {true};
    if ((speed player) >= 2) exitWith {[2, "You have failed to hack the safe."] call AP_fnc_broadcast;
        false};
    if !((vehicle player) isEqualTo player) exitWith {[2, "You have failed to hack the safe."] call AP_fnc_broadcast;
        false};
    if ((!AP_action_in_use) || (!alive player) || ((player distance _closestSafeDoorPos) >= 3)) exitWith {
        [2, "You have failed to hack the safe."] call AP_fnc_broadcast;
        false};
    if (player getVariable["AP_downed", false] || player getVariable["AP_restrained", false]) exitWith {
        [2, "You have failed to hack the safe."] call AP_fnc_broadcast;
        false};
    if (["fed"] call AP_fnc_activeFederalEvent) exitWith {
        ["There is already another Federal Event happening.", "basic"] spawn AP_fnc_handleMessage;
        false};
    false;}; AP_action_in_use = false;
[] spawn AP_fnc_handleAnim;
5 cutText["", "PLAIN"];};
// owner 2026-07-28: THE UNLOCK IS THE SERVER'S. This block used to write AP_vaultlocked and the
// bis_disabled_door_N flags itself, public = true, so the change propagated FROM the client and the
// server never heard about it -- a modified client could open all ten safes instantly from anywhere on
// the map and skip the whole safe-cracking layer, which is the only thing standing between the crew and
// briefcases that spawn inside these buildings unconditionally. Everything else here stays client-side:
// the minigame, the charge, the progress bar, the animations, the messages. Only the decision moved.
// Footnote 2026-07-29, RETRACTING an earlier footnote that stood here. That note called the lowercase
// "bis_disabled_door_N" spelled above a TYPO, said the engine only ever reads "bis_disabled_Door_N"
// with a capital D, and concluded that half of the old client write was inert and the safe doors were
// never locked. All of that is wrong. SQF variable names are CASE-INSENSITIVE -- BIKI Identifier:
// "Identifiers are case-insensitive"; BIKI allVariables documents its return as "array of variable
// names. All names are in lower case (see toLower)", the variable store folding case as it stores.
// bis_disabled_door_N and bis_disabled_Door_N are the same variable, so the old client write was fully
// live on BOTH variables and the safes really were locked. That makes the client-authority hole
// described above worse, not milder, and it is the whole reason the decision moved to the server.
// The server-side seal and unlock now spell it with a capital D only to match the engine's own spelling
// in BIS_fnc_Door and the rest of this build; no behaviour depends on the casing, here or there.
// APS_fnc_maldenFedSRV "safe" re-derives the caller from remoteExecutedOwner and re-checks alive /
// civilian / un-restrained / on foot / at that safe's door / phase >= 2 / genuinely one of AP_fedSafes.
//
// IT IS SENT HERE, at the moment success is decided, and NOT at the end where the unlock used to sit.
// The demolition route tells the player to move away from the door and then waits out a 2.5 s arm plus
// a fuse capped at 6 s; a player who obeys is a long way off by the time the tail runs, and the server's
// proximity check would refuse the breach they just earned. At this line both routes have the player
// provably within 3 m of the door -- the sequence route just passed the check above, and the demo
// progress loop re-checks it every tick. The blast theatre below then plays out unchanged; the only
// visible consequence of asking early is that the door actions come back a few seconds before the bang.
if (_isSuccess) then {
    [["safe", _safe], "APS_fnc_maldenFedSRV", 2] spawn AP_fnc_MP;
    if (_useExplosive) then {[false, "demoCharge", 1] call AP_fnc_handleInv;
        private _toSend = (allPlayers - [allDeadMen]) select {(_x distance player) <= 30};
        [2, "Blasting charge activated, move away from the door."] call AP_fnc_broadcast; [
            [player, "bombarm"], "AP_fnc_playSound", _toSend, false, false] spawn AP_fnc_MP;
        uiSleep 2.5;
        private _demoChargeClass = "GrenadeHand";
        private _maxTime = serverTime + 6;
        private _demoCharge = _demoChargeClass createVehicle _closestSafeDoorPos;
        private _plb_pos = _closestSafeDoorPos;
        while {(!isNull _demoCharge) && (serverTime < _maxTime)}
        do {_demoCharge setPos _plb_pos;
            uiSleep 0.01}; { _safe animate[_x, 0.2]}
        forEach((animationNames _safe) select {(_x find _closestSafeDoor) >= 0});};
    AP_side_exp = AP_side_exp + 25;
    [2, "The safe doors have been breached, and are now unlocked."] call AP_fnc_broadcast;
    ["fedsafeopened", 1] call AP_fnc_statArrUpdate;
    // owner 2026-07-28: the `if !(AP_fed_robbed select 0) then { ... APS_fnc_fedRobbery ... }` that
    // stood here is DELETED, not left inert. APS_fnc_maldenFedSRV's _fnc_setState is the only writer of
    // that shim and sets it to (phase > 0), and this line is only reachable behind the phase >= 2 gate at
    // the top of this file -- so the flag was always true here and the branch never ran in normal play.
    // It was worth removing rather than leaving: the one way it COULD have fired is a reset landing
    // during the 20-25 s minigame (the empty-compound sweep, MaxSec securing the site, or !srv resetfed
    // all set the phase back to 0 and the shim back to false). This client would then have re-armed the
    // ENTIRE alarm -- siren, dispatch, map marker and the wanted-charge recruitment loop -- off a safe
    // crack, seconds after the Reserve had just been declared secure, with no phase behind it to end it.
    // The breach is requested on line 127 above; that request is the whole client-to-server story now.
};