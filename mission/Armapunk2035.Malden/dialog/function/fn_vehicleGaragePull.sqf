#include "..\..\macro.h"
// DECK ROUTE (UI overhaul 2026-08-26): the deck GARAGE app calls this with the
// row as a parameter; the native dialog path still reads its own listbox. ONE
// copy of the pull logic on purpose -- it already exists in three near-copies
// (shop buy, gang pull, here) and every pad-height fix has had to land three
// times. closeDialog is guarded so the deck flow does not shut the phone.
params [["_deckRow", [], [[]]]];
if (scriptAvailable(5)) exitWith {["Wait a few seconds before pulling another vehicle.", "basic"] spawn AP_fnc_handleMessage;};
disableSerialization;
private _grgClose = { if (!isNull (findDisplay 100150)) then { closeDialog 0 } };
private "_vehicle";
if (_deckRow isNotEqualTo []) then { _vehicle = _deckRow; } else {
    if ((lbCurSel 100151) isEqualTo - 1) exitWith {
        ["You did not select a vehicle to retrieve from your garage!", "basic"] spawn AP_fnc_handleMessage;
        call _grgClose;};
    _vehicle = parseSimpleArray(lbData[100151, lbCurSel 100151]);
};
if (isNil "_vehicle") exitWith {
    ["There was an error selecting your vehicle from the garage. Please try again.", "basic"] spawn AP_fnc_handleMessage;
    call _grgClose;};
_vehicle params["_classname", "_plate", "_color", "", "_mods", "_vehWear", "_customPlate"];
if !(AP_vehicles findIf {(_x getVariable["AP_dbInfo", []] param[1, -1]) isEqualTo _plate}
isEqualTo - 1) exitWith {["This vehicle is already in use.", "basic"] spawn AP_fnc_handleMessage};
if ((_classname isEqualTo "O_APC_Wheeled_02_rcws_v2_F") && (count(vehicles select {typeOf _x isEqualTo "O_APC_Wheeled_02_rcws_v2_F"
}) isNotEqualTo 0)) exitWith {call _grgClose;
    ["The maximum amount of Madrids have been pulled.", "basic"] spawn AP_fnc_handleMessage;};
