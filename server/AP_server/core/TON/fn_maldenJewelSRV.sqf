/*
    APS_fnc_maldenJewelSRV -- Malden wiring for the Jewelry Emporium heist.

    Altis binds three Eden-named objects from mission.sqm init lines -- AP_jewerlySafe,
    AP_jewerlyEmporium and AP_jewerlyContainer -- which is why none of them has an assignment
    anywhere in the tree. Malden's sqm has none of them, and all three are read inside SCROLL-MENU
    CONDITIONS, where an undefined variable raises rather than warning. So they are bound here even
    where the heist does not use them: an objNull binding makes a condition simply not match, which
    is the difference between "the action never offers" and "the menu throws".

    The safe does not exist on this map at all, so it is spawned. The drill anchors on the compound's
    back-alley gate rather than on the building: the building is a client-local createSimpleObject,
    and the Fed's gate already proved cursorObject on a large flat structure returns the paving
    underfoot. The drill therefore gates on PROXIMITY to this anchor, not on cursor identity.

    2026-07-28: THE GATE NOW FOLLOWS THE HEIST. Until this commit nothing ever locked it -- the owner's
    in-game report was "everything is unlocked" -- so the drill's own anchor stood open between runs and
    the class's built-in "Open Door" scroll action worked on it like any street furniture. It is the
    SAME class the Malden bank drills (Land_BackAlley_01_l_gate_F), and APS_fnc_maldenBankSRV already
    solves this for it, so the open/seal modes below are shaped after that file. Read its header first.

    MODES  (the argument is new; [] still means ["boot"], so init.sqf's existing call is unchanged)
      ["boot"] / []      resolve, bind, log, SEAL EVERY GATE
      ["open"]           the anchor gate's breach succeeded: unlock and swing THAT ONE gate
      ["open", _gate]    the same for any ONE gate in AP_jewelGates -- what the per-gate sequence
                         hacks call through APS_fnc_jewelryEmporiumSRV
      ["seal"]           the 20-minute window closed (or boot): lock and shut EVERY gate
      ["seal", _gate]    re-seal one gate on its own

    2026-07-29: SIX GATES, NOT ONE -- and AP_jewelGate STILL MEANS ONE OBJECT.
    The owner reported three more openings nobody had ever touched (A/B/C in maldenjewelry2.md). Parsed
    out of mission.sqm there are SIX openable gates inside 44 m of AP_JEWEL_CENTRE, not four: his B is
    TWO Land_ConcreteWall_01_l_gate_F 8.76 m apart with his coordinate between them, and a sixth
    Land_BackAlley_01_l_gate_F stands 6.03 m from the drill gate -- the one this header used to point at
    as the reason the seal traps nobody. All six are now resolved, published as AP_jewelGates and sealed.
    The next instance of either class is 5954 m away, so the 60 m bound is unambiguous by a factor of 100.

    The LIST IS ADDED, NOT SUBSTITUTED, exactly as e7e7c01 did for the Fed (AP_fedGate kept scalar,
    AP_fedGates added). Three client layers read the scalar -- fn_setupActions.sqf:745/747 inside a
    scroll-action CONDITION STRING as `player distance <it>`, fn_jewelryEmporium case "startDrill":13,
    and the alarm emitter in case "clientInit" -- and `distance` against an ARRAY is a type error. A
    throwing condition makes the action silently VANISH rather than error, which is the failure mode this
    event has already eaten twice. Adding a list cannot break a reader that does not know about it.

    A SEALED GATE MUST HAVE A WAY OPEN, or it is welded for the life of the server: ["seal"] is run at
    boot and again at every window close, and the only release anywhere is ["open"]. That is why ["open"]
    takes an OBJECT now. The design gives each gate its own sequence hack, so each gate opens on its own
    breach and the anchor keeps its old argument-free call. If a client layer ever offers the hack on only
    SOME of AP_jewelGates, the rest are welded shut permanently -- offer it on the LIST, not on four
    hard-coded coordinates.

    THE DECOY AT C. Land_BrickWall_03_l_gate_F (Eden 10789) sits 0.13 m from the owner's C coordinate --
    NEARER than the real gate at 0.18 m -- and looks like a gate. It inherits Wall_F: no numberOfDoors,
    no AnimationSources, no UserActions. It cannot be opened and cannot be sealed. It is excluded by
    class and logged at boot as "decorative", so nobody re-derives a missing gate at C later.

    NOT REMOTE-EXECUTABLE, and that is what makes ["open"] safe to add: this function has no CfgRE.hpp
    entry -- only APS_fnc_jewelryEmporiumSRV does (allowedTargets = 2) -- so no client can reach ["open"]
    directly and skip the drill. The only caller of ["open"] is that function's "robberyStarted" case,
    downstream of every one of its guards. If this function is ever whitelisted, ["open"] becomes a free
    unlock of the heist's entry and must be keyed the way the Fed's internal modes are (a server-only
    sentinel generated at boot and never publicVariable'd), NOT with a caller check -- see the bank's
    header for why a caller check is the wrong tool for a mode a spawned loop calls.
*/
if (!isServer) exitWith {};
// _gateArg: objNull means "the default set for this mode" -- every gate for ["seal"], the anchor for
// ["open"]. Typed [objNull] so a caller that passes anything else lands on the default rather than
// reaching animate with a string.
params [["_mode", "boot", [""]], ["_gateArg", objNull, [objNull]]];
private _m = toLower _mode;

// ---- the animations worth driving, and the sources behind them. Both are copied deliberately from
//      APS_fnc_maldenBankSRV rather than re-derived: it drives this exact class at the bank, and its
//      boot log is the evidence that the names are right --
//        gate animations       = [door_1_rot, door_1_handle_rot_1, door_1_handle_rot_2,
//                                 door_1_locked_rot, door_1_handle_locked_rot]
//        gate DOOR animations  = [door_1_rot, door_1_handle_rot_1, door_1_handle_rot_2]
//        gate numberOfDoors    = 1
//      The _locked_ pair is excluded on purpose: that is the engine's "it's locked" handle jiggle
//      (BIS_fnc_Door drives Door_1_locked_source when bis_disabled_Door_1 is 1), so driving it ourselves
//      would fight it. NOTHING here assumes an animation exists -- the list is enumerated from the object
//      and logged at boot, because the inherited bank code animated a "door_4_rot" this class does not
//      have and therefore did nothing while looking as though it did.
private _fnc_doorAnims = {
    params ["_obj"];
    (animationNames _obj) select {
        private _a = toLower _x;
        ((_a find "door") >= 0 || {(_a find "gate") >= 0}) && {(_a find "locked") isEqualTo -1}
    }
};

// animate alone is NOT enough, and this is the whole reason the re-seal below is trustworthy. An
// animation SOURCE is a controller that keeps driving its animation, so one left at the wrong phase
// overrides whatever animate set and the gate stays that way until a restart. That is reachable in
// ordinary play: during the 20-minute window bis_disabled_Door_1 is 0, so the class's own "Open Door"
// scroll action runs, and BIS_fnc_Door (a3\structures_f\scripts\fn_Door.sqf) drives BOTH
// Door_1_sound_source and Door_1_noSound_source -- a later seal that only called animate would not undo
// it and the gate would stand open into the next run. The Fed's test pass step 25 exists to catch
// exactly this (maldenfed_testpass.md:90).
// Both commands are the globally-effective form (BIKI: animate arg=global eff=global; animateSource
// arg=global eff=global), and bis_disabled_Door_N is published with setVariable's third argument, so a
// seal run on the server takes effect on every client -- which it must, the gate being a mission.sqm
// object every machine holds a copy of.
private _fnc_doorSources = {
    params ["_obj", "_phase"];
    { _obj animateSource [_x, _phase]; } forEach ["door_1_sound_source", "door_1_noSound_source"];
};

