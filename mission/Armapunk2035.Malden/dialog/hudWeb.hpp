/*
    hudWeb.hpp -- AP_web_hud (938300): the owner's STATUS HUD as an HTML page, hosted in an
    RscTitles LAYER rather than a dialog. Driven by core\web\fn_hudWebInit.sqf (cut + bridge)
    and core\web\fn_hudWebPush.sqf (one push per native HUD refresh). Page: ui\html\hud.html.

    WHY A TITLE LAYER AND NOT A DIALOG. A HUD must not take input. createDialog creates a
    FOCUSED display: it eats the mouse, it eats movement keys, and Esc closes it -- every web
    screen in this mission (breach 937700, storage 938000, landing 938100, visor 941700) is a
    dialog for exactly that reason, and every one of them is a screen the player has stopped
    playing to look at. An RscTitles layer cut with cutRsc is never focused, so the engine
    never routes input to it: that is what makes AP_ToastBase, AP_AutoRadioMenu and AP_GpsHud
    non-interactive, and it is what makes this one safe to leave up while the player fights.

    THE HOST IS PROVEN IN THIS MISSION, NOT ASSUMED -- two halves, both shipped:

      1. A type=106 browser control INSIDE RscTitles, cut with cutRsc, binds A3API and runs
         its page's JavaScript. That is AP_map_warm (description.ext:60), cut every connect
         from core\init.sqf:60, whose whole job is to call A3API.RequestTexture 338 times from
         a title-layer page. If the engine did not bind A3API in a title layer the map warmer
         would have been a silent no-op since the day it landed. It also proves a title-layer
         browser can sit there for the entire session (duration = 1e10, never cut down) with
         the phone and the casino opening browser dialogs on top of it -- two live controls at
         once is already this mission's normal, not something this class introduces.

      2. A full-screen type=106 control with colorBackground {0,0,0,0} over a transparent page
         renders with the live world showing through. That is AP_web_visor (web_visor.hpp),
         "full-screen, transparent browser control over the live world", shipped and used.

    What neither half proves on its own is the COMPOSITION -- a title-layer browser that draws
    VISIBLE pixels, because AP_map_warm is a 0.02 x 0.02 speck that deliberately paints
    nothing. There is no engine reason for it to differ (a title-layer display's controls go
    through the same draw path a dialog's do, which is why the radio card and the toasts are
    visible at all), but it is inference, not a measurement, and the owner's first look at this
    HUD is the measurement -- see DUTY_SOAK.md H18. This class is deliberately shaped so that
    look is a clean yes/no: the native HUD is untouched and still drawing underneath it, so
    "nothing new appeared" is the failure and "a plate stack over the old bars" is the pass.

    FULL SAFEZONE, like web_visor.hpp and unlike every windowed page. The page anchors itself
    with position:fixed against the CONTROL's viewport, not the screen (core\web\README.md,
    "The page's viewport scales with the CONTROL"), so the control box IS the placement lever:
    at full safezone the designer's right:2rem / bottom:2rem lands in the real bottom-right
    corner at the rem size the design was drawn for. Shrinking this box would move the HUD and
    shrink its type at the same time -- and since the page's revision added a MINIMAP anchored
    left:2rem / bottom:2rem, the box now has to span both bottom corners for either of them to
    sit where it was drawn. A windowed control is no longer even an option.

    colorBackground IS {0,0,0,0} AND MUST STAY THAT WAY. Transparency is the owner's stated
    requirement for this screen and it is a chain, not a property -- the page's own
    html,body{background:transparent}, the shim adding no background of its own, and this
    line. Any one of the three going opaque paints a black rectangle over the whole world.

    idd 938300 continues the web run (937700 breach, 937800 terminal, 937900 journal, 938000
    storage, 938100 landing, 938200 duty terminal) and 938301 is its control, the idd+1
    convention every page in that run uses. The idd is for identification only: a title layer
    is not findDisplay-able, so the display handle comes from onLoad through uiNamespace --
    the AP_AutoRadioMenu / AP_GpsHud pattern, cleared on unload and on destroy so a stale
    handle can never be pushed into after the layer has been cut down.
*/
class AP_web_hud {
    idd = 938300;
    movingEnable = 0;
    enableSimulation = 1;
    fadein = 0;
    fadeout = 0;
    duration = 1e10;
    onLoad = "uiNamespace setVariable ['AP_web_hud', _this select 0];";
    onUnload = "uiNamespace setVariable ['AP_web_hud', displayNull];";
    onDestroy = "uiNamespace setVariable ['AP_web_hud', displayNull];";
    class controls {
        class Page {
            idc = 938301;
            type = 106;
            style = 0;
            x = safezoneX; y = safezoneY; w = safezoneW; h = safezoneH;
            colorBackground[] = {0,0,0,0};
            colorText[] = {1,1,1,1};
            font = "RobotoCondensed";
            sizeEx = 0.03;
            url = "ui\html\hud.html";
        };
    };
};
