/*
    APS_fnc_eventSmugglerBoatSRV  (LooneyBin world event, owner 2026-07-17) -- SMUGGLER SPEEDBOAT RUN (loop rework).
    A civilian boat (C_Boat_Civil_01_F) with an AI smuggler at the wheel patrols the owner's hand-drawn CONTRABAND
    LOOP through the central-south bay (boatLoop from APS_fnc_eventRoutes) -- round and round until intercepted.
    Players intercept by sea or air: DISABLE the boat (kill its engine) or DESTROY it and the contraband spills
    into a lootable crate at the boat's final spot -- first crew there takes the goods. Run past the 25-min hard
    cap = the smuggler got away with the cargo.

    Signature: params [["_pos", [0,0,0], [[]]]];   // admin menu passes a location; the LOOP geometry is fixed, so
    _pos only decides which loop waypoint the boat starts nearest (flavour) -- the route itself is always the loop.

    Map icon: a live b_naval (ship) marker follows the boat every 3s (the "constantly updating icon" the owner asked
    for). HC: the AI-driver GROUP is offloaded to the headless client (setGroupOwner (localNamespace getVariable ["AP_hcOwner", 0])) -- boats never use
    hcDrive (ground-only). No HC online -> the group stays server-owned (AI still drives on the game server).
*/
if (!isServer) exitWith {};
params [["_pos", [0,0,0], [[]]]];
if !([4, "eventSmugglerBoatSRV START"] call APS_fnc_isAdminCaller) exitWith {};   // admin-menu event (eventCfg owner-only row, client gate >= 4): the caller's DB adminlevel, never the payload

// ---- water-snap helper: nearest surfaceIsWater point around _c (outward rings) ----
private _fnWater = {params ["_c", ["_min", 0], ["_max", 600]];
    if (surfaceIsWater _c) exitWith { [_c select 0, _c select 1, 0] };
    private _found = [];
    for "_r" from (_min max 40) to _max step 60 do {for "_a" from 0 to 330 step 30 do {
            private _t = [(_c select 0) + _r * sin _a, (_c select 1) + _r * cos _a, 0];
            if (surfaceIsWater _t) exitWith { _found = _t; };};
        if !(_found isEqualTo []) exitWith {};};
    _found};

// ---- the drawn contraband loop, each waypoint snapped onto water (the loop clips land near Sidewinder) ----
(call APS_fnc_eventRoutes) params ["", "", "_boatLoop"];
private _loop = []; {private _w = [[_x select 0, _x select 1, 0]] call _fnWater;
    if !(_w isEqualTo []) then { _loop pushBack _w };} forEach _boatLoop;
// the drawn loop closes on itself (first point repeated at the end) -- drop the duplicate so the CYCLE waypoint
// doesn't add a zero-length hop / doubled waypoint at the seam.
if (count _loop > 2 && {(_loop select 0) distance2D (_loop select (count _loop - 1)) < 30}) then {_loop deleteAt (count _loop - 1);};
if (count _loop < 3) exitWith {["-SMUGGLERBOAT-", objNull, "SERVER", "boat loop failed to resolve to water -- aborted"] call APS_fnc_logIt;
};

// start the boat at whichever loop waypoint is closest to the chosen location (flavour), rotate loop to start there
private _startIdx = 0; private _bd = 1e12;
{ private _d = _x distance2D _pos; if (_d < _bd) then { _bd = _d; _startIdx = _forEachIndex; }; } forEach _loop;
_loop = (_loop select [_startIdx]) + (_loop select [0, _startIdx]);   // rotate so _startIdx is first
private _spawn = _loop select 0;

// ---- the boat + AI smuggler (captive civ so cops don't auto-aggro; players still may) ----
private _boat = createVehicle ["C_Boat_Civil_01_F", _spawn, [], 0, "NONE"];
_boat setPosASL [_spawn select 0, _spawn select 1, 0.4];
_boat setFuel 1;
_boat setVariable ["owner", "event", true];           // fn_cleanup spare (ownerless = instant reap)
_boat setVariable ["AP_smugglerBoat", true, true];

private _grp = createGroup [civilian, true];
private _drv = _grp createUnit ["C_man_1", _spawn, [], 0, "NONE"];
_drv moveInDriver _boat;
_drv setCaptive true;
_grp setBehaviour "CARELESS"; _grp setCombatMode "BLUE"; _grp setSpeedMode "FULL";
// patrol the loop: a MOVE waypoint per point, then a CYCLE so the AI runs it round and round
{private _wp = _grp addWaypoint [_x, 20];
    _wp setWaypointType "MOVE";
    _wp setWaypointSpeed "FULL";
    _wp setWaypointBehaviour "CARELESS";} forEach _loop;
private _wpCyc = _grp addWaypoint [_loop select 0, 20];
_wpCyc setWaypointType "CYCLE";

// HC OFFLOAD: hand the driver group to the headless client (guarded). hcDrive is ground-only -> not used.
if ((localNamespace getVariable ["AP_hcOwner", 0]) > 0 && {!isNull _drv} && {(driver _boat) isEqualTo _drv}) then {_grp setGroupOwner (localNamespace getVariable ["AP_hcOwner", 0]);};

