/*
    fn_casinoFit.sqf — make a casino table fill the screen.

    The tables shipped at 40x22 UI_GRID, which is the phone's window shape, and
    they are not readable at it. Owner 2026-08-12: the casino is a full-screen
    thing -- it is going to leave the handset entirely and live at the tables in
    the building, where nobody is squinting at a 1200px box.

    Growing the CONTROL is the whole fix; the page follows for free. Every table
    is `#frame{width:min(96vw,192vh); aspect-ratio:2/1}` with `1rem = frame
    width/75`, so the layout is rem-based off the frame rather than pixel-fixed:
    a wider control means a wider frame means a larger rem, and the type scales
    with it. Same design, physically bigger. This is the same reason
    AP_fnc_deckScale works by resizing the control and nothing else.

    Safezone rather than a grid count, because UI_GRID_W is a fixed PHYSICAL size
    (2.5 * pixelW * pixelGrid) tied to the player's interface-size setting -- a
    grid box big enough on one setting hangs off the screen on another. The
    safezone is the screen, whatever the aspect and whatever the setting.

    The page keeps its own 2:1 letterbox inside that, so an ultrawide gets bars
    down the sides rather than a stretched felt. That is the page's call to make
    and it already makes it.

        [_ctrl] call AP_fnc_casinoFit;
*/

params [["_ctrl", controlNull, [controlNull]]];
if (isNull _ctrl) exitWith { false };

_ctrl ctrlSetPosition [safezoneX, safezoneY, safezoneW, safezoneH];
_ctrl ctrlCommit 0;
diag_log format ["[CASINO] fit %1x%2 safezone", (safezoneW / (2.5 * pixelW * pixelGrid)) toFixed 1, (safezoneH / (2.5 * pixelH * pixelGrid)) toFixed 1];
true
