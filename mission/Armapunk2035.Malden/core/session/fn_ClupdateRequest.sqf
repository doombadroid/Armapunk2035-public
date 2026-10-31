if !(AP_session_completed) exitWith {};
// owner 2026-06-21 (player108 money-wipe): bail if the player is at the SPAWN-SELECT screen (display 38500). The
// restart force-flush (init.sqf force-ClupdateRequest, BOTH the scheduled-restart and gracefulsave paths)
// broadcasts to ALL clients -- including one parked at spawn-select whose AP_session_completed is stale-TRUE
// from a prior session while AP_cash/atmcash have reset to 0. The money packet below is gated ONLY by
// session_completed, NOT by in-world state, so it saved cash/bank 0 over the real balance (player108: 547k -> 0;
// isolated -- only he was at spawn-select during the restart). At spawn-select the player is not in-world --
// money/pos/gear aren't live -> never persist from here. (isNull findDisplay 38500 = the established in-world
// idiom, see initPlayerLocal.sqf:395.)
if (!isNull (findDisplay 38500)) exitWith {};
// owner 2026-06-21 (Vista money-wipe): NEVER build the save packet with uninitialised money. AP_session_completed
// goes stale-TRUE across sessions, so at reconnect this can run before the session sets AP_cash/AP_atmcash ->
// the packet shipped [..,any,any], the server defaulted nil->0 and wrote bankacc=0 over the real balance (Vista
// 423k -> 0). Bail until the money vars are real numbers (session actually loaded). Server-side DB_fnc_updateRequest
// has the same guard as the authoritative backstop.
if (isNil "AP_cash" || {isNil "AP_atmcash"} || {!(AP_cash isEqualType 0)} || {!(AP_atmcash isEqualType 0)}) exitWith {};
if (isFilePatchingEnabled) then {[[player, [1, round diag_tickTime]], "APS_fnc_dongClient", 2] call AP_fnc_MP;};
private _totalItemsActual = 0; {_totalItemsActual = _totalItemsActual + (missionNameSpace getVariable [_x, 0]);}
forEach AP_invMonVars;
// BUGS.md #79/#80: was `exitWith` -- the item-count monitor ABORTED the whole periodic save (gear,
// cash, talents, position all stopped persisting) once a player passed 130 items. Log + resync, keep saving.
if (_totalItemsActual > (AP_invMonitor - AP_invRVar) || _totalItemsActual >= 130) then {private _hackedItemArray = []; {
        if ((missionNameSpace getVariable [_x, 0]) > 0) then {_hackedItemArray pushBack[_x, (missionNameSpace getVariable [_x, 0])];};}
    forEach AP_invMonVars; [
        [player, [3, (AP_invMonitor - AP_invRVar), _totalItemsActual, str _hackedItemArray]], "APS_fnc_dongClient", 2] call AP_fnc_MP;
    [] spawn {uiSleep 2;
        diag_log "[LooneyBin] MemHackCash AC neutered (no kick)";};
    AP_invMonitor = _totalItemsActual + AP_invRVar;};
private _packet = [player, profileName, AP_effSide, AP_cash, AP_atmcash];
_packet pushBack AP_side_talents;
_packet pushBack AP_side_exp;
// Same base ring as fn_saveGear.sqf / fn_ClupdatePartial.sqf's case 3, written the other way round
// (save only when OUTSIDE it). Radius is SRV_baseNoSaveRadius, published by server_init.sqf, default 75;
// it was a hardcoded 1000, which reached over the Fed and the Prison -- see fn_saveGear.sqf's clause.
if (((AP_is_arrested param [0,0]) isEqualTo 0) && (player distance(getMarkerPos "respawn_west") > (missionNamespace getVariable ["SRV_baseNoSaveRadius", 75]))) then {
    [false] call AP_fnc_saveGear;
    if ((AP_lastSynced_gear != str(AP_gear)) && (AP_clothing_store isEqualTo "")) then {[3] call AP_fnc_ClupdatePartial;};};
