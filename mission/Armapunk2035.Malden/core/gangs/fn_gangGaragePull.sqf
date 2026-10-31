#include "..\..\macro.h"
if (scriptAvailable(5)) exitWith {["Wait a few seconds before pulling another vehicle.", "basic"] spawn AP_fnc_handleMessage;};
disableSerialization;
// owner 2026-06-23: only gang ranks R1-R3 may pull gang vehicles -- R4 & R5 are blocked. Mirrors the greyed GET
// button (fn_gangGarageLBChange) + the <=3 add-gate in fn_gangGarageAdd. AP_gang_data[2] = this player's gang
// rank (1 = leader/top .. 5 = recruit/lowest); default 5 = blocked if it's somehow missing.
if ((AP_gang_data param [2, 5]) > 3) exitWith {["Only gang ranks R1-R3 can pull gang vehicles.", "basic"] spawn AP_fnc_handleMessage;
    closeDialog 0;};
if ((lbCurSel 10301) isEqualTo - 1) exitWith {
    ["You did not select a vehicle to retrieve from your gang garage!", "basic"] spawn AP_fnc_handleMessage;
    closeDialog 0;};
private _display = findDisplay 10300;
private _vehicleList = _display displayCtrl 10301;
private _vehicleTitle = _display displayCtrl 10302;
private _detailsText = _display displayCtrl 10303;
private _getButton = _display displayCtrl 10304;
private _repairButton = _display displayCtrl 10305;
private _displayTitle = _display displayCtrl 10306;
private _destroyButton = _display displayCtrl 10307;
private _vehicle = parseSimpleArray(lbData[10301, lbCurSel 10301]);
if (isNil "_vehicle") exitWith {
    ["There was an error selecting your vehicle from the garage. Please try again.", "basic"] spawn AP_fnc_handleMessage;
    closeDialog 0;};
_vehicle params["_classname", "_plate", "_color", "", "_mods", "_vehWear", "_customPlate"];
["Attempting to pull vehicle from gang garage...", "basic"] spawn AP_fnc_handleMessage;
_repairButton ctrlEnable false;
_getButton ctrlEnable false;
_destroyButton ctrlEnable false;
private _vehCfgRow = ["getVehicleRowParsed", "", _classname] call AP_fnc_vehicleConfig;
if (_vehCfgRow isEqualTo[]) exitWith {};
private _textureShopFlags = (["specific", _classname, _color] call AP_fnc_vehicleTextures) param[2, [""]];
// 2026-08-13: mirrors the config-category fallback the personal garage got on 2026-06-13 (#162, see
// fn_vehicleGaragePull). This gate reads the stored TEXTURE's shop flags, so it fails for a cop
// vehicle with no cop skin -- which every cop vehicle now is, since the custom police liveries were
// deleted. Without the fallback a gang-stored cop vehicle became unpullable ("undercover role only").
private _copCats = ["cop_car", "cop_air", "cop_ship", "maxtac_car", "srt_car"];
private _isCopVeh = ((_vehCfgRow param[3, []]) findIf { _x in _copCats }) > -1;
if (AP_effSide isEqualTo west && {
    AP_copRole != "scd" && AP_copRole != "all" && (!("cop" in _textureShopFlags) && !("fed" in _textureShopFlags) && !_isCopVeh)}) exitWith {
    ["This vehicle can only be used when you are in the undercover role.", "basic"] spawn AP_fnc_handleMessage};
