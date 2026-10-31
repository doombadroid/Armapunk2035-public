/*
    web_casino.hpp — the HTML casino. ONE DIALOG PER TABLE.

    A CT_WEBBROWSER's `url` is static config and it is the ONLY hand-over that
    binds A3API into the page -- ctrlWebBrowserAction ["LoadFile"] renders fine
    and can never call back. So switching tables cannot be a navigation; it is
    closeDialog + createDialog, and each table needs its own class.

    idds sit clear of the native casino (930000 blackjack, 930310-930360).
    Blackjack is deliberately absent: DEALERBOT'S TABLE is a shared multiplayer
    game, not a reskin, and needs its server engine before a page goes in.
*/

class AP_wcas_landing {
    idd = 930400;
    name = "AP_wcas_landing";
    movingEnable = false;
    enableSimulation = true;
    onLoad = "[_this select 0, 'landing'] spawn AP_fnc_casinoOpen;";
    class controls {
        class Page {
            idc = 930500;
            type = 106;
            style = 0;
            x = -20 * UI_GRID_W + UI_GRID_X; y = -11 * UI_GRID_H + UI_GRID_Y;
            w  =  40 * UI_GRID_W;            h =  22 * UI_GRID_H;
            colorBackground[] = {0,0,0,0};
            colorText[] = {1,1,1,1};
            font = "RobotoCondensed";
            sizeEx = 0.6 * UI_GRID_H;
            url = "ui\html\casino\landing.html";
        };
        #include "..\webui\config\prompt_overlay.hpp"
    };
};

class AP_wcas_wheel {
    idd = 930410;
    name = "AP_wcas_wheel";
    movingEnable = false;
    enableSimulation = true;
    onLoad = "[_this select 0, 'wheel'] spawn AP_fnc_casinoOpen;";
    class controls {
        class Page {
            idc = 930510;
            type = 106;
            style = 0;
            x = -20 * UI_GRID_W + UI_GRID_X; y = -11 * UI_GRID_H + UI_GRID_Y;
            w  =  40 * UI_GRID_W;            h =  22 * UI_GRID_H;
            colorBackground[] = {0,0,0,0};
            colorText[] = {1,1,1,1};
            font = "RobotoCondensed";
            sizeEx = 0.6 * UI_GRID_H;
            url = "ui\html\casino\wheel.html";
        };
        #include "..\webui\config\prompt_overlay.hpp"
    };
};

class AP_wcas_crash {
    idd = 930411;
    name = "AP_wcas_crash";
    movingEnable = false;
    enableSimulation = true;
    onLoad = "[_this select 0, 'crash'] spawn AP_fnc_casinoOpen;";
    onUnload = "[['crash', 'quit', []], 'APS_fnc_casinoSRV', 2] spawn AP_fnc_MP;";
    class controls {
        class Page {
            idc = 930511;
            type = 106;
            style = 0;
            x = -20 * UI_GRID_W + UI_GRID_X; y = -11 * UI_GRID_H + UI_GRID_Y;
            w  =  40 * UI_GRID_W;            h =  22 * UI_GRID_H;
            colorBackground[] = {0,0,0,0};
            colorText[] = {1,1,1,1};
            font = "RobotoCondensed";
            sizeEx = 0.6 * UI_GRID_H;
            url = "ui\html\casino\crash.html";
        };
        #include "..\webui\config\prompt_overlay.hpp"
    };
};

class AP_wcas_slots {
    idd = 930412;
    name = "AP_wcas_slots";
    movingEnable = false;
    enableSimulation = true;
    onLoad = "[_this select 0, 'slots'] spawn AP_fnc_casinoOpen;";
    class controls {
        class Page {
            idc = 930512;
            type = 106;
            style = 0;
            x = -20 * UI_GRID_W + UI_GRID_X; y = -11 * UI_GRID_H + UI_GRID_Y;
            w  =  40 * UI_GRID_W;            h =  22 * UI_GRID_H;
            colorBackground[] = {0,0,0,0};
            colorText[] = {1,1,1,1};
            font = "RobotoCondensed";
            sizeEx = 0.6 * UI_GRID_H;
            url = "ui\html\casino\slots.html";
        };
        #include "..\webui\config\prompt_overlay.hpp"
    };
};

class AP_wcas_roulette {
    idd = 930413;
    name = "AP_wcas_roulette";
    movingEnable = false;
    enableSimulation = true;
    onLoad = "[_this select 0, 'roulette'] spawn AP_fnc_casinoOpen;";
    class controls {
        class Page {
            idc = 930513;
            type = 106;
            style = 0;
            x = -20 * UI_GRID_W + UI_GRID_X; y = -11 * UI_GRID_H + UI_GRID_Y;
            w  =  40 * UI_GRID_W;            h =  22 * UI_GRID_H;
            colorBackground[] = {0,0,0,0};
            colorText[] = {1,1,1,1};
            font = "RobotoCondensed";
            sizeEx = 0.6 * UI_GRID_H;
            url = "ui\html\casino\roulette.html";
        };
        #include "..\webui\config\prompt_overlay.hpp"
    };
};

class AP_wcas_coinflip {
    idd = 930414;
    name = "AP_wcas_coinflip";
    movingEnable = false;
    enableSimulation = true;
    onLoad = "[_this select 0, 'coinflip'] spawn AP_fnc_casinoOpen;";
    class controls {
        class Page {
            idc = 930514;
            type = 106;
            style = 0;
            x = -20 * UI_GRID_W + UI_GRID_X; y = -11 * UI_GRID_H + UI_GRID_Y;
            w  =  40 * UI_GRID_W;            h =  22 * UI_GRID_H;
            colorBackground[] = {0,0,0,0};
            colorText[] = {1,1,1,1};
            font = "RobotoCondensed";
            sizeEx = 0.6 * UI_GRID_H;
            url = "ui\html\casino\coinflip.html";
        };
        #include "..\webui\config\prompt_overlay.hpp"
    };
};

