/*
    fn_vendShop.sqf  (NPC_fnc_vendShop) -- wire one vending machine to the shop its sign advertises.

    Called from the machine's own map_objects row init, client side:

        [_this, "kabuki"] call NPC_fnc_vendShop;

    r2 (owner 2026-09-06): THE CABINET IS A SUPER-SIMPLE OBJECT AND STAYS ONE. BIKI's createSimpleObject
    page is flat about what that means -- "objects created with Syntax 1 [a .p3d path] cannot be
    textured" and "addAction does not work with simple objects" -- so r1, which painted twelve p3d
    variants and hung the actions on the cabinet, shipped twelve machines that could not be retextured
    and offered nothing. A CfgVehicles class would fix both and needs a client mod (mission-config
    classes are not spawnable; proven twice). This is the no-download route:

      * THE SIGNS ARE VANILLA UserTexture QUADS, one per logo face, spawned here as class-name simple
        objects (createSimpleObject Syntax 2: texturable, scalable, no PhysX) and scaled to the face.
        The face positions are MEASURED from the model by build_vending.py and land here through
        vend_signs.inc.sqf -- never hand-copied. The texture is the same .paa r1 baked into the p3d,
        and the same string could be a uiEx(...) UI-on-texture page tomorrow.

      * THE ACTIONS ARE BUILT ON AN INVISIBLE REAL OBJECT at the front sign (a UserTexture1m_F, blank
        texture) so every NPC builder below attaches to it exactly as it would to a shop NPC -- same
        _target, same spawn-pad resolution from its position, same anti-cheat (fn_weaponShopMenu
        refuses _target isEqualTo _caller). BUT THEY ARE SHOWN FROM THE PLAYER, the fabricator's way
        (owner 2026-09-07: "none of them have scroll wheel options"). usertexture1m.p3d has a visual
        LOD and a Memory LOD and nothing else -- no Geometry, no ViewGeometry, no FireGeometry (read
        from misc_f.pbo) -- so the engine's look-at test for addAction can never pass on it, exactly the
        raycast problem fn_fabNear.sqf documents for the printers. So after the builder has done its
        work, every action on the carrier gets a PROXY on the player: same title, priority and
        condition, added by fn_setupActions for the cabinet within 2.5 m
        (fn_setupActions rebuilds the player's set on every scroll; the block at the end of this file
        prepares one spec per carrier action and setupActions adds them for the cabinet within 2.5 m),
        each running the carrier's own script with the carrier as _target (AP_fnc_vendFire).

      * Four objects per machine, all client-local, all tagged owner=AP_customBuilding so fn_cleanup's
        ownerless reap leaves them alone. fn_mapTick deletes the CABINET when the player streams away
        and knows nothing about these four, so one 3 s watchdog reaps any sign set whose cabinet went
        null. Without it, walking out of range and back would leave orphan signs floating where the
        row used to be, then a second set over the new cabinet.

    THE MACHINES DO NOT REIMPLEMENT ANY SHOP. Ten of the twelve hand the action object straight to the
    same NPC builder the real shop NPC uses, with the same arguments -- NPC_fnc_shops,
    NPC_fnc_civVehicles, NPC_fnc_civRebelVehicles, NPC_fnc_civRebelWeapon. (The npcs/ tree is tagged
    NPC_, not AP_ -- an AP_fnc_shops call compiles fine and does nothing at all.) The two REALLY
    ILL-EAGLE machines are New-Drachma-only by the handoff's table and the ND actions live INSIDE the
    rebel builders with the cash ones, so those two transcribe their three actions verbatim;
    tools\vend_check.py fails run_checks if either drifts from its source.

    VEHICLE MACHINES PASS AN EMPTY SPAWNS LIST ON PURPOSE: npcs\fn_nearSpawns.sqf resolves it against
    nearby car_spawn / air_spawn markers at init, so a machine dragged anywhere from its composition
    works as soon as pads come with it.

    WHICH SIDE OF A UserTexture QUAD CARRIES THE ART (owner, first look 2026-09-06: "the label is facing
    the wrong way" -- the quads faced along the outward normal and read from inside the cabinet). The
    quad now sits STANDOFF metres outside the face either way and only its FACING is flipped:
    AP_vendSignFlip (default true) points the quad's direction INTO the cabinet so its art side looks
    out. Set it false and relog to compare; the r2 flag moved the quad inside the model as well.
*/
#include "vend_signs.inc.sqf"