// ---- ONE GATE, ONE PHASE. Both directions are the same three writes in the same order, so they are one
//      helper rather than two nearly-identical blocks that can drift apart -- which is how the seal ended
//      up driving animation SOURCES while ["open"] did not, in an earlier cut of the bank's version.
//      The ORDER is the bank's and it is load-bearing: write bis_disabled_Door_N FIRST, so no fresh
//      hand-open can begin while the rest runs, THEN drive the animations and their sources -- which is
//      what un-does an open a player performed by hand earlier in the window.
//      Phase 0 = shut and locked (doors DISABLED), phase 1 = open and free (doors ENABLED). The disable
//      flag is therefore the INVERSE of the phase, and that is the only asymmetry between the two.
//      gate_max: the bar-gate contract the Fed and the bank both write (0 = fully shut, door action
//      disabled). Nothing in this repo READS it -- it is kept because the other two gates carry it and an
//      inconsistent gate is the kind of difference that costs an hour later, not because it acts.
private _fnc_driveGate = {
    params ["_obj", "_phase"];
    if (isNull _obj) exitWith { false };
    private _n = getNumber (configFile >> "CfgVehicles" >> (typeOf _obj) >> "numberOfDoors");
    private _dis = 1 - _phase;
    for "_i" from 1 to _n do { _obj setVariable [format ["bis_disabled_Door_%1", _i], _dis, true]; };
    { _obj animate [_x, _phase, true]; } forEach ([_obj] call _fnc_doorAnims);
    [_obj, _phase] call _fnc_doorSources;
    _obj setVariable ["gate_max", _phase, true];
    true
};

// The published set, with the old single-gate shape as its fallback -- the same two-step
// APS_fnc_fedLockdown makes, and for the same reason: this file's modes are reachable from a reset that
// can run before or instead of a successful boot, and an undefined variable in an expression HALTS the
// thread that evaluates it. Nulls are filtered here so no caller below has to.
private _fnc_gateList = {
    private _l = (missionNamespace getVariable ["AP_jewelGates", []]) select { !isNull _x };
    if (_l isEqualTo []) then {
        private _g = missionNamespace getVariable ["AP_jewelGate", objNull];
        if (!isNull _g) then { _l = [_g]; };
    };
    _l
};

// Which gates a mode acts on. An explicit object is REFUSED unless it is in the published set: this
// function is not remote-executable, so the caller is server code either way, but a mode that animates
// whatever object it is handed is one whitelist entry away from being a free unlock of anything on the
// map, and the refusal costs one `in`.
private _fnc_pick = {
    params ["_arg", "_default"];
    if (isNull _arg) exitWith { _default };
    private _all = [] call _fnc_gateList;
    if (_arg in _all) exitWith { [_arg] };
    diag_log format ["[maldenJewel] REFUSED a gate that is not in AP_jewelGates: %1 at %2 -- nothing animated",
        typeOf _arg, getPosATL _arg];
    []
};

// ---- ["seal"] -- shut and locked, EVERY gate unless one is named. Flat, top-level exitWith: an exitWith
//      nested in a then {} or else {} leaves only that block, which this codebase has shipped as a bug
//      three times, so the empty-set case below is an if/then/else and NOT a second exitWith inside this
//      one. Idempotent by design -- boot and every window close both call it.
if (_m isEqualTo "seal") exitWith {
    private _gates = [_gateArg, ([] call _fnc_gateList)] call _fnc_pick;
    if (_gates isEqualTo []) then {
        if (isNull _gateArg) then {
            diag_log "[maldenJewel] seal: AP_jewelGates is empty and AP_jewelGate is objNull, so there is no gate to lock. The boot resolver found nothing near AP_JEWEL_CENTRE -- see the WARN above; the heist is unstartable for the same reason.";
        };
    } else {
        private _n = 0;
        { if ([_x, 0] call _fnc_driveGate) then { _n = _n + 1; }; } forEach _gates;
        diag_log format ["[maldenJewel] %1 gate(s) SEALED", _n];
    };
};

// ---- ["open"] -- a breach's payoff, ONE gate. With no argument it opens the anchor, which is the call
//      APS_fnc_jewelryEmporiumSRV case "robberyStarted" already makes, after every guard in it, so a
//      refused or failed breach never reaches here and the gate stays shut. With an argument it opens
//      that gate and only that gate -- the shape the A/B/C sequence hacks need, since each of them opens
//      its own opening and none of them starts the event.
if (_m isEqualTo "open") exitWith {
    private _gates = [_gateArg, [missionNamespace getVariable ["AP_jewelGate", objNull]]] call _fnc_pick;
    _gates = _gates select { !isNull _x };
    if (_gates isEqualTo []) then {
        if (isNull _gateArg) then {
            diag_log "[maldenJewel] open: AP_jewelGate is objNull, so there is no gate to swing.";
        };
    } else {
        { [_x, 1] call _fnc_driveGate;
            diag_log format ["[maldenJewel] gate OPEN: %1 at %2", typeOf _x, getPosATL _x];
        } forEach _gates;
    };
};

if (_m isNotEqualTo "boot") exitWith {
    diag_log format ["[maldenJewel] unknown mode '%1' -- nothing done", _mode];
};

AP_JEWEL_SAFEPOS  = [7538.99, 10583.70, 0.15];
AP_JEWEL_QILINPOS = [7515.07, 10599.30, 0.19];
AP_JEWEL_GATEPOS  = [7535.70, 10578.80];
AP_JEWEL_CENTRE   = [7545.757, 10570.099];

// 2026-07-29: THE CRANE, as a COORDINATE. Land_RepairDepot_01_tan_F, the anchor for the new "Load
// Jewelry" stage. This is a POSITION and not an object binding, and that is a correction to the brief,
// which assumed it was a mission.sqm object resolvable the way the gates are. IT IS NOT: it is a
// core/config/fn_mapData.sqf row carrying _xIsServer = false --
//   ["Land_RepairDepot_01_tan_F",[7515.623,10596.069,3.838],[[-1.0000,0.0080,0.0000],[0,0,1]],"",false]
// -- i.e. a per-client createSimpleObject that fn_dynamicMapSystem builds only while that zone is
// loaded. mission.sqm holds NO object of this class anywhere; the nearest sqm object to the spot is a
// Land_GarageRow_01_small_F 4.46 m away. So nearestObjects on this process returns nothing, for ever,
// and copying the gate resolver here would publish objNull and make every layer of the new stage refuse
// in silence. The stage must gate on PROXIMITY TO THIS COORDINATE, which is exactly what the Fed's dome
// terminal already does with AP_FED_TERMPOS (read at fn_openVault.sqf:29-31 and in fn_setupActions).
// The literal is a seed, not the last word: the deferred pass below re-reads the authored row out of
// allLocalMapEntities and republishes from it if the designer has moved the prop, so there is no second
// copy of the geometry to drift -- the same discipline the display cases use further down.
AP_JEWEL_CRANEPOS = [7515.623, 10596.069, 3.838];

