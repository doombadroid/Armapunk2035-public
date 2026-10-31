/*
    APS_fnc_eventSupplyBomberSRV  (LooneyBin world event, owner 2026-07-17) -- SUPPLY BOMBER (route rework).

    A high-altitude cargo plane flies ONE of the owner's two hand-drawn supply routes (WEST = routeA, EAST =
    routeB from APS_fnc_eventRoutes) and drops ONE sealed supply crate at a random point ALONG that route.
    The crate hits the ground LOCKED (lockInventory + empty) and a 10-minute timer runs -- during which the
    drop site is a REDZONE (public red map circle, PvP hotspot). When the timer expires the crate UNLOCKS:
    it fills with rebel/supply loot and anyone can open it. Ben Bones texts every online player when it drops.
    The PLANE itself carries NO map marker (only the crate/redzone is marked). Fires hourly on the scheduler
    and on-demand from the admin event menu; both let this SRV self-select the route.

    Signature: params [["_routeIn", [], [[]]]];   // pass a route ([[x,y],...]) to force it, or [] to self-pick.
    HC offload: the pilot GROUP is handed to the headless client when one is online (planes = setGroupOwner,
    never hcDrive). No HC -> the AI pilot flies server-side. Everything is swept on resolution -- no leaks.
*/
if (!isServer) exitWith {};
params [["_routeIn", [], [[]]]];
if !([4, "eventSupplyBomberSRV START"] call APS_fnc_isAdminCaller) exitWith {};   // admin-menu event (eventCfg owner-only row, client gate >= 4; the hourly scheduler call is server-internal): the caller's DB adminlevel, never the payload

// --- resolve the route (self-select WEST/EAST unless a concrete route was passed) ---
private _route = _routeIn;
private _side = "";
if (_route isEqualTo [] || {!((_route select 0) isEqualType [])}) then {(call APS_fnc_eventRoutes) params ["_routeA", "_routeB"];
    if (selectRandom [true, false]) then { _route = _routeA; _side = "WEST"; } else { _route = _routeB; _side = "EAST"; };} else {
    // caller forced a route -- label it by matching against the known pair
    (call APS_fnc_eventRoutes) params ["_routeA", "_routeB"];
    _side = if (_route isEqualTo _routeB) then { "EAST" } else { "WEST" };};
if (count _route < 2) exitWith {};

// normalise waypoints to [x,y,0]
private _wps = _route apply { [_x select 0, _x select 1, 0] };

// --- pick the drop point: a random point somewhere along the route (segment + lerp) ---
private _segN = (count _wps) - 1;
private _si = floor (random _segN);
private _t = 0.15 + random 0.7;                       // keep it off the very ends
private _pA = _wps select _si;
private _pB = _wps select (_si + 1);
private _dropPos = [(_pA select 0) + ((_pB select 0) - (_pA select 0)) * _t, (_pA select 1) + ((_pB select 1) - (_pA select 1)) * _t, 0];
// nudge the crate onto the nearest safe ground (avoid water/cliff) but keep it near the route
private _safe = [_dropPos, 0, 120, 3, 0, 0.5, 0] call BIS_fnc_findSafePos;
if (count _safe >= 2) then { _dropPos = [_safe select 0, _safe select 1, 0]; };

["-SUPPLYBOMB-", objNull, "SERVER", format ["supply bomber run on %1 route, drop @ %2", _side, _dropPos]] call APS_fnc_logIt;

// loot tables (rebel/supply tier -- filled at UNLOCK). Each entry = [ [weapons], [mags], [items] ] of [class,count] pairs.
private _lootTables = [
    [[["arifle_MX_Black_F", 2], ["arifle_Katiba_F", 2]], [["30Rnd_65x39_caseless_green", 12], ["30Rnd_65x39_caseless_mag", 12]], [["FirstAidKit", 8], ["optic_Holosight", 3]]],
    [[["LMG_Mk200_F", 1], ["srifle_EBR_F", 2]], [["200Rnd_65x39_cased_Box", 3], ["20Rnd_762x51_Mag", 12]], [["FirstAidKit", 8], ["optic_Arco", 3]]],
    [[["arifle_AKM_F", 3]], [["30Rnd_762x39_Mag_F", 16]], [["FirstAidKit", 10], ["optic_ACO_grn", 3]]],
    [[["hgun_Pistol_heavy_01_F", 3], ["arifle_Katiba_C_F", 2]], [["11Rnd_45ACP_Mag", 10], ["30Rnd_65x39_caseless_green", 10]], [["FirstAidKit", 8], ["Chemlight_green", 8]]]
];

