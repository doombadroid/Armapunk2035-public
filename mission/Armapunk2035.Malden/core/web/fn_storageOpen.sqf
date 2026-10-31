#include "..\..\macro.h"
/*
    fn_storageOpen.sqf -- STORAGE (dual manifest) entry point, web dialog
    AP_web_storage (938000). A parallel entry to fn_openInventory / TrunkMenu
    (idd 4500) for the containers this screen supports: houses/sheds,
    ordinary vehicles (their trunk) and the two generic tents.

    fn_openInventory and TrunkMenu are UNTOUCHED. They still own event crates
    (rebel air drop / UFO wreck / Santa crate / "Patient's Tomb" reammo box),
    quest loot and the cop seize flow -- this opener
    explicitly REFUSES those container kinds and points the player back at
    the native menu rather than reimplement their one-off cooldown timers.

    Guard order mirrors fn_openInventory.sqf on purpose: AP_activeTrunk is
    reserved BEFORE the house hydrate, not after, per the owner 2026-06-27
    serialize-lock note in that file (a locked re-open must not re-bump the
    hydrate generation). AP_trunk_vehicle / AP_is_virtual are the SAME globals
    the native dialog uses -- the two dialogs can never be open at once
    (createDialog is exclusive) -- kept for that reason and so anything that
    happens to read them mid-session (logging helpers etc.) still sees sane
    data.

    NOTHING NEW DECIDES WHAT IS IN A CONTAINER, OR MOVES AN ITEM. Every
    read/write fn_storageBridge.sqf performs routes through the same
    primitives fn_takeInventory / fn_storeInventory / fn_houseToVehicleStore
    / fn_vehicleToHouseStore already use -- AP_fnc_handleInv,
    AP_fnc_calWeightDiff, AP_fnc_index, AP_fnc_virtItemCfg -- and the same
    house hydrate/persist chokepoints, APS_fnc_initHouseInventory /
    APS_fnc_updateHouseTrunk. fn_storageBridge.sqf's header explains exactly
    why fn_takeInventory/fn_storeInventory themselves could not be called
    directly: they read the native TrunkMenu listbox controls (idc 4502-4506)
    as their ONLY input, not explicit params, and createDialog cannot hold
    TrunkMenu open invisibly behind this dialog to feed them.
*/
params [["_target", objNull, [objNull]]];
disableSerialization;

private _isHouse = (_target isKindOf "House_F") || {(typeOf _target) in AP_houseTypes};
private _isVeh   = (_target isKindOf "Car") || (_target isKindOf "Air") || (_target isKindOf "Ship") || (_target isKindOf "Tank");
private _isTent  = (typeOf _target) in ["Land_TentA_F", "Land_TentDome_F"];
// DELEGATE, never dead-end. This is the primary storage entry now (2026-08-18), so anything this
// screen does not model has to reach the native dialog on its own -- telling the player to "use the
// trunk menu" when this IS the trunk menu key is a dead end, not a refusal. Crates, ammo boxes and
// every other container fn_openInventory handles go straight through, unchanged.
if (isNull _target || {!(_isHouse || _isVeh || _isTent)}) exitWith {
    [_target, false] spawn AP_fnc_openInventory;
};

// event / quest / take-only crates keep their existing timers on the native dialog -- refuse rather than
// reimplement fn_openInventory's rebel-airdrop / UFO / Santa / Patient's Tomb one-off cooldown windows.
if (_target getVariable ["AP_supplyPlane", false]
    || {_target getVariable ["AP_rebelAirDrop", false]}
    || {_target getVariable ["AP_ufoLoot", false]}
    || {_target getVariable ["AP_santaLoot", false]}
    || {_target getVariable ["AP_questloot", false]}) exitWith {
    [_target, false] spawn AP_fnc_openInventory;
};

if (scriptAvailable(2)) exitWith { ["Wait a bit before attempting to open the inventory again.", "basic"] spawn AP_fnc_handleMessage; };
if !(isNull (findDisplay 4500)) exitWith {};
if !(isNull (findDisplay 938000)) exitWith {};
if (_isHouse && !(isNull objectParent player)) exitWith {
    ["You can not access your house inventory from within a vehicle...", "basic"] spawn AP_fnc_handleMessage;
};
if (_target getVariable ["AP_seizing", false]) exitWith {
    ["This vehicle is being seized.", "basic"] spawn AP_fnc_handleMessage;
};