// AP_fnc_vendFire runs one prepared spec entry (see "the fabricator pattern" below). Defined up here so
// core\init.sqf's "boot" call makes it final at client init (security 2026-09-26).
if !(isFinal "AP_fnc_vendFire") then {AP_fnc_vendFire = compileFinal {
    (_this select 3) params ["_act", "_id", "_args", "_fn", "_file"];
    if (isNull _act) exitWith {};
    diag_log format ["[AP-VEND] fire: act=%1 id=%2 args=%3 file='%4' eye=%5 aim=%6 lineIntersects=%7", _act, _id, _args, _file, eyePos player, aimPos _act, lineIntersects [eyePos player, aimPos _act, player, _act]];
    if (_file isEqualTo "") then { [_act, player, _id, _args] call _fn; } else { [_act, player, _id, _args] execVM _file; };
}};
if (_this isEqualTo "boot") exitWith {};

params [["_obj", objNull, [objNull]], ["_slug", "", [""]]];

if (!hasInterface) exitWith {};                 // scroll actions and local signs are a client-side thing
if (isNull _obj) exitWith {
    diag_log format ["[AP-VEND] %1: null object -- the map row's init ran against nothing", _slug];
};
// Idempotent. fn_mapTick creates and deletes rows as the player moves, and a machine that streamed
// out and back in must not come back with two of every sign and action.
if (_obj getVariable ["AP_vendWired", false]) exitWith {};
_obj setVariable ["AP_vendWired", true];

private _flip = missionNamespace getVariable ["AP_vendSignFlip", true];
private _standoff = 0.006;         // metres proud of the face. r4 front is FLAT (0.012 proud of the body) and the pickup
                                   // flap frame starts 5 mm behind its face and stands 15 mm past it: at 6 mm the quad sits
                                   // inside the frame's depth, so the flap reads as set INTO the sign, as designed
private _scale = 0.66;             // SIDES: a 1x2 m quad at 0.66 = 0.66 x 1.32 on a 0.66 x 1.38 face
// FRONT: THREE 1 m QUADS STACKED (owner 2026-09-07, "the front displays aren't aligned with the machines").
// The front face is 0.55 x 1.615 (1:2.94) and its art 1:3; the 1:2 quad at 0.66 painted it 0.66 x 1.32 --
// squashed to two-thirds height, 5.5 cm over each side, 15 cm short top and bottom. Vanilla has no 1:3
// quad, a taller 1x2 would overhang the selection column, and the Super emissive rvmat cannot render
// alpha margins, so the front is three UserTexture1m_F at the face WIDTH: 0.55 x 1.65 m, 1.75 cm over
// at each end, art cut into thirds by build_vending_signs.py (front0 top, front1 middle, front2 bottom).
private _frontScale = 0.55;
private _frontTiles = 3;
private _up = vectorUp _obj;
private _made = [];

// ---- the sign quads: three tiles on the front slot, one 1x2 quad on each side slot ----
private _fnQuad = {
    params ["_class", "_pos", "_dir", "_scl", "_tex"];
    private _q = createSimpleObject [_class, _pos, true];
    _q setVectorDirAndUp [_dir, _up];   // direction FIRST: setDir/setVectorDir resets scale (BIKI setObjectScale)
    _q setObjectScale _scl;
    _q setObjectTexture [0, _tex];
    // The handoff's one lighting ask: "give the front a self-illuminated rvmat so it glows at night".
    // ap_vendsign.rvmat (emissive 45, Super shader) was written for exactly this face in r1 and now
    // rides the quad instead. Emissive multiplies the art, so the dark ground stays dark and only
    // the type reads lit. Same file on all faces -- see the rvmat's own header for why.
    _q setObjectMaterial [0, "mpmissions\__cur_mp.Malden\ap_vendsign.rvmat"];
    _q setVariable ["owner", "AP_customBuilding"];
    _made pushBack _q;
};
{
    _x params ["_face", "_c", "_n", "_size"];
    private _dir = _obj vectorModelToWorld (_n vectorMultiply ([1, -1] select _flip));   // facing only
    if (_face isEqualTo "front") then {
        // tile k sits (1 - k) * tile-height above the slot centre, in MODEL space (z is up there)
        for "_k" from 0 to (_frontTiles - 1) do {
            private _dz = _frontScale * ((_frontTiles - 1) / 2 - _k);
            private _pos = _obj modelToWorldWorld ((_c vectorAdd [0, 0, _dz]) vectorAdd (_n vectorMultiply _standoff));
            [ "UserTexture1m_F", _pos, _dir, _frontScale,
              format ["mpmissions\__cur_mp.Malden\ap_vend_%1_front%2_co.paa", _slug, _k] ] call _fnQuad;
        };
    } else {
        private _pos = _obj modelToWorldWorld (_c vectorAdd (_n vectorMultiply _standoff));   // always OUTSIDE the face
        [ "UserTexture_1x2_F", _pos, _dir, _scale,
          format ["mpmissions\__cur_mp.Malden\ap_vend_%1_side_co.paa", _slug] ] call _fnQuad;
    };
} forEach AP_vendSignSlots;

