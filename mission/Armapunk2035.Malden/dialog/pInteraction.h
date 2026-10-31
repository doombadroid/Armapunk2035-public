
#define BGX 0.35 
#define BGY 0.2 
#define BGW 0.3
class pInteraction_Menu {idd = 37400;
    movingEnabled = false;
    enableSimulation = true;
    class controlsBackground {class RscTitleBackground: AP_RscText {colorBackground[] = {
                "(profileNamespace getVariable ['GUI_BCG_RGB_R',0.3843])", "(profileNamespace getVariable ['GUI_BCG_RGB_G',0.7019])", "(profileNamespace getVariable ['GUI_BCG_RGB_B',0.8862])", "(profileNamespace getVariable ['GUI_BCG_RGB_A',0.7])"
            };
            idc = -1;
            x = BGX;
            y = BGY;
            w = BGW;
            h = (1 / 25);};
        class MainBackground: AP_RscText {idc = -1;
            colorBackground[] = {0, 0, 0, 0.7};
            x = BGX;
            y = BGY + (11 / 250);
            w = BGW;
            h = 0.6 - (22 / 250);};
        class Title: AP_RscTitle {colorBackground[] = {0, 0, 0, 0};
            idc = 37401;
            text = "Player Interaction Menu";
            x = BGX;
            y = BGY;
            w = BGW;
            h = (1 / 25);};};
    class controls {class ButtonClose: AP_RscButtonMenu {idc = -1;
            text = "Close";
            onButtonClick = "closeDialog 0;";
            x = BGX;
            y = 0.8 - (1 / 25);
            w = (6.25 / 40);
            h = (1 / 25);};
        class ButtonOne: AP_RscButtonMenu {idc = 37450;
            colorBackground[] = {
                "(profileNamespace getVariable ['GUI_BCG_RGB_R',0.3843])", "(profileNamespace getVariable ['GUI_BCG_RGB_G',0.7019])", "(profileNamespace getVariable ['GUI_BCG_RGB_B',0.8862])", 0.5
            };
            text = "";
            sizeEx = 0.025;
            x = BGX + 0.03;
            y = BGY + 0.07;
            w = 0.24;
            h = 0.038;};
        class ButtonTwo: AP_RscButtonMenu {idc = 37451;
            colorBackground[] = {
                "(profileNamespace getVariable ['GUI_BCG_RGB_R',0.3843])", "(profileNamespace getVariable ['GUI_BCG_RGB_G',0.7019])", "(profileNamespace getVariable ['GUI_BCG_RGB_B',0.8862])", 0.5
            };
            text = "";
            sizeEx = 0.025;
            x = BGX + 0.03;
            y = BGY + 0.12;
            w = 0.24;
            h = 0.038;};
        class ButtonThree: AP_RscButtonMenu {idc = 37452;
            colorBackground[] = {
                "(profileNamespace getVariable ['GUI_BCG_RGB_R',0.3843])", "(profileNamespace getVariable ['GUI_BCG_RGB_G',0.7019])", "(profileNamespace getVariable ['GUI_BCG_RGB_B',0.8862])", 0.5
            };
            text = "";
            sizeEx = 0.025;
            x = BGX + 0.03;
            y = BGY + 0.17;
            w = 0.24;
            h = 0.038;};
        class ButtonFour: AP_RscButtonMenu {idc = 37453;
            colorBackground[] = {
                "(profileNamespace getVariable ['GUI_BCG_RGB_R',0.3843])", "(profileNamespace getVariable ['GUI_BCG_RGB_G',0.7019])", "(profileNamespace getVariable ['GUI_BCG_RGB_B',0.8862])", 0.5
            };
            text = "";
            sizeEx = 0.025;
            x = BGX + 0.03;
            y = BGY + 0.22;
            w = 0.24;
            h = 0.038;};
        class ButtonFive: AP_RscButtonMenu {idc = 37454;
            colorBackground[] = {
                "(profileNamespace getVariable ['GUI_BCG_RGB_R',0.3843])", "(profileNamespace getVariable ['GUI_BCG_RGB_G',0.7019])", "(profileNamespace getVariable ['GUI_BCG_RGB_B',0.8862])", 0.5
            };
            text = "";
            sizeEx = 0.025;
            x = BGX + 0.03;
            y = BGY + 0.27;
            w = 0.24;
            h = 0.038;};
        class ButtonSix: AP_RscButtonMenu {idc = 37455;
            colorBackground[] = {
                "(profileNamespace getVariable ['GUI_BCG_RGB_R',0.3843])", "(profileNamespace getVariable ['GUI_BCG_RGB_G',0.7019])", "(profileNamespace getVariable ['GUI_BCG_RGB_B',0.8862])", 0.5
            };
            text = "";
            sizeEx = 0.025;
            x = BGX + 0.03;
            y = BGY + 0.32;
            w = 0.24;
            h = 0.038;};
        class ButtonSeven: AP_RscButtonMenu {idc = 37456;
            colorBackground[] = {
                "(profileNamespace getVariable ['GUI_BCG_RGB_R',0.3843])", "(profileNamespace getVariable ['GUI_BCG_RGB_G',0.7019])", "(profileNamespace getVariable ['GUI_BCG_RGB_B',0.8862])", 0.5
            };
            text = "";
            sizeEx = 0.025;
            x = BGX + 0.03;
            y = BGY + 0.37;
            w = 0.24;
            h = 0.038;};};};
