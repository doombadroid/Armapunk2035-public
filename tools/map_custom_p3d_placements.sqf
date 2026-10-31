// FROZEN MIGRATION INPUT (tools/map_migrate_v3.py) -- verbatim custom_p3ds/malden_buildings.sqf as of commit 74cb8aea^, 2026-09-04. Not packed, not executed.
// Malden custom buildings (ProjectMaldenMerge). Placement authored by the map designer in Eden as
// Land_HelipadEmpty_F anchors, stripped out of mission.sqm by sqm_strip_anchors.py and re-created
// here as simple objects -- 39 buildings + 16 bridge pieces.
//
// Called from BOTH initServer.sqf and initPlayerLocal.sqf, exactly like custom_p3ds/load.sqf.
// NOT from init.sqf: that runs before the world is ready on clients, so createSimpleObject silently
// no-ops there and the buildings appear server-side only. That lesson is already recorded in
// init.sqf for the LooneyBin rig; the designer file it came from placed these in init.sqf.
//
// EVERY call MUST pass the third argument `true`. createSimpleObject is NOT local by default --
// since Arma 3 1.96 the signature is [shape, positionWorld, local] with local defaulting to FALSE,
// i.e. the two-argument form creates a GLOBAL, replicated object. With this file running on the
// server AND on every client that produced 55 x (1 + players) copies of every custom building,
// all replicated to everyone. Local objects cost no network traffic and JIP handles itself,
// because each machine builds its own set.
// Apparently in arma you CAN actually dynamicaly call .p3d files from the mission folder without a cannonical path neat
//
// ORDER IS LOAD-BEARING: setDir MUST come BEFORE setObjectScale on every line.
// setDir rewrites a simple object's transform matrix and RESETS its scale to 1. Verified in-engine
// 2026-07-25: `setObjectScale 0.5` then `setDir 270` -> getObjectScale returns 1; `setDir 270` then
// `setObjectScale 0.5` -> returns 0.5. This file originally called scale first on all 55 lines, so
// every scaled building silently rendered at 1.0: the Grand Palace came out 113x86x28m instead of
// 79x60x20m and half sunk (its z was authored for 0.7 but it drew at full size, pushing the base
// ~7m underground), the 14m mentalasylum13 never got its x3, and both signs never got their x1.5.
// It also made scale edits look inert -- changing the palace 0.7 -> 0.5 produced no visible change
// because both were being wiped to 1. The designer's own sqm inits get this right (setDir, then
// setObjectScale), which is why the original mission looks correct in the editor.
// All scale/position values below are the designer's, unchanged.
private _MALDEN = getMissionPath "custom_p3ds\";
// Models moved out of the mission root on 2026-08-19. The prefix carries the folder, so
// every `_MALDEN + "X.p3d"` placement line below is unchanged -- 86 of them, none touched.

// Initialize object variable
private _o = objNull;


// =========================================================================
// 1. BRIDGE PLACEMENT (16 Objects)
// =========================================================================