// 2026-07-28: the emporium footprint, SERVER copy. This literal is duplicated -- the client holds the
// other one as AP_jewelryEmporiumPoly in mission/Armapunk2035.Malden/core/configuration.sqf (line 2,
// the minified data line; append-only, do not reformat it). THE TWO MUST STAY IN STEP. The client refuses
// to smash any display case outside its copy (core/actions/fn_jewelryEmporium.sqf, case "breakGlassCase"),
// and the server's all-cases-smashed unlock counts against this one (fn_jewelryEmporiumSRV, case
// "createCase"). If the server's set is ever the larger it requires a case no client can smash, the
// remaining count never reaches zero, slot 2 never flips and the safe never unlocks. The boot log below
// prints both figures and warns when they disagree, so that drift is visible at boot instead of silent.
AP_JEWEL_POLY     = [[7525,10595,0],[7562,10595,0],[7562,10548,0],[7525,10548,0]];

// one line per object in the boot log, the shape APS_fnc_maldenFedSRV writes. The model name is in it
// because two of the six gates are a class whose model tells you how it moves: the concrete gate SLIDES
// (door_1_move) where the back-alley gate SWINGS on handles (door_1_rot + two handle rots).
private _fnc_describe = {
    params ["_obj", "_from"];
    if (isNull _obj) exitWith { "NULL" };
    format ["%1 (model %2) at %3, %4 m from %5",
        typeOf _obj,
        (getModelInfo _obj) param [0, "?"],
        getPosATL _obj,
        ((getPosATL _obj) distance2D _from) toFixed 2,
        _from];
};

// The owner's three coordinates plus the existing drill anchor, kept as data so the log can say which
// opening each resolved gate answers -- and, more usefully, which of his points resolved NOTHING.
// They are used for LOGGING and for picking the anchor. They are deliberately NOT the search seed: a
// per-coordinate proximity search is what binds the decorative Land_BrickWall_03_l_gate_F at C, which
// sits 0.13 m from his point against the real gate's 0.18 m.
private _ownerPts = [
    ["drill anchor", [7535.69, 10577.10]],
    ["A back-alley", [7537.35, 10557.00]],
    ["B concrete",   [7504.37, 10580.20]],
    ["C canal",      [7551.46, 10607.50]]
];

// ---- RESOLVE THE WHOLE PERIMETER, NOT A BUBBLE ROUND ONE GATE. This used to be
//      nearestObjects [AP_JEWEL_GATEPOS, ["Land_BackAlley_01_l_gate_F"], 12] and it found exactly one
//      gate of one class, which is the owner's report: three more openings stood unlocked and the heist
//      could be walked past. Searching from the CENTRE over BOTH openable classes finds six.
//      The bound is 60 m in 2D from a 250 m sphere seeded at z 0, the same two-step the Fed uses: the
//      compound sits on a raised quay, so a 3D radius measured from ground zero would have to absorb
//      the deck height, and the 2D filter is the bound actually meant. It cannot over-collect --
//      parsed out of mission.sqm, the six gates lie between 13.32 m and 43.98 m of AP_JEWEL_CENTRE and
//      the next instance of either class is 5954.05 m away, so 60 m is unambiguous by a factor of 100.
// 2026-07-28: resolved twice over rather than assuming which KIND of object these are. nearestObjects is
// documented to miss objects a long way from a player camera because of map-object streaming (BIKI,
// nearestObjects: "Use nearestTerrainObjects instead"), and a dedicated server at boot has no camera
// anywhere -- so if these were TERRAIN objects the anchor would publish objNull, all three drill layers
// would refuse for ever and the heist would be untestable with nothing in the log to say why.
// The evidence says they are NOT: all six carry Eden ids and `init` lines in mission.sqm (11055, 11053,
// 11044, 10814, 10941, 11637). nearestObjects resolves those exactly and nearestTerrainObjects would not
// return them at all, so the terrain pass below is insurance against the map data changing under us, not
// the expected path. Either way the log names which pass won.
private _gateClasses = ["Land_BackAlley_01_l_gate_F", "Land_ConcreteWall_01_l_gate_F"];
private _ctr3 = [AP_JEWEL_CENTRE select 0, AP_JEWEL_CENTRE select 1, 0];
private _gateHow = "nearestObjects (mission objects)";
// typeOf as well as the class filter, because nearestObjects filters with isKindOf and would also return
// SUBCLASSES -- the same guard the display-case pass below needs for Coffin_02_F. Neither of these two
// classes has one today; welding an unrelated inheritor shut for the life of the server is not a risk
// worth carrying for the sake of one comparison.
AP_jewelGates = (nearestObjects [_ctr3, _gateClasses, 250])
    select { ((typeOf _x) in _gateClasses) && {(_x distance2D AP_JEWEL_CENTRE) < 60} };
if (AP_jewelGates isEqualTo []) then {
    // nearestTerrainObjects [position, types, radius, sort, 2Dmode] -- note the signature differs from
    // nearestObjects. The type list filters on the terrain "map" named property (BUILDING / FENCE / WALL
    // / ...), NOT on the config class, so [] (no filter) is the only safe ask and the class test happens
    // here. 2Dmode, because the seed is a 2D position: a gate standing on a raised kerb must not fall out
    // of a SPHERE measured from ground zero. typeOf answers "" for a terrain object that has no config
    // class, so the model name is checked too (same idiom as APS_fnc_chopTreeSRV).
    AP_jewelGates = (nearestTerrainObjects [AP_JEWEL_CENTRE, [], 60, true, true]) select {
        ((typeOf _x) in _gateClasses)
        || {private _mn = toLower ((getModelInfo _x) param [0, ""]);
            ((_mn find "backalley_01_l_gate") >= 0) || {(_mn find "concretewall_01_l_gate") >= 0}}
    };
    _gateHow = "nearestTerrainObjects (terrain objects)";
};
if (AP_jewelGates isEqualTo []) then { _gateHow = "NOTHING RESOLVED THEM"; };

// The ANCHOR stays ONE OBJECT under its old name. Whichever gate is nearest the coordinate the drill has
// always used -- and the comparison below is `_x distance2D AP_JEWEL_GATEPOS` over RUNTIME OBJECT
// POSITIONS, which is the frame every figure quoted here has to be in.
// 2026-07-29, corrected: the margin quoted here used to be "Eden 11055 at 0.02 m, runner-up 6.03 m back,
// a factor of 300". Both numbers came out of the mission.sqm `position[]` frame, and one of them was
// worse than that -- 6.03 m is 11044's SQM position measured against the anchor's RUNTIME position, two
// frames in one subtraction. In the frame the code actually compares:
//   * the anchor resolves 1.7 m from AP_JEWEL_GATEPOS. MEASURED, not derived: the b0127 boot log reads
//     "Land_BackAlley_01_l_gate_F ... at [7535.69,10577.1,0.52], 1.7 m from the anchor"
//     (maldenjewelry_testpass.md:34), and that line computed the same distance2D this file does. The
//     0.02 m figure is the sqm frame -- 11055's position[] is [7535.681, 10578.813] against a surveyed
//     seed of [7535.70, 10578.80] -- and the runtime position sits ~1.7 m off it along the gate's own
//     heading. AP_JEWEL_GATEPOS is a SEARCH SEED in the sqm frame; it is not where the gate is.
//   * the runner-up (11044, the sixth gate this build never knew about) is 4.69 m from that seed and
//     4.67 m from the anchor gate, both in the sqm frame. Apply the same ~1.7 m per-gate shift and the
//     runtime margin lands somewhere in the 3-6 m band. It is METRES, not a factor of 300, and the
//     ambiguity check below prints both runtime distances rather than trusting either estimate.
// The per-gate log further down prints each gate's own distances, so a swap is visible rather than silent.
private _anchorD = 1e9;
AP_jewelGate = objNull;
{
    private _d = _x distance2D AP_JEWEL_GATEPOS;
    if (_d < _anchorD) then { _anchorD = _d; AP_jewelGate = _x; };
} forEach AP_jewelGates;

