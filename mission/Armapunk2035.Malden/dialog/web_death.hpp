/*
    web_death.hpp -- AP_web_death (938800): the death screen. The approved FLATLINED
    concept (design\death-menu\death-c.html), replacing the native DeathScreen
    (dialog 7300, dialog\deathScreen.h). Opened by AP_fnc_deathWebOpen from
    evh\fn_onPlayerKilled.sqf, which falls back to 7300 when it declines. See
    core\web\fn_deathWebBridge.sqf.

    colorBackground IS FULLY TRANSPARENT, and that is the one thing this class exists
    to get right. Behind this control is the real corpse camera
    (dialog\function\fn_deathCamera.sqf) tracking the player's own body with its
    collision-aware follow. The approved screen is a HUD over that camera, not a
    replacement for it -- an opaque backdrop here would hide the shot the whole
    design is composed around. The page paints its own panel backgrounds and leaves
    the rest of the surface clear.

    FULL SAFEZONE, like web_landing.hpp and web_spawn.hpp: the headline sits at the
    left edge and the recovery console at the right, so the composition needs the
    whole frame rather than the 40x22 grid box the windowed pages use.

    ESCAPE IS BLOCKED BY THE OPENER, not here -- AP_fnc_deathWebOpen attaches the
    same KeyDown handler dialog 7300 has always carried. It cannot live in the class
    because onLoad's display is handed to the bridge.

    938800 continues the web-dialog run (938100 landing, 938700 spawn) and 938801 is
    its control, the idd+1 convention every page in that run uses.
*/
class AP_web_death {
    idd = 938800;
    name = "AP_web_death";
    movingEnable = false;
    enableSimulation = true;
    onLoad = "[_this select 0] spawn AP_fnc_deathWebBridge;";
    class controls {
        class Page {
            idc = 938801;
            type = 106;
            style = 0;
            x = safezoneX; y = safezoneY; w = safezoneW; h = safezoneH;
            colorBackground[] = {0,0,0,0};
            colorText[] = {1,1,1,1};
            font = "RobotoCondensed";
            sizeEx = 0.03;
            url = "ui\html\death.html";
        };
        #include "..\webui\config\prompt_overlay.hpp"
    };
};
