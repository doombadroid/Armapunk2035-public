/*
    hudEdit.hpp -- AP_web_hudedit (938400): the HUD UI EDITOR. Full spec: hudeditor.md.

    A DIALOG, AND THAT IS THE WHOLE REASON THIS CLASS EXISTS. The status HUD itself
    (dialog\hudWeb.hpp, AP_web_hud 938300) is an RscTitles LAYER cut with cutRsc, and a title
    layer is never focused -- which is exactly why the HUD can sit over gameplay without
    eating the mouse, and exactly why nothing in it can ever be dragged. So the editor is a
    focused dialog showing the SAME page, the live layer is cut down for the duration, and
    the player drags the real HUD rather than a mock-up of it.

    THE HOST SHAPE IS SHIPPED, NOT ASSUMED. AP_web_visor (941700, web_visor.hpp) is a
    full-screen type=106 control at safezoneX/Y/W/H with colorBackground {0,0,0,0} over a
    transparent page, rendering with the live world showing through. This is that class with
    a different url and an onLoad of its own.

    SAME URL AS THE LAYER, DELIBERATELY. The editor loads ui\html\hud.html -- the actual HUD
    page, not a copy. Nothing about the layout is re-implemented anywhere, so the editor
    cannot drift from the thing it edits, and a designer re-drop of hud.html changes both at
    once. Everything the editor adds (the drag overlay, the position stylesheet) is INJECTED
    at runtime by core\web\fn_hudEditOpen.sqf -- see that file for why nothing may be written
    into hud.html itself.

    FULL SAFEZONE, for the same reason hudWeb.hpp is: the page anchors itself with
    position:fixed against the CONTROL's viewport, so the control box IS the coordinate
    system. The editor stores offsets as fractions of that viewport, so the box has to be
    identical to the layer's or a saved layout would land somewhere else the moment it is
    applied to the live HUD.

    colorBackground IS {0,0,0,0} AND MUST STAY THAT WAY -- the same three-link chain
    hudWeb.hpp describes (the page's own html,body{background:transparent}, the shim adding
    no background, and this line). Any one of them going opaque paints a black rectangle over
    the world, which for an editor would also make it impossible to place anything against
    what the player actually sees.

    938400 continues the web run (937700 breach, 937800 terminal, 937900 journal, 938000
    storage, 938100 landing, 938200 duty terminal, 938300 status HUD) and 938401 is its
    control, the idd+1 convention every page in that run uses.

    NO movingEnable. The dialog is full-screen and the player is dragging things INSIDE it;
    a draggable dialog frame would fight every gesture.
*/
class AP_web_hudedit {
    idd = 938400;
    name = "AP_web_hudedit";
    movingEnable = 0;
    enableSimulation = 1;
    onLoad = "[_this select 0] spawn AP_fnc_hudEditOpen;";
    onUnload = "[] call AP_fnc_hudEditClose;";
    class controls {
        class Page {
            idc = 938401;
            type = 106;
            style = 0;
            x = safezoneX; y = safezoneY; w = safezoneW; h = safezoneH;
            colorBackground[] = {0,0,0,0};
            colorText[] = {1,1,1,1};
            font = "RobotoCondensed";
            sizeEx = 0.03;
            url = "ui\html\hud.html";
        };
    };
};
