/*
    plbInv.hpp -- PROOF STRONGBOX inventory ("Y menu") -- custom PAA chrome, no mod. Graphite rectangle,
    NO dim scrim. A capacity meter (brass on hairline) + a clean scrollable LIST of item rows ctrlCreate'd
    by AP_fnc_plbInvDemo (row PAA + name + qty + weight), brass full-frame selection, Use/Give/Drop.
    Owner test: !invdemo. Does NOT touch the live player menu.
*/
// ── ctrlCreate'd row templates ─────────────────────────────────────────────────────────────────
class AP_InvRowBg: AP_RscPicture { idc = -1; text = "images\ui\shop_row.paa"; };
class AP_InvRowName: AP_RscStructuredText {idc = -1; text = ""; sizeEx = 0.026;
    class Attributes { font = "PuristaBold"; color = "#eef1f7"; align = "left"; shadow = 0; };};
class AP_InvRowQty: AP_RscStructuredText {idc = -1; text = ""; sizeEx = 0.024;
    class Attributes { font = "PuristaBold"; color = "#d8a24c"; align = "left"; shadow = 0; };};
class AP_InvRowWt: AP_RscStructuredText {idc = -1; text = ""; sizeEx = 0.022;
    class Attributes { font = "PuristaMedium"; color = "#98a1b2"; align = "right"; shadow = 0; };};

// ── the dialog ─────────────────────────────────────────────────────────────────────────────────
class AP_Inv {idd = 515400;
    movingEnable = false;
    enableSimulation = true;
    onLoad = "uiNamespace setVariable ['AP_Inv', _this select 0];";
    onUnload = "uiNamespace setVariable ['AP_Inv', displayNull];";
    class controls {class Panel: AP_RscPicture { idc = -1; text = "images\ui\shop_panel.paa"; x = 0.28; y = 0.20; w = 0.44; h = 0.58; };

        class Title: AP_RscStructuredText {idc = 515401; x = 0.30; y = 0.216; w = 0.36; h = 0.05; sizeEx = 0.040; text = "";
            class Attributes { font = "PuristaBold"; color = "#eef1f7"; align = "left"; shadow = 0; };};
        class Subtitle: AP_RscStructuredText {idc = 515402; x = 0.301; y = 0.256; w = 0.36; h = 0.03; sizeEx = 0.023; text = "";
            class Attributes { font = "PuristaMedium"; color = "#98a1b2"; align = "left"; shadow = 0; };};
        class CloseX: AP_RscButtonMenu {idc = -1; text = "X"; x = 0.685; y = 0.216; w = 0.024; h = 0.030; sizeEx = 0.030;
            colorText[] = { 0.596, 0.631, 0.698, 1 };
            colorBackground[] = { 0, 0, 0, 0 }; colorBackground2[] = { 0, 0, 0, 0 };
            onButtonClick = "closeDialog 0;";};

        // capacity meter
        class CapLabel: AP_RscStructuredText {
            idc = -1; x = 0.30; y = 0.293; w = 0.05; h = 0.026; sizeEx = 0.020; text = "<t color='#98a1b2' font='PuristaMedium'>LOAD</t>";
            class Attributes { font = "PuristaMedium"; color = "#98a1b2"; align = "left"; shadow = 0; };};
        class CapTrack: AP_RscText { idc = -1; x = 0.356; y = 0.302; w = 0.238; h = 0.007; colorBackground[] = { 0.227, 0.259, 0.314, 0.9 }; };
        class CapFill:  AP_RscText { idc = 515410; x = 0.356; y = 0.302; w = 0.045; h = 0.007; colorBackground[] = { 0.847, 0.635, 0.298, 1 }; };
        class CapVal: AP_RscStructuredText {idc = 515411; x = 0.60; y = 0.289; w = 0.10; h = 0.028; sizeEx = 0.024; text = "";
            class Attributes { font = "PuristaBold"; color = "#d8a24c"; align = "right"; shadow = 0; };};

        // rows get ctrlCreate'd into here by the fn -- SCROLLABLE
        class List: AP_RscControlsGroupOneScrollbar {idc = 515420; x = 0.30; y = 0.335; w = 0.40; h = 0.36;
            class controls {};};

        class UseBtn: AP_RscButtonMenu {idc = 515430; text = "USE"; x = 0.30; y = 0.71; w = 0.126; h = 0.045; sizeEx = 0.030;
            colorText[] = { 0.125, 0.137, 0.184, 1 };
            animTextureNormal = "images\ui\shop_btn_brass.paa"; animTextureOver = "images\ui\shop_btn_brass.paa";
            animTextureFocused = "images\ui\shop_btn_brass.paa"; animTexturePressed = "images\ui\shop_btn_brass.paa";
            animTextureDefault = "images\ui\shop_btn_brass.paa"; animTextureDisabled = "images\ui\shop_btn_brass.paa";
            class Attributes { font = "PuristaBold"; color = "#20232f"; align = "center"; shadow = 0; };
            onButtonClick = "['use'] call AP_fnc_plbInvDemo";};
        class GiveBtn: AP_RscButtonMenu {idc = 515431; text = "GIVE"; x = 0.437; y = 0.71; w = 0.126; h = 0.045; sizeEx = 0.030;
            colorText[] = { 0.596, 0.631, 0.698, 1 };
            animTextureNormal = "images\ui\shop_btn_dark.paa"; animTextureOver = "images\ui\shop_btn_dark.paa";
            animTextureFocused = "images\ui\shop_btn_dark.paa"; animTexturePressed = "images\ui\shop_btn_dark.paa";
            animTextureDefault = "images\ui\shop_btn_dark.paa"; animTextureDisabled = "images\ui\shop_btn_dark.paa";
            class Attributes { font = "PuristaBold"; color = "#98a1b2"; align = "center"; shadow = 0; };
            onButtonClick = "['give'] call AP_fnc_plbInvDemo";};
        class DropBtn: AP_RscButtonMenu {idc = 515432; text = "DROP"; x = 0.574; y = 0.71; w = 0.126; h = 0.045; sizeEx = 0.030;
            colorText[] = { 0.596, 0.631, 0.698, 1 };
            animTextureNormal = "images\ui\shop_btn_dark.paa"; animTextureOver = "images\ui\shop_btn_dark.paa";
            animTextureFocused = "images\ui\shop_btn_dark.paa"; animTexturePressed = "images\ui\shop_btn_dark.paa";
            animTextureDefault = "images\ui\shop_btn_dark.paa"; animTextureDisabled = "images\ui\shop_btn_dark.paa";
            class Attributes { font = "PuristaBold"; color = "#98a1b2"; align = "center"; shadow = 0; };
            onButtonClick = "['drop'] call AP_fnc_plbInvDemo";};};};