// --- BridgePieces (x16) ---
_o = createSimpleObject [_MALDEN + "BridgeStraight.p3d", [8512.527, 3765, 0], true]; _o setDir 0; _o setObjectScale 1;
_o = createSimpleObject [_MALDEN + "BridgeStraight.p3d", [8562.527, 3765, 0], true]; _o setDir 0; _o setObjectScale 1;
_o = createSimpleObject [_MALDEN + "BridgeStraight.p3d", [8612.527, 3765, 0], true]; _o setDir 0; _o setObjectScale 1;
_o = createSimpleObject [_MALDEN + "BridgeStraight.p3d", [8662.527, 3765, 0], true]; _o setDir 0; _o setObjectScale 1;
_o = createSimpleObject [_MALDEN + "BridgeStraight.p3d", [8712.527, 3765, 0], true]; _o setDir 0; _o setObjectScale 1;
_o = createSimpleObject [_MALDEN + "BridgeStraight.p3d", [8762.527, 3765, 0], true]; _o setDir 0; _o setObjectScale 1;
_o = createSimpleObject [_MALDEN + "BridgeStraight.p3d", [8812.527, 3765, 0], true]; _o setDir 0; _o setObjectScale 1;
_o = createSimpleObject [_MALDEN + "BridgeStraight.p3d", [8862.527, 3765, 0], true]; _o setDir 0; _o setObjectScale 1;
_o = createSimpleObject [_MALDEN + "BridgeMiddle.p3d",   [8912.527, 3765, 0], true]; _o setDir 0; _o setObjectScale 1; // The Middle Piece
_o = createSimpleObject [_MALDEN + "BridgeStraight.p3d", [8962.527, 3765, 0], true]; _o setDir 0; _o setObjectScale 1;
_o = createSimpleObject [_MALDEN + "BridgeStraight.p3d", [9012.527, 3765, 0], true]; _o setDir 0; _o setObjectScale 1;
_o = createSimpleObject [_MALDEN + "BridgeStraight.p3d", [9062.527, 3765, 0], true]; _o setDir 0; _o setObjectScale 1;
_o = createSimpleObject [_MALDEN + "BridgeStraight.p3d", [9112.527, 3765, 0], true]; _o setDir 0; _o setObjectScale 1;
_o = createSimpleObject [_MALDEN + "BridgeStraight.p3d", [9162.527, 3765, 0], true]; _o setDir 0; _o setObjectScale 1;
_o = createSimpleObject [_MALDEN + "BridgeStraight.p3d", [9212.527, 3765, 0], true]; _o setDir 0; _o setObjectScale 1;
_o = createSimpleObject [_MALDEN + "BridgeStraight.p3d", [9262.527, 3765, 0], true]; _o setDir 0; _o setObjectScale 1;


// =========================================================================
// 2. PROJECT MALDEN CUSTOM BUILDINGS (39 Placements / 10 Models)
// =========================================================================

// --- Bank  (x1) ---
_o = createSimpleObject [_MALDEN + "Bank.p3d", [6244.423, 2870.758, 65.713], true]; _o setDir 180; _o setObjectScale 1;

// --- RebelRig  (x1) ---
_o = createSimpleObject [_MALDEN + "RebelRig.p3d", [6221.131, 11978.708, -10.938], true]; _o setDir 180; _o setObjectScale 1;

// --- mentalasylum13: REMOVED 2026-08-01. Replaced by a Land_Hotel_02_F placed via the map
// pipeline (fn_mapData row at [4254.6, 3909.3]) after the custom p3d's collision saga -- full
// post-mortem in TODO.md ("mentalasylum13") and p3dmemories.md section 4.

// --- EvidenceSign  (x1) ---
_o = createSimpleObject [_MALDEN + "EvidenceSign.p3d", [9549.044, 4202.292, 37.389], true]; _o setDir 315.8; _o setObjectScale 1.5;

// --- FederalReserveSign  (x1) ---
_o = createSimpleObject [_MALDEN + "FederalReserveSign.p3d", [11218.648, 4335.188, 18.736], true]; _o setDir 332.6; _o setObjectScale 1.5;

// --- JewelryBuildingModel  (x1) ---
_o = createSimpleObject [_MALDEN + "JewelryBuildingModel.p3d", [7545.757, 10570.099, 35.734], true]; _o setDir 358.8; _o setObjectScale 1;

// --- HQMesh  (x3) ---
_o = createSimpleObject [_MALDEN + "HQMesh_mcso10.p3d", [8551.151, 3226.337, 33.666], true]; _o setDir 180; _o setObjectScale 1;
_o = createSimpleObject [_MALDEN + "HQMesh_mcso10.p3d", [5588.380, 4227.059, 106.826], true]; _o setDir 180; _o setObjectScale 1;
_o = createSimpleObject [_MALDEN + "HQMesh_mcso10.p3d", [3374.951, 6301.848, 235.165], true]; _o setDir 180; _o setObjectScale 1;

