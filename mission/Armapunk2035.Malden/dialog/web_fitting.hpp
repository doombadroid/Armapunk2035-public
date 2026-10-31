/*
    web_fitting.hpp -- AP_Clothing_Web (idd 3100): FITTING ROOM, the HTML
    clothing shop, SAME IDD as the native dialog on purpose.

    fn_clothingMenu is the engine and stays byte-identical: it snapshots the old
    loadout, creates the preview camera, opens "the clothing dialog", wires the
    filter/list/buy/vision controls, and its post-close tail owns the cancel
    restore, the purchase save, the camera teardown and the invisible-bag
    re-hide. All of that keys off findDisplay 3100 -- so this dialog carries the
    NATIVE CONTROLS, parked offscreen and tiny, and the page on top drives them:
    a try-on is a programmatic lbSetCurSel on the real list, a buy is
    ctrlActivate on the real button. changeClothes and buyClothes run
    byte-for-byte native; the web layer never re-implements a single rule of
    the most restore-sensitive screen in the mission.
*/
class AP_Clothing_Web {
    idd = 3100;
    name = "AP_Clothing_Web";
    movingEnable = false;
    enableSimulation = true;
    onLoad = "[_this select 0] spawn AP_fnc_fittingOpen;";
    class controls {
        // ---- the native control set, offscreen. idcs are the contract. ----
        class Title: AP_RscTitle       { idc = 3103; x = -10; y = -10; w = 0.1;  h = 0.02; };
        class FilterList: AP_RscCombo  { idc = 3102; x = -10; y = -9.9; w = 0.1; h = 0.02; };
        class ClothingList: AP_RscListBox { idc = 3101; x = -10; y = -9.8; w = 0.1; h = 0.1; };
        class SearchInput: AP_RscEdit  { idc = 3110; x = -10; y = -9.6; w = 0.1; h = 0.02; text = ""; };
        class TotalValue: AP_RscText   { idc = 3106; x = -10; y = -9.5; w = 0.1; h = 0.02; };
        class PriceValue: AP_RscText   { idc = 3107; x = -10; y = -9.4; w = 0.1; h = 0.02; };
        class BuyButtonKey: AP_RscButtonMenu   { idc = 1001; x = -10; y = -9.3; w = 0.1; h = 0.02; text = ""; onButtonClick = ""; };
        class CloseButtonKey: AP_RscButtonMenu { idc = 1000; x = -10; y = -9.2; w = 0.1; h = 0.02; text = ""; onButtonClick = "closeDialog 0;"; };
        class VisionButtonKey: AP_RscButtonMenu{ idc = 1002; x = -10; y = -9.1; w = 0.1; h = 0.02; text = ""; onButtonClick = ""; };
        // ---- the page ----
        class Page {
            idc = 3151;
            type = 106;
            style = 0;
            x = -20 * UI_GRID_W + UI_GRID_X; y = -11 * UI_GRID_H + UI_GRID_Y;
            w  =  40 * UI_GRID_W;            h =  22 * UI_GRID_H;
            colorBackground[] = {0,0,0,0};
            colorText[] = {1,1,1,1};
            font = "RobotoCondensed";
            sizeEx = 0.6 * UI_GRID_H;
            url = "ui\html\fitting.html";
        };
        #include "..\webui\config\prompt_overlay.hpp"
    };
};