private _vehCfgRow = ["getVehicleRowParsed", "", _classname] call AP_fnc_vehicleConfig;
if (_vehCfgRow isEqualTo[]) exitWith {};
private _textureShopFlags = (["specific", _classname, _color] call AP_fnc_vehicleTextures) param[2, [""]];
// owner 2026-06-13 (#162): the undercover gate only passed if the vehicle's TEXTURE carried a cop/fed flag.
// A legit cop vehicle with no cop SKIN (e.g. the Strider before its skin was added) failed this and couldn't
// be pulled ("undercover role only"). Also allow when the vehicle is a cop vehicle by CONFIG CATEGORY.
private _copCats = ["cop_car", "cop_air", "cop_ship", "maxtac_car", "srt_car"];
private _isCopVeh = ((_vehCfgRow param[3, []]) findIf { _x in _copCats }) > -1;
if (AP_effSide isEqualTo west && {
    AP_copRole != "scd" && AP_copRole != "all" && (!("cop" in _textureShopFlags) && !("fed" in _textureShopFlags) && !_isCopVeh)
}) exitWith {["This vehicle can only be used when you are in the undercover role.", "basic"] spawn AP_fnc_handleMessage};
private _spawnPoint = "";
// owner 2026-07-31: the domain filter knows BOTH naming schemes -- the Altis civ_g_/civ_air_/civ_sea_
// markers and the new convention pads (car_spawn../air_spawn../boat_spawn.., see npcs\fn_nearSpawns.sqf).
// A ground vehicle may use an air pad (a car fits on a helipad, never the reverse). The filter is a
// LOCAL now -- this used to overwrite AP_garage_sp itself, so one Land pull permanently stripped the
// air pads from the open garage -- and it falls back to the unfiltered list when it matches nothing,
// the same fix fn_vehicleShopBuy got on 2026-07-10; without it the new pad names emptied the list and
// every pull reported "vehicle blocking the spawn point" with nothing there.
private _garageSps = AP_garage_sp;
if (_garageSps isEqualType[]) then {
    private _f = [];
    if (_classname isKindOf "Land") then {_f = _garageSps select { "_g_" in (str _x) || "car_spawn" in (str _x) };};   // owner 2026-08-02: cars never take air pads (third copy of this filter -- ER HQ helipad parking)
    if (_classname isKindOf "Air") then {_f = _garageSps select { "_air_" in (str _x) || "air_spawn" in (str _x) };};
    if (_classname isKindOf "Ship") then {_f = _garageSps select { "_sea_" in (str _x) || "boat_spawn" in (str _x) };};
    if (_f isNotEqualTo []) then { _garageSps = _f; };
    if ((_garageSps param[0, objNull]) isEqualType objNull) then {if !(surfaceIsWater position player) then {
            _spawnPoint = _garageSps param[_garageSps findIf {
                nearestObjects[getPosATL _x, ["Car", "Tank", "Ship"], 5] isEqualTo[] && nearestObjects[getPosATL _x, ["Air"], 14] isEqualTo[] && (player distance2D(getPosATL _x) <= 100)
            }, ""];} else {_spawnPoint = _garageSps param[_garageSps findIf {
                nearestObjects[getPosASL _x, ["Car", "Tank", "Ship"], 5] isEqualTo[] && nearestObjects[getPosASL _x, ["Air"], 14] isEqualTo[] && (player distance2D(getPosASL _x) <= 100)
            }, ""];};} else {_spawnPoint = _garageSps param[_garageSps findIf {
            nearestObjects[getMarkerPos _x, ["Car", "Tank", "Ship"], 5] isEqualTo[] && nearestObjects[getMarkerPos _x, ["Air"], 14] isEqualTo[] && (player distance2D(getMarkerPos _x) <= 100)
        }, ""];};} else {if (AP_garage_sp isKindOf "House_F") then {
        if (nearestObjects[getPosATL AP_garage_sp, ["Car", "Tank", "Air"], 9] isEqualTo[]) then {_spawnPoint = AP_garage_sp};} else {
        if (nearestObjects[getPosATL AP_garage_sp, ["Car", "Tank", "Ship"], 5] isEqualTo[] && nearestObjects[getPosATL AP_garage_sp, ["Air"], 14] isEqualTo[] && (player distance2D(getPosATL AP_garage_sp) <= 100)) then {
            _spawnPoint = AP_garage_sp};};};
if (_spawnPoint isEqualTo "") exitWith {
    ["There is a vehicle currently blocking the spawn point(s).", "basic"] spawn AP_fnc_handleMessage;
    call _grgClose;};
private _pullFee = _vehCfgRow select 9;
if (AP_effSide isEqualTo independent && _classname isKindOf "Air" && 806 in AP_completedLifetimeQuests) then {_pullFee = _pullFee * 0.50
};
private _exit = false;
private _isProperty = _spawnPoint isKindOf "House_F";
if (!_isProperty && !(_pullFee isEqualTo 0)) then {if !([_pullFee] call AP_fnc_debitCard) exitWith {_exit = true;};};
if (_exit) exitWith {call _grgClose;};
private _exit = false;
if (_spawnPoint isKindOf "House_F") then {
    if (typeOf _spawnPoint isEqualTo "Land_i_Shed_Ind_F" && _classname isEqualTo "B_Truck_01_box_F") exitWith {_exit = true};
    if (_classname in ["C_Van_01_box_F", "C_Van_01_fuel_F", "C_Van_01_transport_F", "B_Truck_01_box_F", "B_Truck_01_transport_F", "B_Truck_01_fuel_F", "I_Truck_02_covered_F", "I_Truck_02_transport_F", "O_Truck_03_device_F"] && !(typeOf _spawnPoint isEqualTo "Land_i_Shed_Ind_F")) exitWith {
        _exit = true};};
