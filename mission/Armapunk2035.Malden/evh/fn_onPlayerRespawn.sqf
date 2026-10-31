params[["_aliveUnit", objNull], ["_deadUnit", objNull]];
AP_corpse = _deadUnit;
// owner 2026-09-16 (body drag): the Respawn EH runs directly while the Killed EH is spawned, so this is the
// earliest point a dragger who just died lets go of the body. AP_fnc_dragBodyStop matches the OLD unit through
// the dragger saved in AP_dragMeta and leaves the new unit's pose alone; the later "killed" call is a no-op.
if !(isNull (missionNamespace getVariable ["AP_dragging", objNull])) then {["killed"] call AP_fnc_dragBodyStop;};
// All four respawn_* markers -- civilian/west/guerrila/east -- are SHIPPED in mission.sqm
// (Item4225-4228 post-trim), not created at runtime: initServer.sqf:56-57's createMarker guard only fires when a
// marker is missing (getMarkerPos == [0,0,0]), which is false for all four today, so it creates
// nothing. respawn_west lives at MaxSec HQ (moved in the phase-6 fix); civilian/guerrila/east are unchanged.
// This hard-correct remains a safety net, not the primary fix: it always runs client-side AFTER the
// engine respawn, and if a unit ever DOES land on debug island ([0,0,0], where they get stuck and often
// can't be revived -- the engine auto-deletes the corpse after a long wait, leaving fn_revived nowhere
// to teleport back to) it is moved to the side's first real spawn point (cop/medic HQ), falling back to
// the civilian respawn.
if (((getPosATL _aliveUnit) distance2D [0,0,0]) < 100) then {private _pos = getMarkerPos "respawn_civilian";
    private _spawns = [AP_effSide] call AP_fnc_spawnPointCfg;
    if (count _spawns > 0) then {private _first = (_spawns select 0) select 0;
        private _cand = if (_first isEqualType "") then { getMarkerPos _first } else { _first };
        if !(_cand isEqualTo [0,0,0]) then { _pos = _cand; };};
    _aliveUnit setPosATL _pos;};
if (_aliveUnit getVariable["AP_restrained", false]) then {_aliveUnit setVariable["AP_restrained", false, true]};
if (_aliveUnit getVariable["AP_escorting", false]) then {_aliveUnit setVariable["AP_escorting", false, true]};
if (_aliveUnit getVariable["AP_transporting", false]) then {_aliveUnit setVariable["AP_transporting", false, true]};
if (_aliveUnit getVariable["AP_surrendered", false]) then {_aliveUnit setVariable["AP_surrendered", false, true]};
if !(_aliveUnit getVariable["AP_steamid", ""] isEqualTo(getPlayerUID player)) then {
    _aliveUnit setVariable["AP_steamid", getPlayerUID player, true]};
if !(_aliveUnit getVariable["AP_name", ""] isEqualTo profileName) then {_aliveUnit setVariable["AP_name", profileName, true]};
// FACTION REWORK (2026-08-19): A DUTY SHIFT SURVIVES DEATH, and the respawn has to make that true on this
// client. Nothing on the death path clocks anyone off -- APS_fnc_dutySRV's roster entry is server state and
// its 60s sweep only drops entries whose PLAYER is gone, never one whose unit left the group -- so the
// server still holds this player on shift. The client is the half that can drift: a respawn is a NEW UNIT
// OBJECT, and with respawn=BASE the engine makes no promise it lands back in the duty group. Off that group
// the unit's `side` falls back to the player's login side, which for every officer is CIVILIAN, and then
// APS_fnc_isDutyCop / isDutyMed -- whose first half is still the engine side test -- refuse them at every
// authority gate while the roster says they are on duty. The copTenure job drops their tenure on the same
// tell, so dying would silently reset an officer's heist eligibility to zero.
// joinSilent to the group you are already in is a no-op, so this costs nothing when the engine did the
// right thing by itself. The group is resolved from the PUBLISHED netId exactly as AP_fnc_dutyClient does
// it (fn_dutyClient.sqf:202-204): slot 2 of the cfg row names a SERVER-side variable, which simply does not
// exist on a client, and `%1Net` is the publicVariable'd twin. A null group means that publish has not
// arrived -- leave the unit where it is rather than inventing a private group, the same refusal the apply
// path makes for the same reason.
// AP_fnc_dutyContext then re-applies the identity vars, and it is a superset of the west-only block below:
// AP_unitCopLevel / AP_unitCopRetiredLevel / AP_unitCopRole / AP_showrank verbatim (fn_dutyContext.sqf:68-71)
// plus AP_nonlethal, AP_medLevel, AP_track_radius, AP_effSide, AP_dutyPaycheck, AP_maxWeight/Talents -- and it
// covers TRAUMA, which the block below never did. It is documented idempotent and safe to re-run.
// FLAG-OFF IS THE ELSE BRANCH, BYTE FOR BYTE. AP_onDuty can only ever be true after a granted shift
// (configuration.sqf seeds it false, AP_fnc_dutyClient is the only writer and is itself behind
// AP_dutyEnabled), so on a shipped server this reads exactly as it did before.
if (missionNamespace getVariable ["AP_onDuty", false]) then {
    private _row = [missionNamespace getVariable ["AP_dutyFaction", ""]] call AP_fnc_dutyCfg;
    if !(_row isEqualTo []) then {
        private _grp = groupFromNetId (missionNamespace getVariable [format ["%1Net", _row select 2], ""]);
        if !(isNull _grp) then {[player] joinSilent _grp;} else {
            diag_log format ["[AP-DUTY] respawn: %1 group netId not published -- left in %2", _row select 0, group _aliveUnit];};
    };
    [] call AP_fnc_dutyContext;
} else {
    // owner 2026-06-15 (#249): re-apply the COP identity vars on the respawned unit. The cop lobby init set
    // them once at the INITIAL spawn, so a respawn (= new unit object) lost them -> AP_unitCopLevel defaulted to 0
    // in fn_playerTags -> no rank/police icon over the cop = "cadets get undercover when they come back to life".
    // Restore from the persistent client vars (AP_copLevel/AP_copRole); SCD + 'all' stay undercover.
    // PR7 leaves this VESTIGIAL rather than deleting it: `side _aliveUnit isEqualTo west` needs a west unit,
    // and with the west slots gone the only thing that makes one is a granted shift -- which takes the
    // AP_onDuty branch above. It costs one side test on a respawn and it is the honest shape of the else.
    if (side _aliveUnit isEqualTo west) then {_aliveUnit setVariable["AP_unitCopLevel", call AP_copLevel, true];
        _aliveUnit setVariable["AP_unitCopRetiredLevel", call AP_copRetiredLevel, true];
        _aliveUnit setVariable["AP_unitCopRole", AP_copRole, true];
        _aliveUnit setVariable["AP_showrank", !(AP_copRole in ["scd", "all"]), true];};
};
 {_x setVariable["AP_aggressive", nil];}
