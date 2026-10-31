/*
    APS_fnc_preSpawnPos -- move the SERVER's copy of a spawn-held player to their spawn target
    BEFORE the client re-enables simulation.

    Why this exists (the 50 km release yank, measured 2026-08-20): a setPos on a unit whose
    simulation is DISABLED never propagates off its own machine, so for the whole client-side
    hold the unit's last NETWORKED position stays the 50 km mission.sqm slot. The moment the
    owning client runs `enableSimulation true`, the engine re-syncs the unit from that networked
    position -- the client-side release code measured the snap-back arriving ~40 ms after the
    release, saw "1 re-applies" on almost every spawn, and every one of those re-applies was the
    player spending a simulated frame at 50 km: the freefall animation latched there is the
    "stuck flying, then prone" spawn-in, and the server's copy free-falling from the slot for the
    seconds until the owner's ground position arrived is the fall other players watched.

    Updating the networked position FIRST -- here, on the server, while the owner is still frozen
    and therefore not streaming a position of its own -- makes the post-release re-sync a no-op:
    the position it restores IS the spawn target. The client-side re-assert loops in fn_initCiv /
    fn_spawnConfirm stay as the safety net; their [TPTRACE] re-apply count is this function's
    success meter (expect 0 with it, 1 without).

    SECURITY: the subject is the CALLER'S OWN UNIT, derived from remoteExecutedOwner -- the
    payload only supplies the position. A client can already place its own unit wherever it
    likes (position is owner-authoritative in this engine); what it must not get is a primitive
    that moves OTHER players' server copies, so any owner mismatch is dropped.
    CfgRE: allowedTargets = 2 (client -> server only).
*/
params [["_unit", objNull, [objNull]], ["_pos", [], [[]]], ["_asl", false, [false]]];
if (isNull _unit) exitWith {};
if ((owner _unit) isNotEqualTo remoteExecutedOwner) exitWith {
    diag_log format ["[LB-SPAWNHOLD] preSpawnPos REFUSED: owner %1 != caller %2 (unit %3)", owner _unit, remoteExecutedOwner, name _unit];
};
if ((count _pos) < 3 || {(_pos findIf {!(_x isEqualType 0)}) > -1}) exitWith {};
if (_asl) then {_unit setPosASL _pos} else {_unit setPosATL _pos};
_unit setVelocity [0, 0, 0];
