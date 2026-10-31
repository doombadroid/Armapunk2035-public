/*
    APS_fnc_airdropEventSRV  (LooneyBin, owner 2026-07-15) -- public REBEL WEAPON airdrops.
    Server-only (never client-called; the init loop triggers it). A smuggler VTOL crosses the island and
    parachutes a weapons crate at one of the wilderness drop zones: 5-min warning marker, then the drop,
    crate marked + green smoke, first crew to hold the spot takes the guns. 20-min despawn.
    Drop physics = the probe-verified drop pattern (FULL-form createVehicle + setPosATL both pieces,
    land-check on the CHUTE -- attached objects report junk ATL; the simple form grounds everything).
*/
if (!isServer) exitWith {};
params [["_mode", "drop", [""]]];

private _zones = [["Mountain Pass",     [6358, 12358, 0]], ["Hunting Grounds",   [14200, 22169, 0]],
    ["Shoreline Ruins",   [21381, 10931, 0]], ["Salt Flats",        [23115, 18423, 0]], ["Land Bridge",       [2675, 22094, 0]],
    ["Buoy Graveyard",    [21817, 6268, 0]], ["Warzone Island",    [10197, 7287, 0]], ["Power Plant Ridge", [15370, 16034, 0]]];
private _pick = selectRandom _zones;
_pick params ["_zName", "_zPos"];
// scatter the actual drop up to 150m off the named point -- campers can't pre-sit the pixel
private _sd = random 360;
private _pos = [(_zPos select 0) + (random 150) * sin _sd, (_zPos select 1) + (random 150) * cos _sd, 0];
_pos = [_pos, 0, 60, 4, 0, 0.5, 0] call BIS_fnc_findSafePos;

deleteMarker "AP_airdrop";
private _mk = createMarker ["AP_airdrop", _pos];
"AP_airdrop" setMarkerType "mil_warning";
"AP_airdrop" setMarkerColor "ColorRed";
"AP_airdrop" setMarkerText format ["WEAPON DROP INBOUND (%1)", _zName];

[[0, format ["Smuggler radio intercept: a REBEL WEAPONS DROP hits %1 in 5 minutes. Marked on the map. Bring friends -- or don't, more for you.", _zName]], "AP_fnc_broadcast", -2, false, false] spawn AP_fnc_MP;
["DROP", format ["MYSTERY PLANE DUMPING 'FREEDOM SUPPLIES' OVER %1 -- GOVT 'MONITORING'", toUpper _zName], format ["a plane is dropping GUNS on %1 in 5 minutes. free guns, patriot. i do not ask where guns come from.", _zName]] call APS_fnc_newsPush;
["-AIRDROP-", objNull, "SERVER", format ["weapon drop scheduled: %1 %2", _zName, _pos]] call APS_fnc_logIt;

