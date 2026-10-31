private _radius = 500;
// owner 2026-09-11: which spawn screen ran. fn_initCiv waits on display 38500 after calling this, and
// 38500 only ever belongs to the NATIVE menu -- so this flag is what keeps a web-path login from
// blocking on a display that will never appear. Set on line 1 so every exit path below leaves it
// defined, including the arrested and lucky-revive early exits.
AP_spawnMenuWeb = false;
if ((AP_is_arrested param [0,0]) isEqualTo 1) exitWith {[] spawn AP_fnc_respawned;};
private _exit = false;
// owner 2026-06-13: "Resilient Respawn" (lucky hospital revive) made SEMI-RARE -- was 1/8 (12.5%) gated on
// talent 50, but the talent system was removed so every god-stat player passed the gate -> it fired
// constantly. Now a flat ~5% roll for everyone (1 in 20), no dead talent gate.
if (AP_respawned) then {private _lucky = floor(random 20) isEqualTo 0;
    if (_lucky && isNil "AP_suicide") exitWith {
        private _action = ["You were lucky and TT medics saved your life, respawn at the nearest TT Hospital?", "Resilient Respawn", "Yes", "No"] call BIS_fnc_guiMessage;
        if (_action) exitWith {[player, true] spawn AP_fnc_revived;
            _exit = true;};};};
if (_exit) exitWith {};
if (AP_respawned) then {[] spawn AP_fnc_respawned;};
if (!isNull(findDisplay 17000)) then {closeDialog 0;};
disableSerialization;
"loadingScreen"
cutRsc["AP_loadingScreen", "PLAIN", -1, true];
AP_suicide = nil;
// owner 2026-07-19: hold connecting / dead / waiting players at map-center @ 50km with simulation OFF (so they
// don't fall) while they pick a spawn -- replaces them lingering on the northmost "debug" island proxy cluster.
// Simulation is restored at the real teleport in fn_spawnConfirm (+ initPlayerLocal failsafe loop).
// owner 2026-07-27: mark the hold EXPLICITLY. The failsafe used to infer it from "display 38500 is open",
// which is false for the ~20s of client init before this runs and false forever on the relog path -- so it
// un-froze players mid-hold and dropped them 50km. AP_spawnHold is cleared at the real teleport below.
AP_spawnHold = true;
AP_spawnHoldSince = diag_tickTime;
player setVelocity [0, 0, 0];   // a held player must arrive at the hold with no inherited fall speed
player setPosASL [worldSize / 2, worldSize / 2, 50000];
player enableSimulation false;
// owner 2026-09-11: the 3D spawn screen (ui\html\spawn.html, dialog 938700) gets first refusal. It
// BLOCKS until the player deployed, so a true return means this function has nothing left to do. A
// decline -- kill switch off, no webui library, the dialog failing -- or an Esc without deploying
// falls through to the native dialog below, byte for byte as it was. The hold above is already in
// place either way, which is deliberate: both screens are picked from the same frozen 50 km slot, so
// the web path cannot strand a player the native path would not have.
if ([false] call AP_fnc_spawnWebOpen) exitWith { AP_spawnMenuWeb = true; };
["AP_spawn_selection"] call AP_fnc_createDialog;
(findDisplay 38500) displaySetEventHandler["keyDown", "_this call AP_fnc_displayHandler"];
private _spCfg = [AP_effSide] call AP_fnc_spawnPointCfg; {private _markerName = (_spCfg select _forEachIndex) select 1;
    if (!("phouse_" in ((_spCfg select _forEachIndex) select 0))) then {
        _markerName = _markerName + format[" [%1]", count(allplayers select {
            (_x distance2d(getMarkerPos((_spCfg select _forEachIndex) select 0))) < _radius})];};
    lbAdd[38510, _markerName];}
forEach _spCfg;
[] spawn {private _display = findDisplay 38500;
    while {uiSleep 1;
        !(isNull _display)}
    do {private _disabledCount = count AP_disabled_spawns;
        private _spawnableTurfCount = {
            (_x getVariable["AP_turf_data", []] param[0, -1]) isEqualTo(AP_gang_data param[0, -2]) && !(_x getVariable["AP_turf_data", []] param[2, false])
        }
        count[panagia_flag, zaros_flag, rodo_flag];
        waitUntil {uiSleep 1;
            isNull _display || !(_disabledCount isEqualTo(count AP_disabled_spawns)) || !(_spawnableTurfCount isEqualTo({
                (_x getVariable["AP_turf_data", []] param[0, -1]) isEqualTo(AP_gang_data param[0, -2]) && !(_x getVariable["AP_turf_data", []] param[2, false])
            }
            count[panagia_flag, zaros_flag, rodo_flag]))};
        if (isNull _display) exitWith {};
        private _spCfg = [AP_effSide] call AP_fnc_spawnPointCfg;
        lbClear 38510; {lbAdd[38510, (_spCfg select _forEachIndex) select 1];}
        forEach _spCfg;};};
private _sp = _spCfg param[0, []];
[(findDisplay 38500) displayCtrl 38502, 1, 0.1, getMarkerPos(_sp param[0, ""])] call AP_fnc_setMapPosition;
AP_spawn_point = _sp;
