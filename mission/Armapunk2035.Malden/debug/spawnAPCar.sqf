/*
    debug/spawnAPCar.sqf  -- DEV ONLY. Spawn an autopilot-equipped Hatchback Sport on the nearest
    road, seat the player as driver, plot a GPS route and engage Tesla mode. For exercising the
    Malden road graph (core/gps/roadgraph_data.sqf) end to end.

    Usage, from the debug console:

        []                 execVM "debug\spawnAPCar.sqf";   // spawn + seat, then YOU pick the
                                                            // destination: ALT+Click the map (or
                                                            // press G on the map to search by name).
                                                            // Autopilot engages by itself once a
                                                            // route exists -- no coords to type.
        ["Chapoi"]         execVM "debug\spawnAPCar.sqf";   // or auto-plot: any Malden place name
        [[6012.5,8627.3]]  execVM "debug\spawnAPCar.sqf";   // or a raw [x,y]
        ["","madmax"]      execVM "debug\spawnAPCar.sqf";   // manual dest, mode sloth|normal|madmax

    Manual is the default because ALT+Click is the real player path (the MapSingleClick handler
    installed by initPlayerLocal.sqf:362 -> AP_fnc_gps "set"), so it exercises the same route code
    a player hits rather than a debug shortcut past it.

    Every precondition AP_fnc_gpsAutopilot's "start" case checks is set up here, because each one
    fails with only a small on-screen toast and they are easy to chase in the wrong order:
      * AP_autopilot on the vehicle   -- the $300 garage module (fn_prepareVehicle.sqf:26). Without
                                          it: "this vehicle has no autopilot module".
      * player is DRIVER of a LandVehicle.
      * a plotted route of >= 4 points in AP_gpsRoutePts -- otherwise "set a GPS destination first".
      * the car is ON a road (engaging snaps it to the rail, so an off-road engage would be a free
        teleport; the check is deliberate) -- hence spawning on nearRoads rather than under the player.
      * undamaged -- a fresh spawn is, but setDamage 0 is explicit in case it clips something.
*/
if (!hasInterface) exitWith {};
params [["_dest", ""], ["_mode", "normal", [""]]];

private _say = { [format ["<t color='#00d4ff'>[APDEBUG]</t> %1", _this], "basic"] spawn AP_fnc_handleMessage; };

// ---- resolve the destination ---------------------------------------------------------------------
// A name is looked up in the WORLD's own config rather than a hardcoded table, so it works for any
// Malden place and survives the designer moving things. Fragment + case-insensitive match, because
// the config spells the capital "La Trinité" with an accent.
private _manual = (_dest isEqualType "") && {_dest isEqualTo ""};
private _to = [];
if (!_manual && {_dest isEqualType []}) then { _to = _dest };
if (!_manual && {_dest isEqualType ""}) then {
    private _names = configFile >> "CfgWorlds" >> worldName >> "Names";
    for "_i" from 0 to ((count _names) - 1) do {
        private _e = _names select _i;
        if (isClass _e && {_to isEqualTo []}) then {
            private _nm = getText (_e >> "name");
            if (_nm != "" && {(toLower _nm) find (toLower _dest) > -1}) then { _to = getArray (_e >> "position"); };
        };
    };
};
if (!_manual && {_to isEqualTo []}) exitWith { format ["no place matching '%1' on %2", _dest, worldName] call _say; };

// ---- find a road to start from -------------------------------------------------------------------
private _roads = (getPosATL player) nearRoads 400;
if (_roads isEqualTo []) exitWith { "no road within 400m -- move closer to one" call _say; };
private _road = _roads select 0;
private _rp = getPosATL _road;

// Face along the road: aim at a connected segment so the car starts pointing down the lane rather
// than across it (the autopilot can recover from either, but a sideways start looks broken).
private _dir = 0;
private _conn = roadsConnectedTo _road;
if !(_conn isEqualTo []) then { _dir = _rp getDir (getPosATL (_conn select 0)); };