// contraband cargo table (recreated into a crate on disable/kill so it's never lost with the boat)
private _cargo = selectRandom [[[["arifle_Katiba_F", 3]], [["30Rnd_65x39_caseless_green", 12]], [["FirstAidKit", 6], ["optic_Arco", 2]]],
    [[["arifle_MX_Black_F", 2], ["srifle_EBR_F", 1]], [["30Rnd_65x39_caseless_mag", 10], ["20Rnd_762x51_Mag", 8]], [["optic_Holosight", 2], ["FirstAidKit", 6]]],
    [[["LMG_Mk200_F", 1], ["arifle_AKM_F", 2]], [["200Rnd_65x39_cased_Box", 3], ["30Rnd_762x39_Mag_F", 12]], [["FirstAidKit", 8]]]];

// ---- live map marker following the boat ----
private _mk = createMarker [format ["smugboat_%1", floor serverTime], _spawn];
_mk setMarkerType "b_naval"; _mk setMarkerColor "ColorBlue"; _mk setMarkerText "Smuggler Speedboat";   // b_naval = valid ship icon ("mil_destroyer" is NOT a CfgMarkers type -> engine throws)

[[0, "Coast Guard intercept: a SMUGGLER SPEEDBOAT is running CONTRABAND through the bay. It's marked on the map -- sink it, disable it, or board it and the goods are yours."], "AP_fnc_broadcast", -2, false, false] spawn AP_fnc_MP;
["-SMUGGLERBOAT-", objNull, "SERVER", format ["loop run started, spawn %1 (%2 waypoints)", _spawn, count _loop]] call APS_fnc_logIt;

// ---- watchdog: track, resolve on disable / destroy / timeout, then clean up (no leaks) ----
[_boat, _drv, _grp, _mk, _cargo] spawn {params ["_boat", "_drv", "_grp", "_mk", "_cargo"];
    private _end = time + 1500;                        // 25-min hard backstop = got away
    private _outcome = "";
    while { _outcome isEqualTo "" } do {uiSleep 3;
        if (!isNull _boat) then { _mk setMarkerPos (getPosATL _boat); };
        if (isNull _boat || {!alive _boat}) then { _outcome = "destroyed"; }
        else {
            // disabled = engine shot out, OR (defensive: some boat classes don't expose "HitEngine") immobilised / near-dead
            if (((_boat getHitPointDamage "HitEngine") >= 0.85) || {!canMove _boat} || {(damage _boat) >= 0.9}) then { _outcome = "disabled"; }
            else { if (time > _end) then { _outcome = "timeout"; }; };};};

    private _cratePos = if (isNull _boat) then { getMarkerPos _mk } else { getPosATL _boat };
    ["-SMUGGLERBOAT-", objNull, "SERVER", format ["run resolved: %1 at %2", _outcome, _cratePos]] call APS_fnc_logIt;

    switch (_outcome) do {case "disabled";
        case "destroyed": {
            // spill the contraband into a lootable crate at the boat's final spot
            private _bp = [_cratePos select 0, _cratePos select 1, 0];
            private _crate = createVehicle ["B_supplyCrate_F", _bp, [], 0, "CAN_COLLIDE"];
            _crate setPosASL [(getPosASL _crate) select 0, (getPosASL _crate) select 1, ((getPosASL _crate) select 2) + 0.2];
            _crate setVariable ["owner", "event", true];
            clearWeaponCargoGlobal _crate; clearItemCargoGlobal _crate; clearMagazineCargoGlobal _crate; clearBackpackCargoGlobal _crate;
            _cargo params ["_wpns", "_mags", "_items"];
            { _crate addWeaponCargoGlobal _x; } forEach _wpns;
            { _crate addMagazineCargoGlobal _x; } forEach _mags;
            { _crate addItemCargoGlobal _x; } forEach _items;
            private _smoke = "SmokeShellRed" createVehicle (getPosATL _crate);
            _mk setMarkerType "mil_box"; _mk setMarkerColor "ColorRed"; _mk setMarkerText "Contraband (adrift)"; _mk setMarkerPos (getPosATL _crate);
            [[0, "The smuggler's been stopped -- CONTRABAND is adrift and marked on the map. Grab it before someone else does."], "AP_fnc_broadcast", -2, false, false] spawn AP_fnc_MP;
            if (!isNull _drv) then { deleteVehicle _drv; };
            if (!isNull _boat) then { deleteVehicle _boat; };
            // reaper: despawn when emptied (nobody near), or after a 15-min loot window
            private _lootEnd = time + 900;
            waitUntil {uiSleep 8;
                private _empty = (weaponCargo _crate isEqualTo []) && {magazineCargo _crate isEqualTo []} && {itemCargo _crate isEqualTo []} && {backpackCargo _crate isEqualTo []};
                private _clear = ((call AP_fnc_realPlayers) findIf { alive _x && {(_x distance _crate) < 25} }) < 0;
                (isNull _crate) || {time > _lootEnd} || {_empty && _clear}};
            if (!isNull _crate) then { deleteVehicle _crate; };
            if (!isNull _smoke) then { deleteVehicle _smoke; };};
        default {   // "timeout" -- the smuggler completed enough laps and slipped out with the cargo
            [[0, "The smuggler slipped out of the bay with the contraband. Better luck next run."], "AP_fnc_broadcast", -2, false, false] spawn AP_fnc_MP;
            if (!isNull _boat) then {
                _boat spawn { params ["_b"]; uiSleep 30; if (!isNull _b) then { { deleteVehicle _x } forEach (crew _b); deleteVehicle _b; }; };
            };
            if (!isNull _drv) then { deleteVehicle _drv; };};};

    if (!isNull _grp) then { { deleteVehicle _x } forEach (units _grp); deleteGroup _grp; };
    deleteMarker _mk;};