// the safe: spawned, because this map has none. Fridge_01_closed_F is the class Altis uses, and it is
// the closed half of the pair whose open half (Fridge_01_open_F) the client's takeSafeContents reads.
AP_jewelSafe = createVehicle ["Fridge_01_closed_F", AP_JEWEL_SAFEPOS, [], 0, "CAN_COLLIDE"];
AP_jewelSafe setPosATL AP_JEWEL_SAFEPOS;
AP_jewelSafe allowDamage false;
AP_jewelSafe enableSimulationGlobal false;
AP_jewelSafe setVariable ["AP_furniture", true, true];   // exempt from fn_cleanup's sweep

// The crane, resolved in the deferred pass below. Declared here, before the publish list, so the
// variable EXISTS on every client from the first publicVariable rather than only if the pass finds
// something -- an undefined variable in a scroll-menu condition RAISES, which is the whole reason these
// three AP_* names are bound at all.
AP_jewelCrane = objNull;

AP_jewerlySafe      = AP_jewelSafe;
AP_jewerlyEmporium  = AP_jewelGate;
// 2026-07-29: the deposit container IS the crane, and on this map it is a coordinate, not an object --
// see the AP_JEWEL_CRANEPOS note above. This binding tracks AP_jewelCrane so that IF the
// Land_RepairDepot_01_tan_F row is ever promoted to _xIsServer = true it wires itself up with no further
// change here; until then it stays objNull, which makes a condition simply not match instead of throwing.
// THIS IS THE SERVER'S OWN COPY AND IT IS NOT PUBLISHED. AP_* names are per-client state -- every
// client sets its own at initPlayerLocal.sqf:118 -- so publicVariable'ing one from here would be a
// name collision that the client's own assignment then races. The client-side line to change is that
// one, and it is not this file's to change:
//     AP_jewerlyContainer = missionNamespace getVariable ["AP_jewelCrane", objNull];
// The load stage must NOT depend on it either way. cursorObject is the trap this build has already
// fallen into twice (the Fed gate, then the emporium gate): a Land_RepairDepot_01_tan_F is a
// 7.8 x 6.5 x 4.9 m gantry and the cursor ray lands on the deck underfoot. Gate the stage on distance
// to AP_JEWEL_CRANEPOS, with the registration wrap, the action condition and the server's own refusal
// all measuring the same thing at the same radius.
AP_jewerlyContainer = AP_jewelCrane;

{ publicVariable _x; } forEach ["AP_JEWEL_SAFEPOS", "AP_JEWEL_QILINPOS", "AP_JEWEL_GATEPOS",
                                "AP_JEWEL_CENTRE", "AP_JEWEL_POLY", "AP_JEWEL_CRANEPOS",
                                "AP_jewelSafe", "AP_jewelGate", "AP_jewelGates", "AP_jewelCrane"];

// 2026-07-28: the method is logged, not just the result. "did the gate resolve, and how" is the one
// question the drill's three refusal layers cannot answer from the client side, and a null anchor makes
// every one of them refuse silently for ever.
// 2026-07-29: ONE LINE PER GATE, the way the Fed proves its perimeter (fn_maldenFedSRV case "boot").
// A count on its own is worthless here -- the whole bug being fixed was a resolver that found ONE gate
// and reported success. Each line carries class, model, position, distance from the drill anchor and
// from the emporium centre, which of the owner's four openings it is nearest, and whether it IS the
// anchor. The DOOR animation list and numberOfDoors are on it too, because the seal drives whatever the
// enumeration returns: an EMPTY door list means a silent no-op seal, and this log is the only place that
// would say so. Do not read a line and assume -- an earlier cut of the bank animated a "door_4_rot" this
// class does not have, and it did nothing for weeks while looking as though it worked.
// Expected, measured from mission.sqm and the two classes' configs on 2026-07-29:
//   4 x Land_BackAlley_01_l_gate_F  -- 5 animations, 3 driven (door_1_rot + two handle rots), 1 door
//   2 x Land_ConcreteWall_01_l_gate_F -- 2 animations, 1 driven (door_1_move, it SLIDES), 1 door
diag_log format ["[maldenJewel] %1 gate(s) resolved via %2 (2D bound 60 m from %3)",
    count AP_jewelGates, _gateHow, AP_JEWEL_CENTRE];
{
    private _g = _x;
    private _lbl = ""; private _lblD = 1e9;
    { _x params ["_nm", "_p"];
        private _d = _g distance2D _p;
        if (_d < _lblD) then { _lblD = _d; _lbl = _nm; };
    } forEach _ownerPts;
    diag_log format ["[maldenJewel] gate %1/%2 [%3] = %4; %5 m from the emporium centre; nearest owner point: %6 (%7 m); DOOR animations = %8; numberOfDoors = %9",
        _forEachIndex + 1, count AP_jewelGates,
        if (_g isEqualTo AP_jewelGate) then {"ANCHOR   "} else {"perimeter"},
        [_g, AP_JEWEL_GATEPOS] call _fnc_describe,
        ((getPosATL _g) distance2D AP_JEWEL_CENTRE) toFixed 2,
        _lbl, _lblD toFixed 2,
        [_g] call _fnc_doorAnims,
        getNumber (configFile >> "CfgVehicles" >> (typeOf _g) >> "numberOfDoors")];
    if (([_g] call _fnc_doorAnims) isEqualTo []) then {
        diag_log format ["[maldenJewel] WARN gate %1 (%2) enumerated NO drivable door animation, so sealing it is a silent no-op. Its full animation list is %3 -- _fnc_doorAnims matches names containing ""door"" or ""gate"" and not ""locked"", and must be widened to whatever this class actually calls them before the seal means anything.",
            _forEachIndex + 1, typeOf _g, animationNames _g];
    };
} forEach AP_jewelGates;

// ---- THE OWNER'S OPENINGS, ANSWERED ONE BY ONE. The gate loop above proves what was found; this proves
//      that each thing he pointed at was covered. It is the half that would have caught the original bug:
//      three of these four would have printed "no gate within 8 m" against the old 12 m single-class
//      resolver. It is also where his B shows up as TWO gates -- both are ~4-5 m from his coordinate, on
//      either side of it, which is why a nearest-one-per-coordinate resolver would have sealed half of it.
{
    _x params ["_nm", "_p"];
    private _best = objNull; private _bd = 1e9;
    { private _d = _x distance2D _p; if (_d < _bd) then { _bd = _d; _best = _x; }; } forEach AP_jewelGates;
    if (isNull _best) then {
        diag_log format ["[maldenJewel] WARN owner opening ""%1"" at %2 resolved NO openable gate at all -- that way in is NOT sealed.", _nm, _p];
    } else {
        diag_log format ["[maldenJewel] owner opening ""%1"" at %2 -> nearest resolved gate %3 at %4, %5 m",
            _nm, _p, typeOf _best, getPosATL _best, _bd toFixed 2];
        if (_bd > 8) then {
            diag_log format ["[maldenJewel] WARN owner opening ""%1"" has no gate within 8 m (nearest is %2 m away). Either the coordinate is stale or the opening is a class the resolver does not search.", _nm, _bd toFixed 2];
        };
    };
} forEach _ownerPts;

