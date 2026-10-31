/*
    APS_fnc_eventIceCreamSRV  (LooneyBin world event) -- THE ICE CREAM TRUCK OF DOOM.
    Admin event menu passes the chosen location position. A DRIVERLESS service van crawls a ROUTE of 4-6 road
    stops around that location, dixie-jingling ("dixiehorn") at each one. At every stop it pauses ~20s and DROPS
    a lootable supply crate for whoever's brave enough to crowd it -- because at each stop there's a ~15% chance
    the truck DETONATES (Bo_GBU12_LGB + setDamage 1), turning the sundae line into a crater. Risk vs. reward.
    HC autopilot physics-drives the driverless van when a headless client is online (AP_fnc_hcDrive); with no
    HC it falls back to a temporary captive AI driver + doMove. Marker on the truck, 25-min watchdog, no leaks.
*/
if (!isServer) exitWith {};
params [["_pos", [0,0,0], [[]]]];
if !([4, "eventIceCreamSRV START"] call APS_fnc_isAdminCaller) exitWith {};   // admin-menu event (eventCfg owner-only row, client gate >= 4): the caller's DB adminlevel, never the payload
if (_pos isEqualTo [0,0,0]) exitWith { diag_log "[LooneyBin][icecream] no location position -- aborted"; };

// ---- build a route of 4-6 ROAD stops scattered around the location ----
private _roads = _pos nearRoads 700;
if (count _roads < 6) then { _roads = _pos nearRoads 1500; };
private _nStops = 4 + floor (random 3);                 // 4, 5 or 6
private _stops = [];
if (count _roads >= _nStops) then {
    // spread picks so stops aren't all bunched on one street
    private _shuf = _roads call BIS_fnc_arrayShuffle;
    for "_i" from 0 to (_nStops - 1) do { _stops pushBack (getPosATL (_shuf select _i)); };} else {
    for "_i" from 0 to (_nStops - 1) do { _stops pushBack (_pos getPos [80 + random 240, random 360]); };};
private _spawn = _stops select 0;                        // start at the first stop

private _van = createVehicle ["C_Van_02_service_F", _spawn, [], 0, "NONE"];
_van setPosATL _spawn;
_van setVectorUp (surfaceNormal (getPosATL _van));
_van setFuel 1;
_van lock 2;
_van enableRopeAttach false;
_van setVariable ["owner", "event", true];              // fn_cleanup spare (ownerless = instant reap)
_van setVariable ["hc_ap_lock", true, true];            // hcDrive re-asserts the lock where the van is LOCAL

private _useHC = (localNamespace getVariable ["AP_hcOwner", 0]) > 0;
private _grp = grpNull;
if (!_useHC) then {_grp = createGroup [civilian, true];
    private _drv = _grp createUnit ["C_man_1", _spawn, [], 0, "NONE"];
    _drv moveInDriver _van;
    _drv setCaptive true; _drv allowDamage false;
    _grp setBehaviour "CARELESS"; _grp setSpeedMode "LIMITED"; _grp setCombatMode "BLUE";} else {
    _van setVariable ["hc_ap_mode", "sloth", true];     // ice cream trucks crawl
    _van setVariable ["hc_ap_arrive", 8, true];};
_van limitSpeed 45;

// ---- map marker that tracks the truck ----
private _mk = format ["AP_icecream_%1", floor serverTime];
createMarker [_mk, getPosATL _van];
_mk setMarkerType "mil_dot";
_mk setMarkerColor "ColorPink";
_mk setMarkerText "Ice Cream Truck";
[_van, _mk] spawn {params ["_van", "_mk"];
    while { !isNull _van && {alive _van} && {!(_van getVariable ["AP_icDone", false])} } do {_mk setMarkerPos (getPosATL _van);
        uiSleep 3;};
    deleteMarker _mk;};

[[0, "An ICE CREAM TRUCK is doing the rounds. Free crates at every stop... word is the freezer's been acting up though. Stand near it at your own risk."], "AP_fnc_broadcast", -2, false, false] spawn AP_fnc_MP;
["-ICECREAM-", objNull, "SERVER", format ["truck spawned, %1 stops around %2 (HC=%3)", _nStops, _pos, _useHC]] call APS_fnc_logIt;

