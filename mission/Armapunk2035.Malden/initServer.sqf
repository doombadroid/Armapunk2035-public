// LooneyBin: removed `if !(_this select 0) exitWith {}` -- Arma auto-runs initServer with _this=[],
// so that guard aborted server init (AP_server never spawned). Auto-run must proceed.
bis_fnc_drawMinefields_active = true;
AP_worldName =
switch (worldName) do {case ("blud_vidda"): {"Vidda"}; case ("chernarus"): {"Chernarus Autumn"}; case ("sara"): {
                    "Sahrani"}; case ("zargabad"): {"Zargabad"}; case ("utes"): {
                            "Utes"}; default {worldName};}; publicVariable "AP_worldName";
// PERMANENT DUSK, 16:00 (the pre-After-Dark state, restored 2026-09-02 -- owner: the After-Dark
// permanent-night / neon look "looks terrible", all of it reverted). This fork inherited Altis's
// dayNightTime scheduler job (setTimeMultiplier 12x day / 54x night -- a full day in ~1.5 real
// hours). A moving clock meant the client atmosphere script had to keep snapping the time back,
// and every setDate is a full lighting recalculation: screen flash + frame dip on all clients every
// few seconds. Freeze the clock at the source instead; the job below reads this flag and parks the
// multiplier at 0 rather than cycling it.
// setTimeMultiplier is CLAMPED by the engine to 0.1..120, so this reads back as 0.1, not 0 -- the
// clock is not truly stopped, it runs at a tenth of real time (~6 in-game minutes per real hour).
// Measured: zero drift from 16:00 over 60s. Each client also re-anchors to 16:00 via the atmosphere
// script when it joins, so per-session drift stays bounded.
// Set AP_freezeTimeOfDay = false to get the day/night cycle back.
// DEV: everyone who joins is admin level 4 (owner request 2026-07-25, Malden testing).
// Read by fn_queryRequest on login; applied in memory only, never persisted, so setting this
// false immediately restores real admin levels with no DB cleanup.
// >>> TURN OFF BEFORE PUBLIC LAUNCH -- tracked in launch.md <<<
// The copy the server must act on is the localNamespace one: the published global is what ANY client's
// publicVariable overwrites (audit Lsec-0-1). fn_queryRequest still reads the global -- DB-layer follow-up.
localNamespace setVariable ["AP_devAutoAdmin", false]; AP_devAutoAdmin = localNamespace getVariable "AP_devAutoAdmin"; publicVariable "AP_devAutoAdmin";   // launch.md: off since 2026-09-07 (closed test on .96)

AP_freezeTimeOfDay = true; publicVariable "AP_freezeTimeOfDay";
setDate [2035, 10, 31, 16, 0];
setTimeMultiplier 0;

// Weather is the weatherCycle wheel job's (server_init.sqf), as before After-Dark: no seed here.

AP_serverId =
switch (profileName) do {case "LoonyBinServer1": {1}; case "LoonyBinServer2": {2};
        case "LoonyBinServer3": {3};
        case "LoonyBinServer4": {4};
        default {1};}; publicVariable "AP_serverId";

// owner 2026-07-10: DAY/NIGHT CYCLE RE-ENABLED. This used to re-assert noon every 10 min ("permanent
// DAYTIME"), which snapped the clock back before it ever reached dark -> the server_init "dayNightTime"
// setTimeMultiplier job (12x day / 54x night, already live) could never carry it into night. Removed so
// the multiplier cycles freely: a full game-day passes in ~1.5 real hours, nights pass fast (54x) so it's
// never dark for long. (The old comment's fear that setTimeMultiplier stretches mission `time`/uiSleep is
// outdated -- setTimeMultiplier only accelerates the time-of-DAY clock, not `time`; the 12x multiplier has
// been live via the scheduler the whole time with no timer issues.) Start date/hour comes from mission.sqm.

// LooneyBin: cops (respawn_west) + medics (respawn_guerrila) had NO respawn=BASE marker, so on
// bleedout the engine respawned them at [0,0,0] = debug island. Create the missing side anchors at
// the civilian respawn pos (just a pre-spawn-menu holding spot) so nobody lands on debug island.
{if ((getMarkerPos _x) isEqualTo [0,0,0]) then {createMarker [_x, getMarkerPos "respawn_civilian"];
        _x setMarkerAlpha 0;};} forEach ["respawn_west", "respawn_guerrila", "respawn_east"];