// ---- THE DECOY AT C IS LOGGED AS A DECISION, not left for the next reader to re-derive.
//      Land_BrickWall_03_l_gate_F (Eden 10789) is 0.13 m from the owner's C coordinate -- NEARER than the
//      real gate at 0.18 m, and 0.64 m higher. It inherits Wall_F: no numberOfDoors, no AnimationSources,
//      no UserActions, SimpleObject animate = []. It cannot be opened, so there is nothing to seal, and
//      the seal's door loop would be a no-op on it anyway. Excluded by class, and the numberOfDoors it
//      reports is printed so the claim is evidence rather than assertion.
{
    diag_log format ["[maldenJewel] gate NOT SEALED (decorative -- cannot be opened) = %1; numberOfDoors = %2; %3 m from the owner's C coordinate, i.e. NEARER than the real gate there. A resolver seeded on C by proximity alone binds THIS and seals nothing.",
        [_x, AP_JEWEL_CENTRE] call _fnc_describe,
        getNumber (configFile >> "CfgVehicles" >> (typeOf _x) >> "numberOfDoors"),
        ((getPosATL _x) distance2D [7551.46, 10607.50]) toFixed 2];
} forEach ((nearestObjects [_ctr3, ["Land_BrickWall_03_l_gate_F"], 250]) select { (_x distance2D AP_JEWEL_CENTRE) < 60 });
// 2026-07-28: the SEAL -- only when a gate actually resolved, which is how the bank orders it too (its
// case "boot" exitWiths on a null gate BEFORE it reads animationNames, so that command is never handed
// objNull there and is not handed one here either). No exitWith in this branch: the display-case pass
// further down still has to run even when every gate is missing.
//
// SEALING is the state the owner found missing -- between robberies the gates stood open and their own
// "Open Door" scroll action worked on them, so the heist's perimeter was decorative. From here they are
// shut until a breach calls ["open"], and shut again when that run's 20-minute window closes.
// The call comes AFTER the publicVariable above because ["seal"] re-reads AP_jewelGates out of
// missionNamespace rather than closing over the local -- the same read ["open"] and the re-seal make.
//
// 2026-07-29: THE OLD "IT DOES NOT TRAP ANYONE" NOTE HERE WAS RETIRED WITH THE BUG IT DESCRIBED. It read
// "a second, never-locked Land_BackAlley_01_l_gate_F stands 6.0 m away in mission.sqm (7532.46,
// 10582.20)" -- that gate is Eden 11044 and it is now IN AP_jewelGates and sealed with the rest, which
// was the point. What still stands: the emporium building is a doorless createSimpleObject and the
// display cases and the safe sit out in the open, so the gates are a perimeter, not a room anyone can be
// shut inside. What is NEW and must be kept true is the other half -- every gate sealed here needs a
// breach that opens it, or it is welded for the life of the server. Six are sealed; the client layers
// must offer their sequence hack against AP_jewelGates, not against four hard-coded coordinates.
if (AP_jewelGates isEqualTo []) then {
    diag_log format ["[maldenJewel] WARN NO gate of either openable class resolved within 60 m of %1, by either method. AP_jewelGate publishes as objNull, so all three drill layers (the fn_setupActions registration wrap, the action condition and fn_jewelryEmporium case ""startDrill"") refuse for ever and the heist cannot be started at all. Check the gates are still in mission.sqm at those positions.", AP_JEWEL_CENTRE];
    diag_log "[maldenJewel] WARN consequence: there is also nothing to SEAL, so every way in stands open and each gate's own ""Open Door"" scroll action stays live -- which is what the owner reported in game before the seal existed.";
} else {
    // ---- IS THE ANCHOR BIND UNAMBIGUOUS? 2026-07-29: this replaces a WARN that could never fire.
    //      It read `if (_anchorD > 8)` and claimed to catch AP_jewelGate binding the wrong gate, against
    //      an "expected ~0.02 m" taken from the mission.sqm frame. The anchor's real runtime distance to
    //      the seed is 1.7 m and its nearest rival sits a few metres past that, so BOTH the right answer
    //      and the wrong one are comfortably under 8 -- the test was dead code either way round.
    //      A wrong bind is not a long distance, it is a CLOSE CALL: two gates near enough to the same seed
    //      that a nudge in the map data swaps which one wins. So warn on the MARGIN between the nearest and
    //      the second-nearest, both measured here in the runtime frame the picker itself used, and print
    //      both numbers so the log carries the evidence instead of an assertion.
    //      "Clear" = the runner-up is at least twice as far AND at least 2 m further. Against the shipped
    //      map (anchor 1.7 m, runner-up 3-6 m) that passes; if the anchor ever bound 11044 instead, the
    //      figures swap and it fires. A single resolved gate cannot be ambiguous.
    private _secondD = 1e9;
    {
        if !(_x isEqualTo AP_jewelGate) then {
            private _d = _x distance2D AP_JEWEL_GATEPOS;
            if (_d < _secondD) then { _secondD = _d; };
        };
    } forEach AP_jewelGates;
    private _anchorClear = ((count AP_jewelGates) < 2)
        || {(_secondD > (_anchorD * 2)) && {(_secondD - _anchorD) > 2}};
    if (!_anchorClear) then {
        diag_log format ["[maldenJewel] WARN the anchor bind is AMBIGUOUS: the nearest gate to the drill seed %1 is %2 m away and the second-nearest is %3 m away (margin %4 m). AP_jewelGate may have bound the wrong gate, in which case the breach action offers in the wrong place AND the gate that trips the alarm is the one the perimeter hack refuses to open. Compare the per-gate lines above: the anchor should be ~1.7 m out in the runtime frame and its rival 3-6 m.",
            AP_JEWEL_GATEPOS, _anchorD toFixed 2, _secondD toFixed 2, (_secondD - _anchorD) toFixed 2];
    };
    // The other half of the same question, and the one the old absolute test was reaching for: has the
    // whole set resolved somewhere else entirely (a stale seed, a moved fence line)? 5 m, against a
    // measured 1.7 m -- inside the runtime frame shift plus slack, so it flags a real move without
    // firing on the shipped map.
    if (_anchorD > 5) then {
        diag_log format ["[maldenJewel] WARN the nearest resolved gate to the drill seed %1 is %2 m away, where the shipped map measures 1.7 m in this frame. Either AP_JEWEL_GATEPOS is stale or the gates have moved; the breach action is offered around the GATE, so check the per-gate lines above before assuming the seed is still right.",
            AP_JEWEL_GATEPOS, _anchorD toFixed 2];
    };
    ["seal"] call APS_fnc_maldenJewelSRV;
};
// the height read-back is weak evidence on its own -- getPosATL here just echoes the setPosATL above
// (simulation is off, nothing can have moved it), so it only ever catches a total spawn failure. The
// distance from the emporium centre is independent of that write, so it is what actually proves the
// coordinate is sane and the safe is inside the compound rather than somewhere else on Malden.
diag_log format ["[maldenJewel] safe  = %1 at %2 (terrain %3, %4 m from the emporium centre)",
    typeOf AP_jewelSafe, getPosATL AP_jewelSafe,
    (getTerrainHeightASL [AP_JEWEL_SAFEPOS select 0, AP_JEWEL_SAFEPOS select 1]) toFixed 2,
    ((getPosATL AP_jewelSafe) distance2D AP_JEWEL_CENTRE) toFixed 1];

