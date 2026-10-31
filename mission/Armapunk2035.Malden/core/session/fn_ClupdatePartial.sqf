#include "..\..\macro.h"
if !(AP_session_completed) exitWith {};
// owner 2026-06-21 (player108 money-wipe): mirror the spawn-select guard from fn_ClupdateRequest. case 0/1 below
// persist AP_cash/atmcash, so block ALL partial saves while the spawn-select menu (38500) is open (player
// not in-world -> money not live). This path is in-world-triggered today (ATM deposit/withdraw), but it carries
// the identical save-0-over-real-balance hole, so guard it too (defense-in-depth).
if (!isNull (findDisplay 38500)) exitWith {};
if (isFilePatchingEnabled) then {[[player, [1, round diag_tickTime]], "APS_fnc_dongClient", 2] call AP_fnc_MP;};
params[["_mode", 0, [0]]];
// PR9: NO POSITION SAVE WHILE THE PLAYER IS IN THE PRE-SPAWN HOLD. Twin of the spawn-select guard six
// lines up and for the same reason -- the player is not in the world. initPlayerLocal.sqf:8-19 freezes
// every session on its mission.sqm slot at 50 km until a real teleport clears AP_spawnHold, and case 10
// below has no idea: the slot is >1000 m from respawn_civilian and >1000 m from origin, so it passes
// every test and writes [5826.91, 6873.62, 50324.5] over the character's real last position. Nothing
// could reach case 10 inside that window before -- fn_initCiv's 240s civ loop is registered after the
// spawn and mode 10's other two callers (fn_eventGraveyardClient.sqf:128, fn_trialSystem.sqf:196) are
// in-world-triggered -- but the landing screen's MaxSec/Trauma deploy runs AP_fnc_dutyClient's civilian
// flush from inside the hold, and that flush is a mode 10.
// The 38500 guard above does not cover this: the landing is display 938100, and the relog-teleport branch
// opens no display at all.
if (_mode isEqualTo 10 && {missionNamespace getVariable ["AP_spawnHold", false]}) exitWith {
    diag_log "[LB-SPAWNHOLD] position save skipped: player is still held pre-spawn";
};
if (alive player && !isNil "AP_sidechat") then {[AP_sidechat] call AP_fnc_manageSidechat;};
if (AP_effSide isEqualTo west && _mode in [8, 10]) exitWith {};
if (AP_effSide isEqualTo independent && _mode in [10]) exitWith {};
if (AP_effSide isEqualTo civilian && _mode in []) exitWith {};
if (!isNil "AP_shop_cam" && {!isNull AP_shop_cam} && {_mode in [3]}) exitWith {};
private _packet = [player, AP_effSide, getPlayerUID player, _mode];
private _array = [];
private _sideFlag =
switch (AP_effSide) do {case west: {"cop"};
    case civilian: {"civ"};
    case independent: {"med"};}; private _exit = false;
private _hackDetected = false;
if (_mode isEqualTo 3) then {private _totalItemsActual = 0; {
        _totalItemsActual = _totalItemsActual + (missionNameSpace getVariable [_x, 0]);}
    forEach AP_invMonVars;
    if (_totalItemsActual > (AP_invMonitor - AP_invRVar) || _totalItemsActual >= 130) exitWith {_hackDetected = true;
        private _hackedItemArray = []; {if ((missionNameSpace getVariable [_x, 0]) > 0) then {
                _hackedItemArray pushBack[_x, (missionNameSpace getVariable [_x, 0])];};}
        forEach AP_invMonVars; [
            [player, [3, (AP_invMonitor - AP_invRVar), _totalItemsActual, str _hackedItemArray]], "APS_fnc_dongClient", 2] call AP_fnc_MP;
        [] spawn {uiSleep 2;
            diag_log "[LooneyBin] MemHackCash AC neutered (no kick)";};
        // BUGS.md #79/#80: same monitor -- was blocking the mode-3 gear save past 130 items. Log + resync, keep saving.
        AP_invMonitor = _totalItemsActual + AP_invRVar;
        _hackDetected = false;};};
