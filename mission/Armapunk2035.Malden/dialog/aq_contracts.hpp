/*
    aq_contracts.hpp -- AP_AqContracts (idd 941800, owner 2026-09-05). The CONTRACTS picker:
    one list of every ArmaQuest giver plus the player's own journal, driven by AP_fnc_aqContracts.

    WHY IT EXISTS. Until now the only way to open a giver's offer board was a walk-up scroll
    action on a spawned NPC (ArmaQuest's own "addAction" driver) or one of six permanent
    "Cyberdeck: Contact X" self-actions on the player, armed at boot. The NPCs are gone and the
    six wheel entries went with them, so the boards needed a home that is not the scroll wheel.
    This is that home: the deck's "Quest Log" app opens it, you pick who to talk to, and
    aq_fnc_openOffers does exactly what it did before -- it sets aq_pendingGiver and re-opens the
    ArmaQuest journal (AQ_Journal, 937900) on that giver's Available tab.

    WHY A PICKER AND NOT A MERGED BOARD. The journal page cannot show more than one giver at a
    time and that page is VENDORED (ArmaQuest\ui\journal.html -- do not edit; see VENDORED.txt).
    Its onOffers handler does `MODEL.offers = ids`, replacing the Available tab wholesale on every
    push, and its accept verb sends only the quest id -- the bridge fills in the giver from the
    single aq_pendingGiver. Pushing six boards would leave five of them invisible and let an
    accept resolve against the wrong giver. One giver at a time is the page's own contract, so the
    picker sits in front of it rather than fighting it.

    Chrome copied from maldenPicker.hpp (515800) so it reads as the same family.
    idcs: 941810 list, 941820 status.
*/
class AP_AqContracts {idd = 941800;
    name = "AP_AqContracts";
    movingEnable = 0;
    enableSimulation = 1;
    onLoad = "uiNamespace setVariable ['AP_AqContracts', _this select 0];";
    onUnload = "uiNamespace setVariable ['AP_AqContracts', displayNull];";

    class controlsBackground {class NCPanel: AP_RscPicture {idc = -1;
            text = "images\ui\nc_panel.paa";
            x = 0.38 * safezoneW + safezoneX;
            y = 0.30 * safezoneH + safezoneY;
            w = 0.24 * safezoneW;
            h = 0.40 * safezoneH;};
        class TitleText: AP_RscTitle {idc = -1;
            sizeEx = 0.042;
            text = "CONTRACTS";
            x = 0.395 * safezoneW + safezoneX;
            y = 0.318 * safezoneH + safezoneY;
            w = 0.20 * safezoneW;
            h = 0.028 * safezoneH;
            colorText[] = { 0.922, 0.937, 0.957, 1 };
            colorBackground[] = { 0, 0, 0, 0 };};
        class NCDivider: AP_RscPicture {idc = -1;
            text = "images\ui\nc_divider.paa";
            x = 0.395 * safezoneW + safezoneX;
            y = 0.350 * safezoneH + safezoneY;
            w = 0.21 * safezoneW;
            h = 0.005 * safezoneH;};
        class HdrText: AP_RscText {idc = -1;
            sizeEx = 0.030;
            text = "WHO ARE YOU CALLING?";
            x = 0.395 * safezoneW + safezoneX;
            y = 0.362 * safezoneH + safezoneY;
            w = 0.20 * safezoneW;
            h = 0.022 * safezoneH;
            colorText[] = { 0.537, 0.576, 0.627, 1 };
            colorBackground[] = { 0, 0, 0, 0 };};};

    class Controls {class GiverList: AP_RscListBox {idc = 941810;
            sizeEx = 0.034;
            x = 0.393 * safezoneW + safezoneX;
            y = 0.390 * safezoneH + safezoneY;
            w = 0.214 * safezoneW;
            h = 0.215 * safezoneH;
            colorBackground[] = { 0.078, 0.094, 0.129, 0.9 };
            colorSelectBackground[] = { 0.945, 0.239, 0.659, 0.35 };
            colorSelectBackground2[] = { 0.945, 0.239, 0.659, 0.35 };
            onLBDblClick = "['show'] call AP_fnc_aqContracts;";};
        class OpenBtn: AP_RscButtonMenu {idc = -1;
            text = "OPEN";
            onButtonClick = "['show'] call AP_fnc_aqContracts;";
            x = 0.393 * safezoneW + safezoneX;
            y = 0.616 * safezoneH + safezoneY;
            w = 0.134 * safezoneW;
            h = 0.028 * safezoneH;
            colorText[] = { 0.043, 0.075, 0.102, 1 };
            colorBackground[] = { 0.216, 0.910, 0.941, 1 };
            colorBackground2[] = { 0.35, 0.95, 0.97, 1 };
            class Attributes { font = "PuristaSemibold"; color = "#0b131a"; align = "center"; shadow = "false"; };};
        class CloseBtn: AP_RscButtonMenu {idc = -1;
            text = "Close";
            onButtonClick = "closeDialog 0;";
            x = 0.533 * safezoneW + safezoneX;
            y = 0.616 * safezoneH + safezoneY;
            w = 0.074 * safezoneW;
            h = 0.028 * safezoneH;
            colorText[] = { 0.537, 0.576, 0.627, 1 };
            colorBackground[] = { 0.118, 0.153, 0.208, 1 };
            colorBackground2[] = { 0.157, 0.196, 0.247, 1 };};
        class StatusText: AP_RscStructuredText {idc = 941820;
            size = 0.024;
            sizeEx = 0.024;
            text = "";
            x = 0.393 * safezoneW + safezoneX;
            y = 0.652 * safezoneH + safezoneY;
            w = 0.214 * safezoneW;
            h = 0.026 * safezoneH;
            class Attributes { font = "PuristaLight"; color = "#8993a0"; align = "left"; shadow = 0; };};};};
