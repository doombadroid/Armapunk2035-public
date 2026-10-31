/*
    APS_fnc_duelArenaSystemSRV  (LooneyBin: IMPLEMENTED -- was a logging no-op stub)
    Called (no args) once both duelers have accepted + each paid their half of the wager
    (SRV_duelArenaData = [active, time, inviterUID, inviteeUID, wager, score]). The whole arena session
    is client-side in AP_fnc_duelArenaSystem "joinArena" (save pre-duel state -> teleport + duel
    loadout + countdown -> waitUntil the duel ends -> restore, with refund baked in). Death-scoring +
    payout are wired in fn_onPlayerKilled (nextRound/endArena). So the server's only job is to teleport
    BOTH players into the arena to begin -- which is what was missing (the stub never started anything).
*/
if (isNil "SRV_duelArenaData") exitWith {};
private _p1uid = SRV_duelArenaData select 2;   // inviter
private _p2uid = SRV_duelArenaData select 3;   // invitee
if (_p1uid isEqualTo "" || {_p2uid isEqualTo ""}) exitWith {};

private _positions = [[23000.4, 17110.9, 0.00143886], [22982.8, 17153.9, 0.00144863]];
private _civs = allPlayers select { side _x isEqualTo civilian };
private _p1 = _civs param [_civs findIf { (getPlayerUID _x) isEqualTo _p1uid }, objNull];
private _p2 = _civs param [_civs findIf { (getPlayerUID _x) isEqualTo _p2uid }, objNull];

SRV_duelArenaData set [5, [0, 0]];   // fresh score
SRV_duelArenaData set [6, false];    // not-yet-ended/paid flag (also ensures index 6 exists)
private _bothHere = (!isNull _p1 && {!isNull _p2});
if (!_bothHere) then { SRV_duelArenaData set [0, false]; };   // someone vanished -> abort; joinArena's waitUntil refunds whoever enters
publicVariable "SRV_duelArenaData";

if (!isNull _p1) then { ["joinArena", [_positions select 0]] remoteExec ["AP_fnc_duelArenaSystem", _p1]; };
if (!isNull _p2) then { ["joinArena", [_positions select 1]] remoteExec ["AP_fnc_duelArenaSystem", _p2]; };

[[994, objNull, format ["DUEL start: %1 vs %2 wager $%3 (bothHere=%4). Srv %5", _p1uid, _p2uid, SRV_duelArenaData select 4, _bothHere, AP_server_instance]], "APS_fnc_logIt", false, false] spawn AP_fnc_MP;
