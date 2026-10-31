/*
    web_inventory.hpp -- AP_web_inventory (938500): the HTML I-screen -- worn gear, the three
    containers, what is in reach (vehicle / crate / ground) and the virtual bag on one page, plus
    the GUNSMITH panel for the primary and handgun. INVENTORY_SPEC.md §9.

    Opened by evh/fn_inventoryOpened.sqf in place of the engine's display 602 (the EH returns true,
    which suppresses the native dialog), via core/inventory/fn_invOpen.sqf. CTRL+SHIFT+I still
    reaches the native inventory (evh/fn_keyDownHandler.sqf) until this page has been played.

    Position is a placeholder; fn_invBridge.sqf repositions the Page control at runtime (40x22
    grid, AP_deckScale-scaled, centred -- the armory's "windowed web UI" convention; 1.82:1 is the
    ratio the design was drawn at).
*/
class AP_web_inventory {
    idd = 938500;
    name = "AP_web_inventory";
    movingEnable = false;
    enableSimulation = true;
    onLoad = "[_this select 0] spawn AP_fnc_invBridge;";
    class controls {
        // THE LIVE FIGURE. The page's WORN column draws a silhouette; this native group is laid over
        // that strip (native controls render above the browser) and shows a render-to-texture camera
        // on the player's actual body -- fn_invFigure.sqf, the clothing shop's preview camera pointed
        // at a surface instead of the screen. DECLARED BEFORE THE PAGE: a control declared after the
        // browser never shows (proven 2026-09-03 -- the browser surface is drawn over its later
        // siblings), while the browser alpha-composites over what was drawn BEFORE it (the deck's
        // see-through chassis). So this sits under the page, and the page cuts a transparent hole
        // exactly at the strip (body.figlive #frame mask) for it to show through. The surface is SQUARE (512x512: the shape BIS_fnc_PIP and
        // every working r2t in the wild uses -- a 256x1024 surface rendered nothing, 2026-09-03); the
        // picture inside is square too, sized to the strip's height and centred, and the GROUP clips it
        // to the strip, so the body arrives at full height and true proportions. Positioned at runtime
        // from the box the page reports; hidden until then and whenever PiP is off (isPiPEnabled).
        class FigureClip: AP_RscControlsGroupNoScrollbars {
            idc = 938502; show = 0;
            x = 0; y = 0; w = 0.1; h = 0.4;
            class controls {
                // the strip's own background in the page's --panel colour: a native colour is exact, a
                // colour rendered in the studio is shaded by its lighting; the picture sits on this
                class Fill {
                    idc = 938505;
                    type = 0; style = 0;
                    x = 0; y = 0; w = 0.1; h = 0.4;
                    font = "RobotoCondensed"; sizeEx = 0.02;
                    colorText[]       = {0,0,0,0};
                    colorBackground[] = {0.047,0.086,0.133,1};
                    text = "";
                };
                // two pictures, upper and lower half of the body, each fed by its own camera: the
                // engine renders a PiP at the screen's aspect at a capped resolution, so one camera
                // spends ~80% of its texels beside the body; two stacked halves give ~1:1 on screen
                class FigureA {
                    idc = 938503;
                    type = 0; style = 48;                  // CT_STATIC, ST_PICTURE
                    x = 0; y = 0; w = 0.4; h = 0.2;
                    font = "RobotoCondensed"; sizeEx = 0.02;
                    colorText[]       = {1,1,1,1};
                    colorBackground[] = {0,0,0,0};
                    text = "";
                };
                class FigureB: FigureA { idc = 938504; y = 0.2; };
            };
        };
        class Page {
            idc = 938501;
            type = 106;
            style = 0;
            x = -20 * UI_GRID_W + UI_GRID_X; y = -11 * UI_GRID_H + UI_GRID_Y;
            w  =  40 * UI_GRID_W;            h =  22 * UI_GRID_H;
            colorBackground[] = {0,0,0,0};
            colorText[] = {1,1,1,1};
            font = "RobotoCondensed";
            sizeEx = 0.6 * UI_GRID_H;
            url = "ui\html\inventory.html";
        };
        #include "..\webui\config\prompt_overlay.hpp"
    };
};