// ---- the invisible action carrier, at the front slot ----
private _front = AP_vendSignSlots select 0;
private _fn = _front select 2;                     // the OUTWARD normal: the carrier sits outside the face...
private _apos = _obj modelToWorldWorld ((_front select 1) vectorAdd (_fn vectorMultiply (_standoff + 0.05)));
// ...whatever the flip says. Until 2026-09-07 the flip was applied to _fn BEFORE this offset, which put the
// carrier 5.6 cm INSIDE the cabinet body; once the actions could actually be reached (the proxies), every
// shop menu's `lineIntersects [eyePos player, aimPos _target, ...]` crossed the cabinet's geometry and
// refused with "through the wall". Flip is a FACING concern only, same rule as the sign quads above.
if (_flip) then { _fn = _fn vectorMultiply -1; };
private _act = "UserTexture1m_F" createVehicleLocal [0, 0, 0];
_act setPosWorld _apos;
_act setVectorDirAndUp [_obj vectorModelToWorld _fn, _up];
_act setObjectTexture [0, ""];      // blank texture = invisible; the actions are what it is for
_act setVariable ["owner", "AP_customBuilding"];
_act setVariable ["AP_vendCabinet", _obj];
_made pushBack _act;

// ---- register with the reaper: signs die with their cabinet ----
if (isNil "AP_vendSigns") then {
    AP_vendSigns = [];
    [{
        AP_vendSigns = AP_vendSigns select {
            _x params ["_cab", "_objs"];
            if (isNull _cab) then { { deleteVehicle _x } forEach _objs; };
            !isNull _cab
        };
    }, createHashMap, 3] call AP_fnc_addPerFrameHandler;
};
AP_vendSigns pushBack [_obj, _made];
_obj setVariable ["AP_vendSignObjs", _made];
diag_log format ["[AP-VEND] %1 wired: cabinet %2, %3 sign quad(s) (front %4 tiles at %5, sides at %6), actions on %7", _slug, _obj, count _made - 1, _frontTiles, _frontScale, _scale, _act];

switch (_slug) do {

    // ---- SYNTH-MEAT MARKET -> the general market stall ------------------------------------
    case "synthmeat": { [_act, "", "market"] call NPC_fnc_shops; };

    // ---- CYBERTHREADS -> the civilian clothing shop (clothes + faces) ---------------------
    case "cyberthreads": { [_act, "", "civ"] call NPC_fnc_shops; };

    // ---- LO-POINT FIREARMS -> the legal gun store (licence + shop) ------------------------
    case "lopoint": { [_act, "", "gun"] call NPC_fnc_shops; };

    // ---- GROUNDED MOTORS -> the civilian car shop + garages -------------------------------
    case "carshop": { [_act, [], "", "carShop"] call NPC_fnc_civVehicles; };

    // ---- GROUNDED AVIATION -> the civilian helicopter shop + garages ----------------------
    case "airshop": { [_act, [], "", "airshop"] call NPC_fnc_civVehicles; };

    // ---- PACK RAT SURPLUS -> the general store --------------------------------------------
    case "gearshop": { [_act, "", "genstore"] call NPC_fnc_shops; };

    // ---- ILL-EAGLE FIREARMS & GEAR -> the rebel outfitter, whole ---------------------------
    case "illeagle": { [_act, ""] call NPC_fnc_civRebelWeapon; };

    // ---- ILL-EAGLE VEHICLES -> the rebel vehicle dealer, ground + air -----------------------
    case "illeaglevehicles": { [_act, [], "", "air"] call NPC_fnc_civRebelVehicles; };

    // ---- HARD RESET PHARMA -> the medical dispensary ---------------------------------------
    case "pharma": { [_act, "", "medicaldispensary"] call NPC_fnc_shops; };

    // ---- KABUKI ELECTRONICS -> the tech shop (chips, consumables, recycler) -----------------
    case "kabuki": { [_act, "", "tech"] call NPC_fnc_shops; };

    // ---- REALLY ILL-EAGLE FIREARMS & GEAR -- black market, New Drachma only -----------------
    // VERBATIM from npcs\fn_civRebelWeapon.sqf lines 8-9. tools\vend_check.py asserts that.
    case "reallyilleagleweapons": {
        _act addAction["New Drachma Clothes", AP_fnc_clothingMenu, ["rebcloth", true], 1.5, false, false, "", 'license_civ_rebel && AP_effSide isEqualTo civilian', 5];
        _act addAction["New Drachma Weapons", AP_fnc_weaponShopMenu, ["rebelwep", true], 1.5, false, false, "", 'license_civ_rebel && AP_effSide isEqualTo civilian', 5];
    };

    // ---- REALLY ILL-EAGLE VEHICLES -- black market, New Drachma only ------------------------
    // VERBATIM from npcs\fn_civRebelVehicles.sqf case "ground". There is no ND AIR shop in this
    // mission -- the rebel air NPC sells nd_car and nothing else -- so this machine sells the one
    // New Drachma vehicle list that exists, and the garages that make it usable.
    case "reallyilleagle": {
        // The builder we are NOT calling is also what normally resolves the pads, so this machine has
        // to do it itself -- the same prefixes fn_civRebelVehicles case "ground" asks for.
        private _spawns = [getPosATL _act, ["car_spawn", "air_spawn"]] call NPC_fnc_nearSpawns;
        if (_spawns isEqualTo []) then {
            diag_log format ["[AP-VEND] reallyilleagle: NO SPAWN PADS near %1 -- place car_spawn.. / air_spawn.. markers", getPosATL _act];
        };
        _act addAction["New Drachma Car Shop", AP_fnc_vehicleShopMenu, ['nd_car', civilian, _spawns, 'reb', "LoonyBin New Drachma Vehicles"], 1.5, false, false, "", 'license_civ_rebel && isNull objectParent player', 5];
        _act addAction["Vehicle Garage", {["Car", _this select 3] call AP_fnc_handleVehicles;
        }, _spawns, 1.5, false, false, "", 'isNull objectParent player', 5];
        _act addAction["Store vehicle in Garage", AP_fnc_storeVehicle, "", 1.5, false, false, "", '!AP_garage_store && isNull objectParent player', 5];
    };

    default {
        diag_log format ["[AP-VEND] unknown shop slug '%1' -- machine is inert", _slug];
    };
};

