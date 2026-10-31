// 3D printer / Fabricator. Modelled on AP_factory_menu (1800) -- same proven geometry, widened for
// the one thing the factory has no equivalent of: a JOB PANEL. Printing is not instant here; a job
// runs on a server clock for minutes to hours and keeps running while the owner is logged off, so
// the menu has to show what is in the machine and how long is left, not a progress bar.
//
// idd 1810: the block from 1801 to 2099 is empty and this sits beside the factory it is a sibling
// of. Native, not a web page -- server-side page serving is currently disabled (42d4446d) and the
// in-game CEF surface renders at 1 fps unless the player has turned off Steam's GPU-accelerated
// web rendering.
class AP_fab_menu {idd = 1810;
    name = "AP_fab_menu";
    movingEnable = false;
    enableSimulation = true;
    onLoad = "uiNamespace setVariable ['AP_fab_menu', _this select 0];";
    class controlsBackground {
        class AP_RscTitleBackground: AP_RscText {idc = -1;
            x = 0.284375 * safezoneW + safezoneX;
            y = 0.26 * safezoneH + safezoneY;
            w = 0.43125 * safezoneW;
            h = 0.022 * safezoneH;
            colorBackground[] = {0.02, 0.34, 0.36, 0.85};};
        class MainBackground: AP_RscText {idc = -1;
            x = 0.284375 * safezoneW + safezoneX;
            y = 0.282 * safezoneH + safezoneY;
            w = 0.43125 * safezoneW;
            h = 0.458 * safezoneH;
            colorBackground[] = {0, 0, 0, 0.75};};
        class Title: AP_RscTitle {idc = 1811;
            text = "Fabricator";
            x = 0.284375 * safezoneW + safezoneX;
            y = 0.26 * safezoneH + safezoneY;
            w = 0.43125 * safezoneW;
            h = 0.022 * safezoneH;
            colorText[] = {0.95, 0.95, 0.95, 1};};};
    class controls {
        // ---- level / xp header
        class LevelText: AP_RscStructuredText {idc = 1812;
            text = "";
            x = 0.289531 * safezoneW + safezoneX;
            y = 0.2854 * safezoneH + safezoneY;
            w = 0.42 * safezoneW;
            h = 0.026 * safezoneH;};

        // ---- recipe list. Row colour encodes the XP RULE, not affordability: green if the recipe
        // still grants progress, red if it is above your level, dim otherwise. That single detail
        // is what makes the level +/-1 window legible without explaining it anywhere.
        class RecipeList: AP_RscListBox {idc = 1850;
            onLBSelChanged = "[] call AP_fnc_fabLBChange;";
            sizeEx = 0.032;
            x = 0.289531 * safezoneW + safezoneX;
            y = 0.316 * safezoneH + safezoneY;
            w = 0.175 * safezoneW;
            h = 0.33 * safezoneH;};
        // Mode toggle. The schematic vendor lives INSIDE the fabricator rather than on its own
        // NPC: placing an NPC means a 3DEN pass through the generated edenNPC_data table, and the
        // machine is where a player already is when they discover they cannot print something.
        class Mode_Button: AP_RscButtonMenu {idc = 1816;
            onButtonClick = "[] call AP_fnc_fabMode;";
            text = "Buy Schematics";
            x = 0.289531 * safezoneW + safezoneX;
            y = 0.680 * safezoneH + safezoneY;
            w = 0.175 * safezoneW;
            h = 0.024 * safezoneH;
            colorText[] = {1, 1, 1, 1};
            colorBackground[] = {0.10, 0.12, 0.16, 0.9};};
        class SearchBox: AP_RscEdit {idc = 1813;
            text = "";
            onKeyUp = "[] call AP_fnc_fabMenuFill;";
            x = 0.289531 * safezoneW + safezoneX;
            y = 0.650 * safezoneH + safezoneY;
            w = 0.175 * safezoneW;
            h = 0.024 * safezoneH;};