// ---- the crane -------------------------------------------------------------------------------
// The anchor for the new "Load Jewelry" stage, and the one anchor in this file that is NOT a server
// object. Everything this pass does is EVIDENCE: it reads the authored fn_mapData row, says whether that
// row is server-side, probes for a real object anyway, and prints the geometry the brief got wrong. It
// changes no behaviour when the answer is the expected "client-local", which is the point -- the next
// person to look for a crane on this process needs the log to tell them why there isn't one.
//
// DEFERRED for the same reason the display cases are: allLocalMapEntities is written by
// [] call AP_fnc_mapData on initServer.sqf:161, and initServer separately spawns AP_server\init.sqf,
// which is what calls this function. Two independent scheduler queues, no ordering guarantee between
// them -- and this function is called synchronously from a path every client's join waits on, so the
// ~15k-row filter belongs off it either way.
[] spawn {
    private _rows = (localNamespace getVariable ["APS_mapEntities", []]) select {   // APS_fnc_mapLoad's snapshot (not client-writable)
        ((_x param [0, ""]) isEqualTo "Land_RepairDepot_01_tan_F")
        && {((_x param [1, [0,0,0]]) distance2D AP_JEWEL_CRANEPOS) < 25}
    };
    if ((count _rows) isNotEqualTo 1) then {
        diag_log format ["[maldenJewel] WARN expected exactly ONE Land_RepairDepot_01_tan_F row within 25 m of %1 in core/config/fn_mapData.sqf, found %2. The published AP_JEWEL_CRANEPOS is the literal in this file and has NOT been checked against the map data.",
            AP_JEWEL_CRANEPOS, count _rows];
    } else {
        // Typed params on both reads. _rowSrv reaches an `if`, which raises on a non-Boolean, and _rowPos
        // is republished as a position other machines range-check against -- a malformed row must fall
        // back to the literal, not propagate.
        private _row = _rows select 0;
        private _rowPos = _row param [1, AP_JEWEL_CRANEPOS, [[]]];
        private _rowSrv = _row param [4, false, [false]];
        // Adopt the authored position if the designer has moved the prop. The literal above is a seed;
        // the map data is the source of truth, exactly as the display cases take their heights from it
        // rather than from a second copy here. Republished, because the client range-checks against it.
        private _drift = _rowPos distance2D AP_JEWEL_CRANEPOS;
        if (_drift > 0.5) then {
            diag_log format ["[maldenJewel] crane MOVED in the map data: authored %1, this file's literal %2, %3 m apart. Adopting the authored position and republishing AP_JEWEL_CRANEPOS.",
                _rowPos, AP_JEWEL_CRANEPOS, _drift toFixed 2];
            AP_JEWEL_CRANEPOS = _rowPos;
            publicVariable "AP_JEWEL_CRANEPOS";
        };
        diag_log format ["[maldenJewel] crane row = Land_RepairDepot_01_tan_F at %1, _xIsServer = %2 (%3)",
            _rowPos, _rowSrv,
            if (_rowSrv) then {"promoted -- initServer creates a real object for it"}
                         else {"CLIENT-LOCAL createSimpleObject: this process can never see it with nearestObjects, and a client only builds it while fn_dynamicMapSystem has that zone loaded"}];
        if (!_rowSrv) then {
            diag_log "[maldenJewel] crane: the ""Load Jewelry"" stage must therefore gate on PROXIMITY TO AP_JEWEL_CRANEPOS, not on an object -- the same shape the Fed's dome terminal uses with AP_FED_TERMPOS. AP_jewerlyContainer stays objNull, so the legacy cursor-based ""Load Container"" entry simply never matches, which is the intended resting state until that entry is replaced.";
        };
    };

    // Probe for a real object regardless of what the row says: if the row is ever promoted, or something
    // else spawns one, this binds it with no further change here. The wait exists ONLY for the promoted
    // case (initServer spawns one thread per row and they land within a few frames); an unpromoted row
    // gets a single probe and no 30-second stall waiting for an object that can never appear. The two
    // branches repeat the nearestObjects line rather than share it through a sentinel deadline, because
    // the alternative reads as a trick and this reads as what it is.
    private _wait = ((_rows param [0, [], [[]]]) param [4, false, [false]]);
    private _c = objNull;
    if (_wait) then {
        private _deadline = time + 30;
        waitUntil {
            uiSleep 1;
            _c = (nearestObjects [AP_JEWEL_CRANEPOS, ["Land_RepairDepot_01_tan_F"], 12]) param [0, objNull];
            (!isNull _c) || {time > _deadline}
        };
    } else {
        _c = (nearestObjects [AP_JEWEL_CRANEPOS, ["Land_RepairDepot_01_tan_F"], 12]) param [0, objNull];
    };
    AP_jewelCrane = _c;
    AP_jewerlyContainer = _c;
    publicVariable "AP_jewelCrane";
    if (isNull _c) then {
        diag_log format ["[maldenJewel] crane OBJECT = NULL -- nothing of that class exists server-side within 12 m of %1. AP_jewelCrane publishes as objNull, which is CORRECT for a client-local row and is not on its own a fault. It IS a fault if the row above says _xIsServer = true.",
            AP_JEWEL_CRANEPOS];
    } else {
        // fn_cleanup's junk sweep runs forEach vehicles and takes ownerless objects; the display cases
        // and the safe both carry this tag for exactly that reason.
        _c setVariable ["AP_furniture", true, true];
        // _fnc_describe is NOT reachable from here: spawn starts a script with its own variable space and
        // does not inherit the caller's local variables, so the format is written out rather than called.
        diag_log format ["[maldenJewel] crane OBJECT = %1 (model %2) at %3, %4 m from %5",
            typeOf _c, (getModelInfo _c) param [0, "?"], getPosATL _c,
            ((getPosATL _c) distance2D AP_JEWEL_CRANEPOS) toFixed 2, AP_JEWEL_CRANEPOS];
        diag_log "[maldenJewel] WARN the crane is a REAL OBJECT now, so its config is live: Land_RepairDepot_01_base_F carries transportRepair = 200000000 and supplyRadius = 5, i.e. a working vehicle repair point a few metres from the getaway pad. That is the cost of promoting the row, and it is a design decision, not a bug.";
    };

    // The brief's geometry, corrected in the log rather than in a comment nobody reads. It says the Qilin
    // spawns "1.2 m from the crane"; it does not. The pad is on the lower quay and the crane on the
    // raised deck, and the conclusion (the pad is still the right place to load at) survives the numbers
    // being wrong -- but a stage whose radius was chosen from 1.2 m would refuse at the pad.
    diag_log format ["[maldenJewel] crane %1 -> Qilin pad %2: %3 m in 2D, %4 m of height between them (the pad is on the lower quay). The brief's ""1.2 m"" is wrong; size the load radius from these.",
        AP_JEWEL_CRANEPOS, AP_JEWEL_QILINPOS,
        (AP_JEWEL_CRANEPOS distance2D AP_JEWEL_QILINPOS) toFixed 2,
        ((AP_JEWEL_CRANEPOS param [2, 0]) - (AP_JEWEL_QILINPOS param [2, 0])) toFixed 2];
};

