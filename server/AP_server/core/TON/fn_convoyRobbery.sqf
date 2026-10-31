/*
    APS_fnc_convoyRobbery  (LooneyBin -- implemented from stub 2026-06-09)
    Altis Shipping convoy robbery, START. Client (core/actions/fn_startConvoyRobbery.sqf, dock-worker
    NPC via npcs/fn_civConvoy in mapData) validated cooldown/cops/federal-event + took the bribe, then
    sends [_level] (0/1/2 = low/med/high value).
    Server: spawn the shipment truck + AI driver at marker AP_convoy_start, drive it along roads to a
    far destination; robbers stop it, steal the truck (AP_convoyTransport) and deliver it to a fence NPC
    (fn_civConvoy delivery actions -> APS_fnc_endConvoyRobbery). Escort comes from MaxSec (4/6/9 cops
    required client-side) -- the driver is a captive civilian agent so AI sides stay neutral.
    SRV_convoy_status = [active, lastAttack, level, copsExtra]  (init.sqf)
*/
params [["_level", 0, [0]]];
diag_log format ["[LooneyBin][convoy] called: level=%1 status=%2", _level, SRV_convoy_status];
if !(_level in [0, 1, 2]) exitWith { diag_log "[LooneyBin][convoy] reject: bad level"; };
if (SRV_convoy_status param [0, false]) exitWith { diag_log "[LooneyBin][convoy] reject: already active"; };

private _start = getMarkerPos "AP_convoy_start";
if (_start isEqualTo [0,0,0]) exitWith { diag_log "[LooneyBin][convoy] reject: marker AP_convoy_start missing"; };
// owner 2026-06-16 (#302): server-authoritative one-federal-event-at-a-time gate (client check has a window).
if (["convoy"] call APS_fnc_fedEventActive) exitWith { diag_log "[LooneyBin][convoy] reject: another federal event active (#302 server gate)"; };
// owner 2026-07-24 SECURITY (audit): the police requirement (4/6/9 by level), the 30-minute cooldown and
// the bribe were ALL enforced only in fn_startConvoyRobbery on the client, and this fn is CfgRE
// allowedTargets=2 -- so a client could remoteExec [2] to launch the highest-value convoy on demand, with
// no cops online, no cooldown and no bribe paid, then fence it via APS_fnc_endConvoyRobbery. Mirror the
// two server-checkable gates here, using the same tenuredCops + AP_betaZeroCops idiom every other heist
// uses (fn_fedAlarm:20, fn_bankDrillVault:30, fn_jewelryEmporiumSRV:29). The bribe stays client-side --
// it debits the client's own cash, which is the pre-existing money trust boundary, not a new hole.
private _reqCops = [4, 6, 9] param [_level, 4];
if ((([] call AP_fnc_tenuredCops) < _reqCops) && {!(localNamespace getVariable ["AP_betaZeroCops", false])}) exitWith {
    diag_log format ["[LooneyBin][convoy] reject: needs %1 tenured cops", _reqCops];
    ["-SEC-", objNull, format ["BLOCKED convoy start lvl %1 (needs %2 cops)", _level, _reqCops]] call APS_fnc_logIt;};
if ((SRV_convoy_status param [1, -9999]) > serverTime - 1800) exitWith {
    diag_log "[LooneyBin][convoy] reject: 30-minute cooldown still active";
    ["-SEC-", objNull, format ["BLOCKED convoy start lvl %1 (cooldown)", _level]] call APS_fnc_logIt;};
