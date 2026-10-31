/*
    web_breach.hpp — SEQUENCE BREACH (937700). One browser control, ui\html\breach.html.

    Replaces cyberdeck_seq (940000) and the 2.67 MB backdrop it was painted on. Same
    contract to the world: fn_cyberdeckSeq still blocks and still answers 1 / 0 / -1.
*/
class AP_web_breach {
    idd = 937700;
    name = "AP_web_breach";
    movingEnable = false;
    enableSimulation = true;
    onLoad = "[_this select 0] spawn AP_fnc_breachOpen;";
    class controls {
        class Page {
            idc = 937701;
            type = 106;
            style = 0;
            x = -20 * UI_GRID_W + UI_GRID_X; y = -11 * UI_GRID_H + UI_GRID_Y;
            w  =  40 * UI_GRID_W;            h =  22 * UI_GRID_H;
            colorBackground[] = {0,0,0,0};
            colorText[] = {1,1,1,1};
            font = "RobotoCondensed";
            sizeEx = 0.6 * UI_GRID_H;
            url = "ui\html\breach.html";
        };
    };
};
