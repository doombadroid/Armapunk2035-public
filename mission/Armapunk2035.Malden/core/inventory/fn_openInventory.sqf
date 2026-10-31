#include "..\..\macro.h"
if (scriptAvailable(2)) exitWith {["Wait a bit before attempting to open the inventory again."] spawn AP_fnc_handleMessage};
if !(isNull(findDisplay 4500)) exitWith {};
if !(isNull(findDisplay 3000)) exitWith {};
disableSerialization;
params[["_vehicle", objNull, [objNull]], ["_isadmin", false, [false]]];
if (isNull _vehicle || !(_vehicle isKindOf "Car" || _vehicle isKindOf "Air" || _vehicle isKindOf "Ship" || _vehicle isKindOf "Tank" || (typeOf _vehicle) in AP_houseTypes || _vehicle getVariable["AP_supplyPlane", false] || typeOf _vehicle in ["Land_TentA_F", "Land_TentDome_F", "C_IDAP_CargoNet_01_supplies_F", "B_CargoNet_01_ammo_F", "Box_FIA_Ammo_F", "VirtualReammoBox_F", "VirtualReammoBox_small_F", "I_E_CargoNet_01_ammo_F", "I_E_CargoNet_01_ammo_F"])) exitWith {};   // owner 2026-07-23: + Tank (blood-shop Nyx trunk)
// LooneyBin (owner 2026-06-16): defense-in-depth STORAGE ACCESS GUARD for houses/sheds. Blocks opening a
// house/shed you have no rights to -- the tent+cursorObject exploit AND any other malformed caller -- while
// FULLY PRESERVING shared access by mirroring the game's own model. ALLOWS: admin, the OWNER (AP_homeOwner),
// KEYHOLDERS / shared keys (AP_fnc_keyHolderStatus "accessInv" = rank 1 or 2), and GANGMATES of a gang
// house/shed (AP_house_gang == your gang id, AP_gang_data select 0). Unowned map/industrial sheds carry
// none of these (homeOwner ""/NoPidVar, house_gang -1, no keys) -> blocked. Scoped to House_F only so
// vehicles/tents/crates are untouched.
// LooneyBin (owner 2026-07-04): DISTANCE guard for house/shed storage. cursorObject can resolve a House_F
// from far when aiming with binoculars, so a scroll/keybind path could open your storage from across the map.
// The house menu's own <10m gate doesn't cover every entry point -- guard the chokepoint here. Size-aware so
// the far door of a big shed/house still counts (sizeOf), but 30m+ binocular range is blocked. Admins exempt.
if (((_vehicle isKindOf "House_F") || {(typeOf _vehicle) in AP_houseTypes}) && !_isadmin && {!((call AP_adminLevel) >= 2)} && {(player distance _vehicle) > ((if (214 in AP_side_talents) then {25} else {10}) + (0.5 * sizeOf (typeOf _vehicle)))}) exitWith {   // HOMESTEADER Open House: 25m reach
    ["You are too far from the house to access its storage.", "basic"] spawn AP_fnc_handleMessage;
    closeDialog 0;};
if (((_vehicle isKindOf "House_F") || {(typeOf _vehicle) in AP_houseTypes}) && !_isadmin && {!((call AP_adminLevel) >= 2)}) then {
    private _uid = getPlayerUID player;
    private _owner = _vehicle getVariable ["AP_homeOwner", ""];
    private _hGang = _vehicle getVariable ["AP_house_gang", -1];
    private _myGang = AP_gang_data param [0, -1];
    private _isOwner = (_owner isEqualType "") && {_owner != ""} && {_owner != "NoPidVar"} && {_uid isEqualTo _owner};
    private _isKey  = ([_vehicle, _uid, "accessInv"] call AP_fnc_keyHolderStatus) isEqualTo true;
    private _isGang = (_hGang isEqualType 0) && {_hGang > 0} && {_myGang isEqualType 0} && {_hGang isEqualTo _myGang};
    if !(_isOwner || _isKey || _isGang) exitWith {["You do not have access to this storage.", "basic"] spawn AP_fnc_handleMessage;
        closeDialog 0;};};
