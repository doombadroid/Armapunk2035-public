/*
    web_exttest.hpp -- AP_web_exttest (938600): DEV-ONLY probe for the CT_WEBBROWSER attribute
    `allowExternalURL` (BIKI: experimental, Development Branch; "not yet decided whether this will
    ever become available in Stable"). The owner runs the profiling branch; this answers whether
    that build honours the attribute. Nothing in the mission depends on it.

    Open from the debug console:   createDialog "AP_web_exttest";
    Loaded page = external content; blank/black = the branch ignores or blocks the attribute.
    Same host shape as AP_web_hudedit (type 106, full safezone). Esc closes. REMOVE before launch:
    an external-URL browser inside a released mission is an attack surface, not a feature.
    938600 continues the web run (938400 hud editor, 938500 inventory).
*/
class AP_web_exttest {
    idd = 938600;
    name = "AP_web_exttest";
    movingEnable = 0;
    enableSimulation = 1;
    onLoad = "diag_log format ['[AP-PROBE] exttest open: ctrl %1', (_this select 0) displayCtrl 938601];";
    class controls {
        class Page {
            idc = 938601;
            type = 106;
            style = 0;
            x = safezoneX + 0.1 * safezoneW; y = safezoneY + 0.1 * safezoneH; w = 0.8 * safezoneW; h = 0.8 * safezoneH;
            colorBackground[] = {0,0,0,1};
            colorText[] = {1,1,1,1};
            font = "RobotoCondensed";
            sizeEx = 0.03;
            allowExternalURL = 1;
            url = "https://example.com/";
        };
    };
};
