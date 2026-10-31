/*
    AP_fnc_warmRepush -- put a fresh landing payload on the landing page, from outside its bridge.

        [] call AP_fnc_warmRepush;

    The landing screen is pushed to from exactly two places in its own bridge: the landingReady
    handler and the tail push (core\web\fn_landingBridge.sqf:49 and :102). Both resolve the page
    through uiNamespace "WEBUI_ctrl", which is correct for them -- they run from the dialog's own
    onLoad, so the slot is theirs at that instant. It is NOT correct for anything that fires later:
    the slot holds whichever browser control initialised last, and by the time the cache worker has
    something to say that can be a different page entirely.

    So this resolves the display by idd instead. 938100 is a DIALOG and therefore findDisplay-able
    (unlike a title layer -- dialog\hudWeb.hpp's header records that distinction), and 938101 is its
    control by the idd+1 convention every page in the 9377xx-9385xx run uses.

    A CLOSED LANDING IS THE NORMAL CASE, NOT AN ERROR. The dialog closes on DEPLOY and the cache goes
    on filling for a minute afterwards; every one of those pushes lands here, finds no display and
    does nothing. That silence is the whole reason the worker survives the screen going away.

    Returns true if a payload actually went out.
*/
disableSerialization;
if (!hasInterface) exitWith { false };
if (isNil "webui_fnc_push") exitWith { false };

private _d = findDisplay 938100;
if (isNull _d) exitWith { false };

private _c = _d displayCtrl 938101;
if (isNull _c) exitWith { false };

[_c, "landing", ([] call AP_fnc_landingData)] call webui_fnc_push;
true