class genericInteractionMenu {idd = 37400;
    movingEnabled = false;
    enableSimulation = true;
    class controlsBackground {class RscTitleBackground: AP_RscText {colorBackground[] = {
                "(profileNamespace getVariable ['GUI_BCG_RGB_R',0.3843])", "(profileNamespace getVariable ['GUI_BCG_RGB_G',0.7019])", "(profileNamespace getVariable ['GUI_BCG_RGB_B',0.8862])", "(profileNamespace getVariable ['GUI_BCG_RGB_A',0.7])"
            };
            idc = -1;
            x = BGX;
            y = BGY;
            w = BGW;
            h = (1 / 25);};
        class MainBackground: AP_RscText {idc = -1;
            colorBackground[] = {0, 0, 0, 0.7};
            x = BGX;
            y = BGY + (11 / 250);
            w = BGW;
            h = 0.45 - (22 / 250);};
        class Title: AP_RscTitle {colorBackground[] = {0, 0, 0, 0};
            idc = 37401;
            text = "";
            x = BGX;
            y = BGY;
            w = BGW;
            h = (1 / 25);};};
    class controls {class ButtonClose: AP_RscButtonMenu {idc = -1;
            text = "Close";
            onButtonClick = "closeDialog 0;";
            x = BGX;
            y = 0.65 - (1 / 25);
            w = (6.25 / 40);
            h = (1 / 25);};
        class ButtonOne: AP_RscButtonMenu {idc = 37450;
            colorBackground[] = {
                "(profileNamespace getVariable ['GUI_BCG_RGB_R',0.3843])", "(profileNamespace getVariable ['GUI_BCG_RGB_G',0.7019])", "(profileNamespace getVariable ['GUI_BCG_RGB_B',0.8862])", 0.5
            };
            text = "";
            sizeEx = 0.025;
            x = BGX + 0.03;
            y = BGY + 0.07;
            w = 0.24;
            h = 0.038;};
        class ButtonTwo: AP_RscButtonMenu {idc = 37451;
            colorBackground[] = {
                "(profileNamespace getVariable ['GUI_BCG_RGB_R',0.3843])", "(profileNamespace getVariable ['GUI_BCG_RGB_G',0.7019])", "(profileNamespace getVariable ['GUI_BCG_RGB_B',0.8862])", 0.5
            };
            text = "";
            sizeEx = 0.025;
            x = BGX + 0.03;
            y = BGY + 0.12;
            w = 0.24;
            h = 0.038;};
        class ButtonThree: AP_RscButtonMenu {idc = 37452;
            colorBackground[] = {
                "(profileNamespace getVariable ['GUI_BCG_RGB_R',0.3843])", "(profileNamespace getVariable ['GUI_BCG_RGB_G',0.7019])", "(profileNamespace getVariable ['GUI_BCG_RGB_B',0.8862])", 0.5
            };
            text = "";
            sizeEx = 0.025;
            x = BGX + 0.03;
            y = BGY + 0.17;
            w = 0.24;
            h = 0.038;};
        class ButtonFour: AP_RscButtonMenu {idc = 37453;
            colorBackground[] = {
                "(profileNamespace getVariable ['GUI_BCG_RGB_R',0.3843])", "(profileNamespace getVariable ['GUI_BCG_RGB_G',0.7019])", "(profileNamespace getVariable ['GUI_BCG_RGB_B',0.8862])", 0.5
            };
            text = "";
            sizeEx = 0.025;
            x = BGX + 0.03;
            y = BGY + 0.22;
            w = 0.24;
            h = 0.038;};
        class ButtonFive: AP_RscButtonMenu {idc = 37454;
            colorBackground[] = {
                "(profileNamespace getVariable ['GUI_BCG_RGB_R',0.3843])", "(profileNamespace getVariable ['GUI_BCG_RGB_G',0.7019])", "(profileNamespace getVariable ['GUI_BCG_RGB_B',0.8862])", 0.5
            };
            text = "";
            sizeEx = 0.025;
            x = BGX + 0.03;
            y = BGY + 0.27;
            w = 0.24;
            h = 0.038;};
        class ButtonSix: AP_RscButtonMenu {idc = 37455;
            colorBackground[] = {
                "(profileNamespace getVariable ['GUI_BCG_RGB_R',0.3843])", "(profileNamespace getVariable ['GUI_BCG_RGB_G',0.7019])", "(profileNamespace getVariable ['GUI_BCG_RGB_B',0.8862])", 0.5
            };
            text = "";
            sizeEx = 0.025;
            x = BGX + 0.03;
            y = BGY + 0.32;
            w = 0.24;
            h = 0.038;};};};