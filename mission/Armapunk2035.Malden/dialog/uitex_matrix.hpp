/*
    uitex_matrix.hpp -- AP_uiTexMatrix (941900): a display that is never opened on screen.

    It exists to be NAMED in a procedural texture string:

        #(rgb,1024,1024,1)uiEx(display:AP_uiTexMatrix,uniqueName:apmatrix_x,bgColor:#000000ff)

    The engine instantiates the display off-screen and renders it into that texture ("UI On
    Texture", Arma 3 2.12/2.14), and AP_fnc_uiTexMatrix paints the texture onto a vehicle's
    hidden selections. One CT_WEBBROWSER fills the whole display, at ui\html\matrix.html.

    THE DISPLAY IS 0..1, NOT SAFEZONE. Every other browser dialog here spans safezoneX/Y/W/H
    because it is composited over the player's screen; this one is rendered into a square
    texture whose viewport is the display's own 0..1 space (uiEx's viewportX/Y/W/H default to
    0,0,1,1). Safezone maths on a texture would push the page part-way off it.

    NO onLoad BRIDGE. matrix.html runs itself and never calls back, so nothing attaches
    webui_fnc_init -- the probe is deliberately the smallest thing that can move.
*/
class AP_uiTexMatrix {
    idd = 941900;
    name = "AP_uiTexMatrix";
    movingEnable = false;
    enableSimulation = true;
    class controls {
        class Page {
            idc = 941901;
            type = 106;
            style = 0;
            x = 0; y = 0; w = 1; h = 1;
            colorBackground[] = {0,0,0,1};
            colorText[] = {1,1,1,1};
            font = "RobotoCondensed";
            sizeEx = 0.03;
            url = "ui\html\matrix.html";
        };
    };
};
