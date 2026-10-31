/*
    gpsHUD.hpp -- AP_GpsHud (RscTitles layer): turn-by-turn banner, top-center. Driven by
    core\gps\fn_gpsHud.sqf (repainted ~1.5Hz while a route is active). idc 91510.
*/
class AP_GpsHud {idd = -1;
    duration = 1e10;
    fadeIn = 0.25;
    fadeOut = 0.35;
    onLoad = "uiNamespace setVariable ['AP_GpsHud', _this select 0];";
    class controls {class GpsBanner: AP_RscStructuredText {idc = 91510;
            text = "";
            size = 0.038;
            sizeEx = 0.038;
            x = safezoneX + 0.33 * safezoneW;
            y = safezoneY + 0.012 * safezoneH;
            w = 0.34 * safezoneW;
            h = 0.085 * safezoneH;
            colorBackground[] = {0, 0, 0, 0};
            class Attributes { font = "PuristaMedium"; color = "#e8f6ff"; align = "center"; shadow = 1; };};};};
