if (isRemoteExecuted && {remoteExecutedOwner != 2}) exitWith {};   // server hop only: APS_fnc_victimSRV checks actor/range/state
params[["_source", objNull, [objNull]], ["_shanked", false, [false]]];
if ((call AP_adminLevel) isEqualTo 0) then {(findDisplay 49) closeDisplay 1;};
private _vehSource = false;
private _plb_dmg = player;
private _sourceStatArr = [];
private _RemoteStats = [];
_plb_dmg setDamage 0;
if (isNull _source) exitWith {player allowDamage true;
    AP_isDowned = false;};
// LooneyBin: clear a STALE AP_isDowned. If we're flagged downed but NOT actually incapacitated (no
// downed UI [display 7300] + alive), the flag is stale -- left true after a botched revive/recovery -- and
// it was permanently blocking the guard below, so every stun/down round early-exited and did NOTHING while
// lethal rounds still killed (the "<player> can't be downed, only killed" bug -- per-client, hits one
// person). Reset it so a genuine down can fire. When ACTUALLY down (display 7300 present) this won't clear.
if (AP_isDowned && {alive player} && {(!([] call AP_fnc_deathUiOpen)) || {(time - (missionNamespace getVariable ["AP_downStamp", -1e9])) > 65}}) then { AP_isDowned = false; };   // LooneyBin: also self-heal a flag stuck true for >65s (longer than any real down) even if the downed UI (7300) is wedged open -- recovers a "can't be downed" client WITHOUT a relog.
// LooneyBin (Torch/Nikki bug): a STUCK DeathScreen (display 7300) left open on a player who is ALIVE is
// stale -- a real death screen only shows while the player is a corpse (!alive). It came from a medic/drone
// revive that didn't close 7300 (see fn_revived). It permanently fails the guard below -> "can't be downed
// at all." If alive, close it so a genuine down can fire (self-heals already-stuck clients, no relog needed).
// owner 2026-09-11: either death screen. A stuck web screen strands a living player exactly
// as a stuck native one does, and the next line's gate reads the same predicate.
if (alive player && {[] call AP_fnc_deathUiOpen}) then {
    if !(isNull (findDisplay 7300))   then { (findDisplay 7300)   closeDisplay 0; };
    if !(isNull (findDisplay 938800)) then { (findDisplay 938800) closeDisplay 0; };
};
if !(!AP_isDowned && alive player && !([] call AP_fnc_deathUiOpen)) exitWith {};
// LooneyBin: stamp who downed us (+ when) so a later DEATH can still be attributed to them. Revivable
// players (esp. cops, AP_revive_cops) often DIE by bleed-out/scripted setDamage, where the "Killed" EH
// _killer = the victim (not the shooter) -> fn_onPlayerKilled's charge gate (_killer != _unit) skipped
// -> no Manslaughter on the killer. onPlayerKilled reads this to recover the real killer. Timestamped so
// a stale downer (downed -> revived -> later unrelated death) is ignored.
if (!isNull _source) then { player setVariable ["AP_downedBy", [_source, time]]; };
if (vehicle _source isKindOf "LandVehicle" && {driver(vehicle _source) isEqualTo _source}) then {_vehSource = true; [
        [0, format["%1 has been run over by %2.", [profileName] call AP_fnc_cleanName, [name _source] call AP_fnc_cleanName]], "AP_fnc_broadcast", -2, false, false] spawn AP_fnc_MP;
    if (alive _source && !(side _source isEqualTo west)) then {[[10, _source], "APS_fnc_wantedAdd", false, false] spawn AP_fnc_MP;};
} else {private _extra =
    switch (true) do {case ((side _source isEqualTo west) && (_source getVariable["AP_showrank", true])): {
                [west, _source] call AP_fnc_getRankString;};
        case (side _source isEqualTo civilian): {(group _source) getVariable["AP_grpTag", ""];};
        case (typeOf _source in ["B_G_Offroad_01_armed_F", "I_C_Offroad_02_LMG_F", "O_LSV_02_armed_F"] && {!isNull gunner _source
        } && side _source isEqualTo civilian): {(group(gunner _source)) getVariable["AP_grpTag", ""];};
        default {""};}; private _groupTag =
    switch (true) do {case (AP_effSide isEqualTo civilian && !((group player) getVariable["AP_grpTag", ""] isEqualTo "")): {
                (group player) getVariable "AP_grpTag"};
        case (AP_effSide isEqualTo west && player getVariable["AP_showrank", true]): {[west, player] call AP_fnc_getRankString};
        case (AP_effSide isEqualTo independent): {[independent, player] call AP_fnc_getRankString};
        default {""};}; if ((side _source isEqualTo civilian) && (AP_effSide isEqualTo west)) then {
        _sourceStatArr pushBack["civ_cops_downed", 1];};
    // LooneyBin: guard the quest/inv vars. For a civ victim whose AP_completedLifetimeQuests is nil or
    // not an array (e.g. a new player), `456 in <bad>` THREW here and aborted handleDowned before the
    // actual down -> civ took damage but never died or downed, while medics (side check short-circuits)
    // downed fine. Type/nil-check before using them.
    if ((AP_effSide isEqualTo civilian) && {AP_completedLifetimeQuests isEqualType []} && {456 in AP_completedLifetimeQuests} && {(round random 100) <= 5} && {!isNil "AP_inv_adrenalineShot" && {AP_inv_adrenalineShot >= 1}}) then {
        [] spawn {uiSleep 5;
            [false, "adrenalineShot", 1] call AP_fnc_handleInv;
            [] call AP_fnc_adrenalineShotEffect;};};
    if !(_shanked) then {if (isPlayer _source && !(_source isEqualTo player)) then {[[
                    [0], format["%1%2 was downed by %3%4.", _groupTag, profileName, _extra, name _source]
                ], "AP_fnc_broadcast", -2, false, false] spawn AP_fnc_MP;
            _RemoteStats pushBack[16, 1, false, [], [profileName, false, true]];
            private _isAtWar =
            if (!(_source getVariable["gang_data", []] isEqualTo[]) && !(group _source isEqualTo group player) && {
                (_source getVariable["gang_data", [-1]] select 0) in AP_gang_wars}); [
                ["-DOWNED-", player, (profileName), format["(%5) was downed by %1 (%2) (%6) with a %3, DIST: %4m. Shooter: %7, Target: %8, In War: %9", (name _source), (getPlayerUID _source), (getText(configFile >> "CfgWeapons" >> (currentWeapon(vehicle _source)) >> "DisplayName")), (floor(player distance _source)), (side player), (side _source), getPos _source, getPosATL player, _isAtWar]], "APS_fnc_logIt", 2, false, false] spawn AP_fnc_MP;
            [
                ["-DOWNED-", _source, (name _source), format["(%5) downed %1 (%2) (%6) with a %3, DIST: %4m. Shooter: %7, Target: %8, In War: %9", (profileName), (getPlayerUID player), (getText(configFile >> "CfgWeapons" >> (currentWeapon(vehicle _source)) >> "DisplayName")), (floor(player distance _source)), (side _source), (side player), getPos _source, getPosATL player, _isAtWar]], "APS_fnc_logIt", 2, false, false] spawn AP_fnc_MP;
        };} else {[
            ["-SHANKED-", _source, (name _source), format["(%1) shanked %2 (%3) (%4).", side _source, (profileName), (getPlayerUID player), AP_effSide]], "APS_fnc_logIt", 2, false, false] spawn AP_fnc_MP;
    };};
