/*
    storageVault.hpp -- THE STORAGE WORKER dialog (idd 515700, LooneyBin owner 2026-07-11). Styled to MATCH
    the live house/trunk storage menu (trunk.hpp, TrunkMenu idd 4500): same nc_panel.paa graphite chrome,
    nc_divider, muted column captions, split AP_RscListBox panels with magenta selection, gold weight/cash
    readout top-right, cyan PuristaSemibold primaries, graphite Close. Two lists here = YOUR PROPERTIES (left)
    / THE VAULT (right); primaries = PACK (empty a property into a slot) / UNPACK (fill a property from a slot).
    All idcs match AP_fnc_storageVault / AP_fnc_storageVaultRecv: 515710 houses, 515720 slots, 515730
    status, 515740 cash, 515741 pack button.
*/
class AP_StorageVault {idd = 515700;
    name = "AP_StorageVault";
    movingEnable = 0;
    enableSimulation = 1;
    onLoad = "uiNamespace setVariable ['AP_StorageVault', _this select 0];";
    onUnload = "uiNamespace setVariable ['AP_StorageVault', displayNull];";

    class controlsBackground {class NCPanel: AP_RscPicture {idc = -1;
            text = "images\ui\nc_panel.paa";
            x = 0.29 * safezoneW + safezoneX;
            y = 0.24 * safezoneH + safezoneY;
            w = 0.42 * safezoneW;
            h = 0.52 * safezoneH;};
        class TitleText: AP_RscTitle {idc = -1;
            sizeEx = 0.045;
            text = "STORAGE WORKER";
            x = 0.31 * safezoneW + safezoneX;
            y = 0.263 * safezoneH + safezoneY;
            w = 0.25 * safezoneW;
            h = 0.03 * safezoneH;
            colorText[] = { 0.922, 0.937, 0.957, 1 };
            colorBackground[] = { 0, 0, 0, 0 };};
        class CashVal: AP_RscTitle {idc = 515740;
            style = 1;
            sizeEx = 0.032;
            text = "";
            x = 0.408 * safezoneW + safezoneX;
            y = 0.267 * safezoneH + safezoneY;
            w = 0.285 * safezoneW;
            h = 0.026 * safezoneH;
            colorText[] = { 0.780, 0.635, 0.306, 1 };
            colorBackground[] = { 0, 0, 0, 0 };};
        class NCDivider: AP_RscPicture {idc = -1;
            text = "images\ui\nc_divider.paa";
            x = 0.31 * safezoneW + safezoneX;
            y = 0.300 * safezoneH + safezoneY;
            w = 0.26 * safezoneW;
            h = 0.005 * safezoneH;};
        class HdrProps: AP_RscText {idc = -1;
            sizeEx = 0.032;
            text = "YOUR PROPERTIES";
            x = 0.31 * safezoneW + safezoneX;
            y = 0.312 * safezoneH + safezoneY;
            w = 0.180 * safezoneW;
            h = 0.024 * safezoneH;
            colorText[] = { 0.537, 0.576, 0.627, 1 };
            colorBackground[] = { 0, 0, 0, 0 };};
        class HdrVault: AP_RscText {idc = -1;
            sizeEx = 0.032;
            text = "THE VAULT";
            x = 0.513 * safezoneW + safezoneX;
            y = 0.312 * safezoneH + safezoneY;
            w = 0.180 * safezoneW;
            h = 0.024 * safezoneH;
            colorText[] = { 0.537, 0.576, 0.627, 1 };
            colorBackground[] = { 0, 0, 0, 0 };};};

