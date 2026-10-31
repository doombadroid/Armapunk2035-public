/*
    radialRadio.hpp -- AP_RadialRadio (idd 515500): TAB-in-vehicle radial car-radio selector, NIGHT CITY.
    All station controls are ctrlCreate'd by AP_fnc_radioRadial (station count/colors/logos come from
    AP_Radio_Cfg at runtime -- adding a station in radioCfg.hpp automatically adds a slot here).
    Root classes below exist so ctrlCreate can instantiate them.
*/
class AP_RadialPic {type = 0;
    idc = -1;
    style = 48;   // ST_PICTURE
    x = 0; y = 0; w = 0; h = 0;
    colorBackground[] = { 0, 0, 0, 0 };
    colorText[] = { 1, 1, 1, 1 };
    font = "PuristaMedium";
    sizeEx = 0.02;
    text = "";
    shadow = 0;};
class AP_RadialPicKA: AP_RadialPic {style = "48 + 0x800";   // ST_PICTURE + keepAspect (logos)
};
class AP_RadialTxt {type = 13;   // structured text
    idc = -1;
    style = 0;
    x = 0; y = 0; w = 0; h = 0;
    size = 0.032;
    colorBackground[] = { 0, 0, 0, 0 };
    colorText[] = { 0.922, 0.937, 0.957, 1 };
    text = "";
    shadow = 0;
    class Attributes {font = "PuristaMedium";
        color = "#EBEFF4";
        align = "center";
        shadow = "false";};};
class AP_RadialBtn: AP_RscButtonInvisible {onMouseEnter = "";
    onMouseExit = "";};

class AP_RadialRadio {idd = 515500;
    name = "AP_RadialRadio";
    movingEnable = 0;
    enableSimulation = 1;
    onLoad = "";
    class controlsBackground {};
    class controls {};};