if !(_sourceStatArr isEqualTo[]) then {[["", -1, _sourceStatArr], "AP_fnc_statArrUpdate", _source] spawn AP_fnc_MP;};
if !(_RemoteStats isEqualTo[]) then {[[0, 0, false, _RemoteStats], "AP_fnc_updateRemoteStat", _source] spawn AP_fnc_MP;};
if !(isNull(player getVariable["AP_escortObj", objNull])) then {[] call AP_fnc_stopEscorting;};
// owner 2026-09-16: a downed dragger lets go of the body. Called BEFORE setUnconscious below, so the stop's
// "downed" reason is what keeps it from resetting (and mirroring) a standing pose onto a falling player.
if !(isNull (missionNamespace getVariable ["AP_dragging", objNull])) then {["downed"] call AP_fnc_dragBodyStop;};
if (player getVariable["AP_escorting", false]) then {private _escort = player getVariable["AP_escortee", objNull]; [
        [], "AP_fnc_stopEscorting", _escort, false, false] spawn AP_fnc_MP;};
if !(isNull objectParent player) then {private _vehicle = vehicle player;
    if (player isEqualTo(driver _vehicle)) then {if (_vehicle isKindOf "Helicopter") then {[
                [_vehicle], "APS_fnc_enableCoPilot", 2] spawn AP_fnc_MP;};};};
