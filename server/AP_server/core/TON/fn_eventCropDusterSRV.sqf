/*
    APS_fnc_eventCropDusterSRV  (LooneyBin world event -- Ben Bones canon). Crop-duster gas run.
    A slow, low civilian plane (C_Plane_Civil_01_F, AI pilot offloaded to the headless client) makes passes
    over the chosen location trailing a gas plume, and arms a ~200m effect zone for 5 minutes.

    EFFECT (cartel-branched): if the location sits within 400m of a cartel flag (arms/drug/oil/wongs) the mist is
    a BUFF -- players inside breathe deep and get a brief sprint/no-fatigue kick. Anywhere else it's raw pesticide:
    a mild DEBUFF (coughing / blurred vision). Same CfgRE-safe delivery the chemtrail/purge use: the server
    publishes AP_cropDusterZone = [_pos, _radius, _mode] and pushes per-player flavor via AP_fnc_handleMessage;
    a client watcher (mirror of the chemtrail block in initPlayerLocal) reads the zone and applies the mechanical
    setAnimSpeedCoef / ppEffect locally. mode=1 remoteExec would block a server->client engine command, so effects
    NEVER go out as a raw remoteExec.

    Admin event menu passes the chosen LOCATION position.
*/
if (!isServer) exitWith {};
params [["_pos", [0,0,0], [[]]]];
if !([4, "eventCropDusterSRV START"] call APS_fnc_isAdminCaller) exitWith {};   // admin-menu event (eventCfg owner-only row, client gate >= 4): the caller's DB adminlevel, never the payload
if (_pos isEqualTo [0,0,0]) exitWith {};

private _radius = 200;
private _zoneDur = 300;   // 5-min effect window

// cartel proximity (flags are editor-placed globals -- read defensively so an unloaded flag can't throw)
private _flags = [];
{ if (!isNil _x) then { _flags pushBack (missionNamespace getVariable [_x, objNull]); }; } forEach ["arms_flag", "drug_flag", "oil_flag", "wongs_flag"];
private _nearCartel = (_flags findIf { !isNull _x && {(_x distance2D _pos) < 400} }) > -1;
private _mode = if (_nearCartel) then { "buff" } else { "debuff" };

// ---- the plane: a slow low civilian duster, AI pilot, three crossing passes over the point ----
private _bear = random 360;
private _sp = [(_pos select 0) + 2600 * sin _bear, (_pos select 1) + 2600 * cos _bear, 120];
private _plane = createVehicle ["C_Plane_Civil_01_F", _sp, [], 0, "FLY"];
_plane setPosATL _sp;
_plane setDir (_bear + 180);
_plane setVelocityModelSpace [0, 90, 0];
createVehicleCrew _plane;                          // AI pilot = the no-HC fallback (flies waypoints server-side)
_plane setVariable ["owner", "event", true];       // fn_cleanup spare (ownerless = instant reap)
_plane flyInHeight 60;
private _grp = group (driver _plane);
_grp setBehaviour "CARELESS"; _grp setSpeedMode "LIMITED"; _grp setCombatMode "BLUE"; {private _wp = _grp addWaypoint [_x, 0];
    _wp setWaypointType "MOVE";
    _wp setWaypointCompletionRadius 200;} forEach [[(_pos select 0) - 2600 * sin _bear, (_pos select 1) - 2600 * cos _bear, 60],
    [(_pos select 0) + 2600 * cos _bear, (_pos select 1) - 2600 * sin _bear, 60],
    [(_pos select 0) - 2600 * cos _bear, (_pos select 1) + 2600 * sin _bear, 60],
    [(_pos select 0) + 2600 * sin _bear, (_pos select 1) + 2600 * cos _bear, 60]];
// HC OFFLOAD -- the AI pilot flies on the headless client; guard so no HC leaves it server-owned (AI still flies)
if ((localNamespace getVariable ["AP_hcOwner", 0]) > 0) then { _grp setGroupOwner (localNamespace getVariable ["AP_hcOwner", 0]); };

