/*
    map_editor.hpp -- the in-game map editor panel (idd 12950).

    FULLY SELF-CONTAINED ON PURPOSE. Every control base used here is defined in this
    file and inherits from nothing outside it. cyberdeck_base.hpp records why: ONE
    undefined base class aborts the whole config parse, which loses description.ext
    entirely -- no Header, no disabledAI, no enableDebugConsole, no CfgFunctions. A
    panel that only staff open is not worth that blast radius.

    Coordinates are plain safeZone arithmetic rather than UI_GRID macros. The macros
    must appear BARE and never inside quotes; quoted, they produce an invisible dialog
    with no error at all. Avoiding them here removes the trap rather than dodging it.

    The panel is optional: the editor's camera, selection, grab and nudge are all
    driven from display 46 and work with this closed. TAB opens it for the catalogue
    and for typing exact numbers -- which is the thing Zeus cannot do and the reason
    this was worth building rather than reusing.
*/
class AP_MapEd_TextBase  { type=0;  idc=-1; style=0;  x=0;y=0;w=0;h=0; text=""; colorText[]={0.78,0.94,1,1}; colorBackground[]={0,0,0,0}; font="RobotoCondensed"; sizeEx=0.030; shadow=1; };
class AP_MapEd_BoxBase   { type=0;  idc=-1; style=48; x=0;y=0;w=0;h=0; text=""; colorText[]={1,1,1,1};       colorBackground[]={0.02,0.05,0.08,0.86}; font="RobotoCondensed"; sizeEx=0.02; shadow=0; };
class AP_MapEd_ListBase  { type=5;  idc=-1; style=16; x=0;y=0;w=0;h=0;
    // CT_LISTBOX needs MORE properties than look necessary, and a missing one is a
    // runtime WARNING per control per open -- "No entry ...Cat.colorDisabled",
    // "Size: '/' not an array" -- not a config-parse failure, so nothing catches it
    // until the panel is opened on a real client. The first open logged 18 of them.
    // Everything CT_LISTBOX reads is therefore declared here explicitly.
    colorText[]={0.85,0.97,1,1}; colorDisabled[]={0.4,0.5,0.5,1};
    colorBackground[]={0.03,0.07,0.10,0.75};
    colorSelect[]={0.05,0.09,0.12,1}; colorSelect2[]={0.05,0.09,0.12,1};
    colorSelectBackground[]={0.18,0.85,0.55,0.55}; colorSelectBackground2[]={0.18,0.85,0.55,0.35};
    colorScrollbar[]={0.2,0.9,0.6,1};
    colorPicture[]={1,1,1,1}; colorPictureSelected[]={1,1,1,1}; colorPictureDisabled[]={1,1,1,0.5};
    colorPictureRight[]={1,1,1,1}; colorPictureRightSelected[]={1,1,1,1}; colorPictureRightDisabled[]={1,1,1,0.5};
    colorShadow[]={0,0,0,0}; colorBorder[]={0,0,0,0}; borderSize=0;
    tooltipColorText[]={1,1,1,1}; tooltipColorBox[]={1,1,1,1}; tooltipColorShade[]={0,0,0,0.65};
    soundSelect[]={"",0.1,1}; soundExpand[]={"",0.1,1}; soundCollapse[]={"",0.1,1};
    arrowEmpty="#(argb,8,8,3)color(1,1,1,1)"; arrowFull="#(argb,8,8,3)color(1,1,1,1)";
    period=0; rowHeight=0.032; itemSpacing=0.001; shadow=0;
    maxHistoryDelay=1; autoScrollSpeed=-1; autoScrollDelay=5; autoScrollRewind=0;
    canDrag=0; drawSideArrows=0; idcLeft=-1; idcRight=-1;
    font="RobotoCondensed"; sizeEx=0.028;
    // CT_LISTBOX reads its scrollbar from a subclass named ListScrollBar -- not ScrollBar. The
    // wrong name is a runtime warning per listbox per open ("No entry ...Cat.ListScrollBar").
    class ListScrollBar { color[]={1,1,1,0.6}; colorActive[]={1,1,1,1}; colorDisabled[]={1,1,1,0.3};
        thumb="#(argb,8,8,3)color(1,1,1,1)"; arrowFull="#(argb,8,8,3)color(1,1,1,1)";
        arrowEmpty="#(argb,8,8,3)color(1,1,1,1)"; border="#(argb,8,8,3)color(1,1,1,1)";
        shadow=0; scrollSpeed=0.06; width=0; height=0; autoScrollEnabled=0; };
};
class AP_MapEd_EditBase  { type=2;  idc=-1; style=0;  x=0;y=0;w=0;h=0; text="";
    colorText[]={0.87,1,0.96,1}; colorBackground[]={0.02,0.09,0.11,0.8};
    colorSelection[]={0.20,1,0.73,0.35}; colorDisabled[]={0.4,0.5,0.5,1};
    font="EtelkaMonospacePro"; sizeEx=0.030; autocomplete=""; canModify=1; maxChars=24; shadow=0; };