class AP_wcas_hilo {
    idd = 930415;
    name = "AP_wcas_hilo";
    movingEnable = false;
    enableSimulation = true;
    onLoad = "[_this select 0, 'hilo'] spawn AP_fnc_casinoOpen;";
    onUnload = "[['hilo', 'quit', []], 'APS_fnc_casinoSRV', 2] spawn AP_fnc_MP;";
    class controls {
        class Page {
            idc = 930515;
            type = 106;
            style = 0;
            x = -20 * UI_GRID_W + UI_GRID_X; y = -11 * UI_GRID_H + UI_GRID_Y;
            w  =  40 * UI_GRID_W;            h =  22 * UI_GRID_H;
            colorBackground[] = {0,0,0,0};
            colorText[] = {1,1,1,1};
            font = "RobotoCondensed";
            sizeEx = 0.6 * UI_GRID_H;
            url = "ui\html\casino\hilo.html";
        };
        #include "..\webui\config\prompt_overlay.hpp"
    };
};

/*
    DEALERBOT'S TABLE. Not a reskin -- APS_fnc_bjTableSRV is a new shared engine,
    so this dialog talks to AP_fnc_bjOpen rather than AP_fnc_casinoOpen.

    onUnload gives the seat up. A player who alt-F4s out of a hand would otherwise
    hold four other people on a 20s clock every turn, and the server cannot tell a
    closed dialog from a thinking one.
*/
class AP_wcas_blackjack {
    idd = 930420;
    name = "AP_wcas_blackjack";
    movingEnable = false;
    enableSimulation = true;
    onLoad = "[_this select 0] spawn AP_fnc_bjOpen;";
    onUnload = "[['unwatch', []], 'APS_fnc_bjTableSRV', 2] spawn AP_fnc_MP;";
    class controls {
        class Page {
            idc = 930421;
            type = 106;
            style = 0;
            x = -20 * UI_GRID_W + UI_GRID_X; y = -11 * UI_GRID_H + UI_GRID_Y;
            w  =  40 * UI_GRID_W;            h =  22 * UI_GRID_H;
            colorBackground[] = {0,0,0,0};
            colorText[] = {1,1,1,1};
            font = "RobotoCondensed";
            sizeEx = 0.6 * UI_GRID_H;
            url = "ui\html\casino\blackjack.html";
        };
        #include "..\webui\config\prompt_overlay.hpp"
    };
};

/*
    TEXAS HOLD'EM. The second table that is not a reskin: APS_fnc_holdemSRV is
    its own engine, so this dialog talks to AP_fnc_holdemOpen rather than to
    AP_fnc_casinoOpen. idc is idd + 1, the convention DEALERBOT'S TABLE above
    uses and the one the 937700-938200 web run settled on.

    onUnload UNSUBSCRIBES, and the server takes that as leaving the table -- a
    seated player who cannot see the felt cannot act on it, and a kept seat
    would hold five other people on a 20 s clock every orbit. Their stack banks
    on the way out; the reasoning is in APS_fnc_holdemSRV's "close" case. A
    client that never sends this (alt-F4, a crash) is caught by
    fn_playerDisconnected instead, so the seat is freed either way.
*/
class AP_wcas_holdem {
    idd = 930422;
    name = "AP_wcas_holdem";
    movingEnable = false;
    enableSimulation = true;
    onLoad = "[_this select 0] spawn AP_fnc_holdemOpen;";
    onUnload = "[['close', []], 'APS_fnc_holdemSRV', 2] spawn AP_fnc_MP;";
    class controls {
        class Page {
            idc = 930423;
            type = 106;
            style = 0;
            x = -20 * UI_GRID_W + UI_GRID_X; y = -11 * UI_GRID_H + UI_GRID_Y;
            w  =  40 * UI_GRID_W;            h =  22 * UI_GRID_H;
            colorBackground[] = {0,0,0,0};
            colorText[] = {1,1,1,1};
            font = "RobotoCondensed";
            sizeEx = 0.6 * UI_GRID_H;
            url = "ui\html\casino\holdem.html";
        };
        #include "..\webui\config\prompt_overlay.hpp"
    };
};

/*
    ARMORY (930460) -- the HTML weapon shop. Lives in this file with the other
    web dialogs; fn_armoryOpen reads the shop type from AP_armoryShop.
*/
class AP_web_armory {
    idd = 930460;
    name = "AP_web_armory";
    movingEnable = false;
    enableSimulation = true;
    onLoad = "[_this select 0] spawn AP_fnc_armoryOpen;";
    class controls {
        class Page {
            idc = 930461;
            type = 106;
            style = 0;
            x = -20 * UI_GRID_W + UI_GRID_X; y = -11 * UI_GRID_H + UI_GRID_Y;
            w  =  40 * UI_GRID_W;            h =  22 * UI_GRID_H;
            colorBackground[] = {0,0,0,0};
            colorText[] = {1,1,1,1};
            font = "RobotoCondensed";
            sizeEx = 0.6 * UI_GRID_H;
            url = "ui\html\armory.html";
        };
        #include "..\webui\config\prompt_overlay.hpp"
    };
};
