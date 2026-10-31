private "_vehicle";

if !(isNull objectParent player) then {_vehicle = objectParent player;} else {
    // owner 2026-06-19 (#386): widened 50 -> 100m for far-parked gang-fort helis. owner 2026-06-30 (#566):
    // tightened back to 20m -- 100m let players store from way off the flag. owner 2026-07-03: 20 -> 40m --
    // a big airframe (Blackfish) can't taxi its CENTER within 20m of the air NPC, so it was un-storable; 40m
    // fits it while staying well under the abusive 100m. The findIf below still only matches YOUR own / your
    // gang's vehicles, so you can't store someone else's.
    private _nearVehicles = nearestObjects[getPos(_this select 0), ["Car", "Tank", "Air", "Ship"], 40];
    _vehicle = _nearVehicles param[_nearVehicles findIf {((((_x getVariable["AP_vehOwners", [[]
        ]] select 0) select 0) isEqualTo getPlayerUID player) || (((_x getVariable["AP_dbInfo", ["", 0, false]]) param[0, ""]) isEqualTo(str(AP_gang_data param[0, -1])))) && alive _x && !(_x getVariable["AP_mobileHeadQuartersTruckLocked", false])
    }, objNull]};
if (isNil "_vehicle" || {isNull _vehicle}) exitWith {["There isn't a vehicle near the NPC.", "basic"] spawn AP_fnc_handleMessage};
// find objects
_objects = attachedObjects _vehicle;
// owner 2026-06-13: duty vehicles (MaxTac/SRT/Fire) are temp -- no DB row, so APS_fnc_vehicleStore deletes the
// object with nothing to mark "stored" -> the vehicle is LOST. Block storing them.
if ((_vehicle getVariable["AP_vehIsMaxTac", false]) || (_vehicle getVariable["AP_isSRT", false]) || (_vehicle getVariable["AP_vehIsFirefighter", false])) exitWith {
    ["Duty vehicles (MaxTac / SRT / Fire) can't be stored in the garage.", "basic"] spawn AP_fnc_handleMessage;};
private _aggressive = allPlayers param[allPlayers findIf {_x getVariable["AP_aggressive", -300] > (time - 60)}, objNull];
if (!isNull _aggressive) exitWith {
    ["You are in (or have recently been in) combat and the garage clerk cowers in fright! Wait a few minutes and try again!", "basic"] spawn AP_fnc_handleMessage;
};
[getItemCargo _vehicle, getWeaponCargo _vehicle, getMagazineCargo _vehicle, getBackpackCargo _vehicle] params["_vehItem", "_vehWeapon", "_vehAmmo", "_vehBackpack"];
private _countWeapons1 = count(_vehWeapon select 0);
private _countAmmo1 = count(_vehAmmo select 0);
private _vehicleDisplayName = [configFile >> "CfgVehicles" >> typeOf _vehicle] call BIS_fnc_displayName;
private _exit = false;
if !((_vehItem select 0) findIf {_x != "Toolkit" && _x != "FirstAidKit"}
isEqualTo - 1) then {_exit = true};
if (_vehicle getVariable["AP_vinv", [[], 0]] select 1 > 0 || !((_countWeapons1 + _countAmmo1) isEqualTo 0)) then {_exit = true};
if !((_vehBackpack select 0) findIf {_x find "Parachute"
    isEqualTo - 1 && _x != "B_AssaultPack_cbr"}
isEqualTo - 1) then {_exit = true};
// owner 2026-06-21 (vehicle-vanish on store): dbInfo slot 2 is NOT a reliable gang-bool. RESTORED vehicles carry
// objNull there (fn_restoreVehicles:85 nulls a stringified slot 2), so `params [...["_isGang",false,[false]]]`
// logged "Type Object, expected Bool" AND defaulted _isGang=false -> a restored GANG vehicle then took the
// PERSONAL store path (APS_fnc_vehicleStore, pid = dbInfo[0] = the gang id) -> no matching row in `vehicles`
// (gang vehicles live in gang_vehicles) -> the world object was deleted but nothing was stored = vehicle VANISHED
// from both garages. Derive gang-ownership from the OWNER field instead (same test as the L12 near-vehicle gang
// match): it's a gang vehicle when its owner id == the player's current gang id. Type-safe, no params throw.
private _dbI = _vehicle getVariable["AP_dbInfo", []];
private _uid = _dbI param[0, "", [""]];
private _plate = _dbI param[1, 0, [0]];
// owner 2026-06-24 (#532 "can't store a pulled gang vehicle -- doesn't belong to you"): AP_dbInfo[0] is ALREADY
// a string (a UID for personal, str(gangID) for gang -- set by fn_gangGaragePull). The old test wrapped it in a
// SECOND str() -> `str "50011"` yields the 7-char literal """50011""" (quotes included), which never equals
// `str 50011` ("50011", 5 chars) -> _isGang was ALWAYS false for a gang vehicle -> it took the PERSONAL store
// path (APS_fnc_vehicleStore), whose owner check (uid==player) failed with "doesn't belong to you". Compare the
// raw _uid against str(gangID), exactly like the L12 near-vehicle gang match. format-normalize for type safety.
private _isGang = (format ["%1", _uid]) isEqualTo (format ["%1", (AP_gang_data param[0, -1])]);
AP_gang_data params[["_myGangID", -1, [0]], ["_myGangName", "", [""]], ["_myGangRank", -1, [0]]];
private _gangExit = false;
if (_isGang) then {
    private _action = [format["You are about to store %1's %2. Are you sure you want to store this vehicle?", _myGangName, _vehicleDisplayName], format["%1's Gang Vehicle", _myGangName], "Yes", "No"] call BIS_fnc_GUIMessage;
    if !(_action) exitWith {_gangExit = true};};
