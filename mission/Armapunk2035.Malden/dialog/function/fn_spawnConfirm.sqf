#include "..\..\macro.h"
params[["_redeploy", false, [true]]];
if (_redeploy && AP_serverId isEqualTo 1 && {scriptAvailable(300)}) exitWith {closeDialog 0;
    ["You can only redeploy once every 5 minutes!", "basic"] spawn AP_fnc_handleMessage;};
private _exit = false;
if (_redeploy) then {closeDialog 0;
    private _damage = damage player;
    private _startPos = getPos player;
    for "_i"
    from 1 to 15 step 1 do {if !(alive player) exitWith {_exit = true;};
        if !(isNull objectParent player) exitWith {_exit = true;
            ["Redeploy aborted.", "basic"] spawn AP_fnc_handleMessage;};
        if (damage player > _damage) exitWith {_exit = true;
            ["You took damage while attempting to deploy to a new loaction. Redeploy aborted.", "basic"] spawn AP_fnc_handleMessage;};
        if (player distance2D _startPos > 10) exitWith {_exit = true;
            ["You wandered off while attempting to deploy to a new location. Redeploy aborted.", "basic"] spawn AP_fnc_handleMessage;};
        titleText[format["Redeploying to %1 in %2 seconds...", AP_spawn_point select 1, 16 - _i], "PLAIN"];
        uiSleep 1;
        titleText["", "PLAIN"];
        AP_copEviReq = nil;};};
if (_exit) exitWith {closeDialog 0};
private _text =
if (_redeploy) then {"You have deployed to"} else {"You have spawned at"};
private _plb_pos = [0, 0, 0];
private _marker = AP_spawn_point param[0, ""];
// LooneyBin: short-circuit on (AP_radio_civ isEqualType 0). AP_radio_civ is "" (no numeric
// radio channel created on this server yet); radioChannelInfo needs a Number, so the bare call
// threw here and ABORTED spawnConfirm before the teleport -> "click Spawn, nothing happens".
if (AP_sidechat && (AP_effSide isEqualTo civilian) && !(player in ((radioChannelInfo AP_radio_civ) param [3, []]))) then {
	[AP_sidechat] call AP_fnc_manageSidechat;};
