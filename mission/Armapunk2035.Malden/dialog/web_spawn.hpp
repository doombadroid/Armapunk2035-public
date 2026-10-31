/*
    web_spawn.hpp -- AP_web_spawn (938700): the spawn screen. The owner's SPOOL MK-II deck mockup
    (spawn.zip, 2026-09-11) with its satmap placeholder replaced by the real 3D renderer
    (ui\html\grid3d.js, the same one behind MALDEN GRID and the HUD minimap). Opened by
    AP_fnc_spawnWebOpen from fn_spawnMenu and fn_redeployMenu, both of which fall back to the native
    dialog 38500 when it declines. See core\web\fn_spawnWebBridge.sqf.

    FULL SCREEN, like web_landing.hpp and web_visor.hpp and unlike the windowed casino tables: this is
    the whole frame while the player is still held pre-spawn, so it takes the safezone rather than the
    40x22 grid box.

    colorBackground is OPAQUE, for web_landing.hpp's reason exactly: behind this control is the
    mission.sqm player slot at 50 km (initPlayerLocal.sqf:8-19) -- open sky, and a frame of it showing
    through while the page paints would read as a broken screen. On the redeploy path the player is
    standing in the world instead, and an opaque backdrop is still right: a spawn picker over a live
    3D view of wherever they happen to be standing is a worse screen, not a better one.

    938700 continues the web-dialog run (938100 landing, 938200-938600 the rest) and 938701 is its
    control, the idd+1 convention every page in that run uses.
*/
class AP_web_spawn {
    idd = 938700;
    name = "AP_web_spawn";
    movingEnable = false;
    enableSimulation = true;
    onLoad = "[_this select 0] spawn AP_fnc_spawnWebBridge;";
    class controls {
        class Page {
            idc = 938701;
            type = 106;
            style = 0;
            x = safezoneX; y = safezoneY; w = safezoneW; h = safezoneH;
            colorBackground[] = {0,0,0,1};
            colorText[] = {1,1,1,1};
            font = "RobotoCondensed";
            sizeEx = 0.03;
            url = "ui\html\spawn.html";
        };
        #include "..\webui\config\prompt_overlay.hpp"
    };
};