[_pos, _zName] spawn {params ["_pos", "_zName"];
    uiSleep 300;   // the 5-min warning window

    // the smuggler: a VTOL crossing over the zone, drop on the overfly
    private _bear = random 360;
    private _sp = [(_pos select 0) + 3000 * sin _bear, (_pos select 1) + 3000 * cos _bear, 300];
    private _plane = createVehicle ["B_T_VTOL_01_vehicle_F", _sp, [], 0, "FLY"];
    _plane setPosATL _sp;
    _plane setDir (_bear + 180);
    _plane setVelocityModelSpace [0, 100, 0];
    createVehicleCrew _plane;
    _plane flyInHeight 180;
    (group (driver _plane)) setBehaviour "CARELESS";
    _plane setVariable ["owner", "airdrop", true];
    (driver _plane) doMove [(_pos select 0) - 3000 * sin _bear, (_pos select 1) - 3000 * cos _bear, 300];
    // owner 2026-07-17: HC OFFLOAD -- the VTOL's AI pilot flies on the headless client (setGroupOwner). The doMove
    // above ran server-local; hand off after. No HC online -> stays server-owned.
    if ((localNamespace getVariable ["AP_hcOwner", 0]) > 0) then { (group (driver _plane)) setGroupOwner (localNamespace getVariable ["AP_hcOwner", 0]); };
    private _end = time + 180;
    waitUntil { uiSleep 2; isNull _plane || {!alive _plane} || {(_plane distance2D _pos) < 350} || {time > _end} };

    // the drop (proven physics)
    private _chute = createVehicle ["B_Parachute_02_F", [_pos select 0, _pos select 1, 160], [], 0, "CAN_COLLIDE"];
    _chute setPosATL [_pos select 0, _pos select 1, 160];
    private _crate = createVehicle ["B_supplyCrate_F", [_pos select 0, _pos select 1, 158], [], 0, "CAN_COLLIDE"];
    _crate setPosATL [_pos select 0, _pos select 1, 158];
    _crate enableRopeAttach false;
    _crate attachTo [_chute, [0, 0, -1.1]];
    _crate setVariable ["owner", "airdrop", true];
    clearWeaponCargoGlobal _crate; clearItemCargoGlobal _crate; clearMagazineCargoGlobal _crate; clearBackpackCargoGlobal _crate;
    // rebel-tier prize table (owner 2026-07-18 overhaul): ALWAYS 1 explosive combo (RPG-7+HEAT or suicide
    // vest, random) PLUS 1 rotated gun bundle. Then fixed mags + optics.
    call (selectRandom [
        { _crate addWeaponCargoGlobal ["launch_RPG7_F", 1]; _crate addMagazineCargoGlobal ["RPG7_F", 1]; },   // RPG-7 + 1 HEAT rocket
        { _crate addItemCargoGlobal ["V_HarnessOGL_brn", 1]; }                                                // suicide vest (suivest)
    ]);
    call (selectRandom [
        { _crate addWeaponCargoGlobal ["LMG_Zafir_F", 1]; _crate addMagazineCargoGlobal ["150Rnd_762x54_Box", 5]; _crate addWeaponCargoGlobal ["srifle_DMR_03_F", 3]; },    // Zafir + 5 mags + 3 Mk-I EMR
        { _crate addWeaponCargoGlobal ["LMG_Mk200_F", 2]; _crate addMagazineCargoGlobal ["200Rnd_65x39_cased_Box", 4]; _crate addWeaponCargoGlobal ["srifle_DMR_03_F", 2]; }, // 2 Mk200 + 4 belts + 2 Mk-I EMR
        { _crate addWeaponCargoGlobal ["srifle_EBR_F", 2]; },    // Mk18 ABR
        { _crate addWeaponCargoGlobal ["arifle_AKM_F", 3]; }     // AKM
    ]);
    { _crate addMagazineCargoGlobal _x; } forEach [["20Rnd_762x51_Mag", 8], ["30Rnd_762x39_Mag_F", 12]];
    { _crate addItemCargoGlobal _x; } forEach [["optic_Arco", 2], ["optic_Holosight", 2], ["optic_AMS", 1], ["optic_DMS", 1]];

    // send the plane on its way + clean up
    [_plane] spawn { params ["_p"]; uiSleep 90; if (!isNull _p) then { { deleteVehicle _x } forEach (crew _p); deleteVehicle _p; }; };

    [[0, format ["The weapons crate is FALLING over %1!", _zName]], "AP_fnc_broadcast", -2, false, false] spawn AP_fnc_MP;
    waitUntil { uiSleep 1; isNull _chute || {isNull _crate} || {(getPosATL _chute) select 2 < 3} };
    if (isNull _crate) exitWith { if (!isNull _chute) then { deleteVehicle _chute; }; deleteMarker "AP_airdrop"; };
    detach _crate;
    private _gp = getPosATL _crate;
    _crate setPosATL [_gp select 0, _gp select 1, 0.1];
    _crate setVectorUp [0, 0, 1];
    if (!isNull _chute) then { deleteVehicle _chute; };
    "AP_airdrop" setMarkerType "mil_box";
    "AP_airdrop" setMarkerText "WEAPON DROP (landed)";
    "AP_airdrop" setMarkerPos (getPosATL _crate);
    private _smoke = "SmokeShellGreen" createVehicle (getPosATL _crate);
    ["-AIRDROP-", objNull, "SERVER", format ["crate landed at %1", getPosATL _crate]] call APS_fnc_logIt;

    uiSleep 1200;   // 20 minutes of scrap
    { if (!isNull _x) then { deleteVehicle _x; }; } forEach [_crate, _smoke];
    deleteMarker "AP_airdrop";};
