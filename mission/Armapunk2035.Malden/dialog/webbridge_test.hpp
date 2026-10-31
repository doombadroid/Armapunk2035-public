/*
    webbridge_test.hpp  --  CT_WEBBROWSER bridge prototype. idd 937400.

    Throwaway harness for measuring the embedded-Chromium UI path before any real
    screen is built on it. Deliberately minimal: one browser control filling the
    standard -20/-10/40/20 deck grid, a dim backdrop, and a close button.

    The browser control is type 106 (CT_WEBBROWSER), Arma 2.20+. The page is NOT
    loaded via `url=` here -- fn_webBridgeOpen loads it from script instead, so the
    dev console can be attached before the first paint.

    Everything inside the control is laid out by CSS. That is the point of the
    exercise: only this one control carries UI_GRID math, the page reflows itself.
*/

class AP_webbridge_test {
    idd = 937400;
    name = "AP_webbridge_test";
    movingEnable = false;
    enableSimulation = true;
    onLoad = "[_this select 0] spawn AP_fnc_webBridgeOpen;";

    class controlsBackground {
        class Dim: AP_RscText {
            idc = -1;
            x = safezoneX; y = safezoneY; w = safezoneW; h = safezoneH;
            colorBackground[] = {0,0,0,0.75};
        };
        class Frame: AP_RscText {
            idc = -1;
            x = -20.4 * UI_GRID_W + UI_GRID_X; y = -10.4 * UI_GRID_H + UI_GRID_Y;
            w  =  40.8 * UI_GRID_W;            h =  21.6 * UI_GRID_H;
            colorBackground[] = {0.047,0.09,0.07,1};
        };
    };

    class controls {
        // the browser surface -- one control, CSS does the rest
        class Page {
            idc = 937401;
            type = 106;                 // CT_WEBBROWSER
            style = 0;
            x = -20 * UI_GRID_W + UI_GRID_X; y = -10 * UI_GRID_H + UI_GRID_Y;
            w  =  40 * UI_GRID_W;            h =  20 * UI_GRID_H;
            colorBackground[] = {0,0,0,1};
            colorText[] = {1,1,1,1};
            font = "RobotoCondensed";
            sizeEx = 0.6 * UI_GRID_H;

            // Served by path, which is what binds A3API into the document and so
            // makes JS -> SQF possible at all. ctrlWebBrowserAction ["LoadFile", ...]
            // would hand the page over as a data URL instead: it renders fine and
            // silently cannot call back. The path must appear in
            // CfgCommands::allowedHTMLLoadURIs (description.ext).
            url = "ui\html\bridgetest.html";
        };


        // native text entry (an <input> in the page cannot be read from JS)
        #include "..\webui\config\prompt_overlay.hpp"

        class CloseBtn: AP_RscButtonMenu {
            idc = 937402;
            text = "CLOSE";
            x = 15.6 * UI_GRID_W + UI_GRID_X; y = 10.5 * UI_GRID_H + UI_GRID_Y;
            w  =  4.4 * UI_GRID_W;            h =  1.0 * UI_GRID_H;
            colorText[] = {0.86,0.905,0.878,1};
            colorBackground[] = {0.02,0.045,0.035,0.9};
            onButtonClick = "closeDialog 0;";
        };
    };
};
