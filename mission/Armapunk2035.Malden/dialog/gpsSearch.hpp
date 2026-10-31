/*
    gpsSearch.hpp -- AP_GpsSearch (idd 91500): GPS destination search, Night City palette
    (ink panel, cyan accents). Opened with G on the map (core\gps\fn_gps.sqf key hook).
    Type-to-filter across towns (CfgWorlds Names) + every named map marker; double-click
    or [PLOT ROUTE] routes there via AP_fnc_gps. Logic: core\gps\fn_gpsSearch.sqf.
*/
class AP_GpsSearch {idd = 91500;
    movingEnable = 0;
    enableSimulation = 1;
    onLoad = "ctrlSetFocus ((_this select 0) displayCtrl 91501);";

    class controlsBackground {class Backdrop: AP_RscText {idc = -1;
            x = 0.32 * safezoneW + safezoneX;
            y = 0.18 * safezoneH + safezoneY;
            w = 0.36 * safezoneW;
            h = 0.62 * safezoneH;
            colorBackground[] = {0.027, 0.035, 0.051, 0.96};};
        class HeaderStripe: AP_RscText {idc = -1;
            x = 0.32 * safezoneW + safezoneX;
            y = 0.18 * safezoneH + safezoneY;
            w = 0.36 * safezoneW;
            h = 0.002 * safezoneH;
            colorBackground[] = {0.0, 0.83, 1.0, 1};};
        class Title: AP_RscStructuredText {idc = -1;
            text = "<t font='PuristaSemibold' size='1.25' color='#00d4ff'>NAVIGATION</t><t size='1.05' color='#5c6a78'>  //  LOONYBIN GPS</t>";
            x = 0.335 * safezoneW + safezoneX;
            y = 0.195 * safezoneH + safezoneY;
            w = 0.33 * safezoneW;
            h = 0.035 * safezoneH;};
        class Hint: AP_RscStructuredText {idc = -1;
            text = "<t size='0.8' color='#5c6a78'>towns, drug sites and federal events -- for anywhere else, ALT+Click the map</t>";
            x = 0.335 * safezoneW + safezoneX;
            y = 0.755 * safezoneH + safezoneY;
            w = 0.33 * safezoneW;
            h = 0.03 * safezoneH;};};

    class controls {class SearchEdit: AP_RscEdit {idc = 91501;
            text = "";
            onKeyUp = "['filter'] call AP_fnc_gpsSearch;";
            x = 0.335 * safezoneW + safezoneX;
            y = 0.235 * safezoneH + safezoneY;
            w = 0.33 * safezoneW;
            h = 0.035 * safezoneH;
            colorBackground[] = {0.055, 0.07, 0.095, 1};
            colorText[] = {0.91, 0.96, 1, 1};
            colorSelection[] = {0.0, 0.52, 0.63, 1};
            sizeEx = 0.032;};
        class ResultList: AP_RscListBox {idc = 91502;
            onLBDblClick = "['go'] call AP_fnc_gpsSearch;";
            x = 0.335 * safezoneW + safezoneX;
            y = 0.28 * safezoneH + safezoneY;
            w = 0.33 * safezoneW;
            h = 0.42 * safezoneH;
            colorBackground[] = {0.038, 0.049, 0.068, 0.9};
            colorSelectBackground[] = {0.0, 0.52, 0.63, 0.45};
            colorSelectBackground2[] = {0.0, 0.52, 0.63, 0.6};
            colorSelect[] = {1, 1, 1, 1};
            colorSelect2[] = {1, 1, 1, 1};
            sizeEx = 0.03;
            rowHeight = 0.032;};
        class BtnRoute: AP_RscButtonMenu {idc = -1;
            text = "PLOT ROUTE";
            onButtonClick = "['go'] call AP_fnc_gpsSearch;";
            x = 0.335 * safezoneW + safezoneX;
            y = 0.712 * safezoneH + safezoneY;
            w = 0.16 * safezoneW;
            h = 0.032 * safezoneH;
            colorBackground[] = {0.0, 0.35, 0.44, 0.9};};
        class BtnClear: AP_RscButtonMenu {idc = -1;
            text = "CLEAR ROUTE";
            onButtonClick = "closeDialog 0; ['clear'] call AP_fnc_gps;";
            x = 0.505 * safezoneW + safezoneX;
            y = 0.712 * safezoneH + safezoneY;
            w = 0.10 * safezoneW;
            h = 0.032 * safezoneH;
            colorBackground[] = {0.10, 0.12, 0.16, 0.9};};
        class BtnClose: AP_RscButtonMenu {idc = -1;
            text = "CLOSE";
            onButtonClick = "closeDialog 0;";
            x = 0.615 * safezoneW + safezoneX;
            y = 0.712 * safezoneH + safezoneY;
            w = 0.05 * safezoneW;
            h = 0.032 * safezoneH;
            colorBackground[] = {0.10, 0.12, 0.16, 0.9};};};};
