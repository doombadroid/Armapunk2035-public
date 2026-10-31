/*
    fn_deckScale.sqf — size the phone. Owner request 2026-08-11.

    The page never changes size on its own: ui\html\deck.html's fit() already scales the whole
    chassis to fill whatever the browser control gives it (Math.min of the two axes against the
    1034x494 assembly). So making the phone bigger is entirely a matter of making the CONTROL
    bigger, and the page follows for free.

    This works because UI_GRID_W is 2.5 * pixelW * pixelGrid -- a fixed PHYSICAL size tied to the
    player's interface-size setting, not a fraction of the screen. A 40x20 grid box is therefore
    a modest window with real headroom above it, and the same scale looks the same on any
    resolution.

    Scale 1.0 is the current size and is the FLOOR, per the owner: the phone never gets smaller
    than it shipped. The ceiling is computed from the safezone rather than guessed, so the handset
    can never grow off the edge of the screen on a narrow aspect or a large interface-size setting.

        [_ctrl]      call AP_fnc_deckScale;   // apply the saved scale
        [_ctrl, 1.4] call AP_fnc_deckScale;   // set, persist, apply

    Returns the scale actually applied, which is not always the one asked for -- the caller wants
    to know what it got so the slider can snap back to the real ceiling.
*/

params [["_ctrl", controlNull, [controlNull]], ["_set", -1, [0]]];

// UI_GRID_W / UI_GRID_H from dialog\MasterHandler.h, evaluated live because pixelGrid moves with
// the player's interface size.
private _gw = 2.5 * pixelW * pixelGrid;
private _gh = 2.5 * pixelH * pixelGrid;

// Ceiling: the largest scale where the control still fits the safezone on BOTH axes. 0.98 keeps a
// hair of margin so it never sits flush against the edge.
private _maxW = (safezoneW * 0.98) / (40 * _gw);
private _maxH = (safezoneH * 0.98) / (20 * _gh);
private _max  = ((_maxW min _maxH) min 2.5) max 1;

private _s = if (_set >= 0) then { _set } else { profileNamespace getVariable ["AP_deckScale", 1] };
if !(_s isEqualType 0) then { _s = 1 };
_s = (_s max 1) min _max;

if (_set >= 0) then {
    profileNamespace setVariable ["AP_deckScale", _s];
    saveProfileNamespace;
};

if (!isNull _ctrl) then {
    private _w = 40 * _s * _gw;
    private _h = 20 * _s * _gh;
    // UI_GRID_X / UI_GRID_Y are both 0.5, so the box stays centred as it grows.
    _ctrl ctrlSetPosition [0.5 - (_w / 2), 0.5 - (_h / 2), _w, _h];
    _ctrl ctrlCommit 0;
    // The DOM resize event does fire when the control is resized, but only once the engine has
    // committed it -- calling fit() directly removes the ordering question entirely.
    _ctrl ctrlWebBrowserAction ["ExecJS", "if (typeof fit === 'function') fit();"];
};

_s
