/*
    web_shop.hpp  --  the web virtual shop. idd 39600.

    One CT_WEBBROWSER control and nothing else, same shape as deck_phone.hpp.
    Everything drawn -- panel, rows, prices, buttons -- comes from ui\html\shop.html.

    One dialog serves EVERY virtual shop: the shop type is pushed as data, not
    baked into the layout, so market / rebel / gas / hospital / wongs / black
    market and the rest all arrive here.

    idd 39600 sits clear of the native shop's 39500 on purpose -- both exist, and
    fn_virtualShopMenu picks between them, so the old one stays as a fallback.
*/

class AP_web_shop {
    idd = 39600;
    name = "AP_web_shop";
    movingEnable = false;
    enableSimulation = true;
    onLoad = "[_this select 0] spawn AP_fnc_shopOpen;";

    class controls {
        class Page {
            idc = 39601;
            type = 106;                 // CT_WEBBROWSER, Arma 2.20+
            style = 0;
            x = -20 * UI_GRID_W + UI_GRID_X; y = -11 * UI_GRID_H + UI_GRID_Y;
            w  =  40 * UI_GRID_W;            h =  22 * UI_GRID_H;
            colorBackground[] = {0,0,0,0};
            colorText[] = {1,1,1,1};
            font = "RobotoCondensed";
            sizeEx = 0.6 * UI_GRID_H;
            url = "ui\html\shop.html";
        };

        // native text entry -- the fallback prompt, same include the deck uses
        #include "..\webui\config\prompt_overlay.hpp"
    };
};