private _flickExit = false;
if (_spawnPoint isEqualType objNull && {AP_effSide isEqualTo civilian && !("VR_" in typeOf _spawnPoint)}) then {
    if (!(_spawnPoint in AP_vehicles) && !(_spawnPoint in AP_gangBuilding)) then {
        if !([cursorObject, getPlayerUID player, "accessLock"] call AP_fnc_keyHolderStatus) then {_flickExit = true};};};
if (_flickExit) exitWith {call _grgClose;
    ["You must be looking at your building to pull out a vehicle!", "basic"] spawn AP_fnc_handleMessage;};
private _vehName = ([_classname] call AP_fnc_fetchCfgDetails) select 1;
if (_exit) exitWith {[format["%1 is too large for this garage.", _vehName], "basic"] spawn AP_fnc_handleMessage;};
call _grgClose;
// owner 2026-07-30: read the marker's OWN height -- `getMarkerPos _m` returns z = 0, only the
// [_m, true] syntax returns the marker's z. Without it an ELEVATED spawn point (a helipad on a
// structure) resolved to [x, y, 0] and the vehicle was placed at terrain level, inside whatever the
// pad stands on. Same fix as fn_vehicleShopBuy; this logic exists in three copies and fixing one is
// what let the rebel outpost helicopter keep exploding after the first fix.
private _markerPos =
if (_spawnPoint isEqualType objNull) then {getPosATL _spawnPoint} else {getMarkerPos [_spawnPoint, true]};
if (_spawnPoint isKindOf "House_F") then {if (typeOf _spawnPoint == "Land_i_Shed_Ind_F") then {
        _markerPos = _spawnPoint modelToWorld[4, 4, -0.5];
        // owner 2026-07-10 SHED HELIPAD: an upgraded shed pulls AIR vehicles dead-centre on its pad deck,
        // ~1m clearance; the setDir(direction _spawnPoint) below already points the nose along the shed's
        // facing (owner spec: nose = shed front, never the sides). Offsets are the shed-model frame of the
        // owner's Eden comp (pad centre [3.35,3.44], deck top +4.79).
        if (_classname isKindOf "Air" && {_spawnPoint getVariable ["AP_helipad", false]}) then {
            _markerPos = _spawnPoint modelToWorld [3.351, 3.436, 5.8];};} else {
        _markerPos set[2, (getPosATL _spawnPoint select 2) + 0.155541];};} else {_markerPos set[2, (_markerPos select 2) + 1.5];};
private _vehicle = createVehicle[_classname, [random 999, random 999, 999], [], 0, "CAN_COLLIDE"];
// owner 2026-06-27: TT AMV-7 Marshall stays ammo-less + non-rearmable on garage pull too (see fn_vehicleShopBuy).
if (typeOf _vehicle isEqualTo "B_APC_Wheeled_01_cannon_F") then {
    { _vehicle removeMagazinesTurret [_x select 0, _x select 1] } forEach (magazinesAllTurrets _vehicle);
    _vehicle setVehicleAmmo 0;
    _vehicle addEventHandler ["Reloaded", { (_this select 0) setVehicleAmmo 0 }];};