// --- PoliceHQWallLong  (x27) ---
_o = createSimpleObject [_MALDEN + "PoliceHQWallLong.p3d", [8557.775, 3248.894, 31.733], true]; _o setDir 320; _o setObjectScale 1;
_o = createSimpleObject [_MALDEN + "PoliceHQWallLong.p3d", [8550.845, 3257.144, 31.684], true]; _o setDir 320; _o setObjectScale 1;
_o = createSimpleObject [_MALDEN + "PoliceHQWallLong.p3d", [8541.939, 3261.480, 31.634], true]; _o setDir 271.9; _o setObjectScale 1;
_o = createSimpleObject [_MALDEN + "PoliceHQWallLong.p3d", [8531.076, 3261.820, 31.585], true]; _o setDir 271.9; _o setObjectScale 1;
_o = createSimpleObject [_MALDEN + "PoliceHQWallLong.p3d", [8520.126, 3262.151, 31.505], true]; _o setDir 271.9; _o setObjectScale 1;
_o = createSimpleObject [_MALDEN + "PoliceHQWallLong.p3d", [8518.658, 3200.299, 30.304], true]; _o setDir 269.1; _o setObjectScale 1;
_o = createSimpleObject [_MALDEN + "PoliceHQWallLong.p3d", [8529.616, 3200.531, 31.000], true]; _o setDir 269.1; _o setObjectScale 1;
_o = createSimpleObject [_MALDEN + "PoliceHQWallLong.p3d", [8540.590, 3200.728, 31.949], true]; _o setDir 269.1; _o setObjectScale 1;
_o = createSimpleObject [_MALDEN + "PoliceHQWallLong.p3d", [8551.505, 3200.908, 32.586], true]; _o setDir 269.1; _o setObjectScale 1;
_o = createSimpleObject [_MALDEN + "PoliceHQWallLong.p3d", [8514.116, 3257.127, 31.467], true]; _o setDir 181.9; _o setObjectScale 1;
_o = createSimpleObject [_MALDEN + "PoliceHQWallLong.p3d", [8513.776, 3246.143, 31.375], true]; _o setDir 181.9; _o setObjectScale 1;
_o = createSimpleObject [_MALDEN + "PoliceHQWallLong.p3d", [8513.375, 3235.189, 31.343], true]; _o setDir 181.9; _o setObjectScale 1;
_o = createSimpleObject [_MALDEN + "PoliceHQWallLong.p3d", [8512.730, 3205.488, 30.225], true]; _o setDir 181.9; _o setObjectScale 1;
_o = createSimpleObject [_MALDEN + "PoliceHQWallLong.p3d", [5528.076, 4225.441, 106.560], true]; _o setDir 0; _o setObjectScale 1;
_o = createSimpleObject [_MALDEN + "PoliceHQWallLong.p3d", [5528.115, 4214.390, 106.577], true]; _o setDir 0; _o setObjectScale 1;
_o = createSimpleObject [_MALDEN + "PoliceHQWallLong.p3d", [5527.911, 4247.202, 106.546], true]; _o setDir 0; _o setObjectScale 1;
_o = createSimpleObject [_MALDEN + "PoliceHQWallLong.p3d", [5533.750, 4208.940, 106.574], true]; _o setDir 270; _o setObjectScale 1;
_o = createSimpleObject [_MALDEN + "PoliceHQWallLong.p3d", [5544.792, 4208.988, 106.615], true]; _o setDir 270; _o setObjectScale 1;
_o = createSimpleObject [_MALDEN + "PoliceHQWallLong.p3d", [5527.956, 4258.271, 106.035], true]; _o setDir 0; _o setObjectScale 1;
_o = createSimpleObject [_MALDEN + "PoliceHQWallLong.p3d", [5544.297, 4263.823, 105.511], true]; _o setDir 90; _o setObjectScale 1;
_o = createSimpleObject [_MALDEN + "PoliceHQWallLong.p3d", [5533.254, 4263.771, 105.551], true]; _o setDir 90; _o setObjectScale 1;
_o = createSimpleObject [_MALDEN + "PoliceHQWallLong.p3d", [5566.428, 4263.876, 105.566], true]; _o setDir 90; _o setObjectScale 1;
_o = createSimpleObject [_MALDEN + "PoliceHQWallLong.p3d", [5555.385, 4263.824, 105.607], true]; _o setDir 90; _o setObjectScale 1;
_o = createSimpleObject [_MALDEN + "PoliceHQWallLong.p3d", [5588.572, 4264.030, 105.737], true]; _o setDir 90; _o setObjectScale 1;
_o = createSimpleObject [_MALDEN + "PoliceHQWallLong.p3d", [5577.529, 4263.978, 105.777], true]; _o setDir 90; _o setObjectScale 1;
_o = createSimpleObject [_MALDEN + "PoliceHQWallLong.p3d", [5594.174, 4257.887, 105.608], true]; _o setDir 180; _o setObjectScale 1;
_o = createSimpleObject [_MALDEN + "PoliceHQWallLong.p3d", [5594.125, 4246.820, 105.586], true]; _o setDir 180; _o setObjectScale 1;