class AP_MapEd_BtnBase   { type=1;  idc=-1; style=2;  x=0;y=0;w=0;h=0; text="";
    colorText[]={0.05,0.09,0.12,1}; colorFocused[]={0.30,1,0.70,1}; colorDisabled[]={0.4,0.4,0.4,1};
    colorBackground[]={0.18,0.85,0.55,1}; colorBackgroundDisabled[]={0.2,0.2,0.2,1}; colorBackgroundActive[]={0.30,1,0.70,1};
    offsetX=0; offsetY=0; offsetPressedX=0; offsetPressedY=0;
    colorShadow[]={0,0,0,0}; colorBorder[]={0,0,0,0}; borderSize=0;
    soundEnter[]={"",0,1}; soundPush[]={"",0,1}; soundClick[]={"",0.1,1}; soundEscape[]={"",0,1};
    font="RobotoCondensed"; sizeEx=0.030; };

class AP_map_editor {
    idd = 12950;
    movingEnable = 0;
    enableSimulation = 1;
    onLoad = "uiNamespace setVariable ['AP_mapEd_display', _this select 0]; [] spawn AP_fnc_mapEditorPanelLoad;";
    onUnload = "uiNamespace setVariable ['AP_mapEd_display', displayNull];";
    class controls {
        class BG: AP_MapEd_BoxBase   { idc=12950; x="safeZoneX+0.02*safeZoneW"; y="safeZoneY+0.12*safeZoneH"; w="0.30*safeZoneW"; h="0.74*safeZoneH"; };
        class Title: AP_MapEd_TextBase { idc=-1;  text="MAP EDITOR"; x="safeZoneX+0.03*safeZoneW"; y="safeZoneY+0.135*safeZoneH"; w="0.28*safeZoneW"; h="0.04*safeZoneH"; sizeEx=0.038; };

        class LCat:  AP_MapEd_TextBase { text="Category";    x="safeZoneX+0.03*safeZoneW"; y="safeZoneY+0.185*safeZoneH"; w="0.14*safeZoneW"; h="0.03*safeZoneH"; };
        class Cat:   AP_MapEd_ListBase { idc=12951;          x="safeZoneX+0.03*safeZoneW"; y="safeZoneY+0.215*safeZoneH"; w="0.28*safeZoneW"; h="0.14*safeZoneH"; };
        class LSub:  AP_MapEd_TextBase { text="Subcategory"; x="safeZoneX+0.03*safeZoneW"; y="safeZoneY+0.360*safeZoneH"; w="0.14*safeZoneW"; h="0.03*safeZoneH"; };
        class Sub:   AP_MapEd_ListBase { idc=12952;          x="safeZoneX+0.03*safeZoneW"; y="safeZoneY+0.390*safeZoneH"; w="0.28*safeZoneW"; h="0.12*safeZoneH"; };
        class LCls:  AP_MapEd_TextBase { text="Object";      x="safeZoneX+0.03*safeZoneW"; y="safeZoneY+0.515*safeZoneH"; w="0.14*safeZoneW"; h="0.03*safeZoneH"; };
        class Cls:   AP_MapEd_ListBase { idc=12953;          x="safeZoneX+0.03*safeZoneW"; y="safeZoneY+0.545*safeZoneH"; w="0.28*safeZoneW"; h="0.14*safeZoneH"; };
        class Place: AP_MapEd_BtnBase  { idc=12954; text="PLACE  (8 m ahead, ground-aligned)"; x="safeZoneX+0.03*safeZoneW"; y="safeZoneY+0.690*safeZoneH"; w="0.28*safeZoneW"; h="0.035*safeZoneH";
            action="[] call AP_fnc_mapEditorPanelPlace;"; };

