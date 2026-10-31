/*
    uitex_holo.hpp -- AP_uiTexHolo (941910): never opened on screen; named in a UI-on-texture string
    by AP_fnc_uiTexHolo and rendered onto the holographic shell it floats over a car. Same shape as
    uitex_matrix.hpp: 0..1 coords (the display's own space, rendered into a square texture), one
    CT_WEBBROWSER at ui\html\holo.html. Transparent background -- the page draws on nothing, and
    uiEx's bgColor stays at its transparent default, so the real paint shows through the hologram.
*/
class AP_uiTexHolo {
    idd = 941910;
    name = "AP_uiTexHolo";
    movingEnable = false;
    enableSimulation = true;
    class controls {
        class Page {
            idc = 941911;
            type = 106;
            style = 0;
            x = 0; y = 0; w = 1; h = 1;
            colorBackground[] = {0,0,0,0};
            colorText[] = {1,1,1,1};
            font = "RobotoCondensed";
            sizeEx = 0.03;
            url = "ui\html\holo.html";
        };
    };
};
