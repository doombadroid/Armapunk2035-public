/*
    web_carradio.hpp -- AP_web_carRadio (515600): the HTML port of the TAB-in-vehicle car
    radio (design_handoff_phone_rework/radial.html, "PHOSPHOR RING"). ONE browser control,
    transparent -- fn_carRadioBridge.sqf (this dialog's onLoad) sizes it to the safezone at
    load via the same AP_fnc_casinoFit helper web_map.hpp uses, so the class geometry below
    is only the pre-fit frame. The page then anchors its own dial bottom-left over that,
    the same placement fn_radioRadial.sqf computes from safezoneX/Y/H.

    SITS ALONGSIDE dialog\radialRadio.hpp (AP_RadialRadio, idd 515500) -- untouched, still
    what TAB opens. This dialog has no key bound yet; see fn_carRadioOpen.sqf's header.

    No prompt_overlay.hpp include: this screen has no typed-text surface (matches
    web_probe.hpp / web_journal.hpp, the other single-control web dialogs that skip it).
*/
class AP_web_carRadio {
    idd = 515600;
    name = "AP_web_carRadio";
    movingEnable = false;
    enableSimulation = true;
    onLoad = "[_this select 0] spawn AP_fnc_carRadioBridge;";
    class controls {
        class Page {
            idc = 515601;
            type = 106;
            style = 0;
            x = -20 * UI_GRID_W + UI_GRID_X; y = -11 * UI_GRID_H + UI_GRID_Y;
            w  =  40 * UI_GRID_W;            h =  22 * UI_GRID_H;
            colorBackground[] = {0,0,0,0};
            colorText[] = {1,1,1,1};
            font = "RobotoCondensed";
            sizeEx = 0.6 * UI_GRID_H;
            url = "ui\html\carradio.html";
        };
    };
};