if (AP_spawn_point isEqualTo[]) then {private _spawnPoint = ([AP_effSide] call AP_fnc_spawnPointCfg) select 0;
    if (AP_effSide isEqualTo civilian) then {
        // owner 2026-06-18 (#347): this branch built _spawnPos but NEVER wrote it to _plb_pos -> _plb_pos stayed
        // [0,0,0] -> spawnConfirm errored (the [0,0,0] guard below) and the engine left the player at the default
        // respawn (water) at restart. Assign it. civ_spawn_N (fn_initCiv) = array of city buildings; pick one + a
        // building position, fall back to the building's getPos, and to the city marker if the array is empty.
        private _arr = missionNamespace getVariable _spawnPoint;
        if (_arr isEqualType [] && {count _arr > 0}) then {private _bld = selectRandom _arr;
            _plb_pos = _bld buildingPos 0;
            if (_plb_pos isEqualTo [0,0,0]) then { _plb_pos = getPosATL _bld; };} else {
            _plb_pos = getMarkerPos (_spawnPoint param [0, "civ_spawn_3"]);};} else {private _marker = _spawnPoint select 0;
        if (AP_effSide isEqualTo west) then {_marker = format["%1_%2", _marker, floor random 4]};
        _plb_pos = getMarkerPos _marker;};
    titleText[format["%2 %1", _spawnPoint select 1, _text], "BLACK IN"];} else {if (AP_effSide isEqualTo civilian) then {switch (true) do {
            case ("house" in _marker): {
                    // owner 2026-07-09: houseTypes-filtered + param (was a bare House_F select 0 -- script error on
                    // an empty result, and never matched sheds; a shed spawn resolved nothing/derelict).
                    private _mpos = getMarkerPos _marker;
                    // owner 2026-07-09 #2 (shed spawn race, SPAWNPROBE): if the marker is MISSING (login-time
                    // CLinitHouses raced the streaming intact shed and named it under the DB-id fallback), the
                    // menu-listed phouse_<OID> resolves [0,0,0]. Re-derive the position from the owned object
                    // itself: match the marker's id suffix against AP_houseID across AP_vehicles.
                    if (_mpos isEqualTo [0,0,0]) then {private _suffix = _marker select [7];   // strip "phouse_"
                        private _own = (AP_vehicles select { format ["%1", _x getVariable ["AP_houseID", ""]] isEqualTo _suffix }) param [0, objNull];
                        if (!isNull _own) then { _mpos = getPosATL _own; };};
                    private _hcands = nearestObjects[_mpos, ["House"], 18, true];
                    private _house = (_hcands select { (typeOf _x) in AP_houseTypes }) param [0, (_hcands param [0, objNull])];
                    private _buildingPos = [_house] call AP_fnc_getBuildingPositions;
                    if (_buildingPos isEqualTo[]) exitWith {_plb_pos = _mpos;};
                    _plb_pos = selectRandom _buildingPos;};
            // owner 2026-07-27: a town civ spawn is one of five designer-placed empty markers, picked at
            // random, at GROUND level. Previously this fell through to `default` and used the town marker
            // itself -- a single point, wherever CfgWorlds happens to put the town centre. Any scatter
            // marker that is missing is skipped, so a renamed or deleted one degrades to the remaining
            // ones instead of dropping a player at [0,0,0]; all five missing falls back to the town marker.
            // owner 2026-07-30: TABLE-DRIVEN. Adding a town is one row here plus one row in
            // fn_spawnPointCfg, not a second copy of this block. The scatter markers live in the map layer
            // (mission.sqm) per the standing rule, so the designer places them and nothing here hardcodes
            // a coordinate.
            case (_marker in ["civ_spawn_1", "civ_spawn_2", "civ_spawn_3", "civ_spawn_4", "civ_spawn_5"]): {
                    private _sets = createHashMapFromArray [
                        ["civ_spawn_1", ["lt_cspawn_1", "lt_cspawn_2", "lt_cspawn_3", "lt_cspawn_4", "lt_cspawn_5"]],
                        ["civ_spawn_2", ["lh_civspawn_1", "lh_civspawn_2", "lh_civspawn_3", "lh_civspawn_4", "lh_civspawn_5"]],
                        ["civ_spawn_3", ["lp_cspawn_1", "lp_cspawn_2", "lp_cspawn_3", "lp_cspawn_4", "lp_cspawn_5"]],
                        ["civ_spawn_4", ["ch_cspawn_1", "ch_cspawn_2", "ch_cspawn_3", "ch_cspawn_4", "ch_cspawn_5"]],
                        ["civ_spawn_5", ["ps_cspawn_1", "ps_cspawn_2", "ps_cspawn_3", "ps_cspawn_4", "ps_cspawn_5"]]
                    ];
                    private _cands = ((_sets getOrDefault [_marker, []])
                        select { (markerType _x) isNotEqualTo "" && {!((getMarkerPos _x) isEqualTo [0,0,0])} });
                    if (_cands isEqualTo []) then {
                        diag_log format ["[LB-SPAWN] scatter markers for %1 all missing -- falling back to the town marker", _marker];
                        _plb_pos = getMarkerPos _marker;
                    } else {
                        private _pick = getMarkerPos (selectRandom _cands);
                        _plb_pos = [_pick select 0, _pick select 1, 0];   // z 0 -> setPosATL puts them on the ground
                    };};
            case ("safezone" in _marker): {_plb_pos = [[[getMarkerPos _marker, 5]], []] call BIS_fnc_randomPos;};
            case ("gangbldg" in _marker): {
                    // owner 2026-06-18 (#343/345/347): resolve the gang-building spawn from the PERSISTED HQ pos
                    // (AP_gang_data param 3), NOT a marker -> works for any member even with the owner offline.
                    // Spawn inside the building if its positions are loaded, else at the HQ pos. A [0,0,0] (building
                    // unset between menu-open and confirm) falls through to the generic [0,0,0] guard below = a clean
                    // "try a different spawn", never the ocean.
                    private _gpos = AP_gang_data param [3, [0,0,0]];
                    private _ghc = nearestObjects [_gpos, ["House"], 18, true];
                    private _gh = (_ghc select { (typeOf _x) in AP_houseTypes }) param [0, (_ghc param [0, objNull])];   // owner 2026-07-09: shed-proof resolve (gang houses are often sheds)
                    private _bp = if (isNull _gh) then { [] } else { [_gh] call AP_fnc_getBuildingPositions };
                    _plb_pos = if (_bp isEqualTo []) then { _gpos } else { selectRandom _bp };};
            default {private _houses = missionNamespace getVariable _marker;
                if (isNil "_houses") then {if (_marker isEqualTo "gangboat_label" && {(!isNil "SRV_gangBoatShops")}) then {
                        _plb_pos = (SRV_gangBoatShops select 3);} else {_plb_pos = getMarkerPos _marker;};} else {
                    _plb_pos = getPosATL(selectRandom _houses);};};};} else {
        // owner 2026-07-31: the random _0.._3 suffix is the ALTIS scatter convention -- four
        // sub-markers per HQ so cops don't stack on one point. Malden's cop_spawn_N markers have no
        // suffixed variants, so the unconditional rename sent every cop to getMarkerPos [0,0,0] and
        // the ocean guard below turned ALL five brand-new spawn points into "try a different spawn
        // point". Use the scatter marker only when it actually exists; plain markers work as-is,
        // and adding cop_spawn_N_0..3 later re-enables scatter with no code change.
        if (AP_effSide isEqualTo west && !(_marker in ["armory_marker"]) && (AP_serverId isEqualTo 1)) then {
            private _plb_try = format["%1_%2", _marker, floor random 4];
            if !((getMarkerPos _plb_try) isEqualTo [0,0,0]) then { _marker = _plb_try; };};
        _plb_pos = getMarkerPos _marker;
        AP_eviSpawn = false;
        if (AP_spawn_point select 1 isEqualTo "Mobile HQ") then {_plb_pos = AP_spawn_point select 0};
        if (AP_effSide isEqualTo west && _marker isEqualTo "armory_marker" && AP_evidence_spawns < 2) then {for "_i" from 1 to 100 do {
                private _safePos = [getMarkerPos "armory_marker", 25, 195, 3, 0, 0.2, 0] call BIS_fnc_findSafePos;
                _safePos pushBack 0;
                if (_safePos inPolygon AP_eviFencePoly) exitWith {_plb_pos = _safePos};};};
        if (_marker isEqualTo "armory_marker" && AP_evidence_spawns < 2) then {private _loadouts = [[
                    ["arifle_MX_Black_F", "", "", "optic_Arco_blk_F", ["30Rnd_65x39_caseless_black_mag", 30], [], ""], [],
                    ["hgun_P07_F", "muzzle_snds_L", "", "", ["30Rnd_9x21_Mag", 26], [], ""], ["U_Rangemaster", [["SmokeShellBlue", 1, 1]]],
                    ["V_PlateCarrier1_blk", [["30Rnd_556x45_Stanag", 1, 30], ["30Rnd_9x21_Mag", 1, 30],
                        ["30Rnd_65x39_caseless_black_mag", 8, 30], ["SmokeShellBlue", 2, 1], ["MiniGrenade", 3, 1]]], ["B_Bergen_blk", [
                        ["ToolKit", 1], ["30Rnd_65x39_caseless_black_mag", 8, 30]]], "H_Cap_police", "", ["Binocular", "", "", "", [],
                        [], ""], ["ItemMap", "ItemGPS", "", "ItemCompass", "ItemWatch", "Integrated_NVG_F"]], [
                    ["arifle_MXM_Black_F", "", "", "optic_Arco_blk_F", ["30Rnd_65x39_caseless_black_mag", 30], [], ""], [],
                    ["hgun_P07_F", "muzzle_snds_L", "", "", ["30Rnd_9x21_Mag", 26], [], ""], ["U_Rangemaster", [["SmokeShellBlue", 1, 1]]],
                    ["V_PlateCarrier1_blk", [["30Rnd_556x45_Stanag", 1, 30], ["30Rnd_9x21_Mag", 1, 30],
                        ["30Rnd_65x39_caseless_black_mag", 8, 30], ["SmokeShellBlue", 2, 1], ["MiniGrenade", 3, 1]]], ["B_Bergen_blk", [
                        ["ToolKit", 1], ["30Rnd_65x39_caseless_black_mag", 8, 30]]], "H_Cap_police", "", ["Binocular", "", "", "", [],
                        [], ""], ["ItemMap", "ItemGPS", "", "ItemCompass", "ItemWatch", "Integrated_NVG_F"]], [
                    ["srifle_DMR_03_F", "", "", "optic_Arco_blk_F", ["20Rnd_762x51_Mag", 20], [], ""], [], [], ["U_Rangemaster", [
                        ["20Rnd_762x51_Mag", 3, 20], ["SmokeShellBlue", 1, 1]]], ["V_PlateCarrier1_blk", [["20Rnd_762x51_Mag", 11, 20],
                        ["SmokeShellBlue", 2, 1]]], ["B_FieldPack_blk", [["ToolKit", 1], ["20Rnd_762x51_Mag", 1, 20]
                    ]], "H_Cap_police", "", ["Binocular", "", "", "", [], [], ""],
                    ["ItemMap", "ItemGPS", "", "ItemCompass", "ItemWatch", "Integrated_NVG_F"]], [
                    ["arifle_SPAR_01_blk_F", "", "", "optic_Aco", ["30Rnd_556x45_Stanag", 30], [], ""], [],
                    ["hgun_P07_F", "muzzle_snds_L", "", "", ["30Rnd_9x21_Mag", 26], [], ""], ["U_Rangemaster", [["SmokeShellBlue", 1, 1]]],
                    ["V_TacVest_blk_POLICE", [["30Rnd_556x45_Stanag", 9, 30], ["MiniGrenade", 2, 1], ["1Rnd_SmokeBlue_Grenade_shell", 1, 1],
                        ["30Rnd_9x21_Mag", 1, 30]]], [], "H_Cap_police", "", ["Binocular", "", "", "", [], [], ""],
                    ["ItemMap", "ItemGPS", "", "ItemCompass", "ItemWatch", "Integrated_NVG_F"]]];
            AP_eviSpawn = true;
            AP_maxtacLoadout = getUnitLoadout player;
            player setUnitLoadout(_loadouts select floor random count _loadouts); [
                ["-COPEVIDENCE-", player, (profileName), "spawned at the evidence lockup."], "APS_fnc_logIt", 2] spawn AP_fnc_MP;
            AP_evidence_spawns = AP_evidence_spawns + 1;
            [] spawn {uiSleep 360;
                AP_evidence_spawns = 0;};};};
    titleText[format["%2 %1", AP_spawn_point select 1, _text], "BLACK IN"];};
