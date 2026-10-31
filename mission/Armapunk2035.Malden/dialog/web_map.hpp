/*
    web_map.hpp — MALDEN GRID (930430). One browser control; fn_mapOpen sizes it
    to the safezone at load, so the class geometry is only the pre-fit frame.
*/
class AP_web_map {
    idd = 930430;
    name = "AP_web_map";
    movingEnable = false;
    enableSimulation = true;
    onLoad = "[_this select 0] spawn AP_fnc_mapOpen;";
    class controls {
        class Page {
            idc = 930431;
            type = 106;
            style = 0;
            x = -20 * UI_GRID_W + UI_GRID_X; y = -11 * UI_GRID_H + UI_GRID_Y;
            w  =  40 * UI_GRID_W;            h =  22 * UI_GRID_H;
            colorBackground[] = {0,0,0,0};
            colorText[] = {1,1,1,1};
            font = "RobotoCondensed";
            sizeEx = 0.6 * UI_GRID_H;
            url = "ui\html\map.html";
        };
        #include "..\webui\config\prompt_overlay.hpp"
    };
};
