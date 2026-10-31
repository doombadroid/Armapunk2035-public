/*
    File: fn_suiteStorage.sqf  (AP_fnc_suiteStorage)
    Luxe Suites 2026-08-07 -- suite storage, through the REAL house storage UI.

        [_oid, _floor] spawn AP_fnc_suiteStorage

    v3. Two bugs found by reading the server log rather than guessing:

    1. createVehicleLocal IS BINARY. v2 wrote `createVehicleLocal "Box_FIA_Ammo_F"`,
       and the unary form takes an ARRAY, so the engine threw
       "createvehiclelocal: Type String, expected Array" and killed the script on
       that line. Nothing after it ever ran: no crate, no UI, and the busy flag set
       just above was never cleared -- which is the whole of "suite storage is still
       saving, try again". One typo, both symptoms.

    2. fn_openInventory HIDES THE VIRTUAL/PHYSICAL SWITCH for anything that is not
       a House_F (fn_openInventory.sqf:179, `ctrlShow[4518,false]`). Handing it a
       crate therefore produced a one-tab screen with no way across -- the owner's
       original complaint, which v2 would still have had even without bug 1.
       A retired crate opener hit this first and documented it; so this is now a lean fork
       of the opener in the same style, and the 4518 switch is shown explicitly.

    The take/store/move/drop/swap functions are used UNCHANGED. They operate on
    AP_trunk_vehicle's AP_vinv / AP_pinv and read their caps from AP_vcap /
    AP_phys_cap straight off the object; House_F appears in them only to gate
    item POLICY (gold bars, uranium, the cop seize view), never to find the data.
    So a crate carrying those variables drives the real screen exactly as a house
    does. What is skipped is everything house-SPECIFIC in the full opener: the DB
    hydrate (APS_fnc_initHouseInventory), the close-persist (updateHouseTrunk),
    house tax and cop seize -- suites are their own table with their own authority.

    THE CRATE IS LOCAL to the player's own machine, so nobody else can open it and
    there is no shared-trunk race to lose. It is hidden, simulation-free and rides
    6 m under the player (see the monitor) so it can never be collided with and can
    never trip the openers' 10 m distance guards. Contents are re-read from the DB
    on every open and written back on every change (AP_fnc_suiteStorageSync, from
    take/store/swap/drop) and on close; the DB row stays the truth, and the server
    validates keys, quantities and capacity regardless of what is sent.
*/
params [["_oid", "", [""]], ["_floor", 0, [0]]];
if (_oid isEqualTo "") then { _oid = missionNamespace getVariable ["AP_suiteMenuOid", ""]; };
if (_oid isEqualTo "") exitWith {};
if (!isNull (findDisplay 4500)) exitWith {};
// SELF-EXPIRING GUARD. This holds the moment the last open STARTED, not a bare
// boolean: if this script ever dies between setting it and clearing it -- an
// error, a relog mid-wait, anything -- a boolean would lock the tenant out of
// their own storage permanently, with no way back short of a server restart.
// That is exactly what happened with the createVehicleLocal throw above.
// Anything older than 30 s is a corpse, not a save in progress.
private _busyAt = missionNamespace getVariable ["AP_suiteStoreBusy", -1e9];
if (time - _busyAt < 30) exitWith {
    ["Suite storage is still saving -- try again in a moment.", "basic"] spawn AP_fnc_handleMessage; };

AP_suiteMenuOid = _oid;
AP_suiteStoreBusy = time;
AP_suiteStoreLoaded = nil;

// ---- ask the server for this suite's contents -------------------------------
[["load", _oid, []], "APS_fnc_suiteStorageSRV", 2] spawn AP_fnc_MP;
private _wait = time + 6;
waitUntil { uiSleep 0.1; time > _wait || !isNil "AP_suiteStoreLoaded" };
if (isNil "AP_suiteStoreLoaded") exitWith {
    AP_suiteStoreBusy = -1e9;
    ["Could not load suite storage. Please try again.", "basic"] spawn AP_fnc_handleMessage; };