if (_hackDetected) exitWith {};
switch (_mode) do {case 0: {if (AP_lastSyncedCash isEqualTo AP_cash) exitWith {_exit = true};
            _packet pushBack AP_cash;
            AP_lastSyncedCash = AP_cash;};
    case 1: {if (AP_lastSyncedBank isEqualTo AP_atmcash) exitWith {_exit = true};
            _packet pushBack AP_atmcash;
            [] call AP_fnc_achievementScan;
            AP_lastSyncedBank = AP_atmcash;};
    case 2: {{if (_x select 1 == _sideFlag) then {_array pushBack[_x select 0, (missionNamespace getVariable(_x select 0))];};}
            forEach AP_licenses;
            _packet pushBack _array;};
    case 3: {
            // LooneyBin: AP_clothing_store is initialised to "init" (initPlayerLocal) and only reset
            // to "" by the clothing shop -> this guard `!= ""` blocked EVERY gear save until you'd
            // opened+closed a clothing shop, so civ_gear never persisted. Treat "init" as "no shop".
            if !(AP_clothing_store in ["", "init"]) exitWith {_exit = true};
            if ((AP_is_arrested param [0,0]) isEqualTo 1) exitWith {_exit = true;};
            private _rwPos = getMarkerPos "respawn_west";  // LooneyBin: respawn_west absent -> [0,0,0];
            // only block near it when it actually exists (else it blocked all saves near map origin).
            // Armapunk 2035 (PR6 fix round 2): respawn_west now sits AT the MaxSec HQ terminal
            // (fn_dutyFlushBlock.sqf's header has the full trace) -- twin clause to fn_saveGear.sqf:7-8's,
            // same AP_dutyFlushBypass exemption, same scope (this clause only; AP_isDead stays a hard block).
            // Radius is SRV_baseNoSaveRadius (server_init.sqf, published; default 75 here as everywhere)
            // -- it was a hardcoded 1000, which drew the ring over the Fed and the Prison. Full trace in
            // fn_saveGear.sqf's clause; all three ring tests must read the same variable.
            private _nearRespawnWest = (_rwPos isNotEqualTo [0,0,0]) && {(player distance _rwPos) < (missionNamespace getVariable ["SRV_baseNoSaveRadius", 75])} && {!(missionNamespace getVariable ["AP_dutyFlushBypass", false])};
            if (AP_isDead || _nearRespawnWest) exitWith {_exit = true};
            if (AP_inEvent) exitWith {_exit = true};
            if (AP_lastSynced_gear isEqualTo(str AP_gear)) exitWith {_exit = true};
            if (AP_activeMAXTAC || AP_eviSpawn) exitWith {_exit = true};
            if (AP_isActiveFirefighter) exitWith {_exit = true};
            if ((missionNamespace getVariable ["AP_copRole", ""]) isEqualTo "scd") exitWith {_exit = true;
                [17] call AP_fnc_ClupdatePartial};
            AP_lastSynced_gear = str AP_gear;
            _packet pushBack AP_gear;};
    case 4: {_packet pushBack AP_side_talents;
            _packet pushBack AP_side_exp;};
    case 5: {_packet pushBack AP_is_arrested;};
    case 6: {_packet pushBack AP_cash;
            _packet pushBack AP_atmcash;
            [] call AP_fnc_achievementScan;};
    case 7: {_packet pushBack AP_achievements;};
    case 8: {_packet pushBack A_stats_crimes;};
    case 9: {
            _packet pushBack[A_stats_warKills, A_stats_warDeaths, A_stats_warRating, A_stats_copArrests, A_stats_civArrests, A_stats_warPoints, A_stats_apbEvades, A_stats_civKills, A_stats_civDeaths, A_stats_civRevives, A_stats_civExecutes, A_stats_civTime, A_stats_copLethals, A_stats_copDeaths, A_stats_copTime, A_stats_medTime, A_stats_medRevives];
        };
    case 10: {profileNamespace setVariable["AP_thirst", APV_thirst];
            profileNamespace setVariable["AP_hunger", APV_hunger];
            profileNamespace setVariable["AP_playerDir", getDir vehicle player];
            profileNamespace setVariable["AP_playerDamage", getDammage player];
            // PR10: the 1000m respawn_civilian ring is GONE -- same change and same measurement as the full
            // save (fn_ClupdateRequest.sqf's civilian case, see the PR10 note there): the marker sits mid-town
            // on Malden, so the ring wiped position to [] for anyone in the main town -> spawn menu on a relog
            // despite logging out alive. Not-in-world is the PR9 spawn-hold guard at :20, not geography.
            if (alive player && (player distance[0, 0, 0] > 1000)) then {
                private _noSyncZones = [["AP_bank_door", 55], ["AP_bank_door_2", 55], ["fed_reserve", 185], ["armory_marker", 220]];
                private _cartelSyncZones = [["arms_cartel", 200], ["drug_cartel", 200], ["oil_cartel", 200], ["wongs_cartel", 200]];
                if (_noSyncZones findIf {player distance(getMarkerPos(_x select 0)) < (_x select 1)}
                isEqualTo - 1) then {private _pos =
                    if (surfaceIsWater(getPosATL player)) then {getPosASL player} else {getPosATL player};
                    if (vehicle player isKindOf "Air") then {_pos set[2, 1]}; {_x params["_marker", "_maxDistance"];
                        if (player distance(getMarkerPos _marker) <= _maxDistance) exitWith {
                            _pos = [getMarkerPos _marker, 250, 300, 3, 0, 1, 0] call BIS_fnc_findSafePos;
                            _pos set[2, 1];};}
                    forEach _cartelSyncZones;
                    AP_ses_last_pos = _pos;} else {_exit = true;};} else {
                // dead -> persist the death sentinel [] (fn_onPlayerKilled set it; a dead relog must get the
                // menu, not restore alive at the death spot). Alive at origin (debug island) -> nothing to
                // say: skip the packet, the DB keeps the last real position.
                if (alive player) exitWith {_exit = true};
                AP_ses_last_pos = [];};
            _packet pushBack AP_ses_last_pos;};
    case 11:
        { _packet pushBack AP_gear; };   // LooneyBin #63: death-gear save. onPlayerKilled resets AP_gear to the side default then calls mode 11/12/13 -- these cases were EMPTY and the server had no matching cases -> the death save was a no-op end to end, so Alt-F4 after dying kept the old loadout in the DB (combat-log dupe). Push the (already-reset) gear; server cases 11/12/13 write it to <side>_gear.
    case 12:
        { _packet pushBack AP_gear; };
    case 13:
        { _packet pushBack AP_gear; };
    case 14: {_packet pushBack AP_honor_exp;
            _packet pushBack AP_honor_talents;};
    case 15: {_packet pushBack(player getVariable["AP_prefix", ""]);};
    case 16: {if (isNil "AP_prestige" || isNil "AP_cop_talents") exitWith {_exit = true};
            _packet pushBack AP_prestige;
            _packet pushBack AP_cop_talents;};
    // Armapunk 2035 (faction rework PR5): the "init" sentinel is accepted here too, matching case 3 (:47-50).
    // Mode 17 is where case 3 hands off an SCD officer's gear save, and this guard was the stricter
    // `isEqualTo ""` -- i.e. it rejected the exact value initPlayerLocal.sqf:59 assigns at login while the
    // guard that routed the save here accepted it. In practice that window is short (core/configuration.sqf
    // re-seeds AP_clothing_store to "" a second or so into core\init.sqf), so this is parity rather than a
    // measured loss -- but a hand-off between two guards that disagree is a trap, and mode 17 is the ONLY
    // route an SCD shift's kit has to cop_gear.
    case 17: {if !(AP_clothing_store in ["", "init"]) exitWith {_exit = true};
            if !((missionNamespace getVariable ["AP_copRole", ""]) isEqualTo "scd") exitWith {_exit = true};
            AP_lastSynced_gear = str AP_gear;
            _packet pushBack AP_gear;};
    case 18: {
            // LooneyBin 2026-07-23 NEW DRACHMA: the wallet is server-authoritative (APS_fnc_ndSRV).
            // The client no longer persists new_drachma -- the server ignores partial-18 anyway.
            _exit = true;};
    case 19: {_packet pushBack([3, ((player getVariable["AP_title", ["", "#B6B6B6"]]) param[0, ""])] call AP_fnc_titleCfg);};
    // case 20 (legacy quest lifetime-progress save) removed with the legacy quest system, task 11 --
    // it pushed AP_completedLifetimeQuests/AP_LifetimeProgressQuests, both retired. Mode 20 is no longer
    // sent by anything (see fn_initStats.sqf / fn_ClupdateRequest.sqf); server case 20 removed to match
    // (server/AP_server/core/DB/fn_updatePartial.sqf).
    case 21: {_packet pushBack AP_govClientData;};
    case 22: {_packet pushBack AP_infamy_exp;
            _packet pushBack AP_infamy_talents;};
    case 23: {if (isNil "AP_medic_exp" || isNil "AP_medic_talents") exitWith {_exit = true};
            _packet pushBack AP_medic_exp;
            _packet pushBack AP_medic_talents;};
    case 24: {
            _packet pushBack (if (AP_isFirefighter) then {1} else {0});   // LooneyBin: firefighter registration -> persist isfirefighter
        };}; if (_exit) exitWith {};
[_packet, "DB_fnc_updatePartial", false, false] call AP_fnc_MP;