/*
    LooneyBin car radio -- "now playing" HUD widget (RscTitles, non-interactive).
    Included inside class RscTitles (description.ext). Driven by core\radio\fn_radioHud.sqf.
    Ported from a public Arma example (dev branding stripped). Vanilla RscText/RscPicture/RscStructuredText
    base classes (always in scope at RscTitles level).
*/
class AP_AutoRadioMenu {idd = 5152005;
    movingEnable = 0;
    enableSimulation = 1;
    fadein = 0;
    duration = 1e11;
    fadeout = 0;
    onLoad = "uiNamespace setVariable ['AP_AutoRadioMenu', _this select 0];";
    onUnload = "uiNamespace setVariable ['AP_AutoRadioMenu', objNull];";
    onDestroy = "uiNamespace setVariable ['AP_AutoRadioMenu', objNull];";

    class controls {class BackgroundImage: AP_RscText {idc = 0100;
            colorBackground[] = { 0.988, 0.816, 0.062, 1 };
            text = "";
            x = 0.0 * safezoneW + safezoneX;
            y = 0.845 * safezoneH + safezoneY;
            w = 0 * safezoneW;
            h = 0.065 * safezoneH;};
        class BackgroundColorW: AP_RscText {idc = 0200;
            colorBackground[] = { 1, 1, 1, 1 };
            text = "";
            x = 0.0 * safezoneW + safezoneX;
            y = 0.810 * safezoneH + safezoneY;
            w = 0 * safezoneW;
            h = 0.035 * safezoneH;};
        class TabNextIcon: AP_RscPicture {idc = 0300;
            text = "images\radio\TabKeyIcon.paa";
            x = 0.007 * safezoneW + safezoneX;
            y = 0.810 * safezoneH + safezoneY;
            w = 0.018 * safezoneW;
            h = 0.035 * safezoneH;};
        class RadioIcon: AP_RscPicture {idc = 0400;
            text = "images\radio\CrossIcon.paa";
            x = 0.0 * safezoneW + safezoneX;
            y = 0.846 * safezoneH + safezoneY;
            w = 0.036 * safezoneW;
            h = 0.063 * safezoneH;};
        class TextSongInfo: AP_RscStructuredText {idc = 0500;
            text = "";
            x = 0.038 * safezoneW + safezoneX;
            y = 0.856 * safezoneH + safezoneY;
            w = 0.175 * safezoneW;
            h = 0.063 * safezoneH;};};};