    class Controls {class HouseList: AP_RscListBox {idc = 515710;
            sizeEx = 0.032;
            x = 0.31 * safezoneW + safezoneX;
            y = 0.340 * safezoneH + safezoneY;
            w = 0.180 * safezoneW;
            h = 0.27 * safezoneH;
            colorBackground[] = { 0.078, 0.094, 0.129, 0.9 };
            colorSelectBackground[] = { 0.945, 0.239, 0.659, 0.35 };
            colorSelectBackground2[] = { 0.945, 0.239, 0.659, 0.35 };
            onLBSelChanged = "params ['_c','_i']; private _h = AP_vaultHouses param [_i, []]; if (_h isEqualTo []) exitWith {}; private _wt = round((((_h param [3,0]) + (_h param [4,0])) max 0)); private _b = (finddisplay 515700) displayCtrl 515741; _b ctrlSetText (if (_wt <= 0) then {'PACK INTO VAULT'} else {format ['PACK  ($%1)', [_wt * 10] call AP_fnc_numberText]});";
        };
        class SlotList: AP_RscListBox {idc = 515720;
            sizeEx = 0.032;
            x = 0.513 * safezoneW + safezoneX;
            y = 0.340 * safezoneH + safezoneY;
            w = 0.180 * safezoneW;
            h = 0.27 * safezoneH;
            colorBackground[] = { 0.078, 0.094, 0.129, 0.9 };
            colorSelectBackground[] = { 0.945, 0.239, 0.659, 0.35 };
            colorSelectBackground2[] = { 0.945, 0.239, 0.659, 0.35 };};

        // primaries (cyan) under each column -- mirrors trunk TAKE / STORE
        class PackBtn: AP_RscButtonMenu {idc = 515741;
            text = "PACK INTO VAULT";
            tooltip = "Empty the selected property's storage into a new vault slot. Fee scales with weight.";
            onButtonClick = "['pack'] call AP_fnc_storageVault;";
            x = 0.31 * safezoneW + safezoneX;
            y = 0.620 * safezoneH + safezoneY;
            w = 0.180 * safezoneW;
            h = 0.028 * safezoneH;
            colorText[] = { 0.043, 0.075, 0.102, 1 };
            colorBackground[] = { 0.216, 0.910, 0.941, 1 };
            colorBackground2[] = { 0.35, 0.95, 0.97, 1 };
            class Attributes { font = "PuristaSemibold"; color = "#0b131a"; align = "center"; shadow = "false"; };};
        class UnpackBtn: AP_RscButtonMenu {idc = -1;
            text = "UNPACK TO PROPERTY";
            tooltip = "Fill the selected property from the selected vault slot. Overflow stays in the vault.";
            onButtonClick = "['unpack'] call AP_fnc_storageVault;";
            x = 0.513 * safezoneW + safezoneX;
            y = 0.620 * safezoneH + safezoneY;
            w = 0.180 * safezoneW;
            h = 0.028 * safezoneH;
            colorText[] = { 0.043, 0.075, 0.102, 1 };
            colorBackground[] = { 0.216, 0.910, 0.941, 1 };
            colorBackground2[] = { 0.35, 0.95, 0.97, 1 };
            class Attributes { font = "PuristaSemibold"; color = "#0b131a"; align = "center"; shadow = "false"; };};

        // result / hint line
        class StatusText: AP_RscStructuredText {idc = 515730;
            size = 0.026;
            sizeEx = 0.026;
            text = "";
            x = 0.31 * safezoneW + safezoneX;
            y = 0.657 * safezoneH + safezoneY;
            w = 0.383 * safezoneW;
            h = 0.030 * safezoneH;
            class Attributes { font = "PuristaMedium"; color = "#8993a0"; align = "left"; shadow = 0; };};

        // bottom row: hint + close
        class HintText: AP_RscText {idc = -1;
            sizeEx = 0.024;
            text = "The vault only moves items between properties. No direct withdrawals.";
            x = 0.31 * safezoneW + safezoneX;
            y = 0.706 * safezoneH + safezoneY;
            w = 0.31 * safezoneW;
            h = 0.022 * safezoneH;
            colorText[] = { 0.537, 0.576, 0.627, 1 };
            colorBackground[] = { 0, 0, 0, 0 };};
        class ButtonClose: AP_RscButtonMenu {idc = -1;
            text = "Close";
            onButtonClick = "closeDialog 0;";
            x = 0.630 * safezoneW + safezoneX;
            y = 0.700 * safezoneH + safezoneY;
            w = 0.063 * safezoneW;
            h = 0.024 * safezoneH;
            colorText[] = { 0.537, 0.576, 0.627, 1 };
            colorBackground[] = { 0.118, 0.153, 0.208, 1 };
            colorBackground2[] = { 0.157, 0.196, 0.247, 1 };};};};
