/*
    web_loot.hpp -- AP_web_loot (1530): the LOOT CARD beside the crosshair.
*/
class AP_web_loot {
    idd = 1530;
    name = "AP_web_loot";
    movingEnable = false;
    enableSimulation = true;
    onLoad = "[_this select 0] spawn AP_fnc_lootBridge;";
    class controls {
        class Page {
            idc = 1531;
            type = 106;
            style = 0;
            x = 0.54; y = 0.24; w = 0.3; h = 0.4;
            colorBackground[] = {0,0,0,0};
            colorText[] = {1,1,1,1};
            font = "RobotoCondensed";
            sizeEx = 0.03;
            url = "ui\html\loot.html";
        };
        #include "..\webui\config\prompt_overlay.hpp"
    };
};
