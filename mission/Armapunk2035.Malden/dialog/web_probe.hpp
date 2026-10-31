/*
    web_probe.hpp  --  measurement rigs for the web bridge. Not player-facing.

    AP_web_probe (937600) -- ONE browser control, and deliberately NO dim
      backdrop behind it. ui\html\probe.html paints a transparent background, so
      whether the game world shows through around its panel answers the
      "can a page be transparent over the world" question that has been sitting
      unverified. If the world is visible, HTML HUD overlays are possible.

    AP_web_multi (937610) -- FOUR browser controls at once, each loading the
      same page. Each announces itself over its own bridge, so the RPT says how
      many the engine will actually run together.
*/

class AP_web_probe {
    idd = 937600;
    name = "AP_web_probe";
    movingEnable = false;
    enableSimulation = true;
    onLoad = "[_this select 0] spawn AP_fnc_webProbeOpen;";

    class controls {
        // NO backdrop on purpose -- the world behind is the measurement
        class Page {
            idc = 937601;
            type = 106;
            style = 0;
            x = -20 * UI_GRID_W + UI_GRID_X; y = -10 * UI_GRID_H + UI_GRID_Y;
            w  =  40 * UI_GRID_W;            h =  20 * UI_GRID_H;
            colorBackground[] = {0,0,0,0};      // transparent, not black
            colorText[] = {1,1,1,1};
            font = "RobotoCondensed";
            sizeEx = 0.6 * UI_GRID_H;
            url = "ui\html\probe.html";
        };
        class CloseBtn: AP_RscButtonMenu {
            idc = 937602;
            text = "CLOSE";
            x = 15.6 * UI_GRID_W + UI_GRID_X; y = 10.5 * UI_GRID_H + UI_GRID_Y;
            w  =  4.4 * UI_GRID_W;            h =  1.0 * UI_GRID_H;
            colorText[] = {0.86,0.905,0.878,1};
            colorBackground[] = {0.02,0.045,0.035,0.9};
            onButtonClick = "closeDialog 0;";
        };
    };
};

class AP_web_multi {
    idd = 937610;
    name = "AP_web_multi";
    movingEnable = false;
    enableSimulation = true;
    onLoad = "[_this select 0] spawn AP_fnc_webProbeMulti;";

    class controlsBackground {
        class Dim: AP_RscText {
            idc = -1;
            x = safezoneX; y = safezoneY; w = safezoneW; h = safezoneH;
            colorBackground[] = {0,0,0,0.75};
        };
    };

    class controls {
        #define PROBE_PANE(IDC,DX,DY) \
            class Pane##IDC { \
                idc = IDC; type = 106; style = 0; \
                x = DX * UI_GRID_W + UI_GRID_X; y = DY * UI_GRID_H + UI_GRID_Y; \
                w = 19 * UI_GRID_W;            h = 9 * UI_GRID_H; \
                colorBackground[] = {0,0,0,1}; colorText[] = {1,1,1,1}; \
                font = "RobotoCondensed"; sizeEx = 0.6 * UI_GRID_H; \
                url = "ui\html\probe.html"; \
            };

        PROBE_PANE(937611,-20,-10)
        PROBE_PANE(937612,  1,-10)
        PROBE_PANE(937613,-20,  0)
        PROBE_PANE(937614,  1,  0)

        class CloseBtn2: AP_RscButtonMenu {
            idc = 937615;
            text = "CLOSE";
            x = 15.6 * UI_GRID_W + UI_GRID_X; y = 10.5 * UI_GRID_H + UI_GRID_Y;
            w  =  4.4 * UI_GRID_W;            h =  1.0 * UI_GRID_H;
            colorText[] = {0.86,0.905,0.878,1};
            colorBackground[] = {0.02,0.045,0.035,0.9};
            onButtonClick = "closeDialog 0;";
        };
    };
};

/*
    AP_canvas_probe (937620) -- are HTML5 GAMES viable here, and are they DOM
    games or canvas games? Loads ui\html\canvasprobe.html, which draws and READS
    BACK on both 2D and WebGL (a context that exists but never rasterises would
    otherwise report as a pass) and then measures a sustained canvas draw rate.
*/
class AP_canvas_probe {
    idd = 937620;
    name = "AP_canvas_probe";
    movingEnable = false;
    enableSimulation = true;
    onLoad = "[_this select 0] spawn AP_fnc_canvasProbe;";
    class controls {
        class Page {
            idc = 937621;
            type = 106;
            style = 0;
            x = -18 * UI_GRID_W + UI_GRID_X; y = -10 * UI_GRID_H + UI_GRID_Y;
            w  =  36 * UI_GRID_W;            h =  20 * UI_GRID_H;
            colorBackground[] = {0,0,0,1};
            colorText[] = {1,1,1,1};
            font = "RobotoCondensed";
            sizeEx = 0.6 * UI_GRID_H;
            url = "ui\html\canvasprobe.html";
        };
    };
};