// ---- the display cases -----------------------------------------------------------------------
// 2026-07-28: the emporium's 8 display cases are SERVER-SIDE as of this commit -- their 8 Coffin_02_F
// rows in mission/Armapunk2035.Malden/core/config/fn_mapData.sqf now carry _xIsServer = true, so
// initServer.sqf creates them with createVehicle instead of leaving them to per-client
// createSimpleObject copies this process could never see. That is the whole point: the unlock in
// APS_fnc_jewelryEmporiumSRV case "createCase" counts the cases to decide when the safe opens, and it
// was counting an EMPTY set, so stage two of the heist could not complete. (The other 14 Coffin_02_F
// rows are still on the original map's coordinates ~14.5 km away and are deliberately left alone.)
//
// Promoting the rows is necessary but NOT sufficient, and the missing half is a property of the CLASS:
//
//   Coffin_02_F -> Coffin_02_animated_base_F -> Coffin_02_base_F -> Coffin_01_base_F -> Items_base_F
//   -> ThingX, and ThingX carries simulation = "thingX" with no override anywhere on that path. It is
//   a PhysX body. AP_fnc_createVehicleLocal's SERVER branch ENABLES simulation (line 15) -- which is
//   correct for what that line was written for, the Federal Reserve's promoted BUILDINGS, which need
//   simulation for their doors and for which the flag is otherwise inert. It is not inert here.
//
//   The cases sit at z ~ 1.59 ATL on the shop's raised display floor, and that floor does not exist on
//   this machine: it is a client-local createSimpleObject, no mapData row within 80 m carries
//   _xIsServer = true, and mission.sqm holds no object within 13 m of the centre. A promoted case
//   therefore free-falls ~1.6 m onto bare terrain -- and because the server owns the object, the fallen
//   position replicates to every client. Eight display cases under the shop floor, with the heist still
//   TESTING as working: the smash action's 3 m radius (fn_setupActions) and the 2D inPolygon gates both
//   survive a 1.6 m drop. So they are frozen and put back, exactly the way AP_jewelSafe is above.
//
//   Being real objects has a second consequence: Coffin_01_base_F carries maximumLoad = 4000 and
//   transportMaxMagazines = 100 -- these are CONTAINERS. As createSimpleObject copies they had no
//   inventory at all; as createVehicle objects they are eight free gear lockers at a landmark.
//
// DEFERRED, in its own thread, because the ordering cannot be assumed: initServer.sqf spawns every
// _xIsServer = true map row into its OWN scheduled thread (initServer.sqf:118-120) and separately
// spawns AP_server\init.sqf, which is what calls this function -- two independent scheduler queues
// with no guarantee between them. Waiting is also what makes the re-placement correct rather than
// lucky: a case that has already begun to fall is put BACK, not merely stopped where it landed.
//
// The authored geometry is read from allLocalMapEntities (set on this machine by the
// [] call AP_fnc_mapData on initServer.sqf:118) instead of being copied into a literal here, so the
// height and heading restored below are by construction the numbers the map data holds. There is no
// second copy to drift out of step -- the mistake AP_JEWEL_POLY has to warn about above.
// The filter itself runs inside the thread too: allLocalMapEntities is ~15k rows, and this function is
// called synchronously from AP_server\init.sqf, which every client's join waits on.
[] spawn {
    private _authored = (localNamespace getVariable ["APS_mapEntities", []]) select {   // APS_fnc_mapLoad's snapshot
        ((_x param [0, ""]) isEqualTo "Coffin_02_F")
        && {_x param [4, false]}
        && {(_x param [1, [0,0,0]]) inPolygon AP_JEWEL_POLY}
    };
    private _want = count _authored;
    if (_want isEqualTo 0) exitWith {
        diag_log "[maldenJewel] WARN no Coffin_02_F row inside AP_JEWEL_POLY carries _xIsServer = true in core/config/fn_mapData.sqf, so initServer.sqf creates no display case server-side and they live only as per-client local objects.";
        diag_log "[maldenJewel] WARN consequence: APS_fnc_jewelryEmporiumSRV case ""createCase"" counts an EMPTY set of cases, so the all-cases-smashed unlock of the safe cannot fire and stage two of the heist cannot complete.";
    };
    // 60 s is a BOUND, not an expectation -- those per-row threads land within a few frames. The pass
    // runs when it expires either way and reports what it actually found, so a short count shows up in
    // the log instead of being waited on for ever in silence.
    // nearestObjects, not allMissionObjects, on purpose: it is exactly the lookup the unlock gate in
    // fn_jewelryEmporiumSRV uses, so this log reports the set that gate can see rather than a more
    // generous one. typeOf as well, because the nearestObjects filter is isKindOf and would also return
    // SUBCLASSES of Coffin_02_F, which both the client action and the unlock count reject.
    private _deadline = time + 60;
    private _all = [];
    private _in  = [];
    waitUntil {
        uiSleep 1;
        _all = (nearestObjects [AP_JEWEL_CENTRE, ["Coffin_02_F"], 120]) select {(typeOf _x) isEqualTo "Coffin_02_F"};
        _in  = _all select {(getPosATL _x) inPolygon AP_JEWEL_POLY};   // inPolygon ignores Z
        ((count _in) >= _want) || {time > _deadline}
    };

    // Freeze EVERY case found, matched to a row or not: a case still under gravity is a case still
    // moving, and nothing below is worth doing to a moving object. enableSimulationGlobal is the global,
    // JIP-safe form, and setPos still replicates afterwards (BIKI, enableSimulation: "After using
    // enableSimulation false or enableSimulationGlobal false on an object, setPos will still update its
    // position across the network in MP"). Nothing in the heist animates a display case -- the client's
    // "breakGlassCase" and the server's "createCase" only read typeOf / getPosATL / isObjectHidden and
    // set AP_jewelCaseLooted -- so simulation-off costs the feature nothing, and the client's smash
    // action finds them with nearestObjects, which is a spatial query and does not care about it.
    //   AP_furniture: fn_cleanup's junk sweep (fn_cleanup.sqf:179) runs forEach vehicles, and `vehicles`
    //   DOES return thingX simulations -- which is why the loot trophies had to be tagged in #152. An
    //   untagged, ownerless Coffin_02_F would be deleted on the first 5-minute pass, so the promotion
    //   would have traded "no cases" for "cases for five minutes". Same tag the safe carries above.
    //   AP_questloot: the OTHER deletion route, and the one that outlives the restart. case "createCase"
    //   in APS_fnc_jewelryEmporiumSRV hangs the crypto mining component off a smashed case under
    //   AP_droppedItems; fn_setupActions.sqf:100 offers "Pick Up Item(s)" on ANY object carrying a
    //   non-empty AP_droppedItems within 5 m, and fn_pickupItem.sqf:82 deleteVehicle's the holder once
    //   the last item is taken -- its ONLY opt-out is AP_questloot, it does NOT check AP_furniture.
    //   That was harmless while the cases were per-client createSimpleObject copies (the delete never
    //   reached a real object); now that they are server objects, deleteVehicle is GLOBAL, so an ordinary
    //   player grabbing the component would destroy that display case for everyone, permanently. Next run
    //   7 cases, then 6; at zero nothing can be smashed, slot 2 never flips and the safe can never unlock
    //   again until a restart -- while every attempt still burns the 30-minute cooldown and the fed-event
    //   lock that blocks the other heists server-wide. The flag is inert to the heist itself (nothing in
    //   it reads AP_questloot) and its other three readers are checked: fn_setupActions.sqf:144 is
    //   class-gated to Box_Syndicate_WpsLaunch_F so no new action appears on a Coffin_02_F;
    //   fn_storeInventory.sqf:37 additionally refuses to STORE into the case, which is wanted -- these are
    //   maximumLoad 4000 containers at a landmark; fn_onTakeItem.sqf:16 gates on `local _container` and
    //   netid "0:0", neither true of a server-created object, so it is unreachable here either way.
    //   lockInventory: the containers, closed. Note the command is documented eff=local, so the honest
    //   claim for it is belt-and-braces on the server's own copy; the load-bearing half is the freeze --
    //   a non-simulated object "will freeze and ignore any input or collisions" (BIKI, Eden Editor:
    //   Object -> Enable Simulation) and is not returned by cursorTarget, while cursorObject still finds
    //   it (BIKI, enableSimulation, Demellion 2016-09-01), which is why the scripted actions still work.
    {
        _x enableSimulationGlobal false;
        _x setVariable ["AP_furniture", true, true];
        _x setVariable ["AP_questloot", true, true];
        _x lockInventory true;
    } forEach _all;

    // Pair each authored row with the NEAREST REMAINING case, not with whatever falls inside a fixed
    // radius. The first cut of this used `_in select {(_x distance2D _rowPos) < 1}`, reasoning that a box
    // dropped straight down moves only centimetres sideways. The 2026-07-28 boot log disproved it: the
    // cases are created simulation-live and fall their full authored height before the freeze above
    // catches them ("deepest fall caught before the freeze: 1.593 m" against an authored 1.594), and a
    // PhysX body landing on an uneven floor can slide well over a metre on the way down. Two of the eight
    // therefore matched no row, were reported as missing, and -- worse -- were skipped by the re-place
    // below while still being simulated, free to sink through the floor later.
    // There are exactly as many cases as rows, so pair them off nearest-first and consume each case as it
    // is claimed. That cannot silently mis-home one: with the closest two authored cases 2.18 m apart, a
    // case has to end up nearer another row than its own to be swapped, and any pairing over a metre is
    // logged with its distance rather than hidden.
    private _fixed   = [];   // [case, authored position] pairs
    private _missing = [];
    private _worst   = 0;
    private _pool    = +_in;
    private _slid    = [];
    {
        _x params ["", ["_rowPos", [0,0,0], [[]]], ["_rowVec", 0]];
        private _case  = objNull;
        private _bestD = 1e10;
        {
            private _d = _x distance2D _rowPos;
            if (_d < _bestD) then { _bestD = _d; _case = _x; };
        } forEach _pool;
        if (isNull _case) then {
            _missing pushBack _rowPos;
        } else {
            _pool = _pool - [_case];   // one case per row: a slid case can never be claimed twice
            if (_bestD > 1) then { _slid pushBack [_rowPos, (round (_bestD * 100)) / 100]; };
            private _fell = (_rowPos select 2) - ((getPosATL _case) select 2);
            if (_fell > _worst) then { _worst = _fell; };
            // heading before position, and the same Array-or-Number branch AP_fnc_createVehicleLocal
            // uses on the very same field -- all 8 emporium rows carry the [[dir],[up]] pair, but this
            // reads whatever the map data holds rather than assuming which form the exporter wrote.
            if (_rowVec isEqualType []) then { _case setVectorDirAndUp _rowVec; } else { _case setDir _rowVec; };
            _case setPosATL _rowPos;
            _fixed pushBack [_case, _rowPos];
        };
    } forEach _authored;

    // The settle read. getPosATL taken straight after setPosATL only echoes the write -- the same weakness
    // the safe's log line above admits to -- so the heights are read again 2 s later. If the freeze had not
    // taken, these numbers would be ~1.6 m lower than the authored ones printed beside them, and that is
    // the whole question this log exists to answer without anyone loading in. Same idiom as the SETTLED
    // line in debug/frame_probe.sqf.
    uiSleep 2;
    private _zNow  = _fixed apply {(((getPosATL (_x select 0)) select 2)) toFixed 3};
    private _zWant = _fixed apply {(((_x select 1) select 2)) toFixed 3};
    private _drift = _fixed select {(abs ((((getPosATL (_x select 0)) select 2)) - ((_x select 1) select 2))) > 0.05};
    private _out   = _all select {!((getPosATL _x) inPolygon AP_JEWEL_POLY)};

    diag_log format ["[maldenJewel] display cases: %1 authored server-side, %2 found within 120 m of the emporium centre, %3 of them inside AP_JEWEL_POLY, %4 frozen and re-placed",
        _want, count _all, count _in, count _fixed];
    diag_log format ["[maldenJewel] display case heights 2 s after the freeze: %1 (authored %2) -- %3 off by more than 0.05 m; deepest fall caught before the freeze: %4 m",
        _zNow, _zWant, count _drift, (_worst toFixed 3)];
    if (_slid isNotEqualTo []) then {
        diag_log format ["[maldenJewel] %1 display case(s) slid more than a metre while falling and were paired to their row by nearest match, then put back: %2 ([authored position, metres slid]). Informational -- they are frozen at the authored spot now. It is worth a line because the earlier fixed-radius match silently dropped exactly these and left them simulated.",
            count _slid, _slid];
    };
    if (_missing isNotEqualTo []) then {
        diag_log format ["[maldenJewel] WARN %1 of %2 authored display case(s) never appeared server-side within 60 s: %3. initServer.sqf creates one object per _xIsServer = true row, so a row that produced nothing means the case is missing from the world entirely and the unlock in APS_fnc_jewelryEmporiumSRV counts fewer cases than the shop shows.",
            count _missing, _want, _missing];
    };
    if (_drift isNotEqualTo []) then {
        diag_log format ["[maldenJewel] WARN %1 display case(s) MOVED after being frozen, now at %2. Coffin_02_F is a PhysX body (ThingX) and there is nothing server-side beneath the emporium floor, so this means the enableSimulationGlobal false above did not take -- those cases will replicate to every client BELOW the shop floor while the heist still tests as working.",
            count _drift, _drift apply {getPosATL (_x select 0)}];
    };
    // 120 m, NOT 40: this must match the radius the unlock gate counts over (fn_jewelryEmporiumSRV, case
    // "createCase"). At 40 m a display case sitting between the two radii would be invisible here -- the
    // log would read a reassuring 8 while the gate waited for ever on a 9th case nobody could smash. The
    // unlock counts only what is inside AP_JEWEL_POLY, which is the only set the client will ever smash,
    // so a case in the ring between the polygon edge and 120 m would be required by nothing and smashable
    // by nobody. That condition IS the two figures above disagreeing, so it warns and names the offenders.
    if (_out isNotEqualTo []) then {
        diag_log format ["[maldenJewel] WARN %1 display case(s) sit within 120 m of the emporium but OUTSIDE the polygon, at %2. The client refuses to smash a case outside AP_jewelryEmporiumPoly, so these are required by nothing and smashable by nobody -- move them inside, or widen BOTH polygon literals (AP_JEWEL_POLY here and AP_jewelryEmporiumPoly in core/configuration.sqf).",
            count _out, _out apply {getPosATL _x}];
    };
};
// READ %1, NOT %2. The anchor resolving is what the old log reported and it was true throughout the bug
// the owner found -- one gate resolved, one gate sealed, five ways in left standing open. The GATE COUNT
// is the discriminating field: a line reading "1 gate(s)" is the regression, whatever else it says.
// The crane is deliberately absent from this line: it is resolved in a deferred thread that has not run
// yet when this executes, so anything printed for it here would be a lie. Its own lines come later.
diag_log format ["[maldenJewel] boot complete -- %1 gate(s) sealed (anchor bound: %2), safe %3, crane anchor %4",
    count AP_jewelGates, !isNull AP_jewelGate, !isNull AP_jewelSafe, AP_JEWEL_CRANEPOS];
