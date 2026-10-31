/*
    File: fn_aqAwardXpClient.sqf  (AP_fnc_aqAwardXpClient)

    The client half of ArmaQuest's awardXp capability. Runs on the REWARDED
    player's own machine, pushed there by AP_fnc_aqAwardXp (core/quests/
    fn_aqProfile.sqf). CfgRE: allowedTargets = 1 (server -> clients only).

    WHY THIS EXISTS RATHER THAN A DIRECT DATABASE WRITE. Side experience lives in
    AP_side_exp, a CLIENT variable, and is persisted by the client's own
    ClupdatePartial case 4. A server-side `UPDATE players SET civ_exp = civ_exp + n`
    would be authoritative for exactly as long as it took the owning client to run
    its next case-4 save, which writes the client's own (now stale) figure straight
    back over it. The reward would vanish with no error and no log. Granting through
    the owner is the only path that leaves one writer in charge of the value.

    WHY IT SAVES IMMEDIATELY. AP_fnc_addExperience only mutates the variable; the
    one other cross-machine caller (core/cop/fn_ticketPay.sqf) leaves persistence to
    whatever save happens next. That is fine for a trickle of ticket XP and wrong
    for a quest reward, which the player was just told they earned: a disconnect
    before the next save turns a completed quest into nothing. So this forces the
    case-4 write itself rather than adding one to fn_addExperience, which would
    change behaviour for a caller that did not ask for it.

    THE HONEST LIMITATION, same as giveItem/takeItem in fn_aqProfile.sqf: the
    server dispatches and cannot hear the result. An offline player is caught
    server-side (the unit does not resolve, awardXp returns false); a client that
    is online but refuses to run this is not detectable from here. ArmaQuest treats
    XP as best-effort by design (ArmaQuest/server/fn_srvPayout.sqf:229) and the
    quest still completes, so the exposure is one quest's XP.
*/
if (isRemoteExecuted && {remoteExecutedOwner != 2}) exitWith {};   // server-origin only: CfgRE allowedTargets limits the target, never the sender
params [["_amount", 0, [0]]];
if (!hasInterface) exitWith {};
// allowedTargets = 1 lets any CLIENT target any other client too; only the server grants XP.
if (isRemoteExecuted && {remoteExecutedOwner != 2}) exitWith {};

// Negative or zero XP is not a thing any authored reward expresses, and treating
// it as a silent no-op is better than letting a malformed config subtract.
_amount = floor _amount;
if (_amount <= 0) exitWith {};

[_amount] call AP_fnc_addExperience;
[4] call AP_fnc_ClupdatePartial;
