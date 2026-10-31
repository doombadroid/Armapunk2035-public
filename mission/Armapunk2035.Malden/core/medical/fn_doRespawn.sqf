// SECURITY 2026-09-26: CfgRE allowedTargets=1 let any client remoteExec this at a LIVING player (or -2 = all):
// spawnMenu -> fn_respawned strips gear, zeroes cash and persists it, and flags the live body AP_respawnedOrphan.
// Every legit caller runs on a dead player (death screen, bleed-out, event death, execute/scalp on the corpse's
// owner, executioner / electric chair after setDamage 1), all after fn_onPlayerKilled set AP_isDead = true.
// A client can publicVariable AP_isDead = true onto everyone, so the flag is mirrored in localNamespace (set next to
// AP_isDead = true in fn_onPlayerKilled, cleared at every AP_isDead = false), which the network cannot write.
if !((missionNamespace getVariable ["AP_isDead", false]) && {localNamespace getVariable ["AP_isDead", false]}) exitWith {};   // getVariable: unset on a headless client
closeDialog 0;
AP_respawned = true;
// owner 2026-06-16 (#291/#292): the engine corpse-immunity window was raised to ~31min so a body can't be
// yanked out from under a player mid-bleedout (the old 360s setting force-respawned them at ~5-6min). But that
// would also make a RESPAWNED player's abandoned body linger ~31min -> corpse buildup. `player` is still the
// dead body here (the engine respawn hasn't fired yet), so flag it -> fn_cleanup reaps a respawned-orphan on
// its next pass instead of waiting the full window. A body left bleeding for a revive is NOT flagged (this
// only runs when the player CHOSE to respawn) -> it stays protected for the full 30min.
player setVariable ["AP_respawnedOrphan", true, true];
AP_inCombat = false; {_x setVariable["AP_aggressive", nil];}
forEach allPlayers;
private _toSend = (allPlayers - [allDeadMen] - [player]) select {
    (side _x isEqualTo west && _x getVariable["AP_unitCopRole", ""] in ["medic", "all"]) || side _x isEqualTo independent};
if !(_toSend isEqualTo[]) then {[[player, player], "AP_fnc_medicRespondDone", _toSend] spawn AP_fnc_MP;};
[] spawn AP_fnc_spawnMenu;