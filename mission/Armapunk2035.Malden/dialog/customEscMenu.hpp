#include "\A3\ui_f\hpp\defineCommonGrids.inc"
class AP_EscapeMenuButton: AP_RscButtonMenu {animTextureNormal = "#(argb,8,8,3)color(1,1,1,1)";
    animTextureDisabled = "#(argb,8,8,3)color(1,1,1,1)";
    animTextureOver = "#(argb,8,8,3)color(1,1,1,1)";
    animTextureFocused = "#(argb,8,8,3)color(1,1,1,1)";
    animTexturePressed = "#(argb,8,8,3)color(1,1,1,1)";
    animTextureDefault = "#(argb,8,8,3)color(1,1,1,1)";
    colorBackground[] = {0, 0, 0, 0.8};
    colorBackgroundFocused[] = {1, 1, 1, 1};
    colorBackground2[] = {0.75, 0.75, 0.75, 1};
    color[] = {1, 1, 1, 1};
    colorFocused[] = {0, 0, 0, 1};
    color2[] = {0, 0, 0, 1};
    colorText[] = {1, 1, 1, 1};
    colorDisabled[] = {1, 1, 1, 0.25};
    colorSecondary[] = {1, 1, 1, 1};
    colorFocusedSecondary[] = {0, 0, 0, 1};
    color2Secondary[] = {0, 0, 0, 1};
    colorDisabledSecondary[] = {1, 1, 1, 0.25};};
class AP_EscapeMenuHeader: AP_StructuredText {idc = -1;
    text = "";
    x = 1 * GUI_GRID_W + GUI_GRID_X;
    y = 8.6 * GUI_GRID_H + GUI_GRID_Y;
    w = 15 * (((safezoneW / safezoneH) min 1.2) / 40);
    h = 1 * ((((safezoneW / safezoneH) min 1.2) / 1.2) / 25);
    colorBackground[] = {0.071, 0.09, 0.129, 1};   // NC graphite (was profile GUI_BCG -> arma-yellow on default profiles)
};
class LoonyBinWikiLinkButton: AP_EscapeMenuButton {url = "https://discord.gg/TdNVfcFcx6";};
// owner 2026-06-14 (#198): was AP_EscapeMenuButton -> AP_RscButtonMenu (type=16 shortcut button). The
// engine `url` auto-open property ONLY fires on a plain CT_BUTTON (type=1), so the ESC Discord link did
// nothing on click. Rebased on AP_SpawnRscButton (complete type=1 button) so the Steam overlay opens.
// Position/text/tooltip are still set at runtime in fn_onGameInterrupt; here we just supply the colours.
class LoonyBinDiscordLinkButton: AP_SpawnRscButton {
    text = "LoonyBin Discord"; // ctrlCreate of a CT_BUTTON (type=1) REQUIRES text; AP_SpawnRscButton omits it
                               // -> "...LoonyBinDiscordLinkButton.text" error on every ESC. Runtime ctrlSetText still overrides.
    style = 2;
    sizeEx = 0.038;
    colorText[] = {1, 1, 1, 1};
    colorBackground[] = {0, 0, 0, 0.8};
    colorBackgroundActive[] = {0.13, 0.54, 0.21, 1};
    colorFocused[] = {0.13, 0.54, 0.21, 1};
    url = "https://discord.gg/TdNVfcFcx6";};
class LoonyBinMyLoonyBinButton: AP_EscapeMenuButton {url = "https://discord.gg/TdNVfcFcx6";};
class LoonyBinTeamspeakLinkButton: AP_EscapeMenuButton {url = "https://discord.gg/TdNVfcFcx6";};
class LoonyBinForumsLinkButton: AP_EscapeMenuButton {url = "https://discord.gg/TdNVfcFcx6";};