if (_vehicle isKindOf "House_F" && !(isNull objectParent player)) exitWith {
    ["You can not access your house inventory from within a vehicle...", "basic"] spawn AP_fnc_handleMessage;
    closeDialog 0};
if (_vehicle getVariable["AP_seizing", false]) exitWith {["This vehicle is being seized.", "basic"] spawn AP_fnc_handleMessage;
    closeDialog 0};
// owner 2026-06-27 (DATA LOSS -- Chris Blanco, 50 Indica Buds vanished): SERIALIZE-LOCK FIX. The house HYDRATE just
// below (APS_fnc_initHouseInventory, :50) BUMPS the server-side AP_invGen on every open. It ran BEFORE the
// AP_trunkLock open-guard (still at :~80 below), so a rapid re-open during a prior close's 1.25s settle was
// ultimately refused there -- but the gen had ALREADY been advanced by the hydrate. That made the settling close
// look STALE, so APS_fnc_updateHouseTrunk SKIPPED it (the #542 guard): the just-deposited items were never persisted
// AND the re-hydrate re-read the pre-deposit DB row = silent deposit loss. FIX: enforce the lock HERE, before the
// hydrate -- a locked re-open bails WITHOUT bumping the gen, so the settling close persists normally and the next
// open (after the ~2s settle, by which point updateHouseTrunk has already written) hydrates the fresh row.
if (_vehicle isKindOf "House_F" && {_vehicle getVariable ["AP_trunkLock", false]}) exitWith {
    ["This storage is being saved, try again in a moment.", "basic"] spawn AP_fnc_handleMessage;
    AP_action_in_use = false;};
// owner 2026-06-24 (LIVE house-storage OUTAGE -- houses opened EMPTY after the first access, and a close-while-empty
// WIPED the DB row): option-B storage is SERVER-LOCAL at rest and DEHYDRATED to [[],0] (broadcast) on every close, so
// after the first open+close the client's AP_vinv/pinv is [[],0] -- NOT nil. The old `isNil` hydrate trigger therefore
// NEVER re-fired: every subsequent open showed empty, and the close then saved that [[],0] back over real stored gear.
// FIX: ALWAYS re-hydrate on a house open. Clear our LOCAL copy to nil first so the wait can detect the server's fresh
// GATED-hydrate broadcast (vs. the stale [[],0]); if it never lands (denied / timeout) the vars stay nil and the guard
// at :120 exits BEFORE the dialog opens -> "Could not load... try again" instead of a false-empty house + wipe-on-close.
if (_vehicle isKindOf "House_F") then {
    _vehicle setVariable ["AP_vinv", nil];   // LOCAL clear -> waitUntil-non-nil detects the hydrate broadcast
    _vehicle setVariable ["AP_pinv", nil];
    private _exitTime = time + 5; [[_vehicle, _vehicle getVariable["AP_houseID", -1]], "APS_fnc_initHouseInventory", 2] call AP_fnc_MP;
    waitUntil {uiSleep 0.1;
        time > _exitTime || (!isNil {_vehicle getVariable "AP_vinv"} && !isNil {_vehicle getVariable "AP_pinv"})};};
if (_vehicle isKindOf "House_F" && {(_vehicle getVariable["AP_house_tax", [false]]) select 0}) exitWith {
    ["Housing"] call AP_fnc_deckOpenApp;};
private _activeTrunk = _vehicle getVariable["AP_activeTrunk", objNull];
if ((_activeTrunk isNotEqualTo objNull) && (_activeTrunk isNotEqualTo player)) exitWith {
    ["This vehicle's trunk is in use, only one person can use it at a time.", "basic"] spawn AP_fnc_handleMessage;
    AP_action_in_use = false;};
// owner 2026-06-18 (CLANKR dupe): refuse to OPEN while the storage is locked for serialization. The store/impound/
// gang-store paths raise AP_trunkLock then settle ~1.25s before snapshotting AP_vinv; this blocks a re-open
// during that window so the player can't inject a fresh take mid-settle. (The in-trunk monitor below already
// force-CLOSES on this flag; this is the matching open-side guard.)
if (_vehicle getVariable["AP_trunkLock", false]) exitWith {
    ["This storage is being saved, try again in a moment.", "basic"] spawn AP_fnc_handleMessage;
    AP_action_in_use = false;};
