/*
    web_duty_maxsec.hpp -- AP_web_dutyMaxsec (938200): the MaxSec HQ duty terminal. Five role rows
    (patrol / warrant / medic / SCD / all) with their rank and whitelist locks, opened by
    AP_fnc_dutyTermOpen from fn_setupActions.sqf's tablet action while the player is OFF duty. See
    core\web\fn_dutyTermBridge.sqf.

    FULL SCREEN on the safezone, like web_visor.hpp and web_landing.hpp: the page is a single centred
    console frame that sizes itself off the viewport (html{font-size:clamp(11px,1.6vh,20px)}), so it wants
    the whole surface rather than the 40x22 grid box the casino tables and the storage screen use.

    colorBackground is TRANSPARENT, and that is the one place this deliberately differs from
    web_landing.hpp. The landing's is opaque because what sits behind it is the mission.sqm player slot at
    50 km -- open sky, which would read as a broken splash for the frame before the page paints. Behind
    this one is the HQ the player is standing in, so the world is the honest thing to show while the page
    comes up; and the page paints its own opaque body background over it a frame later anyway.

    idd 938200 continues the web-dialog run (937700 breach, 937800 terminal, 937900 journal, 938000
    storage, 938100 landing) and 938201 is its control, the idd+1 convention every page in that run uses.
*/
class AP_web_dutyMaxsec {
    idd = 938200;
    name = "AP_web_dutyMaxsec";
    movingEnable = false;
    enableSimulation = true;
    onLoad = "[_this select 0] spawn AP_fnc_dutyTermBridge;";
    class controls {
        class Page {
            idc = 938201;
            type = 106;
            style = 0;
            x = safezoneX; y = safezoneY; w = safezoneW; h = safezoneH;
            colorBackground[] = {0,0,0,0};
            colorText[] = {1,1,1,1};
            font = "RobotoCondensed";
            sizeEx = 0.03;
            url = "ui\html\duty_maxsec.html";
        };
        #include "..\webui\config\prompt_overlay.hpp"
    };
};