// MALDEN FIELDS 2026-07-26. The gather code addresses a field by MARKER NAME ("mine_1", "oil_1",
// "illegal_marker_2_0"), and every one of those names came out of the Altis .sqm -- which this map
// does not have. A missing marker reads as [0,0,0], so until now every field in the game sat stacked
// in the map's SW corner and stood up its full scroll menu there.
//
// The designer marked his own fields, but his markers are auto-named (marker_231 is "Tobacco Field")
// inside a BINARIZED mission.sqm that is no place to be hand-editing names. So the names the code
// wants are created HERE as invisible aliases on his coordinates: his labelled dot stays the one on
// the map, and moving a field means moving the pair. Global markers, so they reach JIP clients too.
//
// Absent on purpose, until the designer places them: apple_*, peaches_*, salt_1. A name with no
// marker means "no such field on Malden", which is how the gather code reads it. Opium, cannabis,
// oysters, prison metal and henbane (illegal_marker_8_0) are not waiting on a marker: they were
// deleted from the game, items and all.
private _fieldsPinned = 0;
{
    _x params ["_zone", "_pos"];
    if (markerType _zone isEqualTo "") then {          // designer's own marker, if he adds one, wins
        createMarker [_zone, _pos];
        _zone setMarkerType "mil_dot";                 // any type will do -- existence is what gets tested
        _zone setMarkerColor "ColorRed";
        _zone setMarkerAlpha 0;
        _fieldsPinned = _fieldsPinned + 1;
    };
} forEach [
    ["illegal_marker_2_0", [8126.7, 7725.5]],          // marker_0    "Smash Field"       + 100 m ring
    ["illegal_marker_3_0", [6925.0, 3936.1]],          // marker_207  "Sparkdust"         + 100 m ring
    ["illegal_marker_4_0", [2928.5, 8572.4]],          // marker_183  "Uranium Ship"      + 100 m ring
    ["tobacco_1",          [4477.5, 9499.0]],          // marker_231  "Tobacco Field"     + 100 m ring
    ["fentanyl_1",         [4346.8, 6765.3]],          // marker_205  "Boost"             + 100 m ring
    ["vineyard_1",         [4483.5, 4185.7]],          // marker_203  "Vinyard"
    ["rock_1",             [4309.5, 2431.9]],          // marker_209  "Redshift"
    ["oil_1",              [2132.2, 3838.5]],          // marker_213  "Oil Field"
    ["oil_2",              [8290.6, 9626.4]],          // marker_237  "Oil Field"
    ["oil_3",              [7978.7, 5991.9]],          // marker_210  "Toxic Slurry" -- oil_N is dual on
                                                       //   purpose: pickaxe + fuel truck gives oil,
                                                       //   otherwise toxic slurry, same as Altis
    ["mine_1",             [5517.2, 6270.0]],          // marker_212  "High Yield Mine" -- mine_1 pays x2
    ["mine_2",             [5020.1, 4791.4]],          // marker_211  "Low Yield Mine"
    ["mine_3",             [5034.3, 8110.8]]           // marker_238  "Low Yield Mine"
];
diag_log format ["::LooneyBin:: MALDEN FIELDS -- %1 gather zone(s) pinned to the designer's markers", _fieldsPinned];

// MALDEN FEDERAL RESERVE -- the whole feature keys off this marker (dispatch, map marker, the AA
// battery list, the boot lockdown). It does not exist on this map, so it is created here at the ring
// centre. Creating it wakes three previously-inert consumers in AP_server\init.sqf; all three were
// audited before this line went in (see the commit).
if ((getMarkerPos "fed_reserve") isEqualTo [0,0,0]) then {
    createMarker ["fed_reserve", [11197.8, 4459.3]];
    "fed_reserve" setMarkerAlpha 0;   // an anchor, not a label -- the robbery marker is created live
    diag_log format ["[maldenFed] fed_reserve marker created at %1", getMarkerPos "fed_reserve"];
} else {
    diag_log format ["[maldenFed] fed_reserve marker already present at %1", getMarkerPos "fed_reserve"];
};