private _exit = false;
if (!(_vehicle in AP_vehicles) && _isadmin && ((call AP_adminLevel) >= 3) && !(_vehicle getVariable["AP_owner", objNull] isEqualTo player)) then {
    private _action = [format["Are you sure you want to force yourself into the inventory? This feature is intended for compensation purposes. Misuse of this feature will result in administrative action."], "Confirmation", "Yes", "No"] call BIS_fnc_guiMessage;
    waitUntil {!isNil "_action"};
    if (_action) then {AP_adminForce = true;} else {_exit = true;
        AP_action_in_use = false;
        AP_adminForce = false;
        _vehicle setVariable["AP_activeTrunk", nil, true];};};
if (_exit) exitWith {};
if (AP_inEvent) exitWith {["You cannot access inventories during an admin event", "basic"] spawn AP_fnc_handleMessage;};
AP_didServerRespond = false;
private _maxDelayTime = time + 5; [[player], "APS_fnc_lagCheck", false, false] spawn AP_fnc_MP;
waitUntil {time > _maxDelayTime || AP_didServerRespond};
if (time > _maxDelayTime) exitWith {["Inventory opening failed... Try again.", "basic"] spawn AP_fnc_handleMessage;
    AP_adminForce = false;};
if (((_vehicle getVariable["AP_rebelAirDrop", false] || _vehicle getVariable["AP_supplyPlane", false] || _vehicle getVariable["AP_ufoLoot", false] || _vehicle getVariable["AP_santaLoot", false]) && ((player distance _vehicle) > 6))) exitWith {
    ["You're too far away!", "basic"] spawn AP_fnc_handleMessage;};
if ((_vehicle getVariable["AP_rebelAirDrop", false]) && (AP_airDrop_last > serverTime - 600)) exitWith {
    [format["The crate is still locked for another %1 minutes. Check back frequently!", ceil(((AP_airDrop_last + 600) - serverTime) / 60)], "basic"] spawn AP_fnc_handleMessage;
};
if ((_vehicle getVariable["AP_ufoLoot", false]) && ((SRV_ufoCrash select 2) > serverTime - 600)) exitWith {
    [format["This radiated loot is unstable right now. Try in another %1 minutes. Check back frequently!", ceil((((SRV_ufoCrash select 2) + 600) - serverTime) / 60)], "basic"] spawn AP_fnc_handleMessage;
};
if ((_vehicle getVariable["AP_santaLoot", false]) && {(SRV_winterEvent select 1) > serverTime - 600}) exitWith {
    [format["The crate is still locked for another %1 minutes. Check back frequently!", ceil((((SRV_winterEvent select 1) + 600) - serverTime) / 60)], "basic"] spawn AP_fnc_handleMessage;
};
if ((typeOf _vehicle isEqualTo "VirtualReammoBox_F") && (SRV_loonyBinData param[4, false])) exitWith {
    ["The Patient's Tomb is still locked! You must first unlock the door!", "basic"] spawn AP_fnc_handleMessage;};
if (_vehicle isKindOf "House_F" && (isNil {_vehicle getVariable "AP_vinv"} || isNil {_vehicle getVariable "AP_pinv"})) exitWith {
    closeDialog 0;
    ["Could not load house inventory. Please try again.", "basic"] spawn AP_fnc_handleMessage};
