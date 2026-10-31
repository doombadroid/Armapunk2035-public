/*
    web_visor.hpp -- AP_web_visor (941700): HTML port of the VR-goggle visor
    HUD / quickhack plate stack. Built ALONGSIDE vr_dock (941300) -- see
    fn_visorOpen.sqf / fn_visorBridge.sqf. Full-screen, transparent browser
    control over the live world, same footprint as vr_dock's own Visor/Catcher
    controls (safezoneX/Y/W/H) -- this is a goggle HUD, not a windowed phone
    screen, so it does not ride the phone's deckScale size slider.
*/
class AP_web_visor {
    idd = 941700;
    name = "AP_web_visor";
    movingEnable = false;
    enableSimulation = true;
    onLoad = "[_this select 0] spawn AP_fnc_visorBridge;";
    onUnload = "AP_visorOpen = false;";
    class controls {
        class Page {
            idc = 941701;
            type = 106;
            style = 0;
            x = safezoneX; y = safezoneY; w = safezoneW; h = safezoneH;
            colorBackground[] = {0,0,0,0};
            colorText[] = {1,1,1,1};
            font = "RobotoCondensed";
            sizeEx = 0.03;
            url = "ui\html\visor.html";
        };
        #include "..\webui\config\prompt_overlay.hpp"
    };
};