        class LSel:  AP_MapEd_TextBase { idc=12960; text="no selection"; x="safeZoneX+0.03*safeZoneW"; y="safeZoneY+0.735*safeZoneH"; w="0.28*safeZoneW"; h="0.03*safeZoneH"; sizeEx=0.026; };
        class LX: AP_MapEd_TextBase { text="X"; x="safeZoneX+0.03*safeZoneW";  y="safeZoneY+0.770*safeZoneH"; w="0.02*safeZoneW"; h="0.03*safeZoneH"; };
        class EX: AP_MapEd_EditBase { idc=12955; x="safeZoneX+0.05*safeZoneW"; y="safeZoneY+0.770*safeZoneH"; w="0.08*safeZoneW"; h="0.03*safeZoneH"; };
        class LY: AP_MapEd_TextBase { text="Y"; x="safeZoneX+0.14*safeZoneW";  y="safeZoneY+0.770*safeZoneH"; w="0.02*safeZoneW"; h="0.03*safeZoneH"; };
        class EY: AP_MapEd_EditBase { idc=12956; x="safeZoneX+0.16*safeZoneW"; y="safeZoneY+0.770*safeZoneH"; w="0.08*safeZoneW"; h="0.03*safeZoneH"; };
        class LZ: AP_MapEd_TextBase { text="Z"; x="safeZoneX+0.25*safeZoneW";  y="safeZoneY+0.770*safeZoneH"; w="0.02*safeZoneW"; h="0.03*safeZoneH"; };
        class EZ: AP_MapEd_EditBase { idc=12957; x="safeZoneX+0.27*safeZoneW"; y="safeZoneY+0.770*safeZoneH"; w="0.04*safeZoneW"; h="0.03*safeZoneH"; };

        class LDir: AP_MapEd_TextBase { text="Yaw";  x="safeZoneX+0.03*safeZoneW"; y="safeZoneY+0.805*safeZoneH"; w="0.04*safeZoneW"; h="0.03*safeZoneH"; };
        class EDir: AP_MapEd_EditBase { idc=12958;   x="safeZoneX+0.07*safeZoneW"; y="safeZoneY+0.805*safeZoneH"; w="0.06*safeZoneW"; h="0.03*safeZoneH"; };
        class LSnap:AP_MapEd_TextBase { text="Snap"; x="safeZoneX+0.14*safeZoneW"; y="safeZoneY+0.805*safeZoneH"; w="0.05*safeZoneW"; h="0.03*safeZoneH"; };
        class ESnap:AP_MapEd_EditBase { idc=12961;   x="safeZoneX+0.19*safeZoneW"; y="safeZoneY+0.805*safeZoneH"; w="0.05*safeZoneW"; h="0.03*safeZoneH"; };

        class Apply: AP_MapEd_BtnBase { idc=12959; text="APPLY EXACT TRANSFORM"; x="safeZoneX+0.03*safeZoneW"; y="safeZoneY+0.845*safeZoneH"; w="0.28*safeZoneW"; h="0.035*safeZoneH";
            action="[] call AP_fnc_mapEditorPanelApply;"; };
    };
};