_vehicle setVariable["AP_activeTrunk", player, true];
AP_trunk_vehicle = _vehicle;
// DECK ROUTE (UI overhaul 2026-08-26; houses joined 2026-08-27, needstest):
// vehicle AND house trunks open as the deck TRUNK app. Still native: admin
// force-opens (compensation should not run through a phone) and COPS on
// houses (the Seize enforcement mode). The deck monitor below mirrors the
// native watchdog kicks by pushing the app dead; the close-persist
// choreography is AP_fnc_trunkCloseSettle -- the SAME copy the dialog runs,
// with the Jeff Stall settle and the #542 gen guard, waiting on the deck
// session instead of dialog 4500.
private _isHouse = (_vehicle isKindOf "House_F") || {(typeOf _vehicle) in AP_houseTypes};
if ((missionNamespace getVariable ["AP_deckApps", true]) && {!_isadmin}
    && {!(_isHouse && {AP_effSide isEqualTo west})}) exitWith {
    private _getInv = { private _array = []; private _val = 0;
        { _val = missionNamespace getVariable [format ["AP_inv_%1", _x], 0];
          if (_val > 0) then { _array pushBack [_x, _val]; }; } forEach ([2] call AP_fnc_virtItemCfg);
        _array };
    if (_isHouse) then {
        [["-HOUSEINV-", player, (profileName), format["opened house storage via deck. (ID: %1 | Owner: %2 | Position: %7), House Virtual Inventory: %3, House Physical Inventory: %4, Player Virtual Inventory: %5, Player Physical Inventory: %6", _vehicle getVariable["AP_houseID", -1], _vehicle getVariable["AP_homeOwner", "NoPidVar"], _vehicle getVariable["AP_vinv", [[], 0]], _vehicle getVariable["AP_pinv", [[], 0]], [] call _getInv, getUnitLoadout player, getPosATL _vehicle]], "APS_fnc_logIt", 2] spawn AP_fnc_MP;
    } else {
        [["-VEHINV-", player, (profileName), format["opened vehicle trunk via deck. (Vehicle: %1 | Owner: %2 | Position: %5) Virtual Inventory: %3, Player Virtual Inventory: %4", typeOf _vehicle, _vehicle getVariable["AP_dbInfo", "NoVehData"], _vehicle getVariable["AP_vinv", [[], 0]], [] call _getInv, getPosATL player]], "APS_fnc_logIt", 2] spawn AP_fnc_MP;
        [_vehicle, 900] call AP_fnc_setVehicleIdle;
    };
    AP_is_virtual = true;
    ["Trunk", _vehicle] call AP_fnc_deckOpenApp;
    // ONE settle per session, spawned up front: it waits for the deck session
    // to end, then runs the persist path (gear save, moved-item republish,
    // close logs, and for houses the lock+settle+gen-guarded updateHouseTrunk).
    [_vehicle, true] spawn AP_fnc_trunkCloseSettle;
    [_vehicle] spawn {
        params ["_vehicle"];
        private _kick = {
            params ["_why"];
            AP_trunkDeckOpen = false;
            private _c = uiNamespace getVariable ["WEBUI_ctrl", controlNull];
            if (!isNull _c) then {
                [_c, "trunk", createHashMapFromArray [["gone", true], ["why", _why]]] call webui_fnc_push; };
        };
        AP_trunkDeckOpen = true;
        waitUntil {
            uiSleep 0.25;
            if (isNull _vehicle) exitWith { ["vehicle gone"] call _kick; true };
            if ((_vehicle getVariable ["AP_activeTrunk", objNull]) isNotEqualTo player) exitWith { ["trunk taken over"] call _kick; true };
            if (_vehicle getVariable ["AP_trunkLock", false]) exitWith {
                _vehicle setVariable ["AP_activeTrunk", nil, true];
                ["inventory is being saved"] call _kick; true };
            if (player getVariable ["AP_restrained", false] || {player getVariable ["AP_downed", false]}) exitWith {
                _vehicle setVariable ["AP_activeTrunk", nil, true];
                ["you are restrained"] call _kick; true };
            // player closed the phone or left the app: release the trunk like the
            // native dialog's unload would
            if (isNull (findDisplay 937500) || {!(missionNamespace getVariable ["AP_trunkDeckOpen", false])}) exitWith {
                if ((_vehicle getVariable ["AP_activeTrunk", objNull]) isEqualTo player) then {
                    _vehicle setVariable ["AP_activeTrunk", nil, true];
                };
                true };
            false
        };
        AP_action_in_use = false;
    };
};
while {dialog}
do {closeDialog 0};
["TrunkMenu"] call AP_fnc_createDialog;
((findDisplay 4500) displayCtrl 4523) ctrlShow false;   // "Store All -> Vehicle": hidden by default, shown for houses (civ view) below
if !(_vehicle isKindOf "House_F") then {[_vehicle, 900] call AP_fnc_setVehicleIdle;};
[_vehicle] spawn {private _vehicle = (_this select 0);
    while {!(isNull(findDisplay 4500))}
    do {uiSleep 0.25;
        if (isNull _vehicle) exitWith {while {dialog}
            do {closeDialog 0;};};
        if ((_vehicle getVariable["AP_activeTrunk", objNull] isNotEqualTo player) && (_vehicle getVariable["AP_activeTrunk", objNull] isNotEqualTo objNull)) exitWith {
            ["Someone else has somehow opened the trunk, only one player may use the trunk at a time.", "basic"] spawn AP_fnc_handleMessage;
            while {dialog}
            do {closeDialog 0;}; AP_adminForce = false;
            AP_action_in_use = false;};
        if (_vehicle getVariable["AP_activeTrunk", objNull] isEqualTo objNull) exitWith {while {dialog}
            do {closeDialog 0;}; AP_adminForce = false;
            AP_action_in_use = false;};
        if (_vehicle getVariable["AP_trunkLock", false]) exitWith {while {dialog}
            do {closeDialog 0;}; _vehicle setVariable["AP_activeTrunk", nil, true];
            ["Inventory is being saved, you cannot access it.", "basic"] spawn AP_fnc_handleMessage;
            AP_adminForce = false;
            AP_action_in_use = false;};
        if (player getVariable["AP_restrained", false]) exitWith {while {dialog}
            do {closeDialog 0;}; _vehicle setVariable["AP_activeTrunk", nil, true];
            AP_adminForce = false;
            AP_action_in_use = false;};
        if (player getVariable["AP_downed", false]) exitWith {while {dialog}
            do {closeDialog 0;}; _vehicle setVariable["AP_activeTrunk", nil, true];
            AP_adminForce = false;
            AP_action_in_use = false;};
        if !(isNull(findDisplay 49)) exitWith {closeDialog 0;
            AP_adminForce = false;
            AP_action_in_use = false;};};};
