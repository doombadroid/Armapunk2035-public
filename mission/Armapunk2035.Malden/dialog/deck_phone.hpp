/*
    deck_phone.hpp  --  the web phone. idd 937500.

    One CT_WEBBROWSER control on the standard -20/-10/40/20 deck grid (40x20
    UI_GRID = a 2:1 landscape box) and nothing else. Everything the player sees
    -- chassis, screen, rail, panels, rows -- is drawn by ui\html\deck.html.
    This file exists to position that one control and to carry the native text
    prompt, which is the only way typed text can reach a page.

    The page MUST be handed over with `url=` from a path listed in
    CfgCommands::allowedHTMLLoadURIs (description.ext). That is what binds A3API
    into the document; ctrlWebBrowserAction ["LoadFile", ...] hands it over as a
    data URL instead, which renders fine and can never call back.
*/

class AP_deck_phone {
    idd = 937500;
    name = "AP_deck_phone";
    movingEnable = false;
    enableSimulation = true;
    onLoad = "[_this select 0] spawn AP_fnc_deckOpen;";

    // No dim layer and no opaque control background: the page paints its own
    // chassis on a transparent body, so the world shows through around it.
    // Verified transparent over the world with the probe rig before doing this.

    class controls {
        class Page {
            idc = 937501;
            type = 106;                 // CT_WEBBROWSER, Arma 2.20+
            style = 0;
            x = -20 * UI_GRID_W + UI_GRID_X; y = -10 * UI_GRID_H + UI_GRID_Y;
            w  =  40 * UI_GRID_W;            h =  20 * UI_GRID_H;
            colorBackground[] = {0,0,0,0};
            colorText[] = {1,1,1,1};
            font = "RobotoCondensed";
            sizeEx = 0.6 * UI_GRID_H;
            url = "ui\html\deck.html";
        };

        // native text entry -- an <input> in the page cannot be read from JS
        #include "..\webui\config\prompt_overlay.hpp"
    };
};