private _spawnPoint = "";
if (AP_garage_sp isEqualType[]) then {
    // owner 2026-07-31: both naming schemes + fallback + no global mutation -- see fn_vehicleGaragePull.
    private _f = [];
    if (_classname isKindOf "Land") then {_f = AP_garage_sp select { "_g_" in (str _x) || "car_spawn" in (str _x) };};   // owner 2026-08-02: cars never take air pads (ER HQ helipad parking)
    if (_classname isKindOf "Air") then {_f = AP_garage_sp select { "_air_" in (str _x) || "air_spawn" in (str _x) };};
    if (_classname isKindOf "Ship") then {_f = AP_garage_sp select { "_sea_" in (str _x) || "boat_spawn" in (str _x) };};
    if (_f isNotEqualTo []) then { AP_garage_sp = _f; };
    if ((AP_garage_sp param[0, objNull]) isEqualType objNull) then {if !(surfaceIsWater position player) then {
            _spawnPoint = AP_garage_sp param[AP_garage_sp findIf {
                nearestObjects[getPosATL _x, ["Car", "Tank", "Ship"], 5] isEqualTo[] && nearestObjects[getPosATL _x, ["Air"], 14] isEqualTo[] && (player distance2D(getPosATL _x) <= 100)
            }, ""];} else {_spawnPoint = AP_garage_sp param[AP_garage_sp findIf {
                nearestObjects[getPosASL _x, ["Car", "Tank", "Ship"], 5] isEqualTo[] && nearestObjects[getPosASL _x, ["Air"], 14] isEqualTo[] && (player distance2D(getPosASL _x) <= 100)
            }, ""];};} else {_spawnPoint = AP_garage_sp param[AP_garage_sp findIf {
            nearestObjects[getMarkerPos _x, ["Car", "Tank", "Ship"], 5] isEqualTo[] && nearestObjects[getMarkerPos _x, ["Air"], 14] isEqualTo[] && (player distance2D(getMarkerPos _x) <= 100)
        }, ""];};} else {if (AP_garage_sp isKindOf "House_F") then {
        if (nearestObjects[getPosATL AP_garage_sp, ["Car", "Tank", "Air"], 9] isEqualTo[]) then {_spawnPoint = AP_garage_sp};} else {
        if (nearestObjects[getPosATL AP_garage_sp, ["Car", "Tank", "Ship"], 5] isEqualTo[] && nearestObjects[getPosATL AP_garage_sp, ["Air"], 14] isEqualTo[] && (player distance2D(getPosATL AP_garage_sp) <= 100)) then {
            _spawnPoint = AP_garage_sp};};};
if (_spawnPoint isEqualTo "") exitWith {
    ["There is a vehicle currently blocking the spawn point(s).", "basic"] spawn AP_fnc_handleMessage;
    closeDialog 0;};
private _pullFee = _vehCfgRow select 9;
private _exit = false;
private _isProperty = _spawnPoint isKindOf "House_F";
if (!_isProperty && !(_pullFee isEqualTo 0)) then {if !([_pullFee] call AP_fnc_debitCard) exitWith {_exit = true;};};
if (_exit) exitWith {closeDialog 0;};
private _exit = false;
if (_spawnPoint isKindOf "House_F") then {
    if (typeOf _spawnPoint isEqualTo "Land_i_Shed_Ind_F" && _classname isEqualTo "B_Truck_01_box_F") exitWith {_exit = true};
    if (_classname in ["C_Van_01_box_F", "C_Van_01_fuel_F", "C_Van_01_transport_F", "B_Truck_01_box_F", "B_Truck_01_transport_F", "B_Truck_01_fuel_F", "I_Truck_02_covered_F", "I_Truck_02_transport_F", "O_Truck_03_device_F"] && !(typeOf _spawnPoint isEqualTo "Land_i_Shed_Ind_F")) exitWith {
        _exit = true};};
private _flickExit = false;
if (_spawnPoint isEqualType objNull && {AP_effSide isEqualTo civilian && !("VR_" in typeOf _spawnPoint)}) then {
    if (!(_spawnPoint in AP_vehicles) && !(_spawnPoint in AP_gangBuilding)) then {
        if !([cursorObject, getPlayerUID player, "accessLock"] call AP_fnc_keyHolderStatus) then {_flickExit = true};};};
if (_flickExit) exitWith {closeDialog 0;
    ["You must be looking at your building to pull out a vehicle!", "basic"] spawn AP_fnc_handleMessage;};