// ---- the fabricator pattern, done the way the fabricator actually does it -----------------------
// THE PLAYER'S SCROLL MENU IS EPHEMERAL: MouseZchanged -> AP_fnc_enableActions -> AP_fnc_setupActions
// rebuilds the whole context set, and 7 s later (or on any click) removeAllActions player wipes it.
// So nothing added to the player outside fn_setupActions survives -- measured 2026-09-07: 46 proxies
// added here were gone within 3 s of the first purchase, and the count swung 48 -> 151 -> 2 as the
// stock set came and went. The fabricator's actions live INSIDE fn_setupActions; so do ours now.
//
// This block only PREPARES: it reads every action the builder hung on the carrier (actionParams),
// compiles the script once, and stores the spec on the cabinet. fn_setupActions finds the cabinet
// within 2.5 m on each rebuild and adds one player action per spec entry, each running the carrier's
// own script with the carrier as _target through AP_fnc_vendFire (the anti-cheat whitelist token:
// initPlayerLocal's audit strips player actions whose title carries "--", "*", "~", "Ammo"... and the
// shop titles are full of them; actions routed through AP_fnc_vendFire are skipped).
//
// WHY NOT `player action ["User", _act, _id]`: the engine ran the shop script without the carrier as
// _this select 0, so fn_virtualShopMenu's lineIntersects measured a line to nowhere ("through the wall").
_obj setVariable ["AP_vendSlug", _slug];
_obj setVariable ["AP_vendAct", _act];
private _spec = [];
{
    private _id = _x;
    // arguments come back as nil for an action added without any -- default them, or the array literal
    // below throws "Undefined variable _args" (measured 17:48, first deploy of this block)
    (_act actionParams _id) params ["_title", ["_script", "", ["", {}]], ["_args", []], "_prio", "_show", "_hideOnUse", "_shortcut", "_cond"];
    if (_cond isEqualTo "") then { _cond = "true" };
    // BIKI says the script comes back as text (a code value as its body); should the engine hand back
    // code, use it as it is. A script FILE stays a file (execVM); anything else compiles once, here.
    private _file = ""; private _fn = {};
    if (_script isEqualType {}) then { _fn = _script; } else {
        if ((toLower _script) find ".sqf" >= 0 && {(toLower _script) find ";" < 0}) then { _file = _script; } else { _fn = compile _script; };
    };
    // The builders' conditions read only globals (checked 2026-09-07: no _target in any of them), so
    // they hold verbatim with the player as the action's own _target.
    _spec pushBack [_title, [_act, _id, _args, _fn, _file], _prio, _show, _hideOnUse, _shortcut, _cond];
} forEach (actionIDs _act);
_obj setVariable ["AP_vendSpec", _spec];
diag_log format ["[AP-VEND] %1: %2 action spec(s) prepared for fn_setupActions", _slug, count _spec];
