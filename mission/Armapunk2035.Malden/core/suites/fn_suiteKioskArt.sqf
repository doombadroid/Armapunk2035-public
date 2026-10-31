/*
    File: fn_suiteKioskArt.sqf  (AP_fnc_suiteKioskArt)
    Luxe Suites 2026-08-07 -- put the WELCOME TO LUXE SUITES panel on the kiosk.

        [] spawn AP_fnc_suiteKioskArt      (once, from core\init.sqf)

    The kiosk is a GalleryDioramaUnit_01_F. Slot 0 is its SCREEN -- read out of
    AoW's own config rather than guessed (props_f_aow.pbo:
    hiddenSelectionsTextures[0] = a3\Props_F_AoW\Civilian\Gallery\data\screen_co.paa,
    slot 1 is a procedural colour and 2..4 are the base unit). The art is baked to
    match that texture's 1024x1024 by scratchpad\suites\bake_kiosk.py.

    WHY A LOOP AND NOT A ONE-SHOT. The diorama comes from mapData, which spawns
    through AP_fnc_createVehicleLocal: the object is CLIENT-LOCAL and zone
    STREAMED, so it does not exist at mission start and it is destroyed and
    recreated as the player leaves and re-enters the area. A single pass at init
    would texture nothing, and even a lucky pass would be undone by the next
    stream cycle. This is the same property that defeated the first attempt to
    tag the kiosk server-side ("[SUITE] kiosk NOT FOUND" -- the server never sees
    these objects at all).

    WHY allSimpleObjects AND NOT nearestObjects (b0368 did not show the art).
    AP_fnc_createVehicleLocal spawns a prop with no doors, no init code and no
    loadout through createSimpleObject -- and the diorama has numberOfDoors 0, so
    the kiosk is a SIMPLE OBJECT. Simple objects do not appear in nearestObjects,
    so the first version's search returned an empty list every tick and textured
    nothing. That is the same reason AP_fnc_suiteTowers already has to reach for
    allSimpleObjects to find the tower. setObjectTexture itself works fine on a
    simple object (BI's own createSimpleObject example does exactly that), so
    only the lookup was wrong.

    allSimpleObjects [] returns every simple object on the map -- thousands, as
    the whole mapData prop set spawns this way -- so this scans ONLY when near a
    tower and caches the kiosk once found, rather than sweeping that list on a
    timer for no reason.

    setObjectTexture, not ...Global: the object is local to this machine, so a
    global call would be broadcasting about an object no one else has.
*/
// Height of the hologram's CENTRE above the diorama's origin. The model is
// 1.75 m tall and centred on its own bbox (simple objects are autocentred, so
// its centre is what setPosASL positions), which puts its base ~0.95 m up --
// clear of the plinth, floating.
#define AP_HOLO_LIFT 1.82

if (!hasInterface) exitWith {};
if (missionNamespace getVariable ["AP_suiteArtMon", false]) exitWith {};
AP_suiteArtMon = true;

[] spawn {
    private _tex = "images\suites\kiosk_welcome.paa";
    while { true } do {
        sleep 5;
        // Only look while we are actually at a tower. Away from one this costs a
        // distance test against a handful of towers and nothing else.
        private _near = (call AP_fnc_suiteTowers) findIf { (_x distance2D player) < 150 };
        if (_near > -1) then {
            // Streaming destroys and recreates these, so a cached handle goes
            // null and we simply look again.
            {
                if (!(_x getVariable ["AP_suiteArt", false]) && {(_x distance2D player) < 120}) then {
                    _x setObjectTexture [0, _tex];
                    _x setVariable ["AP_suiteArt", true];
                };
            } forEach ((allSimpleObjects []) select {
                "gallerydioramaunit" in toLower ((getModelInfo _x) select 0)
            });

            // ---- the hologram -------------------------------------------
            // A stylised massing of the tower turning above the diorama
            // (ap_holo_tower_r1.p3d, 420 faces, visual LOD only so it can never
            // be collided with or shot). Local simple object, like every other
            // custom building: no network traffic and JIP handles itself.
            {
                if (isNull (_x getVariable ["AP_suiteHolo", objNull])) then {
                    private _h = createSimpleObject
                        [(getMissionPath "custom_p3ds\") + "ap_holo_tower_r1.p3d",
                         (getPosASL _x) vectorAdd [0, 0, AP_HOLO_LIFT], true];
                    _x setVariable ["AP_suiteHolo", _h];
                    // Spin + bob. Runs only while the projector is streamed in
                    // and somebody is close enough to see it -- an idle kiosk on
                    // the far side of the map costs nothing.
                    [_x, _h] spawn {
                        params ["_kiosk", "_h"];
                        private _base = getPosASL _h;
                        private _dir = 0;
                        while { !isNull _h && {!isNull _kiosk} } do {
                            if ((_h distance2D player) < 60) then {
                                _dir = (_dir + 0.55) % 360;
                                _h setDir _dir;
                                _h setPosASL (_base vectorAdd
                                    [0, 0, 0.035 * sin (time * 45)]);
                                sleep 0.03;
                            } else {
                                sleep 2;
                            };
                        };
                    };
                };
            } forEach ((allSimpleObjects []) select {
                "gallerydioramaunit" in toLower ((getModelInfo _x) select 0)
                    && {(_x distance2D player) < 120}
            });
        };
    };
};