if (AP_useStatBuffer) then {
    // singleevh.md Phase 3a: durable stat buffer's event flush (double-buffered; same wire format + server RMW).
    call AP_fnc_flushStats;} else {if (APV_tempStats findIf {_x > 0}
isNotEqualTo - 1) then {APV_savedStats = APV_tempStats;
    private _updateArray = []; {if (_x isNotEqualTo 0) then {_updateArray pushBack[_forEachIndex, _x];};}
    forEach APV_savedStats; [[getPlayerUID player, _updateArray], "APS_fnc_statTableUpdate", 2] spawn AP_fnc_MP;
    APV_tempStats = +APV_defaultStats;
    APV_savedStats = +APV_defaultStats;};};
switch (AP_effSide) do {case civilian: {profileNamespace setVariable["AP_thirst", APV_thirst];
            profileNamespace setVariable["AP_hunger", APV_hunger];
            profileNamespace setVariable["AP_playerDir", getDir vehicle player];
            profileNamespace setVariable["AP_playerDamage", getDammage player];
            // PR9 F-2: twin of fn_ClupdatePartial.sqf:20's spawn-hold guard, for the identical reason -- this
            // civilian-case write is the SECOND mode-10-class AP_ses_last_pos writer, gated only by the same
            // distance-from-respawn_civilian/origin tests the 50 km pre-spawn slot passes. The scheduled-restart
            // and gracefulsave broadcasts (server init.sqf:447/:1287 -> AP_fnc_ClupdateRequest, target -2, i.e.
            // every online client) reach a player idling on the landing screen -- still AP_session_completed,
            // still civilian, still held on the 50 km slot -- and would persist [5826.91, 6873.62, 50324.5] over
            // their real last position. UNLIKE the mode-10 case, this function must NOT early-exit: the
            // money/talents/exp halves of the packet above still have to reach the DB on a restart flush. So
            // only the position write is skipped -- AP_ses_last_pos is left exactly as it already was (loaded at
            // login, or last written by a real save), not reset to [] either ([] itself means "no teleport on
            // restore", which would be its own kind of data loss here).
            if (!(missionNamespace getVariable ["AP_spawnHold", false])) then {
            // PR10: the 1500m respawn_civilian ring is GONE. It was Altis logic -- there the marker sat on a
            // remote pre-spawn holding spot, so "inside the ring" meant "not really in the world". On Malden
            // the marker sits mid-town at [7263.75, 7931.26], ~80m from the civ spawns and the garage, so the
            // ring covered the main town and every save inside it wiped position to [] -> spawn menu on the
            // next login despite logging out alive (measured 2026-08-20: UPDATE players SET position='[]' from
            // [7278, 7854], then spawnDecide branch=MENU ses_last_pos=[]). Not-in-world is explicit state now
            // (AP_spawnHold guard above, 38500 guard at the top), not geography. [] has exactly ONE meaning
            // left: the death sentinel from fn_onPlayerKilled -- persisted below so a dead relog still gets
            // the menu instead of restoring alive at the death spot (combat-log guard).
            if (alive player && (player distance[0, 0, 0] > 1000)) then {
                private _noSyncZones = [["AP_bank_door", 55], ["fed_reserve", 185], ["armory_marker", 220]];
                if (!(alive player) || (({(player distance(getMarkerPos(_x select 0))) <= (_x select 1)}
                count _noSyncZones) isEqualTo 0)) then {private _pos = getPosATL player;
                    if (vehicle player isKindOf "Air") then {_pos set[2, 1];};
                    private _randomSyncZone = [["arms_cartel", 200], ["drug_cartel", 200], ["oil_cartel", 200], ["wongs_cartel", 200],
                        ["AP_mentalHospital", 200]]; {_x params["_marker", "_distance"];
                        if ((player distance(getMarkerPos _marker)) <= (_distance)) exitWith {
                            _pos = [getMarkerPos _marker, 250, 300, 3, 0, 1, 0] call BIS_fnc_findSafePos;
                            _pos set[2, 1];};}
                    forEach _randomSyncZone;
                    _pos =
                    if (surfaceIsWater _pos) then {getPosASL player} else {_pos};
                    AP_ses_last_pos = _pos;};} else {
                if (!alive player) then {AP_ses_last_pos = [];};   // dead -> persist the death sentinel; at-origin (debug island) -> keep the last real value
            };
            };
            _packet pushBack AP_ses_last_pos;};}; if (AP_lastUpdateRequest == format["%1", _packet]) exitWith {};
AP_lastUpdateRequest = format["%1", _packet];
[_packet, "DB_fnc_updateRequest", false, false] spawn AP_fnc_MP;