// MALDEN BANK 2026-07-27. The bank's drill action, the drill prop, the cop's Disable Drill and the
// cyberdeck's bank hack all key off these two markers. Neither exists on this map, and getMarkerPos on a
// missing marker returns [0,0,0] -- a real, reachable spot -- so leaving AP_bank_door_2 unmade would put
// the cop action live for anyone standing in the map's south-west corner. Malden's bank has one door; the
// second marker is created on top of the first so the distance test can only ever mean the real door.
{
    if ((getMarkerPos _x) isEqualTo [0,0,0]) then {
        createMarker [_x, [6234.72, 2863.93, 0.34]];
        _x setMarkerAlpha 0;
        diag_log format ["[maldenBank] %1 marker created at %2", _x, getMarkerPos _x];
    };
} forEach ["AP_bank_door", "AP_bank_door_2"];

// MALDEN PRISON 2026-07-29. Malden's mission.sqm carries 228 markers and NOT ONE of the four the jail
// system addresses, and nothing created them at runtime -- so getMarkerPos returned [0,0,0] for all four,
// which is a real, reachable position rather than an error. Confirmed on the running dev server before
// this block existed: "-JAILPROBE- markers m2=[0,0,0] loonybin=[0,0,0] release2=[0,0,0] corrections=[0,0,0]".
// Two live consequences. fn_jailMe's containment test teleported every prisoner to map origin once a
// second -- AP_jailPoly was still the Altis Pyrgos quad, so inPolygon was false everywhere on a 12800 m
// world and the else-branch fired every tick for the whole sentence. And every range gate keyed on these
// markers was satisfied by anyone standing at origin: shank at 70 m, escape query at 100 m, bounty-hunter
// arrest at 19 m, cop Send-to-Prison at 30 m -- while nobody could gather within 200 m of it.
// The marker sweep further down does NOT clean this: it deletes only markers outside world bounds, and
// x = 0 is neither < 0 nor > worldSize, so [0,0,0] passes every test it makes.
//
// Positions are the designer's own prison, not invented. The yard is his Land_BC_Court_F at
// [9766.07,3894.46], inside the ring of 88 CONNECTED Land_Mil_WallBig_4m_battered_F pieces (traced by
// connectivity, not by bounding box -- the 26 SportGround fence pieces that look like an inner ring are
// six unconnected stubs). The label sits on his marker_16 "Malden Prison" in sqm Layer `Prison`.
// jail_release2 is 8 m OUTSIDE the outer sally-port gate, mirroring Altis where release was 55 m outside
// the containment poly. All four spots were checked for geometry collisions -- nothing but sidewalk
// within 6 m of the release point, and the two yard points sit on the court and its cobblestone pad.
//
// Same guarded shape as fed_reserve and the bank doors above: create only when absent, and say which
// happened, so a designer who later places one of these himself wins and the log records it.
{
    _x params ["_mName", "_mPos"];
    if ((getMarkerPos _mName) isEqualTo [0,0,0]) then {
        createMarker [_mName, _mPos];
        _mName setMarkerAlpha 0;
        diag_log format ["[maldenPrison] %1 marker created at %2", _mName, getMarkerPos _mName];
    } else {
        diag_log format ["[maldenPrison] %1 marker already present at %2", _mName, getMarkerPos _mName];
    };
} forEach [
    ["jail_marker2",         [9767.0, 3893.0, 0]],   // intake / cell spawn, yard centre
    ["jail_marker_loonybin", [9766.1, 3894.5, 0]],   // containment TP-back target, the basketball court
    ["jail_release2",        [9769.3, 3948.0, 0]]    // release point, 8 m outside the outer gate
];

// `corrections` is the one VISIBLE marker of the four -- it is the map label players read, and the one
// fn_startPrisonBreak recolours for the duration of a break (:22-23 red "Prison [Break in Progress]",
// :65-66 back to ColorWEST with the world-name label). Seed it with exactly what that fn restores, so a
// fresh boot and a completed break cannot differ by one label. Marker type is cosmetic; "mil_dot"
// matches the designer's own spawn marker in custom_p3ds/malden_markers.sqf.
if ((getMarkerPos "corrections") isEqualTo [0,0,0]) then {
    createMarker ["corrections", [9765.2, 3895.3, 0]];
    "corrections" setMarkerType "mil_dot";
    "corrections" setMarkerColor "ColorWEST";
    "corrections" setMarkerText format ["%1 Maximum Security Prison", worldName];
    diag_log format ["[maldenPrison] corrections marker created at %1", getMarkerPos "corrections"];
} else {
    diag_log format ["[maldenPrison] corrections marker already present at %1", getMarkerPos "corrections"];
};

