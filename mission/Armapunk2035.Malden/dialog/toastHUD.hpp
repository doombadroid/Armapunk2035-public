/*
    LooneyBin HUD toast -- the car-radio "now playing" card (dialog\radioHUD.hpp) generalised into a reusable,
    colour-coded notification. RscTitles, non-interactive. Driven by core\radio\fn_hudToast.sqf.
    5 stacked slots (AP_Toast_0..4, idd 5152100..5152104): a solid ACCENT-colour card with dark text + a glyph,
    exactly the radio's look. The fn sets the colour/glyph/two-tier text per event, positions the slot, slides it
    in ~6s then out. Base control classes (AP_RscText / AP_RscStructuredText) come from dialog\common.hpp
    (global scope, so visible inside RscTitles). idd block 5152100-5152104 sits beside the radio card (5152005).
*/
class AP_ToastBase {idd = -1;
    movingEnable = 0;
    enableSimulation = 1;
    fadein = 0;
    fadeout = 0;
    duration = 1e11;
    class controls {
        // whole card = the accent colour (set per-event by the fn), like the radio's coloured bar
        class Bar: AP_RscText {idc = 100;
            colorBackground[] = { 0.118, 0.137, 0.180, 0.96 };
            text = "";
            x = 0.031 * safezoneW + safezoneX;
            y = 0.30 * safezoneH + safezoneY;
            w = 0.26 * safezoneW;
            h = 0.066 * safezoneH;};
        // glyph (dark, on the accent) -- fn fills it
        class Logo: AP_RscStructuredText {idc = 400;
            text = "";
            x = 0.031 * safezoneW + safezoneX;
            y = 0.30 * safezoneH + safezoneY;
            w = 0.048 * safezoneW;
            h = 0.066 * safezoneH;};
        // two-tier body (eyebrow / title / sub) in dark text
        class Body: AP_RscStructuredText {idc = 500;
            text = "";
            x = 0.079 * safezoneW + safezoneX;
            y = 0.30 * safezoneH + safezoneY;
            w = 0.205 * safezoneW;
            h = 0.066 * safezoneH;};};};
class AP_Toast_0: AP_ToastBase { idd = 5152100; onLoad = "uiNamespace setVariable ['AP_Toast_0', _this select 0]"; onUnload = "uiNamespace setVariable ['AP_Toast_0', displayNull]"; };
class AP_toast_1: AP_ToastBase { idd = 5152101; onLoad = "uiNamespace setVariable ['AP_toast_1', _this select 0]"; onUnload = "uiNamespace setVariable ['AP_toast_1', displayNull]"; };
class AP_toast_2: AP_ToastBase { idd = 5152102; onLoad = "uiNamespace setVariable ['AP_toast_2', _this select 0]"; onUnload = "uiNamespace setVariable ['AP_toast_2', displayNull]"; };
class AP_toast_3: AP_ToastBase { idd = 5152103; onLoad = "uiNamespace setVariable ['AP_toast_3', _this select 0]"; onUnload = "uiNamespace setVariable ['AP_toast_3', displayNull]"; };
class AP_toast_4: AP_ToastBase { idd = 5152104; onLoad = "uiNamespace setVariable ['AP_toast_4', _this select 0]"; onUnload = "uiNamespace setVariable ['AP_toast_4', displayNull]"; };