// --- MaldenGrandPalace  (x1) --- (renamed from AsylumGrandPalaceBuilding by the owner)
// The filename is also a CACHE BUSTER. Arma caches loaded models by path, and the mission root is
// mpmissions\__cur_mp.<WORLD>\ -- world-based, so it is byte-identical on every build. Replacing a
// .p3d in place therefore ships the new file but the client keeps rendering the copy it already
// loaded, until Arma is fully exited. Changing the name changes the path and forces a reload.
// Revision suffix _rN is the cache buster -- bump it on EVERY .p3d edit (see p3dmemories.md 2).
// _r5 (2026-09-02) = the pre-neon base again: owner had the "After Dark" neon sign taken off the
// courtyard arch niche. _r2.._r4 were that sign grafted onto this exact model (blender_work/
// graft_neon_v4.py, BASE = MaldenGrandPalaceBuilding.p3d, sha1 3bd48366...); the base carries no
// neon material and no sign geometry. New revision suffix because Arma caches models BY PATH.
_o = createSimpleObject [_MALDEN + "MaldenGrandPalaceBuilding_r5.p3d", [7214.374, 7862.500, 174.676], true]; _o setDir 270; _o setObjectScale 0.7;
// Guard: if someone re-orders these calls, every scaled building silently reverts to 1.0 with no error.
// Fail loudly in the log instead.
if (isServer && {(getObjectScale _o) != 0.7}) then {
    diag_log format ["[Armapunk2035] WARNING palace scale is %1, expected 0.7 -- setObjectScale/setDir ordering regression in malden_buildings.sqf", getObjectScale _o];
};

