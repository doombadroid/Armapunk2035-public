/*
    web_storage.hpp -- AP_web_storage (938000): the HTML house/vehicle
    storage screen (dual manifest -- container left, ON YOU right).

    Parallel entry to fn_openInventory / TrunkMenu (idd 4500) for the
    containers fn_storageOpen supports (houses/sheds, ordinary vehicle
    trunks, the two generic tents). TrunkMenu is untouched and keeps
    serving event crates, quest loot and the cop seize
    flow -- see fn_storageOpen.sqf's header for why those are out of
    scope here.

    Position is a placeholder; fn_storageBridge.sqf repositions the Page
    control at runtime (40x20 grid, AP_deckScale-scaled, centred -- the
    same "windowed web UI" convention fn_armoryOpen.sqf uses).
*/
class AP_web_storage {
    idd = 938000;
    name = "AP_web_storage";
    movingEnable = false;
    enableSimulation = true;
    onLoad = "[_this select 0] spawn AP_fnc_storageBridge;";
    class controls {
        class Page {
            idc = 938001;
            type = 106;
            style = 0;
            x = -20 * UI_GRID_W + UI_GRID_X; y = -10 * UI_GRID_H + UI_GRID_Y;
            w  =  40 * UI_GRID_W;            h =  20 * UI_GRID_H;
            colorBackground[] = {0,0,0,0};
            colorText[] = {1,1,1,1};
            font = "RobotoCondensed";
            sizeEx = 0.6 * UI_GRID_H;
            url = "ui\html\storage.html";
        };
        #include "..\webui\config\prompt_overlay.hpp"
    };
};
