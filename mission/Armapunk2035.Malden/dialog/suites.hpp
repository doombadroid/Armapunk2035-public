// LUXE SUITES -- lobby kiosk directory (idd 941600) + tenant menu (idd 941601).
// See suites.md. UI_GRID_* coords are BARE, never inside quotes: a quoted macro
// produces an invisible dialog with NO error (documented project footgun).
//
// Deliberately plain AP_Rsc* controls rather than a baked chrome image: this is
// a text list, and the tower already carries the neon. The kiosk's own screen gets
// the art (images\suites\kiosk_welcome.paa, phase 4).

class suiteKiosk {
    idd = 941600;
    name = "suiteKiosk";
    movingEnable = 0;
    enableSimulation = 1;
    onUnload = "AP_suiteBusy = false;";

    class controlsBackground {
        class Bg : AP_RscText {
            idc = -1;
            colorBackground[] = {0.02, 0.03, 0.05, 0.94};
            x = -13*UI_GRID_W + UI_GRID_X; y = -9*UI_GRID_H + UI_GRID_Y;
            w = 26*UI_GRID_W; h = 19*UI_GRID_H;
        };
        class TopRule : AP_RscText {
            idc = -1;
            colorBackground[] = {0.05, 0.72, 1, 0.85};
            x = -13*UI_GRID_W + UI_GRID_X; y = -6.1*UI_GRID_H + UI_GRID_Y;
            w = 26*UI_GRID_W; h = 0.06*UI_GRID_H;
        };
    };

    class controls {
        class Title : AP_RscStructuredText {
            idc = 941613;
            size = 0.9*UI_GRID_H;
            x = -12.4*UI_GRID_W + UI_GRID_X; y = -8.4*UI_GRID_H + UI_GRID_Y;
            w = 25*UI_GRID_W; h = 1.4*UI_GRID_H;
        };
        class Info : AP_RscStructuredText {
            idc = 941611;
            size = 0.62*UI_GRID_H;
            x = -12.4*UI_GRID_W + UI_GRID_X; y = -7.1*UI_GRID_H + UI_GRID_Y;
            w = 25*UI_GRID_W; h = 3.2*UI_GRID_H;
        };
        class SuiteList : AP_RscListBox {
            idc = 941610;
            sizeEx = 0.62*UI_GRID_H;
            colorBackground[] = {0.03, 0.05, 0.07, 0.85};
            x = -12.4*UI_GRID_W + UI_GRID_X; y = -3.7*UI_GRID_H + UI_GRID_Y;
            w = 24.8*UI_GRID_W; h = 12.2*UI_GRID_H;
            onLBDblClick = "[] call AP_fnc_suiteKioskLease;";
        };
        class LeaseBtn : AP_RscButtonMenu {
            idc = 941612;
            text = "LEASE / OPEN";
            colorBackground[] = {0.05, 0.72, 1, 0.22};
            x = -12.4*UI_GRID_W + UI_GRID_X; y = 8.8*UI_GRID_H + UI_GRID_Y;
            w = 8*UI_GRID_W; h = 1.1*UI_GRID_H;
            action = "[] call AP_fnc_suiteKioskLease;";
        };
        class CloseBtn : AP_RscButtonMenu {
            idc = -1;
            text = "CLOSE";
            x = 4.4*UI_GRID_W + UI_GRID_X; y = 8.8*UI_GRID_H + UI_GRID_Y;
            w = 8*UI_GRID_W; h = 1.1*UI_GRID_H;
            action = "closeDialog 0;";
        };
    };
};

class suiteMenu {
    idd = 941601;
    name = "suiteMenu";
    movingEnable = 0;
    enableSimulation = 1;

    class controlsBackground {
        class Bg : AP_RscText {
            idc = -1;
            colorBackground[] = {0.02, 0.03, 0.05, 0.94};
            x = -9*UI_GRID_W + UI_GRID_X; y = -6*UI_GRID_H + UI_GRID_Y;
            w = 18*UI_GRID_W; h = 12*UI_GRID_H;
        };
        class TopRule : AP_RscText {
            idc = -1;
            colorBackground[] = {0.05, 0.72, 1, 0.85};
            x = -9*UI_GRID_W + UI_GRID_X; y = -3.4*UI_GRID_H + UI_GRID_Y;
            w = 18*UI_GRID_W; h = 0.06*UI_GRID_H;
        };
    };

    class controls {
        class Title : AP_RscStructuredText {
            idc = 941620;
            size = 0.85*UI_GRID_H;
            x = -8.4*UI_GRID_W + UI_GRID_X; y = -5.4*UI_GRID_H + UI_GRID_Y;
            w = 17*UI_GRID_W; h = 1.3*UI_GRID_H;
        };
        class Info : AP_RscStructuredText {
            idc = 941621;
            size = 0.6*UI_GRID_H;
            x = -8.4*UI_GRID_W + UI_GRID_X; y = -3.1*UI_GRID_H + UI_GRID_Y;
            w = 17*UI_GRID_W; h = 2.6*UI_GRID_H;
        };
        class FurnBtn : AP_RscButtonMenu {
            idc = 941622;
            text = "BUY FURNITURE";
            x = -8.4*UI_GRID_W + UI_GRID_X; y = -0.2*UI_GRID_H + UI_GRID_Y;
            w = 17*UI_GRID_W; h = 1.1*UI_GRID_H;
            action = "[] call AP_fnc_suiteMenuFurniture;";
        };
        class StoreBtn : AP_RscButtonMenu {
            idc = 941623;
            text = "STORAGE";
            x = -8.4*UI_GRID_W + UI_GRID_X; y = 1.1*UI_GRID_H + UI_GRID_Y;
            w = 17*UI_GRID_W; h = 1.1*UI_GRID_H;
            action = "[] call AP_fnc_suiteMenuStorage;";
        };
        class PayBtn : AP_RscButtonMenu {
            idc = 941625;
            text = "PAY NOW";
            colorBackground[] = {1, 0.35, 0.2, 0.28};
            x = -8.4*UI_GRID_W + UI_GRID_X; y = 2.4*UI_GRID_H + UI_GRID_Y;
            w = 17*UI_GRID_W; h = 1.1*UI_GRID_H;
            action = "[] call AP_fnc_suiteMenuPay;";
        };
        class EndBtn : AP_RscButtonMenu {
            idc = 941624;
            text = "END LEASE";
            colorBackground[] = {0.6, 0.1, 0.1, 0.25};
            x = -8.4*UI_GRID_W + UI_GRID_X; y = 3.7*UI_GRID_H + UI_GRID_Y;
            w = 8.3*UI_GRID_W; h = 1.1*UI_GRID_H;
            action = "[] call AP_fnc_suiteMenuEnd;";
        };
        class CloseBtn : AP_RscButtonMenu {
            idc = -1;
            text = "CLOSE";
            x = 0.3*UI_GRID_W + UI_GRID_X; y = 3.7*UI_GRID_H + UI_GRID_Y;
            w = 8.3*UI_GRID_W; h = 1.1*UI_GRID_H;
            action = "closeDialog 0;";
        };
    };
};

// The bespoke two-list storage dialog that lived here is GONE (owner: "copy the
// storage menu from houses"). Suite storage now opens TrunkMenu, the same screen
// houses use -- see core/suites/fn_suiteStorage.sqf.