if (_gangExit) exitWith {};
if (_exit) exitWith {if !(AP_effSide isEqualTo west) then {
        // #332: only ILLEGAL items (drugs/contraband) get stripped on store now (server-authoritative in
        // DB_fnc_updateVehicle); legal cargo is KEPT. So only warn when there's actually contraband to lose.
        private _action = true;
        private _illSet = [];
        private _ill = ["getIllegalItems"] call AP_fnc_virtItemCfg;
        if (_ill isEqualType []) then { _illSet = _ill apply { _x param [0, ""] }; };
        private _trunkItems = (_vehicle getVariable ["AP_vinv", [[], 0]]) param [0, []];
        if ((_trunkItems findIf { _x isEqualType [] && {count _x >= 2} && {(_x param [0, ""]) in _illSet} }) > -1) then {
            _action = ["Illegal items (drugs / contraband) in this vehicle's trunk will be REMOVED when you store it. Store anyway?", "Contraband Will Be Removed", "Yes", "No"] call BIS_fnc_GUIMessage;
        };
        if (_action) then {

            // check if vehicle has objects or not
 {
                // delete those objects
                deleteVehicle _x;} forEach _objects;

            if (_isGang) then {[[_myGangID, _vehicle, player, getPlayerUID player], "APS_fnc_gangGarageStore", 2] spawn AP_fnc_MP;
                ["The server is trying to store the gang vehicle please wait...", "basic"] spawn AP_fnc_handleMessage;} else {[
                    [_vehicle, false, _this select 1, _uid, _plate], "APS_fnc_vehicleStore", 2] spawn AP_fnc_MP;
                ["The server is trying to store the vehicle...", "basic"] spawn AP_fnc_handleMessage;};
            AP_garage_store = true;
            // owner 2026-06-17 (#323/#327): defensive self-heal. AP_garage_store gates the store action and is
            // meant to be cleared by the server when the store completes; if ANY server path forgets (the gang
            // path did -- #323), the action vanishes server-wide "until restart". This watchdog force-clears it
            // after 15s if still set, so a missed clear can never permanently lock storing. Normal stores clear
            // in 1-3s, so this never fires on the happy path.
            [] spawn { uiSleep 15; if (!isNil "AP_garage_store" && {AP_garage_store}) then { AP_garage_store = false; ["The garage store timed out — you can store again.", "basic"] spawn AP_fnc_handleMessage; }; };
        };} else {
        ["You cannot store a police vehicle which contains equipment. Empty the vehicle first!", "basic"] spawn AP_fnc_handleMessage;};};
if (_isGang) then {[[_myGangID, _vehicle, player, getPlayerUID player], "APS_fnc_gangGarageStore", 2] spawn AP_fnc_MP;
    ["The server is trying to store the gang vehicle please wait...", "basic"] spawn AP_fnc_handleMessage;} else {[
        [_vehicle, false, _this select 1, _uid, _plate], "APS_fnc_vehicleStore", 2] spawn AP_fnc_MP;
    ["The server is trying to store the vehicle...", "basic"] spawn AP_fnc_handleMessage;};
AP_garage_store = true;
// owner 2026-06-21 (#327 "can't store anything until restart"): the 15s self-heal watchdog existed only on the
// cop-equipment branch above; this NORMAL store path (gang + personal) set AP_garage_store=true with NO
// watchdog, so a lost server-clear packet (JIP / packet loss / store object deleted mid-round-trip) left the
// flag stuck true -> the store scroll action (gated on !AP_garage_store) vanished server-wide for that player.
// Mirror the watchdog here so a missed clear can never permanently lock storing.
[] spawn { uiSleep 15; if (!isNil "AP_garage_store" && {AP_garage_store}) then { AP_garage_store = false; ["The garage store timed out — you can store again.", "basic"] spawn AP_fnc_handleMessage; }; };