// MALDEN PRISON GATES 2026-07-29. The prison's north entrance is a SALLY PORT: the wall steps inward at
// X 9760..9774 into a gatehouse recess holding two gates in series, 7.6 m apart. The INNER one is the
// owner's coordinate and was a client-local createSimpleObject statue with simulation disabled -- no
// doors, no animation sources and no networked object, so animate/animateSource were inert on EVERY
// machine, not merely on the server. Its mapData row is promoted in this same commit; this resolves both
// gates once at boot and publishes them, so no client ever hands the server a gate object.
//
// Measured on the running dev server before the promotion (-GATEPROBE-): the server saw exactly ONE gate
// within 25 m, the outer Land_ConcreteWall_01_l_gate_F at [9769.31,3940.18], doors=1,
// anims=["door_1_move","door_1_locked_move"] -- and NOT the inner gate. That also settled two things:
// the "locked" animation must be filtered out of any drive (APS_fnc_prisonGateSRV does), and the runtime
// position of these objects matches their mapData/sqm value exactly, so the position-frame delta that
// affects the jewelry gate (1.7 m, fn_maldenJewelSRV.sqf:305-312) does not apply here.
//
// Radius 8 m even so: it costs nothing, the two gates are 7.6 m apart and each is searched by its OWN
// class, so a generous radius cannot resolve the wrong one.
[] spawn {
    private _fnc_pick = {
        params ["_pos", "_class"];
        private _hits = nearestObjects [_pos, [_class], 8];
        if (_hits isEqualTo []) exitWith { objNull };
        _hits select 0
    };
    // Wait for the mapData spawn pass rather than guessing a sleep: the inner gate cannot resolve before
    // the row that creates it has run, and a fixed sleep would silently publish objNull on a slow boot.
    private _deadline = time + 120;
    private _gIn = objNull;
    private _gOut = objNull;
    waitUntil {
        uiSleep 2;
        _gIn  = [[9767.504, 3932.509, 0.032], "Land_BackAlley_01_l_gate_F"]     call _fnc_pick;
        _gOut = [[9769.31,  3940.18,  0],     "Land_ConcreteWall_01_l_gate_F"] call _fnc_pick;
        ((!isNull _gIn) && {!isNull _gOut}) || {time > _deadline}
    };
    AP_prisonGateIn  = _gIn;
    AP_prisonGateOut = _gOut;
    publicVariable "AP_prisonGateIn";
    publicVariable "AP_prisonGateOut";
    {
        _x params ["_g", "_tag"];
        diag_log format ["[maldenPrison] %1 = %2 null=%3 at %4 doors=%5 anims=%6", _tag,
            typeOf _g, isNull _g, getPosATL _g,
            if (isNull _g) then {-1} else {
                getNumber (configFile >> "CfgVehicles" >> (typeOf _g) >> "numberOfDoors")},
            if (isNull _g) then {[]} else {animationNames _g}];
    } forEach [[AP_prisonGateIn, "gateIn"], [AP_prisonGateOut, "gateOut"]];
    ["boot"] call APS_fnc_prisonGateSRV;
};