private _payload = +AP_suiteStoreLoaded;
AP_suiteStoreLoaded = nil;
if ((_payload param [0, ""]) isEqualTo "denied") exitWith {
    AP_suiteStoreBusy = -1e9;
    ["That is not your suite.", "basic"] spawn AP_fnc_handleMessage; };
// The server refuses the session when it cannot READ the suite, rather than
// handing back an empty one. Opening on an unreadable suite is what destroyed a
// tenant's property on 2026-08-07: they saw an empty room and closing it wrote
// that emptiness over the real row. Nothing is lost while this message shows.
if ((_payload param [0, ""]) isEqualTo "error") exitWith {
    AP_suiteStoreBusy = -1e9;
    ["Suite storage could not be read. Nothing has been changed -- your property is safe. Please report this.", "basic"] spawn AP_fnc_handleMessage; };

private _vinv = _payload param [1, [[], 0]];
private _pinv = _payload param [2, [[], 0]];
private _vcap = _payload param [3, 900];
private _pcap = _payload param [4, 3000];

// ---- the container ----------------------------------------------------------
// Box_FIA_Ammo_F because the take/store paths and the trunk dialog are written
// against a container, and this one carries no special-casing anywhere in the
// mission (VirtualReammoBox_F does -- fn_openInventory:100 ties it to the Loony
// Bin tomb's lock state).
// createVehicleLOCAL: the object exists only on this machine, so there is
// nothing for another client to read off it and no trunk race to lose. The
// networked variant plus a broadcast setVariable would reopen the "read another
// player's stash off the object" hole house storage was rebuilt to close.
// BINARY syntax -- `"class" createVehicleLocal position`. The unary form wants
// an array and throws on a string; that throw is what killed v2.
private _crate = "Box_FIA_Ammo_F" createVehicleLocal ((getPosATL player) vectorAdd [0, 0, -6]);
_crate hideObject true;
_crate enableSimulation false;
_crate allowDamage false;
// local object -> LOCAL cargo commands (the *Global variants are for networked
// objects). The crate spawns with the class's default ammo load, which is
// invisible to this screen -- the UI reads AP_vinv/AP_pinv -- but an empty
// container is one less thing to explain if anything ever does read its cargo.
clearItemCargo _crate; clearWeaponCargo _crate;
clearMagazineCargo _crate; clearBackpackCargo _crate;

_crate setVariable ["AP_vinv", _vinv];
_crate setVariable ["AP_pinv", _pinv];
_crate setVariable ["AP_vcap", _vcap];
_crate setVariable ["AP_phys_cap", _pcap];
_crate setVariable ["AP_suiteOid", _oid];
_crate setVariable ["AP_homeOwner", getPlayerUID player];
_crate setVariable ["AP_activeTrunk", player];
AP_trunk_vehicle = _crate;
localNamespace setVariable ["AP_suiteCrate", _crate];   // fn_suiteStorageSync's test; not network-writable

// ---- the screen -------------------------------------------------------------
while { dialog } do { closeDialog 0 };
["TrunkMenu"] call AP_fnc_createDialog;
disableSerialization;
private _d = findDisplay 4500;
if (isNull _d) exitWith {
    deleteVehicle _crate; AP_trunk_vehicle = objNull; localNamespace setVariable ["AP_suiteCrate", objNull];
    AP_suiteStoreBusy = -1e9;
    diag_log format ["[SUITE][STORE] client: TrunkMenu refused to open for %1", _oid];
    ["Suite storage could not open.", "basic"] spawn AP_fnc_handleMessage; };