if (_plb_pos isEqualTo[0, 0, 0]) exitWith {
    ["Error. Please wait a bit or try a different spawn point.", "basic"] spawn AP_fnc_handleMessage;};
// owner 2026-07-27: TELEPORT FIRST, THEN un-freeze -- that order is the whole point of the 50km hold, and
// setPos preserves velocity, so an un-zeroed arrival lands at terminal velocity and kills the player on spawn.
// Move -> zero (still frozen) -> simulate -> RE-ASSERT until the engine stops pulling them back -> clear flags.
// The contested window is AFTER the release, not before it: see the long note in fn_initCiv -- a setPos on a
// unit whose simulation is disabled never reaches the server, so re-enabling simulation re-syncs the unit from
// the 50km sqm slot ~40ms later and it falls from there.
// NOTE: this function runs UNSCHEDULED (see the loadGear comment below -- a `call` with a waitUntil in it threw
// "Suspending not allowed in this context" here), so the re-assert loop MUST be spawned; a uiSleep inline would
// abort the whole spawn. Simulation is enabled by that thread, not here, so the player stays frozen across the
// gap between this line and the thread's first frame.
player setPosATL _plb_pos;
player setVelocity [0, 0, 0];
AP_spawnSettling = true;               // stays true through the POST-release hold too, so the initPlayerLocal watchdog cannot act inside it
[_plb_pos] spawn {
    params ["_pos"];
    // PR10: move the NETWORKED copy first -- full rationale at the twin call in fn_initCiv. A frozen
    // setPos never leaves this machine, so the release's re-sync restores the 50 km slot (the measured
    // "1 re-applies"), latches the freefall animation, and shows everyone else a body dropping off the
    // slot. Pre-positioning the server copy while still frozen makes that re-sync a no-op; the short
    // sleep is one server frame + wire, and it is legal here because this whole block is spawned.
    [[player, _pos, false], "APS_fnc_preSpawnPos", 2] call AP_fnc_MP;
    uiSleep 0.3;
    player enableSimulation true;
    // Same breath, no tick in between: the re-sync arrives ~40ms after this, so re-assert NOW rather than
    // waiting for the hold loop's first sleep. setPos preserves velocity -- zero it every time.
    player setPosATL _pos;
    player setVelocity [0, 0, 0];
    // stand up -- see the note in fn_initCiv: arriving out of the 50km hold reads as a landing and
    // the engine puts the player prone. playAction, not setUnitPos, moves a player's stance.
    player playActionNow "PlayerStand";
    // Hold it against the re-sync: ~2s at 0.1s, exactly as fn_initCiv does. Any sample more than 2m off is a
    // yank -- re-apply AND zero velocity, because a re-apply mid-fall without zeroing leaves them falling.
    // Exit early after 5 consecutive clean samples (0.5s, an order of magnitude past the ~40ms the snap-back
    // took to arrive). ATL on both sides of the compare (the snap above is setPosATL); mixing ASL and ATL
    // would make the loop settle instantly or never. vectorDistance, not distance: `distance` re-reads array
    // coordinates as PositionAGL (BIKI), vectorDistance is raw Euclidean on the numbers we actually set.
    private _t0 = diag_tickTime;
    private _deadline = _t0 + 2;
    private _stable = 0;
    private _applies = 0;
    while {_stable < 5 && {diag_tickTime < _deadline}} do {
        uiSleep 0.1;                    // sleep FIRST: the clean samples must postdate the last re-apply
        if (((getPosATL player) vectorDistance _pos) > 2) then {
            player setPosATL _pos;
            player setVelocity [0, 0, 0];   // setPos preserves velocity -- zero it on EVERY re-apply
            _applies = _applies + 1;
            _stable = 0;
        } else {_stable = _stable + 1;};
    };
    // Stand them, DETERMINISTICALLY, now that the position has settled. playActionNow above goes through
    // the animation state machine, which was mid freefall->landing whenever the release yanked them -- it
    // ate the request and left the player prone for ~20s (client probe 2026-08-20: halofreefall at t+7,
    // prone t+10..t+29). switchMove snaps the state outright, the same idiom initPlayerLocal.sqf:26 uses
    // on this exact animation; after the settle loop nothing re-evaluates the stance behind our back.
    player switchMove "AmovPercMstpSnonWnonDnon";
    // THE number this fix turns on: on a spawn that previously ended in a 50km fall this must be >= 1.
    // `stable` at exit < 5 means it never settled inside the 2s -- read it with the offset.
    diag_log format ["[TPTRACE] spawnConfirm post-release hold %1s, %2 re-applies, stable=%3, final offset %4m, at %5",
        ((diag_tickTime - _t0) toFixed 2), _applies, _stable, (((getPosATL player) vectorDistance _pos) toFixed 2), getPosATL player];
    AP_spawnHold = false;
    AP_spawnSettling = false;
};
closeDialog 0;
"loadingScreen"
cutText["", "PLAIN"];
cutText["", "BLACK IN"];
if (AP_firstSpawn) then {AP_firstSpawn = false;};
[] call AP_fnc_hudUpdate;
if (AP_effSide isEqualTo civilian) then {if (AP_serverId isEqualTo 1) then {
        // owner 2026-06-19 ("softlog strips gear"): civLoadout = the DEATH loadout -- it strips weapons/vest, force-adds
        // a RANDOM civ uniform, WIPES the virtual inventory, and saveGear-persists that naked state. It was firing on
        // EVERY spawn-menu confirm, so a CONNECT/RELOG that lands on the spawn menu (saved position empty/blanked ->
        // not the teleport-back path) got stripped and the naked state overwrote the real kit in the DB. Gate it on
        // AP_respawned: ONLY an actual death-respawn (AP_respawned=true, set by fn_doRespawn before the menu) strips.
        // A relog (AP_respawned=false) RESTORES the loaded kit instead -- loadGear applies AP_gear (already loaded
        // by requestReceived) and self-falls-back to civLoadout only if AP_gear is genuinely empty.
        if (AP_respawned) then {[] call AP_fnc_civLoadout;} else {
            [] spawn AP_fnc_loadGear;   // owner 2026-06-19: SPAWN not call -- loadGear has a waitUntil (scriptDone stripDownPlayer); fn_spawnConfirm runs UNSCHEDULED so `call` threw "Suspending not allowed in this context" -> loadGear aborted after stripping = naked relog. spawn = scheduled context, waitUntil ok, kit restored. (civLoadout has no suspend, hence it was call-safe.)
        };};} else {if !(_redeploy) then {[uniform player, "setUniform", ""] call AP_fnc_clothingTextures;};};
if (!_redeploy && AP_effSide isEqualTo west && AP_activeMAXTAC && !(_marker isEqualTo "armory_marker")) then {AP_MAXTACActionAvail = false;
    player setUnitLoadout AP_maxtacLoadout;
    AP_activeMAXTAC = false;
    AP_maxtacLoadout = nil;}; [
    ["-RESPAWN-", player, (profileName), format["spawned at %1", getPosATL player]], "APS_fnc_logIt", 2] spawn AP_fnc_MP;