// house access model -- byte-identical to fn_openInventory.sqf: owner / keyholder(accessInv) / gangmate of a
// gang house; admin level 2+ bypasses both this and the distance check below. Scoped to houses only.
private _isAdminView = (call AP_adminLevel) >= 2;
if (_isHouse && !_isAdminView
    && {(player distance _target) > ((if (214 in AP_side_talents) then {25} else {10}) + (0.5 * sizeOf (typeOf _target)))}) exitWith {
    ["You are too far from the house to access its storage.", "basic"] spawn AP_fnc_handleMessage;
};
private _houseAccessOK = true;
if (_isHouse && !_isAdminView) then {
    private _uid = getPlayerUID player;
    private _owner = _target getVariable ["AP_homeOwner", ""];
    private _hGang = _target getVariable ["AP_house_gang", -1];
    private _myGang = AP_gang_data param [0, -1];
    private _isOwner = (_owner isEqualType "") && {_owner != ""} && {_owner != "NoPidVar"} && {_uid isEqualTo _owner};
    private _isKey  = ([_target, _uid, "accessInv"] call AP_fnc_keyHolderStatus) isEqualTo true;
    private _isGang = (_hGang isEqualType 0) && {_hGang > 0} && {_myGang isEqualType 0} && {_hGang isEqualTo _myGang};
    _houseAccessOK = _isOwner || _isKey || _isGang;
};
if (_isHouse && !_houseAccessOK) exitWith {
    ["You do not have access to this storage.", "basic"] spawn AP_fnc_handleMessage;
};
if (_isHouse && {(_target getVariable ["AP_house_tax", [false]]) select 0}) exitWith { ["Housing"] call AP_fnc_deckOpenApp; };

if (_target getVariable ["AP_trunkLock", false]) exitWith {
    ["This storage is being saved, try again in a moment.", "basic"] spawn AP_fnc_handleMessage;
};
private _activeTrunk = _target getVariable ["AP_activeTrunk", objNull];
if ((_activeTrunk isNotEqualTo objNull) && (_activeTrunk isNotEqualTo player)) exitWith {
    ["This storage is in use, only one person can use it at a time.", "basic"] spawn AP_fnc_handleMessage;
};

AP_didServerRespond = false;
private _maxDelayTime = time + 5;
[[player], "APS_fnc_lagCheck", false, false] spawn AP_fnc_MP;
waitUntil { time > _maxDelayTime || AP_didServerRespond };
if (time > _maxDelayTime) exitWith { ["Storage opening failed... Try again.", "basic"] spawn AP_fnc_handleMessage; };

// reserve BEFORE hydrate -- see header note (2026-06-27 fix mirrored from fn_openInventory.sqf)
_target setVariable ["AP_activeTrunk", player, true];

if (_isHouse) then {
    _target setVariable ["AP_vinv", nil];
    _target setVariable ["AP_pinv", nil];
    private _exitTime = time + 5;
    [[_target, _target getVariable ["AP_houseID", -1]], "APS_fnc_initHouseInventory", 2] call AP_fnc_MP;
    waitUntil { uiSleep 0.1; time > _exitTime || (!isNil { _target getVariable "AP_vinv" } && !isNil { _target getVariable "AP_pinv" }) };
};
if (_isHouse && {isNil { _target getVariable "AP_vinv" } || {isNil { _target getVariable "AP_pinv" }}}) exitWith {
    _target setVariable ["AP_activeTrunk", nil, true];
    ["Could not load house inventory. Please try again.", "basic"] spawn AP_fnc_handleMessage;
};

AP_trunk_vehicle = _target;
AP_is_virtual = true;
if (_isVeh) then { [_target, 900] call AP_fnc_setVehicleIdle; };   // matches fn_openInventory: vehicles only, house/tent skip

private _logTag = if (_isHouse) then { "-HOUSEINV-" } else { "-VEHINV-" };
[[_logTag, player, profileName, format ["opened storage via web screen (Target: %1 | Position: %2)", typeOf _target, getPosATL _target]], "APS_fnc_logIt", 2] spawn AP_fnc_MP;

createDialog "AP_web_storage";
