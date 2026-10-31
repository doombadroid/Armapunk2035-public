/*
    web_landing.hpp -- AP_web_landing (938100): the connect-time landing screen. Welcome splash +
    deployment picker (solo civ / MaxSec duty / Trauma Team duty), opened by AP_fnc_landingOpen from
    fn_initCiv in place of the lobby welcome's PLAY gate. See core\web\fn_landingBridge.sqf.

    FULL SCREEN, like web_visor.hpp and unlike every windowed page: this is the whole frame while the
    player is still held pre-spawn, so it takes the safezone rather than the 40x22 grid box the casino
    tables use.

    colorBackground is OPAQUE, which the other web dialogs' is not. Behind this control is the mission.sqm
    player slot at 50 km (initPlayerLocal.sqf:8-19) -- open sky, and a frame of it showing through while
    the page paints would read as a broken splash. The page paints its own background over this anyway.

    idd 938100 continues the web-dialog run (937700 breach, 937800 terminal, 937900 journal, 938000
    storage) and 938101 is its control, the idd+1 convention every page in that run uses.
*/
class AP_web_landing {
    idd = 938100;
    name = "AP_web_landing";
    movingEnable = false;
    enableSimulation = true;
    onLoad = "[_this select 0] spawn AP_fnc_landingBridge;";
    class controls {
        class Page {
            idc = 938101;
            type = 106;
            style = 0;
            x = safezoneX; y = safezoneY; w = safezoneW; h = safezoneH;
            colorBackground[] = {0,0,0,1};
            colorText[] = {1,1,1,1};
            font = "RobotoCondensed";
            sizeEx = 0.03;
            url = "ui\html\landing.html";
        };
        #include "..\webui\config\prompt_overlay.hpp"
    };
};