waitUntil {!isNil "_vehicle" && {!isNull _vehicle}}; [[player, _plate, _vehicle], "APS_fnc_vehicleSetActive", 2] call AP_fnc_MP;
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
    // owner 2026-07-04 (#520): nudge personal-garage pulls off the cartel flag pole (mirrors fn_gangGaragePull;
    // open marker garages only -- house/shed OBJECT garages keep their precise offset).
    // owner 2026-07-04: the #520 findSafePos nudge was meant ONLY to lift a pulled car off the cartel flag pole,
    // but it gated on "string marker = any open garage" -> it fired at EVERY city/marker garage and findSafePos
    // relocated the spawn up to 10m off the marker = vehicle spawns shifted map-wide. Gate it to markers that
    // actually have a flag pole (FlagCarrier) within 5m (cartel garages); normal garages now spawn ON the marker.
    // Also still skip when a vehicle already sits on the marker (2nd+ pull) so it doesn't scatter into a tree.
    if (_spawnPoint isEqualType ""
        && {(nearestObjects [_markerPos, ["FlagCarrier"], 5]) isNotEqualTo []}
        && {(nearestObjects [_markerPos, ["Car", "Air", "Ship"], 9]) isEqualTo []}) then {
        private _safe = [_markerPos, 0, 10, 3.2, 0, 0.4, 0] call BIS_fnc_findSafePos;
        if (_safe isEqualType [] && {count _safe >= 2} && {(_safe distance2D _markerPos) < 20}) then { _markerPos set [0, _safe select 0]; _markerPos set [1, _safe select 1]; };
    };
    // owner 2026-07-30: setPos is AGL and throws the marker height away again, so anything meaningfully
    // above the ground is placed with setPosATL, the frame that height is in. 0.5 m rather than 0 so an
    // editor nudge of a few centimetres still counts as a ground spawn and behaves exactly as before.
    if ((_markerPos select 2) > 0.5) then { _vehicle setPosATL _markerPos;
        // owner 2026-08-02: third copy of the fn_vehicleShopBuy pad raycast -- sit the vehicle on the
        // real structure surface instead of trusting the marker's hand-entered height (ER HQ heli
        // fall damage; the marker only needs to be "above the pad, below the next deck").
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
    ["-VEHICLEPULL-", player, (profileName), format["pulled a %1 (%2), POS: %3 | Mods: %4", getText(configFile >> "CfgVehicles" >> _classname >> "displayName"), _plate, getPosATL player, _mods]], "APS_fnc_logIt", 2, false, false] spawn AP_fnc_MP;
if (_classname isKindOf "Air") then {["action", "garagepullaircraft", 1] call AP_fnc_handleQuest;};

if (AP_effSide isEqualTo west ) then {

    private _textureName = ["specific", typeOf _vehicle, _color] call AP_fnc_vehicleTextures;
    // param, not select: "specific" returns [] for an id with no row, and `[] select 11` leaves
    // _textureAddress undefined -> the _policeMarked line below throws. Any vehicle still holding a
    // retired cop skin id hits this on pull.
    private _textureAddress = _textureName param [11, ""];
    // DEAD GATE -- OWNER DECISION NEEDED (2026-08-13). This tested the livery PATH ("apd", renamed to
    // "maxsec"), which was the only per-vehicle marked/undercover discriminator we had. The custom cop
    // liveries were deleted with the rest of the MaxSec skin art, so this is now always false and the
    // pushbar/lightbar block below never runs. Deliberately NOT re-gated: the obvious fallback, the
    // cop config category used at the top of this file for #162, cannot tell the two apart here --
    // C_Hatchback_01_F and C_Hatchback_01_sport_F both carry "civ_car" AND "cop_car" in the same
    // fn_vehicleConfig row, so it would put a lightbar on undercover cars too. Restoring the props
    // needs a real marked/unmarked signal (a per-vehicle flag, a purchase-time choice, or one cop
    // livery brought back).
    private _policeMarked = "maxsec" in str _textureAddress;
    private _hasPositions = "Hatchback" in (typeOf _vehicle); //([_vehicle] call AP_fnc_copVehObjLoc) select 2;

    diag_log format["%1: %2 %3", _textureAddress, _policeMarked, _hasPositions];

    //only add to land vehicles that have positions for objects and for non UC cops
    if (_vehicle isKindOf "LandVehicle" && _hasPositions == true && _policeMarked == true) then {

        _createfnc = {

            params ["_vehicle"];

            uisleep 2;

            if !(isNull _vehicle) then {[_vehicle] remoteExec ["APS_fnc_createP3DObjects", 2, false]};

            systemChat format "P3D Objects created for vehicle: %1", _vehicle;};

        [_vehicle] spawn _createfnc;};};

[_vehicle] call AP_fnc_clearVehicleAmmo;
clearItemCargoGlobal _vehicle;
clearBackpackCargoGlobal _vehicle;
uiSleep 1;
[_vehicle, _mods, _color, _customPlate, _vehWear, false] spawn AP_fnc_prepareVehicle;
_vehicle setVariable["AP_dbInfo", [getPlayerUID player, _plate], true];