// owner 2026-07-28 SECURITY (audit): SERVER-AUTHORITATIVE cross-heist "security is high" lockout. The
// write below arms SRV_lastRobbery, but the only thing that ever READ it was the client -- six sites
// across five heists, this heist's own being fn_startConvoyRobbery:12 -- so the whole lockout was
// honour-system and a modified client launched a convoy inside another heist's window at will. Interval
// copied verbatim from those readers, (60 * 15) = 900s, so the client gate and this one cannot drift.
// PLACEMENT: below every guard above and ABOVE the SRV_convoy_status stamp on the next line, NOT beside
// the arming write further down. Between the two the event is already marked active and published, and
// the watchdog that clears it is not spawned until the bottom of the file: a refusal after that point
// would leave slot 0 true with no truck and nothing to reset it, locking the convoy out until a restart
// or !srv resetfed. This guard writes nothing and refuses before any state is touched.
// FRESH BOOT is never blocked -- vars.sqf:66 seeds SRV_lastRobbery = -99999, so the test needs serverTime
// below -99099 to fire; serverTime starts at 0 and only climbs. The first heist of a session always runs.
// diag_log + a -SEC- row against objNull, matching the two guards above. objNull deliberately: an honest
// client that had not yet received the publicVariable of SRV_lastRobbery can pass its own gate and land
// here, so naming a player would feed the auto-ban table a false positive for a plain network race.
if (SRV_lastRobbery > (serverTime - (60 * 15))) exitWith {
    diag_log "[LooneyBin][convoy] reject: 15-minute cross-heist security lockout still active";
    ["-SEC-", objNull, format ["BLOCKED convoy start lvl %1 (cross-heist lockout)", _level]] call APS_fnc_logIt;};

SRV_convoy_status set [0, true];
SRV_convoy_status set [1, serverTime];
SRV_convoy_status set [2, _level];
publicVariable "SRV_convoy_status";
// owner 2026-07-28: ARM the 15-minute cross-heist "security is high" lockout. Six client read sites
// across five heists refuse to start while SRV_lastRobbery sits inside the window -- this heist's own
// caller (fn_startConvoyRobbery:12) is one of them -- but fn_bankDrillVault was the only writer in the
// tree, so a convoy locked nothing out. Armed at the START, alongside the state stamp above it, and
// BELOW every guard in this file: a refused start must never arm a server-wide lockout, which would be
// a denial of service any client could trigger by spamming a call it knows will be rejected.
// publicVariable is mandatory -- every reader is client-side.
SRV_lastRobbery = serverTime;
publicVariable "SRV_lastRobbery";

// owner 2026-06-30 (#556): the previous hard-coded coastal coords + sea-level setPosASL spawned the truck on the
// HARBOUR WATER -> it floated, took water damage and exploded. Snap to the nearest ROAD object to the Altis
// Shipping dock marker (_start, on land) and seat the truck with setPosATL (terrain-relative -> it sits ON the
// road, never at sea level). A road position is always dry land, so no descent / allowDamage dance is needed.
private _roadObjs = nearestTerrainObjects [_start, ["MAIN ROAD", "ROAD", "TRACK"], 150, true, true];
private _roadPos = if (_roadObjs isEqualTo []) then { _start } else { getPosATL (_roadObjs select 0) };
private _truck = createVehicle ["C_Truck_02_covered_F", _roadPos, [], 0, "CAN_COLLIDE"];
_truck setVectorUp [0, 0, 1];
_truck setPosATL [_roadPos select 0, _roadPos select 1, 0.3];   // ATL = above TERRAIN -> on the road, never water
_truck setVelocity [0, 0, 0];
_truck setVariable ["AP_convoyTransport", true, true];
_truck setVariable ["AP_convoyLevel", _level, true];
_truck setVariable ["owner", "convoy", true];      // cleanup-sweep spare
_truck lock 0;
private _grp = createGroup [civilian, true];
private _drv = _grp createUnit ["C_man_w_worker_F", _roadPos, [], 0, "CAN_COLLIDE"];
_drv assignAsDriver _truck;
_drv moveInDriver _truck;
_drv setCaptive true;                              // neutral AI -- the defenders are the COPS
_drv disableAI "TARGET"; _drv disableAI "AUTOTARGET";
_drv setSkill 0.2;
// BUGS.md #93: when the seat grab failed (blocked/flooded truck) the AI jogged after his MOVE
// waypoint and boarded the CARGO bay instead -- "random npc gets into the back". Verify the seat;
// one forced retry, then despawn the walker (event continues, truck just sits at the spawn).
[_drv, _truck] spawn {params ["_drv", "_truck"];
    uiSleep 3;
    if (isNull _drv || {isNull _truck}) exitWith {};
    if !((driver _truck) isEqualTo _drv) then {moveOut _drv;
        uiSleep 0.5;
        _drv moveInDriver _truck;
        uiSleep 2;
        if !((driver _truck) isEqualTo _drv) then {diag_log "[LooneyBin][convoy] driver could not seat -- removing AI";
            deleteVehicle _drv;};};};
