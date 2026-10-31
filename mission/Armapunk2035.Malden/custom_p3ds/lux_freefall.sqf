/*
    custom_p3ds\lux_freefall.sqf — stop the HALO pose on the upper floors
    of the Skyscraper30 lux. Owner report 2026-08-07: "anything higher than
    floor 28, if you sprint it puts you in the skydiving animation."

    NOT a model bug and not fixable in the model. From the engine docs for
    setUnitFreefallHeight: "Sets minimum freefall height AGL per unit, at which
    the unit assumes HALO pose. ENGINE DEFAULT IS 100m." The check is against
    height above TERRAIN -- the engine has no idea a floor is holding you up.

    The tower's floors are 3.6 m apart and floor 1 sits on the 3 m foundation
    plinth, so floor 29 is the first storey more than 100 m over the terrain.
    Sprinting takes both feet off the deck for a frame, the engine sees a unit
    falling above its freefall height, and poses it for a skydive. Exactly the
    reported boundary, and it would hit every tall building we ever build.

    FIX: raise the threshold, but ONLY for a player at this tower. A blanket
    raise would break the Battle Royale drop (core\adminEvents\fn_eventBRClient
    parachutes players in and wants the real freefall pose), so the monitor
    hands the height back to the engine default the moment you walk away.

    Runs on every machine like the rest of the tower's systems; the monitor
    itself is client-only and single-instance, iterating whatever towers the
    sweep found. Reads the live value back through getUnitFreefallInfo rather
    than tracking what it last set -- that costs nothing and is automatically
    correct after a respawn, which resets the unit's height to default (the
    documented gotcha with this command).
*/
params ["_bld"];

// 250: clears the roof (~110 m AGL) with room to spare, and is still low
// enough that a genuine high-altitude jump poses correctly.
// 60: the tower is ~35 m square, so this covers the roof edge and the apron.
// Comments are kept OFF the #define lines on purpose -- a trailing comment on
// a macro line is a preprocessor footgun this repo has been bitten by before.
#define AP_LUXFF_HEIGHT   250
#define AP_LUXFF_RADIUS   60
#define AP_LUXFF_TICK     2

if (isNil "AP_LUX_TOWERS") then { AP_LUX_TOWERS = []; };
AP_LUX_TOWERS pushBackUnique _bld;

if (!hasInterface) exitWith {};
if (missionNamespace getVariable ["AP_LUXFF_MON", false]) exitWith {};   // one monitor, many towers
AP_LUXFF_MON = true;

[] spawn {
    while { true } do {
        sleep AP_LUXFF_TICK;
        // AP_inEvent forces the far branch: an admin event can teleport a
        // player straight from this lobby into a parachute drop, and that drop
        // needs the engine default back.
        private _near = !(missionNamespace getVariable ["AP_inEvent", false])
            && { (AP_LUX_TOWERS findIf { !isNull _x && { (player distance2D _x) < AP_LUXFF_RADIUS } }) > -1 };
        private _cur = (getUnitFreefallInfo player) param [2, 100];
        if (_near) then {
            if (_cur < AP_LUXFF_HEIGHT) then { player setUnitFreefallHeight AP_LUXFF_HEIGHT; };
        } else {
            if (_cur > 100) then { player setUnitFreefallHeight -1; };
        };
    };
};
