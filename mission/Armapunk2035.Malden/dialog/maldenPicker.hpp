/*
    maldenPicker.hpp -- MALDEN MAKEOVER skin picker (idd 515800, LooneyBin owner 2026-07-11). Same Night City
    chrome as the trunk/storage menus (nc_panel graphite, muted captions, magenta list selection, cyan primary).
    One list = 6 Malden colors + "Original Altis"; APPLY hands the choice to APS_fnc_maldenSRV via
    AP_fnc_maldenPicker. idcs: 515810 list, 515820 status.
*/
class AP_MaldenPicker {idd = 515800;
    name = "AP_MaldenPicker";
    movingEnable = 0;
    enableSimulation = 1;
    onLoad = "uiNamespace setVariable ['AP_MaldenPicker', _this select 0];";
    onUnload = "uiNamespace setVariable ['AP_MaldenPicker', displayNull];";

    class controlsBackground {class NCPanel: AP_RscPicture {idc = -1;
            text = "images\ui\nc_panel.paa";
            x = 0.38 * safezoneW + safezoneX;
            y = 0.30 * safezoneH + safezoneY;
            w = 0.24 * safezoneW;
            h = 0.40 * safezoneH;};
        class TitleText: AP_RscTitle {idc = -1;
            sizeEx = 0.042;
            text = "MALDEN MAKEOVER";
            x = 0.395 * safezoneW + safezoneX;
            y = 0.318 * safezoneH + safezoneY;
            w = 0.20 * safezoneW;
            h = 0.028 * safezoneH;
            colorText[] = { 0.922, 0.937, 0.957, 1 };
            colorBackground[] = { 0, 0, 0, 0 };};
        class NCDivider: AP_RscPicture {idc = -1;
            text = "images\ui\nc_divider.paa";
            x = 0.395 * safezoneW + safezoneX;
            y = 0.350 * safezoneH + safezoneY;
            w = 0.21 * safezoneW;
            h = 0.005 * safezoneH;};
        class HdrText: AP_RscText {idc = -1;
            sizeEx = 0.030;
            text = "PICK A LOOK";
            x = 0.395 * safezoneW + safezoneX;
            y = 0.362 * safezoneH + safezoneY;
            w = 0.20 * safezoneW;
            h = 0.022 * safezoneH;
            colorText[] = { 0.537, 0.576, 0.627, 1 };
            colorBackground[] = { 0, 0, 0, 0 };};};

    class Controls {class SkinList: AP_RscListBox {idc = 515810;
            sizeEx = 0.034;
            x = 0.393 * safezoneW + safezoneX;
            y = 0.390 * safezoneH + safezoneY;
            w = 0.214 * safezoneW;
            h = 0.215 * safezoneH;
            colorBackground[] = { 0.078, 0.094, 0.129, 0.9 };
            colorSelectBackground[] = { 0.945, 0.239, 0.659, 0.35 };
            colorSelectBackground2[] = { 0.945, 0.239, 0.659, 0.35 };
            onLBDblClick = "['apply'] call AP_fnc_maldenPicker;";};
        class ApplyBtn: AP_RscButtonMenu {idc = -1;
            text = "APPLY";
            onButtonClick = "['apply'] call AP_fnc_maldenPicker;";
            x = 0.393 * safezoneW + safezoneX;
            y = 0.616 * safezoneH + safezoneY;
            w = 0.134 * safezoneW;
            h = 0.028 * safezoneH;
            colorText[] = { 0.043, 0.075, 0.102, 1 };
            colorBackground[] = { 0.216, 0.910, 0.941, 1 };
            colorBackground2[] = { 0.35, 0.95, 0.97, 1 };
            class Attributes { font = "PuristaSemibold"; color = "#0b131a"; align = "center"; shadow = "false"; };};
        class CloseBtn: AP_RscButtonMenu {idc = -1;
            text = "Close";
            onButtonClick = "closeDialog 0;";
            x = 0.533 * safezoneW + safezoneX;
            y = 0.616 * safezoneH + safezoneY;
            w = 0.074 * safezoneW;
            h = 0.028 * safezoneH;
            colorText[] = { 0.537, 0.576, 0.627, 1 };
            colorBackground[] = { 0.118, 0.153, 0.208, 1 };
            colorBackground2[] = { 0.157, 0.196, 0.247, 1 };};
        class StatusText: AP_RscStructuredText {idc = 515820;
            size = 0.024;
            sizeEx = 0.024;
            text = "";
            x = 0.393 * safezoneW + safezoneX;
            y = 0.652 * safezoneH + safezoneY;
            w = 0.214 * safezoneW;
            h = 0.026 * safezoneH;
            class Attributes { font = "PuristaLight"; color = "#8993a0"; align = "left"; shadow = 0; };};};};