AP_isDowned = true;
AP_downStamp = time;   // LooneyBin: down-start timestamp -> lets the stale-flag self-heal (top of file) distinguish a real ongoing down from a wedged-true flag.
player setVariable["AP_downed", true, true];
player setVariable["AP_adrenaline", false, true];
player setUnconscious true;
disableUserInput true;
private _hndlBlur = ppEffectCreate["DynamicBlur", 501];
_hndlBlur ppEffectEnable true;
_hndlBlur ppEffectAdjust[5];
_hndlBlur ppEffectCommit 0;
private _hndlBlack = ppEffectCreate["colorCorrections", 1501];
_hndlBlack ppEffectEnable true;
_hndlBlack ppEffectAdjust[1.0, 1.0, 0.0, [0, 0, 0, 0.9], [1.0, 1.0, 1.0, 1.0], [1.0, 1.0, 1.0, 0.0]];
_hndlBlack ppEffectCommit 0;
private _effects = true;
private _eff1 = 5;
private _eff2 = 0.9;
private _time = 0;
private _dead = false;
private _downed = true;
while {_downed}
do {if (alive player) then {
        if ((_vehSource && _time isEqualTo 5) || (_time isEqualTo 60 && !(_vehSource)) || player getVariable["AP_adrenaline", false]) exitWith {
            _downed = false;
            player setVariable["AP_adrenaline", false]};} else {_downed = false;
        _dead = true;};
    if (_dead) exitWith {};
    _time = _time + 1;
    uiSleep 1;};
[ _hndlBlur , _hndlBlack, _eff1, _eff2, _effects] spawn {params["_hndlBlur", "_hndlBlack", "_eff1", "_eff2", "_effects"];
    while {_effects}
    do {_eff1 = _eff1 - 0.025;
        _eff2 = _eff2 - 0.0045;
        _hndlBlur ppEffectAdjust[_eff1];
        _hndlBlur ppEffectCommit 0;
        _hndlBlack ppEffectAdjust[1.0, 1.0, 0.0, [0, 0, 0, _eff2], [1.0, 1.0, 1.0, 1.0], [1.0, 1.0, 1.0, 0.0]];
        _hndlBlack ppEffectCommit 0;
        uiSleep 0.01;
        if (_eff2 <= 0) then {_effects = false;};}; ppEffectDestroy _hndlBlur;
    ppEffectDestroy _hndlBlack;};
player setUnconscious false;
disableUserInput false;
disableUserInput true;
disableUserInput false;
if (stance player isEqualTo "STAND") then {player playMoveNow "AidlPercMstpSnonWnonDnon_G01";} else {
    player playMoveNow "AmovPpneMstpSnonWnonDnon";};
AP_isDowned = false;
player setVariable["AP_downed", false, true];