private _vehName = ([_classname] call AP_fnc_fetchCfgDetails) select 1;
if (_exit) exitWith {[format["%1 is too large for this garage.", _vehName], "basic"] spawn AP_fnc_handleMessage;};
uiSleep(random 2.1);
uiSleep(random 2.2);
uiSleep(random 2.5);
if !(AP_vehicles findIf {(_x getVariable["AP_dbInfo", []] param[1, -1]) isEqualTo _plate}
isEqualTo - 1) exitWith {["This vehicle is already in use.", "basic"] spawn AP_fnc_handleMessage};
closeDialog 0;
// owner 2026-07-30: read the marker's OWN height -- `getMarkerPos _m` returns z = 0, only the
// [_m, true] syntax returns the marker's z. Without it an ELEVATED spawn point (a helipad on a
// structure) resolved to [x, y, 0] and the vehicle was placed at terrain level, inside whatever the
// pad stands on. Same fix as fn_vehicleShopBuy; this logic exists in three copies and fixing one is
// what let the rebel outpost helicopter keep exploding after the first fix.
private _markerPos =
if (_spawnPoint isEqualType objNull) then {getPosATL _spawnPoint} else {getMarkerPos [_spawnPoint, true]};
if (_spawnPoint isKindOf "House_F") then {if (typeOf _spawnPoint isEqualTo "Land_i_Shed_Ind_F") then {
        _markerPos = _spawnPoint modelToWorld[4, 4, -0.5];} else {_markerPos set[2, (getPosATL _spawnPoint select 2) + 0.155541];};} else {
    _markerPos set[2, (_markerPos select 2) + 1.5];};
private _vehicle = createVehicle[_classname, [random 999, random 999, 999], [], 0, "CAN_COLLIDE"];
// owner 2026-06-27: TT AMV-7 Marshall stays ammo-less + non-rearmable on gang garage pull too.
if (typeOf _vehicle isEqualTo "B_APC_Wheeled_01_cannon_F") then {
    _vehicle animate ["HideTurret", 1];   // owner 2026-07-04: hide the 40mm turret entirely (like the Marid's cop_apc), not just ammo-strip
    { _vehicle removeMagazinesTurret [_x select 0, _x select 1] } forEach (magazinesAllTurrets _vehicle);
    _vehicle setVehicleAmmo 0;
    _vehicle addEventHandler ["Reloaded", { (_this select 0) setVehicleAmmo 0 }];};
waitUntil {!isNil "_vehicle" && {!isNull _vehicle}}; [
    [(AP_gang_data param[0, -1]), player, getPlayerUID player, _plate, _vehicle], "APS_fnc_gangGarageSetActive", 2] spawn AP_fnc_MP;