        // ---- selected recipe
        class SelName: AP_RscStructuredText {idc = 1865;
            text = "Select a recipe";
            x = 0.470 * safezoneW + safezoneX;
            y = 0.316 * safezoneH + safezoneY;
            w = 0.24 * safezoneW;
            h = 0.030 * safezoneH;};
        class DetailFrame: AP_RscFrame {idc = 1009;
            x = 0.470 * safezoneW + safezoneX;
            y = 0.350 * safezoneH + safezoneY;
            w = 0.24 * safezoneW;
            h = 0.062 * safezoneH;};
        class SelDetail: AP_RscStructuredText {idc = 1855;
            text = "";
            x = 0.474 * safezoneW + safezoneX;
            y = 0.352 * safezoneH + safezoneY;
            w = 0.232 * safezoneW;
            h = 0.058 * safezoneH;};
        class IngredientList: AP_RscListBox {idc = 1860;
            sizeEx = 0.030;
            x = 0.470 * safezoneW + safezoneX;
            y = 0.418 * safezoneH + safezoneY;
            w = 0.24 * safezoneW;
            h = 0.120 * safezoneH;};

        // ---- job panel: the part factory.hpp has no equivalent of
        class JobLabel: AP_RscStructuredText {idc = 1814;
            text = "<t size='0.8' color='#7fb2c8'>MACHINE</t>";
            x = 0.470 * safezoneW + safezoneX;
            y = 0.543 * safezoneH + safezoneY;
            w = 0.24 * safezoneW;
            h = 0.024 * safezoneH;};
        class JobList: AP_RscListBox {idc = 1861;
            sizeEx = 0.030;
            x = 0.470 * safezoneW + safezoneX;
            y = 0.568 * safezoneH + safezoneY;
            w = 0.24 * safezoneW;
            h = 0.078 * safezoneH;};
        class AmountBox: AP_RscEdit {idc = 1815;
            text = "1";
            x = 0.470 * safezoneW + safezoneX;
            y = 0.650 * safezoneH + safezoneY;
            w = 0.045 * safezoneW;
            h = 0.024 * safezoneH;};

        // ---- buttons
        class Print_Button: AP_RscButtonMenu {idc = 1830;
            onButtonClick = "[] spawn AP_fnc_fabQueue;";
            text = "Print";
            x = 0.520 * safezoneW + safezoneX;
            y = 0.650 * safezoneH + safezoneY;
            w = 0.090 * safezoneW;
            h = 0.024 * safezoneH;
            colorText[] = {1, 1, 1, 1};
            colorBackground[] = {0.02, 0.30, 0.32, 0.85};};
        class Collect_Button: AP_RscButtonMenu {idc = 1831;
            onButtonClick = "[] spawn AP_fnc_fabCollect;";
            text = "Collect";
            x = 0.616 * safezoneW + safezoneX;
            y = 0.650 * safezoneH + safezoneY;
            w = 0.094 * safezoneW;
            h = 0.024 * safezoneH;
            colorText[] = {1, 1, 1, 1};
            colorBackground[] = {0, 0, 0, 0.8};};
        // Burn a schematic you know back into a tradeable shard. Sits next to Close rather than
        // next to Print because it is destructive -- it is the only button here that takes
        // something away.
        class Burn_Button: AP_RscButtonMenu {idc = 1832;
            onButtonClick = "[] spawn AP_fnc_fabBurn;";
            text = "Burn to Shard";
            x = 0.356 * safezoneW + safezoneX;
            y = 0.7124 * safezoneH + safezoneY;
            w = 0.090 * safezoneW;
            h = 0.024 * safezoneH;
            colorText[] = {1, 1, 1, 1};
            colorBackground[] = {0.24, 0.10, 0.10, 0.85};};
        class Cancel_Button: AP_RscButtonMenu {idc = 1007;
            onButtonClick = "closeDialog 0;";
            text = "Close";
            x = 0.284375 * safezoneW + safezoneX;
            y = 0.7124 * safezoneH + safezoneY;
            w = 0.0670311 * safezoneW;
            h = 0.024 * safezoneH;
            colorText[] = {1, 1, 1, 1};
            colorBackground[] = {0, 0, 0, 0.8};};};};