// destination: the far side of the island, by road
private _dest = if ((_roadPos select 1) > 15000) then { [14000, 8500, 0] } else { [20000, 21000, 0] };
private _wp = _grp addWaypoint [_dest, 50];
_wp setWaypointType "MOVE";
_wp setWaypointSpeed "LIMITED";
_truck setVariable ["AP_convoyDriver", _drv, true];

// owner 2026-07-17: HC OFFLOAD -- hand the convoy driver's group to the headless client so its AI drive sim
// runs on the HC, not the game server. Delayed past the seat-retry window (+3s) so the server-local
// moveInDriver/moveOut retries land first; only after the driver is confirmed seated. The truck stays UNLOCKED,
// so a robber hijacking it just displaces the AI as normal (no autopilot fight). No HC online -> stays server-owned.
[_grp, _drv, _truck] spawn {params ["_grp", "_drv", "_truck"];
    uiSleep 6;
    if ((localNamespace getVariable ["AP_hcOwner", 0]) > 0 && {!isNull _drv} && {!isNull _truck} && {(driver _truck) isEqualTo _drv}) then {
        _grp setGroupOwner (localNamespace getVariable ["AP_hcOwner", 0]);};};

private _mk = createMarker [format ["convoy_%1", floor serverTime], _roadPos];
_mk setMarkerType "mil_warning"; _mk setMarkerColor "ColorOrange"; _mk setMarkerText "Altis Shipping Convoy";
[_truck, _mk] spawn {params ["_truck", "_mk"];
    while { (SRV_convoy_status param [0, false]) && {!isNull _truck} && {alive _truck} } do {_mk setMarkerPos (getPosATL _truck);
        uiSleep 10;};
    deleteMarker _mk;};
// watchdog: destroyed truck or 45-min timeout resets the event
[_truck] spawn {params ["_truck"];
    private _endAt = serverTime + 2700;
    waitUntil { uiSleep 5; isNull _truck || {!alive _truck} || {serverTime > _endAt} || {!(SRV_convoy_status param [0, false])} };
    if (SRV_convoy_status param [0, false]) then {SRV_convoy_status set [0, false];
        publicVariable "SRV_convoy_status";
        if (isNull _truck || {!alive _truck}) then {
            [[0, "The stolen Altis Shipping cargo was destroyed -- the shipment is lost!"], "AP_fnc_broadcast", -2, false, false] spawn AP_fnc_MP;
        };
        private _d = _truck getVariable ["AP_convoyDriver", objNull];
        if (!isNull _d) then { deleteVehicle _d; };
        if (!isNull _truck) then { deleteVehicle _truck; };};};
[[0, "Altis Shipping reports an armed robbery on one of their convoys! MaxSec must protect the shipment!"], "AP_fnc_broadcast", -2, false, false] spawn AP_fnc_MP;
[["A shipping convoy is being robbed -- escort/recover the marked truck!", "copalert"], "AP_fnc_handleMessage", west, false, false] spawn AP_fnc_MP;
diag_log format ["[LooneyBin][convoy] level %1 started at %2", _level, _roadPos];