// MALDEN AFRICAN WARLORD 2026-07-28. The Jewelry Emporium's loot has exactly one buyer -- the
// African Warlord fence (core/config/fn_virt_shops.sqf, case "africanwarlord") -- and the heist's
// own pickup message sends the player to find him by name. The fence NPC is moved onto Malden in
// this same commit (core/config/fn_mapData.sqf), but Malden's mission.sqm carries no marker for
// him and a shop nobody can find is not a shop. Markers cannot be added to that .sqm (it is the
// designer's and is never re-saved), so both are created here, in the same guarded shape as the
// bank doors above: create only when absent, and say so in the log.
//
// Styling is copied off the designer's own illegal sites rather than invented. The label matches
// "Black Market" (his marker_214 -- mil_triangle / ColorRed / size 0.75), the only other illegal
// BUYER he marked; the ring matches every illegal-zone ring he drew (illegalfield_1 at the smash
// field, marker_206/208/215 -- ELLIPSE / ColorRed / "Border" brush / 100 m). ColorRed is load
// bearing beyond looks: core/pmenu/fn_settingsInit.sqf maps ColorRed -> Marker_Illegal, so both
// markers obey the player's "Illegal" map-marker slider like every other illegal site.
//
// The ring's 100 m is COSMETIC -- nothing reads a marker's size here. The one consumer of the name
// is fn_clientMobileHQ's gang-area list, and that measures a hard-coded 1000 m from getMarkerPos.
// Both markers survive the MAP CLEANUP sweep further down (it deletes global markers whose x or y
// falls outside 0..worldSize; 8546.79 and 7674.1 are inside a 12800 m world) and both are GLOBAL,
// so they reach clients that join long after this line has run.
private _warlordPos = [8546.79, 7674.1, 0.54];
if ((getMarkerPos "warlord") isEqualTo [0,0,0]) then {
    createMarker ["warlord", _warlordPos];
    "warlord" setMarkerType "mil_triangle";
    "warlord" setMarkerColor "ColorRed";
    "warlord" setMarkerSize [0.75, 0.75];
    "warlord" setMarkerText "African Warlord";
    diag_log format ["[maldenWarlord] warlord marker created at %1", getMarkerPos "warlord"];
} else {
    diag_log format ["[maldenWarlord] warlord marker already present at %1", getMarkerPos "warlord"];
};
if ((getMarkerPos "illegal_warlord") isEqualTo [0,0,0]) then {
    createMarker ["illegal_warlord", _warlordPos];
    "illegal_warlord" setMarkerShape "ELLIPSE";
    "illegal_warlord" setMarkerBrush "Border";
    "illegal_warlord" setMarkerColor "ColorRed";
    "illegal_warlord" setMarkerSize [100, 100];
    diag_log format ["[maldenWarlord] illegal_warlord marker created at %1", getMarkerPos "illegal_warlord"];
} else {
    diag_log format ["[maldenWarlord] illegal_warlord marker already present at %1", getMarkerPos "illegal_warlord"];
};


// mapdb (2026-09-04): the server's own map rows (is_server, on_server) are spawned by
// APS_fnc_mapLoad from the table; its by-class snapshot (localNamespace APS_mapEntities) is filled there too.

// 2026-07-26: the three scripted weed-processor redzones (and the restricted-house flag for the
// one standing inside a house) were deleted with the cannabis field. House-grown cannabis stays;
// there is simply no outdoor weed economy left for these Altis-coordinate markers to serve.
// SIDEWINDER ISLAND label removed 2026-07-27: it was pinned at [13548, 12082.8], an ALTIS position,
// which on a 12.8 km Malden lands in the black void off the edge of the map.

// MAP CLEANUP. The fork inherited a mission full of Altis coordinates, and every marker still carrying
// one paints a label out in the void where there is no world. Sweep them once the late creators have
// had their turn: any GLOBAL marker outside the world gets deleted, and says so in the log.
[] spawn {
    uiSleep 20;
    private _ws = worldSize;
    private _gone = [];
    {
        private _p = getMarkerPos _x;
        if ((_p select 0) < 0 || {(_p select 0) > _ws} || {(_p select 1) < 0} || {(_p select 1) > _ws}) then {
            _gone pushBack format ["%1 (%2) at %3", _x, markerText _x, _p];
            deleteMarker _x;
        };
    } forEach allMapMarkers;
    if (_gone isEqualTo []) then {
        diag_log "::LooneyBin:: MAP CLEANUP -- no off-map markers left";
    } else {
        diag_log format ["::LooneyBin:: MAP CLEANUP -- deleted %1 off-map marker(s):", count _gone];
        { diag_log format ["::LooneyBin::    %1", _x]; } forEach _gone;
    };
};