AP_is_virtual = true;
((findDisplay 4500) displayCtrl 4518) ctrlSetText "Switch to Physical Inventory";
private _vehData = [0, 0];
private _get_inv = {private _array = [];
    private _val = 0; {_val = missionNamespace getVariable [format["AP_inv_%1", _x], 0];
        if ((_val) > 0) then {_array pushBack[_x, _val];};}
    forEach([2] call AP_fnc_virtItemCfg);
    _array;};
if (_vehicle isKindOf "House_F") then {[
        ["-HOUSEINV-", player, (profileName), format["opened house storage. (ID: %1 | Owner: %2 | Position: %7), House Virtual Inventory: %3, House Physical Inventory: %4, Player Virtual Inventory: %5, Player Physical Inventory: %6", _vehicle getVariable["AP_houseID", -1], _vehicle getVariable["AP_homeOwner", "NoPidVar"], _vehicle getVariable["AP_vinv", [
            [], 0]], _vehicle getVariable["AP_pinv", [
            [], 0]], [] call _get_inv, getUnitLoadout player, getPosATL _vehicle]], "APS_fnc_logIt", 2] spawn AP_fnc_MP;} else {[
        ["-VEHINV-", player, (profileName), format["opened vehicle trunk. (Vehicle: %1 | Owner: %2 | Position: %5) Virtual Inventory: %3, Player Virtual Inventory: %4", typeOf _vehicle, _vehicle getVariable["AP_dbInfo", "NoVehData"], _vehicle getVariable["AP_vinv", [
            [], 0]], [] call _get_inv, getPosATL player]], "APS_fnc_logIt", 2] spawn AP_fnc_MP;};