AP_adminForce = false;
AP_is_virtual = true;
// 4518 IS THE WHOLE POINT. fn_openInventory hides it for non-houses; a suite is
// a home, so it gets both tabs.
(_d displayCtrl 4518) ctrlSetText "Switch to Physical Inventory";
(_d displayCtrl 4518) ctrlShow true;
(_d displayCtrl 4518) ctrlEnable true;
(_d displayCtrl 4507) ctrlSetText "Take";      // take from suite
(_d displayCtrl 4507) ctrlEnable true;
(_d displayCtrl 4508) ctrlEnable true;         // store into suite
(_d displayCtrl 4505) ctrlEnable true;         // quantity boxes
(_d displayCtrl 4506) ctrlEnable true;
(_d displayCtrl 4519) ctrlEnable true;         // move gutter
(_d displayCtrl 4520) ctrlEnable true;
(_d displayCtrl 4521) ctrlEnable true;         // drop from suite (physical tab only)
(_d displayCtrl 4522) ctrlEnable false;        // drop from player -- house view keeps this off
(_d displayCtrl 4509) ctrlShow true;           // swap
(_d displayCtrl 4523) ctrlShow false;          // house<->vehicle bulk: house-only path
ctrlSetText [4501, format ["Suite Storage - Floor %1", _floor]];
ctrlSetText [4504, format ["Weight: %1/%2", _vinv param [1, 0], _vcap]];
[_crate, AP_is_virtual] call AP_fnc_refreshInventory;
player playActionNow "Gear";
diag_log format ["[SUITE][STORE] client: open %1, %2/%3 virtual", _oid, _vinv param [1, 0], _vcap];

// ---- monitor ----------------------------------------------------------------
// The crate RIDES THE PLAYER. fn_takeInventory:21 and fn_storeInventory:52 both
// refuse at >10 m from AP_trunk_vehicle, so a fixed crate would start booting
// the tenant with "You are too far away!" as soon as they crossed their own
// floor. Keeping it under their feet removes the distance term entirely.
// The server drops a session an hour after the open (or its last write), and a write it
// refuses leaves a take in the suite row too -- so no screen outlives 50 minutes.
[_crate] spawn { params ["_crate"]; private _t0 = time;
    while { !(isNull (findDisplay 4500)) } do { uiSleep 0.25;
        if (time - _t0 > 3000) exitWith { while { dialog } do { closeDialog 0 }; };
        if (isNull _crate) exitWith { while { dialog } do { closeDialog 0 }; };
        _crate setPosATL ((getPosATL player) vectorAdd [0, 0, -6]);
        if (player getVariable ["AP_restrained", false]) exitWith { while { dialog } do { closeDialog 0 }; };
        if (player getVariable ["AP_downed", false]) exitWith { while { dialog } do { closeDialog 0 }; };
        if !(isNull (findDisplay 49)) exitWith { closeDialog 0; }; }; };

// ---- write back on close ----------------------------------------------------
waitUntil { uiSleep 0.25; isNull (findDisplay 4500) };
// Detach BEFORE the close is sent: a take/store that still reached the crate after it
// (deck TRUNK, a late handler) would sync into a session the close has ended, be refused,
// and still move the gear.
AP_trunk_vehicle = objNull;
localNamespace setVariable ["AP_suiteCrate", objNull];

private _outV = _crate getVariable ["AP_vinv", [[], 0]];
private _outP = _crate getVariable ["AP_pinv", [[], 0]];
// A vanished crate reads back as the [[],0] defaults, and saving those would wipe the suite.
// Every change was already synced, so skipping the close loses nothing but item order.
if (isNull _crate) then { diag_log format ["[SUITE][STORE] client: close %1, crate gone -- not saving", _oid]; } else {
private _seq = (localNamespace getVariable ["AP_suiteStoreSeq", 0]) + 1;   // see fn_suiteStorageSync
localNamespace setVariable ["AP_suiteStoreSeq", _seq];
[["save", _oid, [_outV, _outP, _seq]], "APS_fnc_suiteStorageSRV", 2] spawn AP_fnc_MP;
diag_log format ["[SUITE][STORE] client: close %1, saving %2 virtual", _oid, _outV param [1, 0]]; };
AP_action_in_use = false;
if (AP_inventoryInteraction) then { [true] call AP_fnc_saveGear; AP_inventoryInteraction = false; };
AP_movedItem = false;
uiSleep 0.5;
deleteVehicle _crate;
AP_suiteStoreBusy = -1e9;