forEach allPlayers;
if (time < (_aliveUnit getVariable["AP_next_revive", -1000])) then {_aliveUnit setVariable["AP_next_revive", -1000, true];};
player playMoveNow "amovppnemstpsraswrfldnon";
[AP_sidechat, _aliveUnit] call AP_fnc_manageSidechat;
// owner 2026-06-20: stamina REMOVED -- kill it on the freshly respawned unit immediately (a new unit defaults to
// stamina ON; the survival loop also re-asserts it each tick, this just closes the spawn-instant window).
player enableStamina false;
// owner 2026-09-16: PARKOUR RESET ON RESPAWN. AP_fnc_parkourMove tears itself down on death within one tick and a
// guard script recovers it if it errors. But only the FIRST death of a session waits for that: core/init.sqf's
// setPlayerRespawnTime 0.6 applies to the next respawn only, and after it description.ext's respawnDelay=0 fires
// this Respawn EH (a direct call) usually BEFORE the mover's next 0.05 s tick. So from the second death on, this
// block is the normal teardown for a death mid-move, not only a net: a stuck non-idle state would refuse every V
// press, and a stuck AP_action_in_use would swallow every keybind, for the rest of the session.
// AP_action_in_use is cleared ONLY when the state is not idle, because only then did a parkour mover own it --
// clearing it unconditionally would break whatever other flow legitimately holds it across a respawn. Bumping
// AP_parkourSerial (seeded 0 on configuration.sqf line 2; read through getVariable only so this block stays
// nil-safe) disowns any mover still running for the old body, so it cannot clear flags or set velocity on the
// new one.
// owner 2026-09-16 (review round 1): DETACH BEFORE DELETE. The corpse is still attached to the helper here, and the
// mover's own hard teardown skips its detach once the helper reads null (a frame after deleteVehicle), so nothing
// else would ever detach the body. Everything on the helper is let go first (repo precedent: fn_handleTagged.sqf).
// AP_parkourCfg_wakeCorpse (default false, unmeasured) additionally wakes the released body's ragdoll if a death
// mid-mantle turns out to leave it hanging in the air.
if !((missionNamespace getVariable ["AP_parkourState", "idle"]) isEqualTo "idle") then {
    private _pkHelper = missionNamespace getVariable ["AP_parkourHelper", objNull];
    if !(isNull _pkHelper) then {
        {detach _x} forEach (attachedObjects _pkHelper);
        deleteVehicle _pkHelper;
    };
    if (!(isNull _deadUnit) && {!(alive _deadUnit)} && {["wakeCorpse"] call AP_fnc_parkourCfg}) then {_deadUnit awake true};
    AP_parkourHelper = objNull;
    AP_parkourSerial = (missionNamespace getVariable ["AP_parkourSerial", 0]) + 1;
    AP_action_in_use = false;
    AP_parkourState = "idle";
};