// ---- spawn + equip -------------------------------------------------------------------------------
if (!isNil "AP_apDebugCar" && {!isNull AP_apDebugCar}) then { deleteVehicle AP_apDebugCar; };
private _car = createVehicle ["C_Hatchback_01_sport_F", _rp, [], 0, "NONE"];
AP_apDebugCar = _car;
_car setDir _dir;
_car setPosATL _rp;
_car setVectorUp (surfaceNormal _rp);
_car setDamage 0;
_car setFuel 1;
clearItemCargoGlobal _car; clearWeaponCargoGlobal _car;
clearMagazineCargoGlobal _car; clearBackpackCargoGlobal _car;

// THE bit that makes it "autopilot equipped" -- published (3rd arg true) because the autopilot check
// runs on the driver's client while the variable may be set from elsewhere.
_car setVariable ["AP_autopilot", true, true];
_car setVariable ["AP_vehicle_color", 0, true];

player moveInDriver _car;
uiSleep 0.5;
if (driver _car isNotEqualTo player) exitWith { "could not seat the player as driver" call _say; };

// ---- manual mode: hand the destination back to the player ----------------------------------------
// ALT+Click on the map is the real routing path (MapSingleClick -> AP_fnc_gps "set", hooked at
// initPlayerLocal.sqf:362); G on the open map opens the name search. Poll for the route the player
// plots and engage the moment one exists, so there is nothing to type and nothing to re-run.
if (_manual) exitWith {
    "car ready. ALT+Click the map to set a destination (or press G on the map to search). Autopilot engages on its own." call _say;
    [_car, _mode] spawn {
        params ["_car", "_mode"];
        private _t0 = time;
        waitUntil { uiSleep 0.5;
            (count (missionNamespace getVariable ["AP_gpsRoutePts", []]) >= 4)
            || {isNull _car} || {!alive player} || {time - _t0 > 600} };
        if (isNull _car || {!alive player}) exitWith {};
        if ((count (missionNamespace getVariable ["AP_gpsRoutePts", []])) < 4) exitWith {
            ["<t color='#00d4ff'>[APDEBUG]</t> timed out waiting for a GPS destination.", "basic"] spawn AP_fnc_handleMessage;
        };
        if (driver _car isNotEqualTo player) exitWith {
            ["<t color='#00d4ff'>[APDEBUG]</t> route set, but you are not in the driver seat.", "basic"] spawn AP_fnc_handleMessage;
        };
        [format ["<t color='#00d4ff'>[APDEBUG]</t> route of %1 pts detected -- engaging %2.",
                 count (missionNamespace getVariable ["AP_gpsRoutePts", []]), toUpper _mode], "basic"] spawn AP_fnc_handleMessage;
        ["start", _mode] call AP_fnc_gpsAutopilot;
    };
};

// ---- plot the route ------------------------------------------------------------------------------
// Same call the GPS app makes (fn_gps.sqf:100). A* over the road graph; [] means no path, which on a
// fresh map usually means the destination is on a component the graph never joined to.
([getPosATL _car, _to] call AP_fnc_routeFind) params [["_pts", []], ["_len", 0]];
if (_pts isEqualTo []) exitWith {
    format ["no route from here to %1 -- disconnected road component?", _dest] call _say;
};
if (count _pts < 4) exitWith { "route too short to engage -- pick somewhere further" call _say; };
AP_gpsRoutePts = _pts;

format ["route: %1 pts, %2 km -> %3. Engaging %4.",
        count _pts, ((_len / 1000) toFixed 2), (if (_dest isEqualType "") then {_dest} else {str _to}), toUpper _mode] call _say;
diag_log format ["[APDEBUG] %1 pts, %2 m, from %3 to %4", count _pts, round _len, getPosATL _car, _to];

// ---- engage --------------------------------------------------------------------------------------
["start", _mode] call AP_fnc_gpsAutopilot;