// ── Moving rebel-outpost aircraft carrier (LooneyBin v1 — translation only) ──────────
//  Picks a random sea position each restart and rigid-translates the carrier + its
//  server-side deck objects + spawn markers there (keeps the original heading).
//  TUNE: edit _carrierSpots ([x,y] sea positions). #1 = the original north-sea spot
//  (known-good). Restart a few times and verify each spot sits on OPEN WATER with no
//  land/seabed clipping; delete any bad one.
//  v1 GAPS to confirm in-game (report for v2 if wrong): the vendor NPC + civ_sea_11/12
//  boat spawns may be client-local / not carrier-owned and might not follow.
if (!isNull AP_aircraftCarrier) then {
    // LooneyBin: ONLY these 3 spots, rotating each restart (owner-set, from 6-fig map grids ->[x,y]x100).
    // CARRIER MUST SIT ON OPEN WATER -- restart a few times + check the LB_CARRIER log / in-game; if any
    // spot clips land/seabed, swap it for a real world [x,y] sea position.
    private _carrierSpots = [[15200.0, 13700.0],    // 1 · grid 152137  (VERIFY WATER — central Altis, may be land)
        [14200.0,  8300.0],    // 2 · grid 142083  (VERIFY WATER)
        [ 1400.0, 13700.0]     // 3 · grid 014137  (VERIFY WATER — far west)
    ];
    private _oldPos = getPosWorld AP_aircraftCarrier;
    private _pick   = selectRandom _carrierSpots;
    private _off    = [(_pick select 0) - (_oldPos select 0), (_pick select 1) - (_oldPos select 1), 0];
    if (vectorMagnitude _off > 1) then {{if (local _x && {!(isPlayer _x)}) then {_x setPosWorld ((getPosWorld _x) vectorAdd _off);};
        } forEach (nearestObjects [_oldPos, [], 320]); {if !((getMarkerPos _x) isEqualTo [0,0,0]) then {
                _x setMarkerPos ((getMarkerPos _x) vectorAdd _off);};
        } forEach ["civ_air_carrier_1", "civ_air_carrier_2", "civ_air_carrier_3", "Rebelop_7"];
        diag_log format ["LB_CARRIER moved to %1 (offset %2)", _pick, _off];};};

// Cartel flags + capture markers MUST exist before the server core starts: its cartelOwnSave,
// oilRubber and auto-deposit jobs all waitUntil on these flag objects, and Malden's sqm has
// neither the named flag objects nor the capture markers the inherited system expects.
[] execVM "custom_p3ds\malden_cartels.sqf";
// Luxe Suites shared helpers -- loaded BEFORE the server core and before
// malden_buildings (whose door sweep stamps ap_luxDoorBase), so suite code on the
// server derives oids from the same one definition the client uses.
call compile preprocessFileLineNumbers "core\suites\fn_suiteData.sqf";
[] spawn compile PreprocessFileLineNumbers "\AP_server\init.sqf";
// LooneyBin: SpyGlass server-side guard removed (was: failMission loop unless profileName ~ sylu/JS)

// owner 2026-06-18: seal the Loony Bin at boot -- lock the church/hospital doors + front gate, restore the
// breach wall/box. Delayed so the server init (SRV_loonyBinData + TON fns) and the mapData church both exist.
// The reset is key-guarded (audit r2heist): "boot" makes sure the server-only key exists, then the reset carries it.
[] spawn { uiSleep 25; if (!isNil "APS_fnc_loonyBinSRV") then { ["boot"] call APS_fnc_loonyBinSRV;
    ["loonyBinReset", [localNamespace getVariable "APS_lbKey"]] call APS_fnc_loonyBinSRV; }; };
// Custom .p3d buildings are map rows (mapdb, 2026-09-04): APS_fnc_mapLoad spawns the server's
// local copies (on_server). The tower door systems still find them by model sweep, after the
// suite data loaded above -- lux_doors_data ordering matters (fn_suiteData).
[] execVM "custom_p3ds\malden_markers.sqf";
[] execVM "custom_p3ds\door_sweep.sqf";

