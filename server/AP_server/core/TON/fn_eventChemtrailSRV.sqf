/*
    APS_fnc_eventChemtrailSRV  (LooneyBin world event -- Ben Bones canon). AP_adminEvent type 8.
    A "chemtrail" cloud settles over a town for 5 min. A civilian plane does a spray flyby (flavor). Players
    inside AP_chemtrailZone roll a random effect every ~20s (client watcher in initPlayerLocal): a Super Male
    Vitality buff, a paranoia haze, or nothing. Server = zone + plane + announce + cleanup.
*/
params [["_locID", -1, [0]]];
if !([4, "eventChemtrailSRV START"] call APS_fnc_isAdminCaller) exitWith {};   // admin-menu event (eventCfg owner-only row, client gate >= 4): the caller's DB adminlevel, never the payload
if (AP_adminEvent param [0, false]) exitWith {};
AP_adminEvent = [true, false, 8, _locID];
publicVariable "AP_adminEvent";
private _locData = (["getLocationByID", _locID] call AP_fnc_eventCfg);
private _locName = _locData param [1, "?"];
private _pos = _locData param [2, [0,0,0]];

deleteMarker "ChemZone";
createMarker ["ChemZone", _pos];
"ChemZone" setMarkerShape "ELLIPSE";
"ChemZone" setMarkerSize [350, 350];
"ChemZone" setMarkerBrush "DiagGrid";
"ChemZone" setMarkerColor "ColorGreen";
"ChemZone" setMarkerAlpha 0.5;
"ChemZone" setMarkerText "CHEMTRAILS";
// AP_chemtrailZone is published at the jet's first overpass -- the SPRAY comes before the effects.

// spray flyby -- an AI jet makes THREE slow low passes over the square, each trailing a fresh plume.
// LIMITED speed + 150m + crossing waypoints: the old single 180m/s pass was audible but over in ~4s.
private _plane = createVehicle ["B_Plane_CAS_01_F", [(_pos select 0) - 2600, (_pos select 1) - 2600, 350], [], 0, "FLY"];
createVehicleCrew _plane;
_plane setVariable ["owner", "SERVER", true];
_plane flyInHeight 150;
// the plume: the engine's own wreck-smoke objects riding the wings -- global objects, engine particles,
// visible to everyone (hand-rolled #particlesource and attached smoke shells both rendered nothing).
private _plume = []; {private _sm = createVehicle ["test_EmptyObjectForSmoke", [0, 0, 0], [], 0, "CAN_COLLIDE"];
    _sm attachTo [_plane, _x];
    _plume pushBack _sm;} forEach [[-6.5, -2, -0.4], [6.5, -2, -0.4]];
_plane setDir 45;
_plane setVelocityModelSpace [0, 140, 0];
private _grp = group (driver _plane);
_grp setBehaviour "CARELESS";
_grp setSpeedMode "LIMITED"; {private _wp = _grp addWaypoint [_x, 0];
    _wp setWaypointType "MOVE";
    _wp setWaypointCompletionRadius 250;} forEach [
    [(_pos select 0) + 2600, (_pos select 1) + 2600, 150],   // pass 1: SW -> NE over the square
    [(_pos select 0) + 2600, (_pos select 1) - 2600, 150],   // swing wide
    [(_pos select 0) - 2600, (_pos select 1) + 2600, 150],   // pass 2: SE -> NW
    [(_pos select 0) - 2600, (_pos select 1) - 2600, 150],   // swing wide
    [(_pos select 0) + 2600, (_pos select 1) + 2600, 150]    // pass 3
];
// owner 2026-07-17: HC OFFLOAD -- the jet's AI pilot flies on the headless client (setGroupOwner), not the game
// server. Waypoints above are added server-local; hand off after. No HC online -> stays server-owned.
if ((localNamespace getVariable ["AP_hcOwner", 0]) > 0) then { _grp setGroupOwner (localNamespace getVariable ["AP_hcOwner", 0]); };
// overpass watcher: first pass over the square ARMS the effect zone (spray first, THEN symptoms)
// and announces it; the plume itself is client-side particle emitters keyed on AP_chemtrailJet
// (attached smoke shells render nothing on a fast mover).
[_plane, _pos, _plume] spawn {params ["_plane", "_pos", "_plume"];
    private _end = time + 170;
    private _announced = false;
    while { time < _end && {!isNull _plane} && {alive _plane} } do {if (!_announced && {(_plane distance2D _pos) < 600}) then {
            _announced = true;
            [[0, "LOOK UP. The spray plane is OVERHEAD. That is NOT water vapor."], "AP_fnc_broadcast", -2, false, false] spawn AP_fnc_MP;
            diag_log format ["[LooneyBin][chemtrail] overpass: jet %1m from zone center, alt %2", round (_plane distance2D _pos), round ((getPosATL _plane) select 2)];
            AP_chemtrailZone = [_pos, 350]; publicVariable "AP_chemtrailZone";   // effects live from HERE
        };
        uiSleep 2;};
    if (!_announced) then { AP_chemtrailZone = [_pos, 350]; publicVariable "AP_chemtrailZone"; };   // jet died/never arrived -> arm anyway
    { detach _x; deleteVehicle _x; } forEach _plume;
    if (!isNull _plane) then { { deleteVehicle _x } forEach (crew _plane); deleteVehicle _plane; };};

[[0, format ["BEN BONES EMERGENCY BROADCAST: they're SPRAYING %1! Chemtrails inbound -- mask up, it's in the AIR for 5 minutes!", _locName]], "AP_fnc_broadcast", -2, false, false] spawn AP_fnc_MP;
["CHEM", format ["CHEMTRAIL DEPLOYMENT CONFIRMED OVER %1 -- 'IT'S JUST VITAMINS' SAYS GOVT (LIE)", _locName], format ["they are SPRAYING %1 RIGHT NOW. i can see the plane. WAKE UP.", _locName]] call APS_fnc_newsPush;

[_plane] spawn {params ["_plane"];
    private _t0 = time;
    waitUntil { uiSleep 5; ((missionNamespace getVariable ["AP_chemtrailZone", []]) isNotEqualTo []) || {time > _t0 + 240} };
    uiSleep 300;
    if (AP_adminEvent param [0, false] && {(AP_adminEvent param [2, 0]) isEqualTo 8}) then {
        AP_adminEvent = [false, false, 0, 0]; publicVariable "AP_adminEvent";
        [[0, "The chemtrails have dispersed. For now. STAY VIGILANT."], "AP_fnc_broadcast", -2, false, false] spawn AP_fnc_MP;};
    deleteMarker "ChemZone";
    AP_chemtrailZone = nil; publicVariable "AP_chemtrailZone";
    if (!isNull _plane) then { { deleteVehicle _x } forEach (crew _plane); deleteVehicle _plane; };};