// --- PalaceShop  (x2) ---
_o = createSimpleObject [_MALDEN + "PalaceShop.p3d", [7193.748, 7932.295, 172.050], true]; _o setDir 10; _o setObjectScale 0.7;
_o = createSimpleObject [_MALDEN + "PalaceShop.p3d", [7287.143, 7952.742, 172.404], true]; _o setDir 180; _o setObjectScale 0.7;
_o = createSimpleObject [_MALDEN + "HQMesh_mcso10.p3d", [7449.942, 8092.055, 172.313], true]; _o setDir 211; _o setObjectScale 1;
_o = createSimpleObject [_MALDEN + "PoliceHQWallLong.p3d", [7397.417, 8121.727, 172.047], true]; _o setDir 31; _o setObjectScale 1;
_o = createSimpleObject [_MALDEN + "PoliceHQWallLong.p3d", [7391.760, 8112.233, 172.064], true]; _o setDir 31; _o setObjectScale 1;
_o = createSimpleObject [_MALDEN + "PoliceHQWallLong.p3d", [7408.484, 8140.464, 172.033], true]; _o setDir 31; _o setObjectScale 1;
_o = createSimpleObject [_MALDEN + "PoliceHQWallLong.p3d", [7393.783, 8104.659, 172.061], true]; _o setDir 301; _o setObjectScale 1;
_o = createSimpleObject [_MALDEN + "PoliceHQWallLong.p3d", [7403.273, 8099.014, 172.102], true]; _o setDir 301; _o setObjectScale 1;
_o = createSimpleObject [_MALDEN + "PoliceHQWallLong.p3d", [7414.223, 8149.930, 171.522], true]; _o setDir 31; _o setObjectScale 1;
_o = createSimpleObject [_MALDEN + "PoliceHQWallLong.p3d", [7431.089, 8146.272, 170.998], true]; _o setDir 121; _o setObjectScale 1;
_o = createSimpleObject [_MALDEN + "PoliceHQWallLong.p3d", [7421.598, 8151.915, 171.038], true]; _o setDir 121; _o setObjectScale 1;
_o = createSimpleObject [_MALDEN + "PoliceHQWallLong.p3d", [7450.087, 8134.919, 171.053], true]; _o setDir 121; _o setObjectScale 1;
_o = createSimpleObject [_MALDEN + "PoliceHQWallLong.p3d", [7440.595, 8140.562, 171.094], true]; _o setDir 121; _o setObjectScale 1;
_o = createSimpleObject [_MALDEN + "PoliceHQWallLong.p3d", [7469.147, 8123.646, 171.224], true]; _o setDir 121; _o setObjectScale 1;
_o = createSimpleObject [_MALDEN + "PoliceHQWallLong.p3d", [7459.654, 8129.290, 171.264], true]; _o setDir 121; _o setObjectScale 1;
_o = createSimpleObject [_MALDEN + "PoliceHQWallLong.p3d", [7470.786, 8115.495, 171.095], true]; _o setDir 211; _o setObjectScale 1;
_o = createSimpleObject [_MALDEN + "PoliceHQWallLong.p3d", [7465.043, 8106.034, 171.073], true]; _o setDir 211; _o setObjectScale 1;
_o = createSimpleObject [_MALDEN + "HQMesh_mcso10.p3d", [10538.991, 4028.176, 13.733], true]; _o setDir 207; _o setObjectScale 1;
_o = createSimpleObject [_MALDEN + "PoliceHQWallLong.p3d", [10484.525, 4054.112, 13.467], true]; _o setDir 27; _o setObjectScale 1;
_o = createSimpleObject [_MALDEN + "PoliceHQWallLong.p3d", [10479.544, 4044.247, 13.484], true]; _o setDir 27; _o setObjectScale 1;
_o = createSimpleObject [_MALDEN + "PoliceHQWallLong.p3d", [10494.259, 4073.576, 13.453], true]; _o setDir 27; _o setObjectScale 1;
_o = createSimpleObject [_MALDEN + "PoliceHQWallLong.p3d", [10482.090, 4036.833, 13.481], true]; _o setDir 297; _o setObjectScale 1;
_o = createSimpleObject [_MALDEN + "PoliceHQWallLong.p3d", [10491.950, 4031.863, 13.522], true]; _o setDir 297; _o setObjectScale 1;
_o = createSimpleObject [_MALDEN + "PoliceHQWallLong.p3d", [10499.322, 4083.418, 12.942], true]; _o setDir 27; _o setObjectScale 1;
_o = createSimpleObject [_MALDEN + "PoliceHQWallLong.p3d", [10516.403, 4080.946, 12.418], true]; _o setDir 117; _o setObjectScale 1;
_o = createSimpleObject [_MALDEN + "PoliceHQWallLong.p3d", [10506.541, 4085.913, 12.458], true]; _o setDir 117; _o setObjectScale 1;
_o = createSimpleObject [_MALDEN + "PoliceHQWallLong.p3d", [10536.146, 4070.946, 12.473], true]; _o setDir 117; _o setObjectScale 1;
_o = createSimpleObject [_MALDEN + "PoliceHQWallLong.p3d", [10526.283, 4075.913, 12.514], true]; _o setDir 117; _o setObjectScale 1;
_o = createSimpleObject [_MALDEN + "PoliceHQWallLong.p3d", [10555.946, 4061.030, 12.644], true]; _o setDir 117; _o setObjectScale 1;
_o = createSimpleObject [_MALDEN + "PoliceHQWallLong.p3d", [10546.083, 4065.997, 12.684], true]; _o setDir 117; _o setObjectScale 1;
_o = createSimpleObject [_MALDEN + "PoliceHQWallLong.p3d", [10558.148, 4053.013, 12.515], true]; _o setDir 207; _o setObjectScale 1;
_o = createSimpleObject [_MALDEN + "PoliceHQWallLong.p3d", [10553.081, 4043.174, 12.493], true]; _o setDir 207; _o setObjectScale 1;


// =========================================================================
// 3. SKYSCRAPER (generated, not designer-authored)
// =========================================================================