_vehicle lock true;
_vehicle allowDamage false;
// Malden: the Altis civ_air_hs_*/civ_air_carrier_* OBJECTS do not exist here -- the bare refs
// errored ("Undefined variable in expression: civ_air_hs_1") on EVERY pull (non-fatal: the array
// literal recovers with nil elements, so positioning still ran -- pure RPT noise). String markers
// only; re-add ship objects via missionNamespace getVariable if they are ever placed on this map.
private _boatSpawns = ["gangboatrebel_air_1", "gangboatrebel_car_1"];
if (_spawnPoint in _boatSpawns) then {if (_spawnPoint in ["gangboatrebel_air_1", "gangboatrebel_car_1"]) then {
        private _boatSpawnPos = getMarkerPos[_spawnPoint, true];
        _boatSpawnPos set[2, (_boatSpawnPos select 2) + 0.2];
        _vehicle setPosATL _boatSpawnPos;} else {_vehicle setPosATL _markerPos;};} else {
    // owner 2026-06-15 (#237): same cartel-flag-pole spawn-kill guard as fn_spawnVehicle, but only for OPEN
    // MARKER garages (spawnPoint is a string). House garages use an object spawnPoint + boats are excluded,
    // so neither is nudged. Moves the car off the flag pole to clear flat ground.
    // owner 2026-07-03 (#520): DROPPED the old "House_F within 8m" skip -- the DRUG cartel sits next to a
    // CHURCH (House_F), so that clause skipped the nudge there and cars STILL spawned on the flag pole and
    // desync-killed players. Mirrors the #254 fix already shipped in fn_spawnVehicle: gate on garage TYPE
    // (string marker = open garage) instead of proximity to a building. Widened to 10m / <20m to match it.
    // owner 2026-07-04: gate the #520 findSafePos nudge to markers that actually have a flag pole (FlagCarrier)
    // within 5m (cartel garages) -- it was firing at every marker garage and shifting spawns up to 10m off the
    // marker map-wide. Normal garages now spawn ON the marker. Still skip when a vehicle already sits there (2nd+
    // pull) so findSafePos can't scatter the next car into a tree.
    if ((_spawnPoint isEqualType "")
        && {!(_spawnPoint in _boatSpawns)}
        && {(nearestObjects [_markerPos, ["FlagCarrier"], 5]) isNotEqualTo []}
        && {(nearestObjects [_markerPos, ["Car", "Air", "Ship"], 9]) isEqualTo []}) then {
        private _safe = [_markerPos, 0, 10, 3.2, 0, 0.4, 0] call BIS_fnc_findSafePos;
        if (_safe isEqualType [] && {count _safe >= 2} && {(_safe distance2D _markerPos) < 20}) then { _markerPos set [0, _safe select 0]; _markerPos set [1, _safe select 1]; };
    };
    // owner 2026-07-30: setPos is AGL and throws the marker height away again, so anything meaningfully
    // above the ground is placed with setPosATL, the frame that height is in. 0.5 m rather than 0 so an
    // editor nudge of a few centimetres still counts as a ground spawn and behaves exactly as before.
    if ((_markerPos select 2) > 0.5) then { _vehicle setPosATL _markerPos;
        // owner 2026-08-02: mirror of the fn_vehicleShopBuy pad raycast -- sit the vehicle on the real
        // structure surface instead of trusting the marker's hand-entered height (heli fall damage).
        private _aslTop = (getPosASL _vehicle) vectorAdd [0, 0, 5];
        private _hits = lineIntersectsSurfaces [_aslTop, _aslTop vectorAdd [0, 0, -30], _vehicle, objNull, true, 1, "GEOM", "NONE"];
        if (_hits isNotEqualTo []) then {private _srf = (_hits select 0) select 0;
            _vehicle setPosASL [_srf select 0, _srf select 1, (_srf select 2) + 0.6];};} else { _vehicle setPos _markerPos; };};
if (_spawnPoint isEqualType objNull) then {
    _vehicle setDir([((direction _spawnPoint) - 90), direction _spawnPoint] select("VR" in typeOf _spawnPoint))} else {
    _vehicle setDir(markerDir _spawnPoint)};
diag_log format ["-VEHSPAWN- %1 pull spawn=%2 markerZ=%3 elevated=%4",
    typeOf _vehicle, _markerPos, (_markerPos select 2), (_markerPos select 2) > 0.5];
private _rebelOutposts = ["Rebelop_1", "Rebelop_2", "Rebelop_3", "Rebelop_4", "Rebelop_5", "Rebelop_6"];
if !(({player distance(getMarkerPos _x) <= 200}
count _rebelOutposts) isEqualTo 0) then {["moneyspentrebel", _pullFee] call AP_fnc_statArrUpdate;};
[format["Your %1 is ready on the spawn point!", getText(configFile >> "CfgVehicles" >> _classname >> "displayName")], "basic"] spawn AP_fnc_handleMessage;
[
    ["-GANGVEHICLEPULL-", player, (profileName), format["pulled a %1 (%2), Gang ID: %4, POS: %3", getText(configFile >> "CfgVehicles" >> _classname >> "displayName"), _plate, getPosATL player, AP_gang_data param[0, 0]]], "APS_fnc_logIt", 2, false, false] spawn AP_fnc_MP;
[_vehicle] call AP_fnc_clearVehicleAmmo;
clearItemCargoGlobal _vehicle;
clearBackpackCargoGlobal _vehicle;
uiSleep 1;
_vehicle setVariable["AP_dbInfo", [str(AP_gang_data param[0, -1]), _plate, true], true]; [
    [_vehicle, player], "AP_fnc_addVehicle2Chain", ([AP_gang_data param[0, -1]] call AP_fnc_getOnlineMembers)] spawn AP_fnc_MP;
[_vehicle, _mods, _color, _customPlate, _vehWear, false, true] spawn AP_fnc_prepareVehicle;