// Luxe Suites: NO server-side kiosk tag. The lobby kiosk is a mapData object, and
// mapData spawns through AP_fnc_createVehicleLocal -- CLIENT-LOCAL and
// zone-streamed, so the server can never see it and a client only holds it while
// fn_dynamicMapSystem has that zone loaded. (Same law that hides the jewelry-
// district crane from the server.) The scroll action therefore matches on the
// classname, which is unique on this map, and fn_suiteKiosk resolves the tower.
// DEV INSTRUMENTATION -- position-frame probe, logs to [FRAMEPROBE] in loonydev.log. Delete this
// line before any live deploy. It spawns seven prison objects, measures them and deletes them again.
[] execVM "debug\frame_probe.sqf";
// The parking-garage probes ([GARAGEPROBE] terrain fit, [GARAGESITE] flat-site scan) were
// DELETED 2026-09-04 with the garage itself. Removing the .sqf without this execVM left
// "Warning Message: Script debug\garageprobe.sqf not found" on every boot -- execVM on a
// missing file warns rather than throwing, which is why nothing else noticed.
// DEV INSTRUMENTATION -- rotation-frame probe (debug\frame_angles.sqf + tools/frame_solve.py).
// It has already answered its question (the convention is recorded in frame_solve.py's header), so
// it is left UNHOOKED rather than run every boot. Re-enable this line to re-verify after any
// mission.sqm change:  [] spawn { uiSleep 20; [] execVM "debug\frame_angles.sqf"; };
// DEV INSTRUMENTATION 2026-07-27 -- server half of the 50km slot-hold fall diagnosis. Delete this line.
[] execVM "debug\simProbeServer.sqf";

// PR10: the 2026-07-27 "restore simulation globally" loop is GONE. Its premise -- that the 201 sqm
// player slots carry disableSimulation=1 -- stopped being true when tools/sqm_slot_sim.py stripped the
// attribute (verified 2026-08-20: all 540 disableSimulation=1 entries in the shipped sqm are decorative
// objects, none is a player slot, and the server probe shows sim=true at every JOIN with this loop
// firing zero times all day). What remained was a trap: the one job it could still do is fire
// enableSimulationGlobal at a player some future code deliberately froze -- a GLOBAL enable overrides
// the owner's own local freeze, which is precisely the 50 km free-fall class this subsystem exists to
// prevent. The hold is client-local (initPlayerLocal.sqf:18) and the release path pre-positions the
// networked copy via APS_fnc_preSpawnPos; nothing needs the server to force simulation on.
// LooneyBin (owner 2026-07-03): swap derelict industrial sheds (Land_u_Shed_Ind_F) for intact, buyable ones.
[] execVM "custom_p3ds\replace_sheds.sqf";
// LooneyBin (owner 2026-07-11): MALDEN MAKEOVER boot pass -- re-swap every malden=1 house (terrain originals
// are pristine each restart). At +9s: after replace_sheds' +6s spawn + immediate tag, so the makeover's own
// tag re-run is the last word on identity vars.
[] spawn { uiSleep 9; if (!isNil "APS_fnc_maldenSRV") then { ["boot"] call APS_fnc_maldenSRV; }; };
// LooneyBin composition zones (owner 2026-07-10): serverSide zones spawn on the dedicated server at boot;
// every client streams its own local copies by proximity. RETIRED with mapdb (2026-09-04): the only
// registered zone was a disabled example; compositions/cryptorig.sqf (the mining rig) is unrelated and stays.


// ArmaQuest world-state resolvers (WORLD_STATE_SPEC.md). After compZones so the
// systems whose globals these read have had their boot pass; registration itself
// only stores code against keys and never evaluates a resolver.
[] call AP_fnc_aqWorld;
// Publish the gang -> faction mirror once at boot. World resolvers run during
// offer building and must not query a database, so the mapping has to be in
// memory before any giver is opened.
["publish"] call APS_fnc_gangAlignSRV;

