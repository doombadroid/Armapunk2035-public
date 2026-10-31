/*
    APS_fnc_eventBugInvasionSRV  (LooneyBin world event -- Ben Bones canon). AP_adminEvent type 9.
    A swarm of 100 rabbits ("the bugs, disguised") floods a town square. They hop/graze ambiently and scatter
    under fire; each pays out when shot. Bounded to 100 (no refill) so it can't print money or spiral on perf.
    Server-side; ambient agents + reward replicate normally. (Rabbit_F has no tintable selection + base Arma has
    no green/insect model, so they're plain rabbits.)
*/
if (!isServer) exitWith {};
params [["_locID", -1, [0]]];
if !([4, "eventBugInvasionSRV START"] call APS_fnc_isAdminCaller) exitWith {};   // admin-menu event (eventCfg owner-only row, client gate >= 4): the caller's DB adminlevel, never the payload
if (AP_adminEvent param [0, false]) exitWith {};

#define BUG_COUNT   100
#define BUG_REWARD  3000    // per kill. 100 rabbits -> $300k max if one player clears them all (owner: intended).

AP_adminEvent = [true, false, 9, _locID];
publicVariable "AP_adminEvent";
private _locData = (["getLocationByID", _locID] call AP_fnc_eventCfg);
private _locName = _locData param [1, "?"];
private _pos = _locData param [2, [0,0,0]];

deleteMarker "BugZone";
createMarker ["BugZone", _pos];
"BugZone" setMarkerShape "ELLIPSE"; "BugZone" setMarkerSize [300, 300]; "BugZone" setMarkerBrush "DiagGrid";
"BugZone" setMarkerColor "ColorBrown"; "BugZone" setMarkerAlpha 0.5; "BugZone" setMarkerText "BUG INVASION";
AP_bugZone = [_pos, 300]; publicVariable "AP_bugZone";

[[0, format ["BEN BONES: THE BUGS ARE HERE -- 100 of them, disguised as RABBITS, swarming %1. $%2 a bug!", _locName, BUG_REWARD]], "AP_fnc_broadcast", -2, false, false] spawn AP_fnc_MP;
["BUGS", format ["100-STRONG BUG SWARM HITS %1 -- THEY LOOK LIKE RABBITS. DO NOT BE FOOLED", _locName], format ["a HUNDRED bugs are swarming %1 wearing RABBIT skins. i TOLD you. shoot them for bounty, patriot.", _locName]] call APS_fnc_newsPush;

private _bugs = [];
private _fnSpawnBug = {params ["_pos", "_list"];
    private _sp = [_pos, 5, 150, 1, 0, 0.6, 0] call BIS_fnc_findSafePos;
    if (_sp isEqualTo [0,0,0] || {(_sp distance2D _pos) > 250}) then { _sp = _pos getPos [random 140, random 360]; };  // dense squares fail findSafePos -> never dump a bug in the ocean
    private _r = createAgent ["Rabbit_F", _sp, [], 0, "CAN_COLLIDE"];
    _r setVariable ["AP_bug", true, true];
    _r setVariable ["AP_bugReward", BUG_REWARD];
    _r addEventHandler ["Killed", {params ["_u", "_killer", "_instigator"];
        private _p = _instigator;
        if (isNull _p || {!isPlayer _p}) then { _p = _killer; };
        if (isNull _p || {!isPlayer _p}) then {                        // scripted/unclear death -> credit the nearest shooter
            private _best = 60;
            { if (isPlayer _x && {alive _x} && {(_x distance _u) < _best}) then { _best = _x distance _u; _p = _x; }; } forEach allPlayers;
        };
        if (!isNull _p && {isPlayer _p}) then {
            [[_u getVariable ["AP_bugReward", 3000]], "AP_fnc_casinoReceive", _p, false] spawn AP_fnc_MP;
            ["-BUGKILL-", _p, name _p, format ["killed a bug +$%1", _u getVariable ["AP_bugReward", 3000]]] call APS_fnc_logIt;};}];
    _list pushBack _r;
    _r};

// stagger the spawn (100 agents at once hitches the server), then run 10 min / until cleared. No refill -> bounded.
[_pos, _bugs, _fnSpawnBug, _locName] spawn {params ["_pos", "_bugs", "_fnSpawnBug", "_locName"];
    for "_i" from 1 to BUG_COUNT do {[_pos, _bugs] call _fnSpawnBug;
        if (_i mod 20 isEqualTo 0) then { uiSleep 0.4; };              // yield every 20 spawns
    };
    diag_log format ["[LooneyBin][bugs] invasion @ %1 (%2): %3 rabbits spawned", _locName, _pos, { alive _x } count _bugs];
    private _end = time + 600;
    waitUntil { uiSleep 10; (time > _end) || {!(AP_adminEvent param [0, false])} || {(AP_adminEvent param [2, 0]) isNotEqualTo 9} || {({ alive _x } count _bugs) isEqualTo 0} };
    { if (!isNull _x) then { deleteVehicle _x; } } forEach _bugs;
    deleteMarker "BugZone"; AP_bugZone = nil; publicVariable "AP_bugZone";
    if (AP_adminEvent param [0, false] && {(AP_adminEvent param [2, 0]) isEqualTo 9}) then {
        AP_adminEvent = [false, false, 0, 0]; publicVariable "AP_adminEvent";
        [[0, "The bug invasion is repelled. The globalists are FURIOUS. Collect your bounties."], "AP_fnc_broadcast", -2, false, false] spawn AP_fnc_MP;
    };};
