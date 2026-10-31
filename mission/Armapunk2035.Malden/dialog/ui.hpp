class AP_playerHUD {idd = 23000;
    movingEnable = 0;
    fadein = 0;
    duration = 99999999999999999999999999999999999999999999;
    fadeout = 0;
    name = "AP_playerHUD";
    onLoad = "uiNamespace setVariable ['AP_playerHUD',_this select 0]";
    objects[] = {};
    class controlsBackground {};
    class controls {class hudtext: AP_RscStructuredText {idc = 23515;
            x = 0;
            y = 1;
            w = 1;
            h = 0.04;
            colorBackground[] = {0, 0, 0, 0};
            colorText[] = {1, 1, 1, 0.8};
            text = "";
            sizeEx = 0.03;
            class Attributes {font = "PuristaSemibold";
                color = "#FFFFFF";
                shadow = true;
                shadowColor = "#000000";
                size = "1";};};
        class hudhead: AP_RscStructuredText {idc = 23525;
            x = 0;
            y = 0;
            w = 1;
            h = 0.04;
            colorBackground[] = {0, 0, 0, 0};
            text = "";
            sizeEx = 0.03;
            class Attributes {font = "EtelkaMonospaceProBold";
                color = "#FFFFFF";
                shadow = true;
                shadowColor = "#000000";
                size = "1";};};

        // ── NIGHT CITY segmented survival bars, TRUE bottom-right (positions + fill + colour + value all set each
        //    tick by fn_hudUpdate via safeZone; hpp positions are placeholders). Each bar: icon + track + fill +
        //    gap-overlay PAA (void dividers -> 10 discrete segments) + mono value. ──
        #define AP_BAR_ICON(IDC,IMG)   class AP_bi##IDC: AP_RscPicture { idc = IDC; x = 0.8; y = 0.85; w = 0.024; h = 0.030; text = IMG; }
        #define AP_BAR_TRACK(IDC)      class AP_bt##IDC: AP_RscText { idc = IDC; x = 0.8; y = 0.85; w = 0.125; h = 0.017; colorBackground[] = { 0.157, 0.196, 0.247, 0.72 }; text = ""; }
        #define AP_BAR_FILL(IDC,R,G,B) class AP_bf##IDC: AP_RscText { idc = IDC; x = 0.8; y = 0.85; w = 0.125; h = 0.017; colorBackground[] = { R, G, B, 1 }; text = ""; }
        #define AP_BAR_OVER(IDC)       class AP_bo##IDC: AP_RscPicture { idc = IDC; x = 0.8; y = 0.85; w = 0.125; h = 0.017; text = "images\ui\hud_seg.paa"; }
        #define AP_BAR_VALUE(IDC)      class AP_bv##IDC: AP_RscStructuredText { idc = IDC; x = 0.8; y = 0.85; w = 0.040; h = 0.044; sizeEx = 0.036; text = ""; class Attributes { font = "EtelkaMonospacePro"; color = "#ebeff4"; align = "left"; shadow = 1; shadowColor = "#05070d"; }; }

        AP_BAR_ICON(23535, "icons\hud_health.paa"); AP_BAR_TRACK(23530); AP_BAR_FILL(23531, 0.325, 0.890, 0.612); AP_BAR_OVER(23532); AP_BAR_VALUE(23534);
        AP_BAR_ICON(23545, "icons\hud_water.paa");  AP_BAR_TRACK(23540); AP_BAR_FILL(23541, 0.216, 0.910, 0.941); AP_BAR_OVER(23542); AP_BAR_VALUE(23544);
        AP_BAR_ICON(23555, "icons\hud_food.paa");   AP_BAR_TRACK(23550); AP_BAR_FILL(23551, 0.216, 0.910, 0.941); AP_BAR_OVER(23552); AP_BAR_VALUE(23554);

        // WANTED bar (civ only): neon-yellow, 0-5000 bounty; full + red at 5000 = probable cause. $ climbs underneath (centred).
        AP_BAR_ICON(23560, "icons\hud_police.paa"); AP_BAR_TRACK(23561); AP_BAR_FILL(23562, 0.957, 0.686, 0.176); AP_BAR_OVER(23563);
        class AP_bv23564: AP_RscStructuredText { idc = 23564; x = 0.8; y = 0.92; w = 0.24; h = 0.050; sizeEx = 0.038; text = ""; class Attributes { font = "EtelkaMonospacePro"; color = "#f4af2d"; align = "center"; shadow = 1; shadowColor = "#05070d"; }; };
    };};