// ---------------------------------------------------------------- UI serving
// Can this server compress a page at all? The whole serve path (APS_fnc_webPageSRV)
// rests on ctrlWebBrowserAction "Deflate", which the BIKI says works with
// controlNull -- but a DEDICATED server has no display and no browser control, and
// "works with controlNull" was written about a client. If the browser subsystem is
// not there, Deflate returns "" and every page override silently never happens,
// which looks exactly like "the server has no newer copy" and would never be
// noticed. So prove it once, out loud, at boot.
//
// This is a diagnostic, not a gate: nothing branches on the result. A failure here
// means clients keep their PBO pages, which is the designed fallback.
[] spawn {
    // Deliberately repetitive: deflate on near-random text tells you nothing, and a
    // round trip that only proves "empty in, empty out" proves nothing either.
    private _sample = "<!doctype html><title>probe</title><p>deflate round trip deflate round trip deflate round trip</p>";
    private _packed = controlNull ctrlWebBrowserAction ["Deflate", _sample];
    if (_packed isEqualTo "") exitWith {
        diag_log "[AP][webserve] PROBE FAIL: Deflate returned empty on this server -- page serving is INERT, clients will use their PBO pages.";
    };
    private _back = controlNull ctrlWebBrowserAction ["Inflate", _packed];
    if (_back isEqualTo _sample) then {
        diag_log format ["[AP][webserve] PROBE OK: Deflate/Inflate round-trips on the server (%1 -> %2 chars). Page serving is available.", count _sample, count _packed];
    } else {
        diag_log format ["[AP][webserve] PROBE FAIL: round trip did not match (%1 chars in, %2 back) -- page serving is INERT.", count _sample, count _back];
    };

    // Second half of the chain, and the half that is actually load-bearing: can
    // the server READ a page at all? The first version of this used loadFile and
    // the engine answered `Trying to execute a disabled command 'loadfile'`,
    // which killed this spawn outright -- that is why the read goes through
    // PySQF now (see APS_fnc_webPageSRV's header).
    //
    // Expect this to report UNAVAILABLE until the daemon is started with the
    // `webpages` module in --modules. Until then every page override is a no-op
    // and clients render their PBO copies, which is the designed fallback.
    private _probePage = "ui/html/loot.html";
    private _r = ["webpages.read", [_probePage]] call APS_fnc_pysqfCall;
    if (!(_r isEqualType []) || {!((_r param [0, false]) isEqualTo true)}) then {
        diag_log format ["[AP][webserve] PROBE: page source UNAVAILABLE (webpages.read said %1). Add `webpages` to the PySQF daemon's --modules to enable serving; until then clients use their PBO pages.", _r];
    } else {
        private _bytes = _r param [1, ""];
        if (_bytes isEqualTo "") then {
            diag_log format ["[AP][webserve] PROBE: webpages module is up but %1 is not on disk -- nothing to serve for it.", _probePage];
        } else {
            diag_log format ["[AP][webserve] PROBE OK: served %1 from disk (%2 chars, %3 deflated). UI can now ship without a client repack.", _probePage, count _bytes, count (controlNull ctrlWebBrowserAction ["Deflate", _bytes])];
        };
    };

    // Third link: the handshake. A client with no version tag asks with "", and
    // the daemon compares the file against the mission baseline. Right after a
    // deploy the two are identical, so the expected answer is "unchanged" -- a
    // "page" here means the serve root and the mission tree have drifted (or the
    // daemon predates webpages.serve and the call failed), and every open of
    // that screen will re-boot it after a network round trip.
    private _h = ["webpages.serve", [_probePage, ""]] call APS_fnc_pysqfCall;
    if (!(_h isEqualType []) || {!((_h param [0, false]) isEqualTo true)}) then {
        diag_log format ["[AP][webserve] PROBE: handshake UNAVAILABLE (webpages.serve said %1) -- daemon predates it? Every served page will be shipped and re-booted on every open.", _h];
    } else {
        (_h param [1, []]) params [["_status", "", [""]], "", ["_version", "", [""]]];
        diag_log format ["[AP][webserve] PROBE: handshake for %1 with no tag -> '%2' (%3)%4", _probePage, _status, _version select [0, 8],
            ["", " -- serve root differs from the mission tree; clients will re-boot this screen on every open until they match"] select (_status isEqualTo "page")];
    };
};


[] execVM "custom_p3ds\lux_footprint.sqf";   // tower is built on a fuel station; clear it.
// mapdb NOTE: lux_footprint.sqf hard-codes the skyscraper30 centre [7216.602, 7777.412]; the tower
// itself is a map_objects row (model custom_p3ds\skyscraper30_r17.p3d). Move one, move the other.
// 2026-09-22: skyscraper30 (row 9649) and the Luxe Suites kiosk (row 13678) are soft-deleted; the
// Vertical City addon tower stands on skyscraper30's site instead. Luxe Suites is therefore off (all
// suite code exits on a null tower). lux_footprint.sqf still clears the fuel station at the OLD
// coordinates above, which the tower had already left before this change.
[] execVM "custom_p3ds\vcity_tower.sqf";

// Boot invariant (owner 2026-09-11): the five town spawn points behind each civ_spawn_N are map-layer
// markers, so an Eden drag can put one inside a wall. One line in the log says whether they are all
// still standable; the positions themselves were found by debug\probe_townspawn.sqf.
[] spawn { uiSleep 30; [] call AP_fnc_spawnScatterCheck; };