[_van, _grp, _mk, _stops, _useHC] spawn {params ["_van", "_grp", "_mk", "_stops", "_useHC"];
    private _crates = [];
    private _hardEnd = time + 1500;                      // 25-min absolute watchdog
    private _exploded = false;

    // shared cleanup -- deletes truck, driver, marker, and any crates still standing
    private _fnCleanup = {if (!isNull _van) then { _van setVariable ["AP_icDone", true, true]; };
        deleteMarker _mk;
        { if (!isNull _x) then { deleteVehicle _x }; } forEach _crates;
        if (!isNull _van) then { { deleteVehicle _x } forEach (crew _van); deleteVehicle _van; };
        if (!isNull _grp) then { deleteGroup _grp; };};
 {private _dest = _x;
        if (isNull _van || {!alive _van} || {time > _hardEnd}) exitWith {};

        // ---- DRIVE LEG to this stop ----
        if (_useHC && {(localNamespace getVariable ["AP_hcOwner", 0]) > 0}) then {_van setVariable ["hc_ap_dest", _dest, true];
            _van setVariable ["hc_ap_done", "", true];
            _van setVariable ["hc_ap_want", true, true];
            _van setOwner (localNamespace getVariable ["AP_hcOwner", 0]);} else {if (!isNull (driver _van)) then { (driver _van) doMove _dest; };};
        private _legEnd = time + 300;                    // 5-min ceiling per leg
        waitUntil {uiSleep 2;
            if (!_useHC && {!isNull _van} && {alive _van} && {!isNull (driver _van)} && {(_van distance2D _dest) > 12}) then { (driver _van) doMove _dest; };
            (isNull _van) || {!alive _van}
                || {(_van distance2D _dest) < 12}
                || {(_van getVariable ["hc_ap_done", ""]) isNotEqualTo ""}
                || {time > _legEnd}};
        if (isNull _van || {!alive _van}) exitWith {};

        // ---- AT THE STOP: jingle ----
        _van say3D "dixiehorn";

        // ---- RANDOM DETONATION (~15%) ----
        if (random 1 < 0.15) then {_exploded = true;
            private _bp = getPosATL _van;
            "Bo_GBU12_LGB" createVehicle (_bp vectorAdd [0, 0, 2]);
            _van setDamage 1;
            [[0, "The ice cream truck's freezer just went up like a bomb. Because it was one. Hope the sprinkles were worth it."], "AP_fnc_broadcast", -2, false, false] spawn AP_fnc_MP;
            ["-ICECREAM-", objNull, "SERVER", format ["DETONATED at %1", _bp]] call APS_fnc_logIt;};

        if (_exploded) exitWith {};   // truck's gone -- stop the route

        // ---- pause ~20s, then drop a lootable crate ----
        uiSleep 20;
        if (isNull _van || {!alive _van}) exitWith {};
        private _cp = getPosATL _van;
        private _crate = createVehicle ["B_supplyCrate_F", [_cp select 0, _cp select 1, 0], [], 2.5, "CAN_COLLIDE"];
        _crate setPosATL [(getPosATL _crate) select 0, (getPosATL _crate) select 1, 0.1];
        _crate setVectorUp [0, 0, 1];
        _crate setVariable ["owner", "event", true];     // fn_cleanup spare
        clearWeaponCargoGlobal _crate; clearItemCargoGlobal _crate; clearMagazineCargoGlobal _crate; clearBackpackCargoGlobal _crate;
        { _crate addItemCargoGlobal _x; } forEach (selectRandom [[["FirstAidKit", 6], ["Chemlight_green", 4]],
            [["FirstAidKit", 4], ["optic_Holosight", 2]], [["FirstAidKit", 8]],
            [["optic_Arco", 1], ["FirstAidKit", 5], ["muzzle_snds_H", 1]]]);
        { _crate addMagazineCargoGlobal _x; } forEach [["SmokeShell", 3], ["HandGrenade", 1]];
        _crates pushBack _crate;
        [[0, "The ice cream truck popped its hatch -- a crate's up for grabs at the truck."], "AP_fnc_broadcast", -2, false, false] spawn AP_fnc_MP;
        ["-ICECREAM-", objNull, "SERVER", format ["dropped crate at %1", _cp]] call APS_fnc_logIt;} forEach _stops;

    // route finished (or blew up): let looters pick over the last crates, then sweep everything
    if (!_exploded && {!isNull _van} && {alive _van}) then {
        [[0, "The ice cream truck's route is done. It rolls off into the sunset, freezer intact. This time."], "AP_fnc_broadcast", -2, false, false] spawn AP_fnc_MP;
    };
    // hold crates open a while for looting, but never past the 25-min watchdog
    private _hold = (time + 300) min _hardEnd;
    waitUntil { uiSleep 5; time > _hold };
    call _fnCleanup;
    ["-ICECREAM-", objNull, "SERVER", "event resolved -- cleaned up"] call APS_fnc_logIt;};