// the gas plume: engine smoke shells riding the wings (renders on a slow low mover)
private _plume = []; {private _sm = createVehicle ["test_EmptyObjectForSmoke", [0, 0, 0], [], 0, "CAN_COLLIDE"];
    _sm attachTo [_plane, _x];
    _plume pushBack _sm;} forEach [[-4.5, -1.5, -0.3], [4.5, -1.5, -0.3]];

// ---- markers: an ellipse over the zone + an icon following the plane ----
private _mkZone = format ["cropDuster_z_%1", floor serverTime];
private _mkPlane = format ["cropDuster_p_%1", floor serverTime];
createMarker [_mkZone, _pos];
_mkZone setMarkerShape "ELLIPSE"; _mkZone setMarkerSize [_radius, _radius];
_mkZone setMarkerBrush "DiagGrid"; _mkZone setMarkerColor (["ColorBrown", "ColorGreen"] select _nearCartel);
_mkZone setMarkerAlpha 0.5; _mkZone setMarkerText "CROP DUSTING";
createMarker [_mkPlane, getPosATL _plane];
_mkPlane setMarkerType "mil_air"; _mkPlane setMarkerColor "ColorBlack"; _mkPlane setMarkerText "Duster";

[_plane, _mkPlane] spawn {params ["_plane", "_mkPlane"];
    while { !isNull _plane && {alive _plane} && {markerType _mkPlane isNotEqualTo ""} } do {_mkPlane setMarkerPos (getPosATL _plane);
        uiSleep 2;};
    deleteMarker _mkPlane;};

// ---- announce ----
private _line = if (_nearCartel) then {
    "Crop-duster inbound over the cartel! Whatever's in that tank, it's making people FAST. Get in the mist."} else {
    "Ben Bones warning: a CROP DUSTER is spraying pesticide over the area for 5 minutes. Do NOT breathe it in."};
[[0, _line], "AP_fnc_broadcast", -2, false, false] spawn AP_fnc_MP;
["DUST", "MYSTERY BIPLANE SPRAYS TOWN -- AG DEPT 'ROUTINE', LOCALS COUGHING", "a crop duster is dumping GAS on us. they say it's for the bugs. i am not a bug. mask up, patriot."] call APS_fnc_newsPush;
["-CROPDUSTER-", objNull, "SERVER", format ["run started at %1 (mode %2, cartel %3)", _pos, _mode, _nearCartel]] call APS_fnc_logIt;

// ---- effect zone + watchdog: arm the zone, push per-player flavor, then clean everything up ----
[_pos, _radius, _zoneDur, _mode, _nearCartel, _plane, _plume, _mkZone, _mkPlane] spawn {
    params ["_pos", "_radius", "_zoneDur", "_mode", "_nearCartel", "_plane", "_plume", "_mkZone", "_mkPlane"];
    AP_cropDusterZone = [_pos, _radius, _mode]; publicVariable "AP_cropDusterZone";
    private _hit = createHashMap;
    private _end = time + _zoneDur;
    private _msg = if (_nearCartel) then {"You breathe in the cartel mist -- your legs feel light and your lungs forget to tire."} else {
        "*cough* You catch a lungful of crop-duster gas. Eyes water, chest burns, screen swims."};
    while { time < _end } do {{if (alive _x && {(_x distance2D _pos) < _radius}) then {private _u = getPlayerUID _x;
                if (time > (_hit getOrDefault [_u, 0])) then {_hit set [_u, time + 18];
                    [[_msg, "info"], "AP_fnc_handleMessage", _x, false, false] spawn AP_fnc_MP;};};
        } forEach (call AP_fnc_realPlayers);
        uiSleep 5;};
    // teardown -- no leaks
    AP_cropDusterZone = nil; publicVariable "AP_cropDusterZone";
    { detach _x; deleteVehicle _x; } forEach _plume;
    if (!isNull _plane) then { { deleteVehicle _x } forEach (crew _plane); deleteVehicle _plane; };
    deleteMarker _mkZone; deleteMarker _mkPlane;
    [[0, "The crop duster has flown off. The air is clearing."], "AP_fnc_broadcast", -2, false, false] spawn AP_fnc_MP;
    ["-CROPDUSTER-", objNull, "SERVER", "run resolved -- zone + plane cleaned"] call APS_fnc_logIt;};
