// Altis Life game mechanic — fictional in-game "quickhack" ability, game logic only.
/*
    File: fn_visorOpen.sqf  (AP_fnc_visorOpen)

    VISOR entry point -- HTML port of fn_qhDock.sqf (SHIFT+Y, dialog vr_dock
    941300). Built ALONGSIDE the native dock, not over it: neither fn_qhDock.sqf
    nor vr_dock.hpp is touched here, and this does not claim SHIFT+Y (this repo's
    key handler is owned elsewhere). Same freeze-frame gaze capture, so the two
    can be compared side by side before the old one retires.

    owner 2026-09-05: THE VR-GOGGLES HARDWARE GATE IS GONE. The visor used to
    require G_Goggles_VR worn on the face (bought for $1,000 at Kabuki, or the
    MaxSec shop for cops); it is now standard issue and every player has the
    overlay from the moment they spawn. G_Goggles_VR survives as an ordinary
    cosmetic in the clothing and fabricator catalogues -- it just does not gate
    anything any more. The side gate below is what remains: civ gets the
    ICEBREAKER ring, MaxSec gets TAL OS, and independent has neither pool.

    Casting authority is NOT decided here, or anywhere in this file -- see
    fn_visorBridge.sqf's header.
*/
if (!hasInterface) exitWith {};
if (!alive player) exitWith {};
if (dialog) exitWith {};
// Not a fn_qhDock.sqf behaviour (the native dock has no restrained check --
// the key handler pre-empts it by routing SHIFT+Y to AP_fnc_qhCuffHack
// instead while cuffed). This opener can be reached by a different trigger,
// so it re-checks locally rather than relying on that pre-empt existing
// upstream -- same restraint gate every other menu/dialog in this mission uses.
if ((player getVariable ["AP_restrained", false]) || (player getVariable ["AP_civRestrained", false])) exitWith {
    ["You can't run the visor while restrained.", "basic"] spawn AP_fnc_handleMessage;
};
private _cop = AP_effSide isEqualTo west;
// SIDE gate, not a hardware or firmware gate (owner 2026-09-05). AP_fnc_hasDeck is now
// "you are civilian", so this reads: MaxSec -> TAL OS ring, civilian -> ICEBREAKER ring,
// independent -> neither, because AP_fnc_qhConsoleGet only has a cop pool and a civ pool and
// handing a medic the civ pool would hand them every illegal hack in the game.
if (!_cop && {!(call AP_fnc_hasDeck)}) exitWith {
    ["The visor has no ring for your side.", "basic"] spawn AP_fnc_handleMessage;
};
if (!isNull (findDisplay 941700)) exitWith {};
AP_cdTarget = cursorObject;   // same freeze-frame "gaze lock" fn_qhDock.sqf captures
createDialog "AP_web_visor";
