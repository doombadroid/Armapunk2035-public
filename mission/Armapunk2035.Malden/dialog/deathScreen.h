class DeathScreen {idd = 7300;
    name = "AP_Death_Screen";
    movingEnabled = false;
    enableSimulation = true;
    class controlsBackground {};
    class Controls {class MedicsOnline: AP_RscText {idc = 7304;
            colorBackground[] = {0, 0, 0, 0};
            text = "Medics Online: 1";
            x = 0.98 * safezoneX;
            y = 0.0556 * safezoneH + safezoneY;
            w = 0.8;
            h = (1 / 25);};
        class MedicsNearby: AP_RscText {idc = 7305;
            colorBackground[] = {0, 0, 0, 0};
            text = "Medics Nearby: No";
            x = 0.98 * safezoneX;
            y = 0.0776 * safezoneH + safezoneY;
            w = 0.8;
            h = (1 / 25);};
        class RespawnBtn: AP_RscButtonMenu {idc = 7302;
            x = 0.9 * safezoneW + safezoneX;
            y = 0.00500001 * safezoneH + safezoneY;
            w = (9 / 40);
            h = (1 / 25);
            text = "Respawn";
            onButtonClick = "closeDialog 0; AP_respawned = true; [] spawn AP_fnc_spawnMenu;";
            colorBackground[] = {
                "(profilenamespace getvariable ['GUI_BCG_RGB_R',0.3843])", "(profilenamespace getvariable ['GUI_BCG_RGB_G',0.7019])", "(profilenamespace getvariable ['GUI_BCG_RGB_B',0.8862])", 0.7
            };
            class Attributes {align = "center";};};
        class MedicBtn: AP_RscButtonMenu {idc = 7303;
            x = 0.98 * safezoneX;
            y = 0.00500001 * safezoneH + safezoneY;
            w = (9 / 40);
            h = (1 / 25);
            onButtonClick = "[true] spawn AP_fnc_deathScreenMedicalButtonClick;";
            text = "Request Medic";
            colorBackground[] = {
                "(profilenamespace getvariable ['GUI_BCG_RGB_R',0.3843])", "(profilenamespace getvariable ['GUI_BCG_RGB_G',0.7019])", "(profilenamespace getvariable ['GUI_BCG_RGB_B',0.8862])", 0.7
            };
            class Attributes {align = "center";};};
        class ReviveBtn: AP_RscButtonMenu {idc = 7306;
            x = 0.9 * safezoneW + safezoneX;
            y = 0.0292 * safezoneH + safezoneY;
            w = (9 / 40);
            h = (1 / 25);
            onButtonClick = "[false] spawn AP_fnc_deathScreenMedicalButtonClick;";
            text = "Allow Revive";
            colorBackground[] = {
                "(profilenamespace getvariable ['GUI_BCG_RGB_R',0.3843])", "(profilenamespace getvariable ['GUI_BCG_RGB_G',0.7019])", "(profilenamespace getvariable ['GUI_BCG_RGB_B',0.8862])", 0.7
            };
            class Attributes {align = "center";};};
        class respawnTime: AP_RscStructuredText {idc = 7301;
            colorBackground[] = {0, 0, 0, 0};
            text = "";
            x = 0.324687 * safezoneW + safezoneX;
            y = 0.916 * safezoneH + safezoneY;
            w = 0.350625 * safezoneW;
            h = 0.075 * safezoneH;};};};