// --- Skyscraper20 (x1), SW La Trinite ---
// 20 enterable floors (4 rooms + ring corridor each), open lobby, switchback core
// stair, open elevator shaft (deliberate fall hazard), roof deck with helipad.
// Generated from the owner's three.js prototype by scratchpad/skyscraper/ (see its
// README for the regen pipeline); MLOD with visual/shadow/Geometry/Roadway LODs
// matching the palace conventions. Model origin is the bbox CENTER (engine
// autocenters, p3dmemories.md 3), so z = terrain + halfHeight; the runtime terrain
// query keeps the base flush if the placement shifts. halfHeight 38.595 is baked
// into the model bbox -- regen prints it; update BOTH together.
// _rN suffix = cache buster: bump on EVERY p3d edit (p3dmemories.md 2).
// --- Skyscraper20 (x1), SW La Trinite --- and --- Skyscraper30 "Lux" (x1) ---
// STANDARD PLACEMENT LINES so the map pipeline can parse/rewrite them and the
// towers exist as MaldenEdit anchors + compositions (make_compositions.py adds
// a composition-local Z OFFSET of halfHeight, so a dropped anchor lands at
// terrain + halfHeight automatically). z here = terrain + halfHeight - 0.15 at
// the current sites. Door systems attach in the model-sweep BELOW the
// placement list, so designer-moved or newly dropped towers wire themselves.
// b3/v11/v2 revs (2026-08-06): all three buildings grew a 3 m foundation
// plinth (autocenter shifts -1.5, so same-ground z = old z - 1.5 + nothing:
// z here = terrain-cut-the-plinth placement, lobby/L1 floor ~0.15 under).
// The jewelry-emporium tower pair and the La Trinite garage were DELETED on
// the owner's call -- they re-place everything from the MaldenEdit
// compositions ("MAD Building ..."), which carry the right alt offsets.
_o = createSimpleObject [_MALDEN + "skyscraper30_r17.p3d", [7216.602, 7777.412, 226.049], true]; _o setDir 146; _o setObjectScale 1;

// =========================================================================
// 4. TOWER DOOR SYSTEMS (model sweep — placement-independent)
// =========================================================================
// The door spawners find their buildings by model, so towers stay fully
// editable/movable via the map pipeline; EVERY instance gets wired (the
// spawners append into shared flat state arrays at a per-instance base).
// The sweep runs in a delayed spawn so it fires strictly after every
// placement line in this file — the map pipeline appends NEW placements at
// EOF, i.e. below this block (that once left a fresh tower doorless), and
// the delay makes the textual position irrelevant. Wiring is serialized
// per instance: concurrent spawner bodies would interleave their pushBacks
// and scramble the flat door indices.
[] spawn {
    sleep 2;   // every placement line above/below runs in ms; leaves settle
               // (do not name the spawn command in this comment — the map
               // pipeline's count gate greps for it substring-wise)
    {
        _x params ["_m", "_fns"];
        private _t = (allSimpleObjects []) select { _m in toLower ((getModelInfo _x) select 0) };
        {
            private _b = _x;
            {
                private _h = [_b] execVM _x;
                waitUntil { scriptDone _h };
            } forEach _fns;
        } forEach _t;
        if (count _t > 0) then {
            diag_log format ["[APDOORS] %1: wired %2 instance(s)", _m, count _t];
        };
    } forEach [
        ["skyscraper20_r14", ["custom_p3ds\skyscraper_doors.sqf"]],
        // v18 removed the hologram layer from the tower (no HOLO_*, no ad wall,
        // no TICKER_screen_*), so lux_ticker.sqf is UNWIRED: it drew a crown
        // ticker onto screens that no longer exist. The script and its generated
        // point data stay in the repo for when the designer brings the holograms
        // back -- re-add it here and regenerate lux_ticker_data.sqf then.
        ["skyscraper30_r17",  ["custom_p3ds\lux_doors.sqf",
                              "custom_p3ds\lux_fixtures.sqf",
                              "custom_p3ds\lux_freefall.sqf"]]
    ];
};
// The La Trinite parking garage was REMOVED 2026-09-04 (owner: not using it). Model
// ap_garage_5f_r3.p3d, its earlier revisions and the whole scratchpad/skyscraper garage
// pipeline went with it. It stood at [7161.748, 7753.046, 174.645] setDir 330 -- recorded
// here because the site is now empty and someone will ask what used to be there.