if (AP_adminForce) then {[
        ["-ADMINACTION-", player, (profileName), format["force opened inventory of %1.", typeOf _vehicle]], "APS_fnc_logIt", 2] spawn AP_fnc_MP;
};
if (_vehicle isKindOf "House_F") then {if (AP_effSide isEqualTo west && !(AP_adminForce)) then {
        ((findDisplay 4500) displayCtrl 4507) ctrlSetText "Seize";
        ((findDisplay 4500) displayCtrl 4507) ctrlEnable true;
        ((findDisplay 4500) displayCtrl 4508) ctrlEnable false;
        ((findDisplay 4500) displayCtrl 4505) ctrlEnable false;
        ((findDisplay 4500) displayCtrl 4506) ctrlEnable false;
        ((findDisplay 4500) displayCtrl 4519) ctrlEnable false;
        ((findDisplay 4500) displayCtrl 4520) ctrlEnable false;
        ((findDisplay 4500) displayCtrl 4521) ctrlEnable false;
        ((findDisplay 4500) displayCtrl 4522) ctrlEnable false;} else {((findDisplay 4500) displayCtrl 4507) ctrlSetText "Take";
        ((findDisplay 4500) displayCtrl 4507) ctrlEnable true;
        ((findDisplay 4500) displayCtrl 4508) ctrlEnable true;
        ((findDisplay 4500) displayCtrl 4519) ctrlEnable true;
        ((findDisplay 4500) displayCtrl 4520) ctrlEnable true;
        ((findDisplay 4500) displayCtrl 4521) ctrlEnable true;
        ((findDisplay 4500) displayCtrl 4522) ctrlEnable false;
        ((findDisplay 4500) displayCtrl 4523) ctrlShow true;    // owner/keyholder/gang house view -> allow bulk store-to-vehicle
        ((findDisplay 4500) displayCtrl 4523) ctrlEnable true;};
    ctrlSetText[4501, format[("House Storage") + " - %1", getText(configFile >> "CfgVehicles" >> (typeOf _vehicle) >> "displayName")]];
    if (AP_is_virtual) then {_vehData = [(_vehicle getVariable["AP_vcap", 100]), (_vehicle getVariable["AP_vinv", [[], 0]]) select 1];
    } else {_vehData = [(_vehicle getVariable["AP_phys_cap", 100]), (_vehicle getVariable["AP_pinv", [[], 0]]) select 1];};
    ctrlSetText[4504, format["Weight: %1/%2", _vehdata select 1, _vehdata select 0]];} else {ctrlShow[4518, false];
    ctrlSetText[4501, format[("Vehicle Trunk") + " - %1", getText(configFile >> "CfgVehicles" >> (typeOf _vehicle) >> "displayName")]];
    private _weight = [_vehicle] call AP_fnc_vehicleWeight;
    _vehData = [_weight select 1, _weight select 0];
    ctrlSetText[4504, format["Weight: %1/%2", _vehData select 0, _vehData select 1]];
    // owner 2026-07-06: REVERSE bulk-store -- for a vehicle YOU own/key, show "Store Item -> House" (deposits the
    // highlighted item into the nearest house you can access, within 25m). Dispatch handled in fn_houseToVehicleStore.
    if (((_vehicle getVariable ["AP_vehOwners", []]) findIf { (format ["%1", _x param [0, ""]]) isEqualTo (getPlayerUID player) }) > -1) then {
        ((findDisplay 4500) displayCtrl 4523) ctrlShow true;
        ((findDisplay 4500) displayCtrl 4523) ctrlEnable true;
        ((findDisplay 4500) displayCtrl 4523) ctrlSetText "Store Item -> House ";};};
if !(AP_adminForce) then {[_vehicle, AP_is_virtual] call AP_fnc_refreshInventory;} else {
    [_vehicle, true] call AP_fnc_refreshAdminInventory;};
if ((currentWeapon player == "Binocular" || currentWeapon player == "Rangefinder") && (vehicle player) isEqualTo player) then {
    player action["SwitchWeapon", player, player, 100];
    uiSleep 1;
    player switchCamera cameraView;
    player playActionNow "Gear";} else {player playActionNow "Gear";};
// The close-settle choreography lives in AP_fnc_trunkCloseSettle now, so the
// deck trunk sessions run the SAME copy of the dupe-critical persist path.
[_vehicle, false] spawn AP_fnc_trunkCloseSettle;
