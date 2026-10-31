/*
    APS_fnc_srvMobileHQ  (LooneyBin -- implemented from stub 2026-06-09)
    Cop prestige Mobile HQ (tree nodes 35/36/37). Client (core/functions/fn_clientMobileHQ.sqf
    "setupMobileHQ") locked the truck, set SRV_mobileHQ[2]=true and sends [player, truck, level]
    (level: 0 = shops only, 1 = +ground garage, 2 = +air garage, from talents 36/37).
    Server: short build delay, spawn the gear NPC + (level>0) the garage NPC beside the truck, publish
    SRV_mobileHQ = [setupTime(serverTime, feeds the 30-min supply cooldown), truck, true, [level, gearNPC, vehNPC]],
    then have every client run clientMobileHQ "setupShops" (adds the local shop actions; JIP included).
    Teardown: when the truck dies/despawns, NPCs are cleaned and SRV_mobileHQ resets (cooldown keeps its stamp).
*/
params [["_player", objNull, [objNull]], ["_truck", objNull, [objNull]], ["_level", 0, [0]]];
if (isNull _truck) exitWith {};
[_player, _truck, _level] spawn {params ["_player", "_truck", "_level"];
    uiSleep 15;   // "Keep the surrounding area clear!" build time
    if (isNull _truck || {!alive _truck}) exitWith {SRV_mobileHQ = [SRV_mobileHQ param [0, -1800], objNull, false, [0, objNull, objNull]];
        publicVariable "SRV_mobileHQ";};
    // owner 2026-06-20 (Mobile HQ rework): capture the deploy DIR once. EVERYTHING below is anchored to the
    // truck's deploy SPOT (fixed world positions) and to the BASE building, NOT to the truck object -- the truck
    // can now be driven off / stored / reaped and the HQ stays up (decoupled). Teardown watches the BASE.
    private _dir = getDir _truck;

    // #150: deploy the physical Mobile HQ structures. Command post (= the BASE) + sandbag cover + floodlight +
    // flag, placed via the truck's deploy-spot model offsets. owner 2026-06-20: enableSimulationGlobal false on
    // every struct (item 5 -- static, never shoved/toppled by a player).
    private _structs = [];
    private _base = objNull; {_x params ["_cls", "_off", "_dirAdd"];
        private _wp = _truck modelToWorld _off;
        private _o = createVehicle [_cls, [_wp select 0, _wp select 1, 0], [], 0, "CAN_COLLIDE"];
        _o setDir (_dir + _dirAdd);
        _o setPosATL [_wp select 0, _wp select 1, 0];
        _o allowDamage false;
        _o enableSimulationGlobal false;
        _structs pushBack _o;
        if (_cls isEqualTo "Land_Cargo_HQ_V1_F") then { _base = _o; };} forEach [
        // owner 2026-06-19 (#383): offsets pushed well BEHIND the truck. Were -3.5/-6m from the truck CENTER,
        // but B_Truck_01_covered_F is ~8.5m long, so the command post + light spawned INSIDE the truck -> the
        // engine ejected the truck on overlap -> it blew up ~30s after deploy. Cleared past the rear bumper.
        ["Land_Cargo_HQ_V1_F",          [0, -11, 0],    0], ["Land_BagFence_Long_F",        [-4, -8, 0],    90],
        ["Land_BagFence_Long_F",        [4, -8, 0],     90], ["Land_PortableLight_double_F", [0, -8, 0],     180],
        ["Flag_NATO_F",                 [-1.2, -11, 0], 0]];

    // owner 2026-06-20 (item 1): NPCs now stand INSIDE the base building (not at the truck). Anchored to the
    // BASE so they stay put with the HQ. item 5: enableSimulationGlobal false = frozen statues players can't push.
    private _mk = { params ["_off"];
        private _p = _base modelToWorld _off;
        private _npc = createAgent ["B_RangeMaster_F", [_p select 0, _p select 1, 0], [], 0, "CAN_COLLIDE"];
        _npc setDir _dir;
        _npc disableAI "ALL"; _npc allowDamage false; _npc setVariable ["BIS_enableRandomization", false];
        _npc switchMove "STAND_U1";
        _npc enableSimulationGlobal false;
        _npc};
    private _gearNPC = [[-1.5, 0, 0]] call _mk;
    private _vehNPC  = if (_level > 0) then { [[1.5, 0, 0]] call _mk } else { objNull };

    // owner 2026-06-20 (item 3): the ground motor pool spawns to the RIGHT of the HQ (+X), with a visible map
    // marker. cop_g_mobile carries "_g_" only -> fn_vehicleShopBuy's ground filter picks it for cars (NOT helis).
    private _vehNPCs = [];
    private _helipad = objNull;
    if (_level > 0) then {private _gp = _truck modelToWorld [16, -9, 0];
        deleteMarker "cop_g_mobile";
        createMarker ["cop_g_mobile", [_gp select 0, _gp select 1, 0]];
        "cop_g_mobile" setMarkerType "loc_Transport";
        "cop_g_mobile" setMarkerColor "ColorBlue";
        "cop_g_mobile" setMarkerText "Mobile HQ Motor Pool";
        _vehNPCs pushBack "cop_g_mobile";};
    // owner 2026-06-20 (item 6): at level 2 (air garage) add a HELIPAD far to the LEFT (-X), well clear of the HQ
    // structs so a spawned/landing heli can't clip a building and go boom. cop_air_mobile carries "_air_" only ->
    // the air filter spawns helis HERE (left pad), separated from the ground motor pool (right).
    if (_level == 2) then {private _hp = _truck modelToWorld [-28, -9, 0];
        _helipad = createVehicle ["Land_HelipadCircle_F", [_hp select 0, _hp select 1, 0], [], 0, "CAN_COLLIDE"];
        _helipad setDir _dir;
        _helipad setPosATL [_hp select 0, _hp select 1, 0];
        _helipad enableSimulationGlobal false;
        deleteMarker "cop_air_mobile";
        createMarker ["cop_air_mobile", [_hp select 0, _hp select 1, 0]];
        "cop_air_mobile" setMarkerType "loc_Heliport";
        "cop_air_mobile" setMarkerColor "ColorBlue";
        "cop_air_mobile" setMarkerText "Mobile HQ Helipad";
        _vehNPCs pushBack "cop_air_mobile";};

    _truck setVariable ["AP_mobileHQActive", true, true];
    // SRV_mobileHQ payload extended: [level, gearNPC, vehNPC, base, helipad, vehSpawnMarkers] -- clients read
    // base+markers in clientMobileHQ "setupShops" (the pack-up action + the right spawn-point list).
    SRV_mobileHQ = [serverTime, _truck, true, [_level, _gearNPC, _vehNPC, _base, _helipad, _vehNPCs]];
    publicVariable "SRV_mobileHQ";
    [["setupShops", [], objNull, objNull], "AP_fnc_clientMobileHQ", -2, true, false] spawn AP_fnc_MP;   // all clients + JIP: add the shop actions
    [[1, "The MaxSec Mobile HQ is now operational!"], "AP_fnc_broadcast", west, false, false] spawn AP_fnc_MP;
    diag_log format ["[LooneyBin][mobileHQ] up at %1 (level %2)", getPosATL _base, _level];

    // owner 2026-06-20 (items 1+4): teardown is tied to the BASE, not the truck. The HQ stays up until a cop
    // packs it up (scroll-wheel sets AP_mobileHQPackup, added on _base in setupShops) or the base is destroyed.
    waitUntil { uiSleep 5; isNull _base || {!alive _base} || {_base getVariable ["AP_mobileHQPackup", false]} };
    { if (!isNull _x) then { deleteVehicle _x; }; } forEach ([_gearNPC, _vehNPC, _helipad] + _structs);
    { deleteMarker _x; } forEach ["cop_g_mobile", "cop_air_mobile"];
    SRV_mobileHQ = [SRV_mobileHQ param [0, serverTime], objNull, false, [0, objNull, objNull]];
    publicVariable "SRV_mobileHQ";
    [[1, "The MaxSec Mobile HQ has been packed up."], "AP_fnc_broadcast", west, false, false] spawn AP_fnc_MP;};
