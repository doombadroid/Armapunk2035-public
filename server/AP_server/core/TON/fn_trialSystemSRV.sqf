/*
    APS_fnc_trialSystemSRV  (LooneyBin -- implemented 2026-06-09; the 2020 client speaks a CASE
    protocol, the 2017 trial system is positional -> court trials never started.)
    Client (core/civilian/fn_trialSystem.sqf):
      ["startTrial",    [player, bountyTotal]]   -> 2017 trialRequest (summons up to 30 civ jurors,
                                                    waits for 12 / 160s, then trialBegin teleports
                                                    court + runs the verdict flow)
      ["addJuryPlayer", [player, "add"|"remove"]] -> juror accepts / drops the summons
      ["addJuryVote",   [player, "GUILTY"|"INNOCENT"]] -> 2017 juryVote tally
*/
params [["_caseType", "", [""]], ["_data", [], [[]]]];
// owner 2026-07-24 SECURITY (audit): CfgRE allowedTargets=2 and EVERY case reads its actor from _data
// element 0, a client-supplied object that was never compared to the caller. "addJuryVote" only checked
// the passed unit is seated on the jury -- and the roster is publicVariable'd in SRV_trialData[1] -- so a
// DEFENDANT could cast every juror's vote and decide its own trial. "addJuryPlayer" could seat or unseat
// other players, and "startTrial" could request a trial as someone else.
// All three cases legitimately act on SELF (the client passes `player` in every one -- see the header),
// so forcing element 0 to the real caller fixes all of them at once and is a no-op for honest calls.
// An unresolvable caller yields an empty _data, which each case's own `isNull _unit` guard then drops.
private _src = remoteExecutedOwner;   // 0 == server-internal = trusted
if (_src isNotEqualTo 0) then {private _realCaller = (allPlayers select { owner _x isEqualTo _src }) param [0, objNull];
    if (isNull _realCaller) then {_data = [];} else {if (_data isEqualType [] && {count _data > 0}) then {
            if (!((_data select 0) isEqualTo _realCaller)) then {
                ["-SEC-", _realCaller, format ["BLOCKED trialSystem impersonation (%1): claimed %2", _caseType, _data select 0]] call APS_fnc_logIt;
            };
            _data set [0, _realCaller];};};};
switch (_caseType) do {case "startTrial": {_data params [["_unit", objNull, [objNull]], ["_amount", 0, [0]]];
        if (isNull _unit) exitWith {};
        if (!isNil "AP_trial_inprogress" && {AP_trial_inprogress}) exitWith {
            [["A trial is already in session. Try again later.", "basic"], "AP_fnc_handleMessage", _unit, false, false] spawn AP_fnc_MP;
        };
        // owner 2026-07-24 (audit): AP_juryVoted is the per-trial double-vote guard but NOTHING ever
        // cleared it, so anyone who served once could never vote again -- their votes were silently
        // discarded for the rest of the session. Since NOT GUILTY needs >70% INNOCENT of ALL seated
        // jurors, every repeat juror pushed trials further toward a guaranteed GUILTY. Clear it for
        // everyone as a new trial starts (this is the one place a trial legitimately begins).
        { _x setVariable ["AP_juryVoted", nil]; } forEach allPlayers;
        [_unit, _amount max 1] spawn AP_fnc_trialRequest;
        ["-TRIAL-", _unit, format ["requested a jury trial (bounty $%1)", _amount]] call APS_fnc_logIt;};
    case "addJuryPlayer": {_data params [["_unit", objNull, [objNull]], ["_op", "add", [""]]];
        if (isNull _unit) exitWith {};
        if (isNil "AP_trial_jury") then { AP_trial_jury = []; };
        if (_op isEqualTo "add") then {if ((count AP_trial_jury) < 12 && {!(_unit in AP_trial_jury)} &&
                {isNil "AP_trial_jury_invites" || {_unit in AP_trial_jury_invites}}) then {AP_trial_jury pushBack _unit;};} else {
            AP_trial_jury = AP_trial_jury - [_unit];};
        // LooneyBin: mirror the live jury roster into SRV_trialData[1] so every client's courthouse UI sees the
        // seat count (registerForJury checks count(SRV_trialData select 1) == 12 for "courtroom full").
        if (!isNil "SRV_trialData" && {SRV_trialData isEqualType []} && {count SRV_trialData > 1}) then {
            SRV_trialData set [1, +AP_trial_jury];
            publicVariable "SRV_trialData";};};
    case "addJuryVote": {_data params [["_unit", objNull, [objNull]], ["_verdict", "", [""]]];
        if (isNull _unit || {!(_unit in (missionNamespace getVariable ["AP_trial_jury", []]))}) exitWith {};
        if (_unit getVariable ["AP_juryVoted", false]) exitWith {};
        _unit setVariable ["AP_juryVoted", true];
        [_verdict isEqualTo "INNOCENT"] call AP_fnc_juryVote;
        ["-TRIAL-", _unit, format ["jury vote: %1", _verdict]] call APS_fnc_logIt;};
    default { diag_log format ["[LooneyBin][trial] unhandled case: %1", _this]; };};