// =========================== the plane run (no marker) ===========================
[_wps, _dropPos, _side, _lootTables] spawn {params ["_wps", "_dropPos", "_side", "_lootTables"];

    private _first = _wps select 0;
    private _second = _wps select 1;
    private _hdg = ((_second select 0) - (_first select 0)) atan2 ((_second select 1) - (_first select 1));
    // spawn 3500m behind the first waypoint, on-heading, at altitude
    private _startPt = [(_first select 0) - (sin _hdg) * 3500, (_first select 1) - (cos _hdg) * 3500, 320];
    private _plane = createVehicle ["B_T_VTOL_01_vehicle_F", _startPt, [], 0, "FLY"];
    _plane setPosATL _startPt;
    _plane setDir _hdg;
    _plane setVelocityModelSpace [0, 130, 0];
    createVehicleCrew _plane;
    _plane flyInHeight 200;
    _plane setVariable ["owner", "event", true];      // fn_cleanup spare (NO map marker on the plane, per owner)
    private _grp = group (driver _plane);
    _grp setBehaviour "CARELESS";
    _grp setCombatMode "BLUE";
    _grp setSpeedMode "FULL";
    // fly the drawn route: a MOVE waypoint per point, then an exit leg past the end
    {private _wp = _grp addWaypoint [_x, 0];
        _wp setWaypointType "MOVE";
        _wp setWaypointSpeed "FULL";
        _wp setWaypointBehaviour "CARELESS";} forEach _wps;
    private _last = _wps select (count _wps - 1);
    private _prev = _wps select (count _wps - 2);
    private _exitHdg = ((_last select 0) - (_prev select 0)) atan2 ((_last select 1) - (_prev select 1));
    private _exitPt = [(_last select 0) + (sin _exitHdg) * 4000, (_last select 1) + (cos _exitHdg) * 4000, 320];
    private _wpE = _grp addWaypoint [_exitPt, 0]; _wpE setWaypointType "MOVE"; _wpE setWaypointSpeed "FULL";
    // HC OFFLOAD: planes = setGroupOwner only (never hcDrive). No-op when no HC online.
    if ((localNamespace getVariable ["AP_hcOwner", 0]) > 0) then { _grp setGroupOwner (localNamespace getVariable ["AP_hcOwner", 0]); };

    // wait until the plane reaches the drop point (or a hard timeout), then release ONE crate
    private _dropTimeout = time + 240;
    waitUntil {uiSleep 1;
        (isNull _plane) || {!alive _plane} || {(_plane distance2D _dropPos) < 300} || {time > _dropTimeout}};

    if (!isNull _plane && {alive _plane}) then {private _dx = _dropPos select 0; private _dy = _dropPos select 1;
        // proven drop physics: FULL-form createVehicle + setPosATL both pieces, land-check on the CHUTE
        private _chute = createVehicle ["B_Parachute_02_F", [_dx, _dy, 180], [], 0, "CAN_COLLIDE"];
        _chute setPosATL [_dx, _dy, 180];
        private _crate = createVehicle ["B_supplyCrate_F", [_dx, _dy, 178], [], 0, "CAN_COLLIDE"];
        _crate setPosATL [_dx, _dy, 178];
        _crate enableRopeAttach false;
        _crate attachTo [_chute, [0, 0, -1.1]];
        _crate setVariable ["owner", "event", true];   // survive fn_cleanup
        // sealed on arrival: empty + locked. Fills + unlocks after 10 min.
        clearWeaponCargoGlobal _crate; clearItemCargoGlobal _crate; clearMagazineCargoGlobal _crate; clearBackpackCargoGlobal _crate;
        _crate lockInventory true;

        // markers: a REDZONE circle + a locked-icon (the crate is marked; the plane is NOT)
        private _uid = str (floor serverTime);
        private _mkZ = format ["AP_supplyzone_%1", _uid];
        private _mkI = format ["AP_supplyicon_%1", _uid];
        createMarker [_mkZ, [_dx, _dy, 0]];
        _mkZ setMarkerShape "ELLIPSE"; _mkZ setMarkerBrush "Border"; _mkZ setMarkerSize [200, 200]; _mkZ setMarkerColor "ColorRed";
        createMarker [_mkI, [_dx, _dy, 0]];
        _mkI setMarkerType "mil_warning"; _mkI setMarkerColor "ColorRed"; _mkI setMarkerText "SUPPLY DROP -- SEALED 10:00";

        // land the crate: ground it when the chute settles, pop green smoke
        private _smokeRef = objNull;
        [_chute, _crate, _mkZ, _mkI] spawn {params ["_chute", "_crate", "_mkZ", "_mkI"];
            private _bail = time + 120;
            waitUntil { uiSleep 1; isNull _chute || {isNull _crate} || {((getPosATL _chute) select 2) < 3} || {time > _bail} };
            if (isNull _crate) exitWith { if (!isNull _chute) then { deleteVehicle _chute; }; };
            detach _crate;
            private _gp = getPosATL _crate;
            _crate setPosATL [_gp select 0, _gp select 1, 0.1];
            _crate setVectorUp [0, 0, 1];
            if (!isNull _chute) then { deleteVehicle _chute; };
            _mkZ setMarkerPos (getPosATL _crate); _mkI setMarkerPos (getPosATL _crate);
            _crate setVariable ["AP_smoke", ("SmokeShellRed" createVehicle (getPosATL _crate))];};

        // ---- ANNOUNCE the drop: all-player broadcast + Ben Bones text to everyone online ----
        private _sideWord = if (_side == "WEST") then { "west" } else { "east" };
        [[1, format ["SUPPLY BOMBER DROP -- a SEALED crate just landed on the %1 supply run. It's a REDZONE and it cracks open in 10 minutes. Marked on your map. Fight for it.", _sideWord]], "AP_fnc_broadcast", -2, false, false] spawn AP_fnc_MP;
        private _bones = format ["Yo. Just watched a supply bird dump a SEALED crate out on the %1 run. Locked tight -- cracks open in 10 min, and it's a redzone til then. It's pinged on your map. Don't be last there. -Bones", _sideWord];
        [[_bones], "AP_fnc_bonesText", -2, false, false] spawn AP_fnc_MP;
        ["-SUPPLYBOMB-", objNull, "SERVER", format ["crate SEALED @ %1 (%2 route) -- redzone up, 10min lock", _dropPos, _side]] call APS_fnc_logIt;

        // ---- 10-minute LOCK: coarse countdown, then UNLOCK (fill + open) ----
        [_crate, _mkI, _mkZ, _lootTables] spawn {params ["_crate", "_mkI", "_mkZ", "_lootTables"];
            for "_min" from 9 to 1 step -1 do {uiSleep 60;
                if (isNull _crate) exitWith {};
                _mkI setMarkerText format ["SUPPLY DROP -- SEALED %1:00", _min];};
            uiSleep 60;
            if (isNull _crate) exitWith {};
            // UNLOCK: fill with loot, open the inventory, flip the markers green
            private _roll = selectRandom _lootTables;
            { _crate addWeaponCargoGlobal _x; }   forEach (_roll select 0);
            { _crate addMagazineCargoGlobal _x; } forEach (_roll select 1);
            { _crate addItemCargoGlobal _x; }     forEach (_roll select 2);
            _crate lockInventory false;
            _mkI setMarkerType "mil_box"; _mkI setMarkerColor "ColorGreen"; _mkI setMarkerText "SUPPLY DROP -- OPEN";
            _mkZ setMarkerColor "ColorGreen";
            [[1, "The SUPPLY BOMBER crate has CRACKED OPEN -- loot's up for grabs. Redzone's still hot."], "AP_fnc_broadcast", -2, false, false] spawn AP_fnc_MP;
            ["-SUPPLYBOMB-", objNull, "SERVER", "supply crate UNLOCKED (filled + openable)"] call APS_fnc_logIt;};

        // ---- reaper: after the crate is looted (empty + nobody near) or a hard window, sweep everything ----
        [_crate, _mkZ, _mkI] spawn {params ["_crate", "_mkZ", "_mkI"];
            private _hardEnd = time + 600 + 900;           // 10-min lock + 15-min loot window
            waitUntil {uiSleep 10;
                if (isNull _crate) exitWith { true };
                private _empty = (((getItemCargo _crate) select 0) isEqualTo []) && {(weaponCargo _crate) isEqualTo []} && {(magazineCargo _crate) isEqualTo []};
                private _clear = ((call AP_fnc_realPlayers) findIf { alive _x && {(_x distance _crate) < 25} }) < 0;
                (time > _hardEnd) || {(!(lockedInventory _crate)) && _empty && _clear}};
            private _sm = if (isNull _crate) then { objNull } else { _crate getVariable ["AP_smoke", objNull] };
            if (!isNull _sm) then { deleteVehicle _sm; };
            if (!isNull _crate) then { deleteVehicle _crate; };
            deleteMarker _mkZ; deleteMarker _mkI;
            ["-SUPPLYBOMB-", objNull, "SERVER", "supply drop swept (crate + redzone removed)"] call APS_fnc_logIt;};};

    // ---- send the plane off the map + despawn it (it never had a marker) ----
    [_plane] spawn {params ["_p"];
        uiSleep 90;
        if (!isNull _p) then { { deleteVehicle _x } forEach (crew _p); deleteVehicle _p; };};};
