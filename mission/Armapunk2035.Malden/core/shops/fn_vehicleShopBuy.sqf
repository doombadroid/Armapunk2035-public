#include "..\..\macro.h"
if (scriptAvailable(3)) exitWith {["Please don't spam vehicle purchases!", "basic"] spawn AP_fnc_handleMessage;};
// owner 2026-06-24: DUTY shops (MaxTac / Firefighter / SRT) don't count toward the garage cap, so fn_vehicleShopMenu
// deliberately SKIPS fetching AP_garageCount for them -> it stays at the default -1. The "-1 / over-cap" guards below
// then wrongly blocked the buy ("Failed to fetch garage count") in the MaxTac/Fire/SRT garage for any cop who hadn't
// opened a normal garage first this session. Skip both count guards for duty shops (MaxTac pulls unlimited; Firefighter
// and SRT keep their OWN per-type caps in the duty block further down).
private _dutyShop = (AP_veh_shop param [0, ""]) in ["maxtac_car", "firefighter_car", "srt_car"];
if (!_dutyShop && {AP_garageCount isEqualTo - 1}) exitWith {
    ["Please try this vehicle purchase in a few seconds. Failed to fetch garage count from server.", "basic"] spawn AP_fnc_handleMessage;
};
if (!_dutyShop && {AP_garageCount >= (call AP_maxGarageVeh)}) exitWith {
    [format["You have %1 out of %2 max vehicles allowed in your garage.", AP_garageCount, (call AP_maxGarageVeh)], "basic"] spawn AP_fnc_handleMessage;
};
// DECK ROUTE (UI overhaul 2026-08-26): the deck VEHICLE SHOP passes everything
// the dialog would be read for: [class, alarm, skinID, skinText, modValues[8],
// modCost]. The mod COST is recomputed SQF-side by AP_fnc_deckVShop from the
// same config the combos price from -- the page never prices anything.
params [["_deckBuy", [], [[]]]];
private _fromDeck = _deckBuy isNotEqualTo [];
private _shopClose = { if (!isNull (findDisplay 100100)) then { closeDialog 0 } };
if (!_fromDeck && {(lbCurSel 100102) isEqualTo - 1}) exitWith {["You did not select a vehicle to purchase!", "basic"] spawn AP_fnc_handleMessage;};
private _display = findDisplay 100100;
private _classname = if (_fromDeck) then {_deckBuy param [0, ""]} else {lbData[100102, lbCurSel 100102]};
private _vehCfgRow = ["getVehicleRowParsed", "", _classname] call AP_fnc_vehicleConfig;
if (_vehCfgRow isEqualTo []) exitWith {["No such vehicle in this shop.", "basic"] spawn AP_fnc_handleMessage;};
private _vehPrice = _vehCfgRow param[7, 1000];
private _alarmOn = if (_fromDeck) then {(_deckBuy param [1, 0]) isEqualTo 1} else {ctrlChecked(_display displayCtrl 100106)};
private _price = if (_alarmOn) then {_vehPrice + 500} else {_vehPrice};
private _alarm = if (_alarmOn) then {1} else {0};
private _skinID = if (_fromDeck) then {_deckBuy param [2, -1]} else {
    if (lbSize 100105 isEqualTo 0) then {-1} else {lbValue[100105, lbCurSel 100105]}};
private _selText = if (_fromDeck) then {_deckBuy param [3, ""]} else {lbText[100105, lbCurSel 100105]};
// NIGHT CITY buy-time mods: read the configure grid (duty vehicles are temporary -> no mods)
private _modCost = 0;
private _fnModRead = {params ["_idc"];
    private _c = _display displayCtrl _idc;
    if ((lbSize _c) isEqualTo 0 || {(lbCurSel _c) < 0}) exitWith { 0 };
    _modCost = _modCost + parseNumber (_c lbData (lbCurSel _c));
    _c lbValue (lbCurSel _c)};
private "_mTrunk"; private "_mHandling"; private "_mHorn"; private "_mNitro";
private "_mTracker"; private "_mLocks"; private "_mDoors"; private "_mAutopilot"; private "_mChameleon";
if (_fromDeck) then {
    (_deckBuy param [4, [0,0,0,0,0,0,0,0,0]]) params
        [["_a",0],["_b",0],["_c2",0],["_d2",0],["_e",0],["_f",0],["_g",0],["_h",0],["_i",0]];
    _mTrunk = _a; _mHandling = _b; _mHorn = _c2; _mNitro = _d2;
    _mTracker = _e; _mLocks = _f; _mDoors = _g; _mAutopilot = _h; _mChameleon = _i;   // 9th = Chameleon Paint (slot 6)
    _modCost = _deckBuy param [5, 0];
} else {
    _mTrunk    = [100110] call _fnModRead;
    _mHandling = [100111] call _fnModRead;
    _mHorn     = [100112] call _fnModRead;
    _mNitro    = [100113] call _fnModRead;
    _mTracker  = [100114] call _fnModRead;
    _mLocks    = [100115] call _fnModRead;
    _mDoors    = [100116] call _fnModRead;
    _mAutopilot = [100118] call _fnModRead;
    _mChameleon = 0;   // the native grid has no combo for slot 6; the deck shop (the primary UI) sells it
};
private _purchaseButton = _display displayCtrl 100107;
private _ndBuy = AP_ndShop;
_price = _price + (_price * (call AP_fnc_getGovTax));
_purchaseButton ctrlEnable false;
AP_veh_shop params["_shopVar", "_spawnPoints", "_shopFlag", ""];
private _isMaxTac = _shopVar isEqualTo "maxtac_car";
if (_dutyShop) then { _modCost = 0; _mTrunk = 0; _mHandling = 0; _mHorn = 0; _mNitro = 0; _mTracker = 0; _mLocks = 0; _mDoors = 0; _mAutopilot = 0; };
private _isFirefighter = _shopVar isEqualTo "firefighter_car";
private _isSRT = _shopVar isEqualTo "srt_car";
private _vehCount = count(vehicles select {
    (_x getVariable["AP_vehIsMaxTac", false]) || (_x getVariable["AP_vehIsFirefighter", false]) || (_x getVariable["AP_isSRT", false])});
private _maxVehicles = 3;
// owner 2026-06-20 (Payton): MaxTac vehicle pulls are UNLIMITED (was capped at 3). Firefighter + SRT keep the cap.
if (_vehCount >= _maxVehicles && _isFirefighter) exitWith {call _shopClose;
    ["The maximum amount of Firefighting vehicles have been pulled.", "basic"] spawn AP_fnc_handleMessage;};
if (_vehCount >= _maxVehicles && _isSRT) exitWith {call _shopClose;
    ["The maximum amount of SRT vehicles have been pulled.", "basic"] spawn AP_fnc_handleMessage;};
if ((_classname isEqualTo "O_APC_Wheeled_02_rcws_v2_F") && (count(vehicles select {typeOf _x isEqualTo "O_APC_Wheeled_02_rcws_v2_F"
}) isNotEqualTo 0)) exitWith {call _shopClose;
    ["The maximum amount of Madrids have been pulled.", "basic"] spawn AP_fnc_handleMessage;};
private _spawnPoint = "";
if (_spawnPoints isEqualType[]) then {
    // owner 2026-07-10: pick the spawn points matching the vehicle's domain, but FALL BACK to the garage's
    // own pads if it has none of that type. A ground-type MaxTac garage carries only "_g_" spawns, so pulling an
    // air vehicle (MaxTac Orca) used to empty this list -> findIf on [] returned -1 -> _spawnPoint="" -> a bogus
    // "vehicle blocking the spawn point" with nothing there. The fallback lets a duty heli spawn on an open
    // ground pad instead; the 5m Car / 14m Air clearance checks below still guard against a genuinely occupied pad.
    // owner 2026-07-31: also match the new convention pads (car_spawn../air_spawn../boat_spawn..).
    // owner 2026-08-02: cars NEVER take air pads (they were parking on the ER HQ helipad -- alphabetical
    // order put air_spawn_4 first in the list). A garage with ONLY air pads still falls back to the full
    // list below, so the degenerate case keeps working.
    if (_classname isKindOf "Land") then {private _f = _spawnPoints select { "_g_" in (str _x) || "car_spawn" in (str _x) };
        if (_f isNotEqualTo []) then { _spawnPoints = _f };};
    if (_classname isKindOf "Air") then {private _f = _spawnPoints select { "_air_" in (str _x) || "air_spawn" in (str _x) };
        if (_f isNotEqualTo []) then { _spawnPoints = _f };};
    if (_classname isKindOf "Ship") then {private _f = _spawnPoints select { "_sea_" in (str _x) || "boat_spawn" in (str _x) };
        if (_f isNotEqualTo []) then { _spawnPoints = _f };};
    if ((_spawnPoints param[0, objNull]) isEqualType objNull) then {if !(surfaceIsWater position player) then {
            _spawnPoint = _spawnPoints param[_spawnPoints findIf {
                nearestObjects[getPosATL _x, ["Car", "Tank", "Ship"], 5] isEqualTo[] && nearestObjects[getPosATL _x, ["Air"], 14] isEqualTo[] && (player distance2D(getPosATL _x) <= 100)
            }, ""];} else {_spawnPoint = _spawnPoints param[_spawnPoints findIf {
                nearestObjects[getPosASL _x, ["Car", "Tank", "Ship"], 5] isEqualTo[] && nearestObjects[getPosASL _x, ["Air"], 14] isEqualTo[] && (player distance2D(getPosASL _x) <= 100)
            }, ""];};} else {_spawnPoint = _spawnPoints param[_spawnPoints findIf {
            nearestObjects[getMarkerPos _x, ["Car", "Tank", "Ship"], 5] isEqualTo[] && nearestObjects[getMarkerPos _x, ["Air"], 14] isEqualTo[]
        }, ""];}} else {if (_spawnPoints isEqualType "") then {
        if (nearestObjects[getMarkerPos _spawnPoints, ["Car", "Tank", "Ship"], 5] isEqualTo[] && nearestObjects[getMarkerPos _spawnPoints, ["Air"], 14] isEqualTo[]) then {
            _spawnPoint = _spawnPoints};} else {
        if (nearestObjects[getPosATL _spawnPoints, ["Car", "Tank", "Ship"], 5] isEqualTo[] && nearestObjects[getPosATL _spawnPoints, ["Air"], 14] isEqualTo[]) then {
            _spawnPoint = _spawnPoints};};};
if (_spawnPoint isEqualTo "") exitWith {
    ["There is a vehicle currently blocking the spawn point(s).", "basic"] spawn AP_fnc_handleMessage;};
private _success = false;
private _ndPricePaid = "0";
if (_ndBuy) then {
    // NEW DRACHMA: the vehicle's ND price is INDEPENDENT (fn_ndPriceCfg, keyed by classname). Discount
    // applies as a fraction; mods add at 6000:1 (they have no ND table entry). Server-authoritative debit
    // via AP_fnc_ndBuySync (this fn is spawned -> waitUntil is legal).
    private _ndBase = [_classname] call AP_fnc_ndPriceCfg;
    if (_ndBase isEqualTo "") then { _ndBase = [_price] call AP_fnc_ndFromLegacy; diag_log format ["[LooneyBin][ND] vehicle missing price key %1 -- 6000:1 fallback", _classname]; };
    // apply the vehshop discount to the ND base, add the mods (converted), re-round to 4dp -> string
    private _ndNum = (parseNumber _ndBase) * (["vehshop", true] call AP_fnc_getDiscount);
    _ndNum = _ndNum + (parseNumber ([_modCost] call AP_fnc_ndFromLegacy));
    private _ndPrice = ((round (_ndNum * 10000)) / 10000) toFixed 4;
    _ndPricePaid = _ndPrice;
    if !([_ndPrice] call AP_fnc_ndAfford) exitWith {
        [format["You cannot afford this. You need %1 ND", [_ndPrice] call AP_fnc_ndText], "basic"] spawn AP_fnc_handleMessage;};
    if !([_ndPrice] call AP_fnc_ndBuySync) exitWith {["New Drachma payment failed -- try again.", "basic"] spawn AP_fnc_handleMessage;};
    _success = true;} else {
    if (_classname isEqualTo "C_Hatchback_01_sport_F" && AP_effSide isEqualTo west && 656 in AP_completedLifetimeQuests) then {
        _price = _price * 0.95;};
    if (_classname isKindOf "Air" && AP_effSide in [west, independent] && ((657 in AP_completedLifetimeQuests) || (809 in AP_completedLifetimeQuests))) then {
        _price = _price * 0.98;};
    if (_classname isKindOf "Land" && AP_effSide isEqualTo independent && 808 in AP_completedLifetimeQuests) then {
        _price = _price * 0.98;};
    if (_classname in ["B_MRAP_01_F", "I_MRAP_03_F", "O_MRAP_02_F", "O_APC_Wheeled_02_rcws_v2_F"] && AP_effSide isEqualTo west && 658 in AP_completedLifetimeQuests) then {
        _price = _price * 0.98;};
    _price =
    if (_isMaxTac || _isFirefighter) then {0} else {_price * (["vehshop", true] call AP_fnc_getDiscount);};
    _price = _price + _modCost;   // buy-time mods: flat, untaxed/undiscounted (garage parity)
    if !([_price] call AP_fnc_debitCard) exitWith {};
    _success = true;
    if (_classname isKindOf "Land") then {["buy", "invehiclevalue", _price] call AP_fnc_handleQuest;};
    if (_classname isKindOf "Air") then {["buy", "inaircraftvalue", _price] call AP_fnc_handleQuest;};
    if (_classname isEqualTo "C_Hatchback_01_sport_F") then {["buy", "inhatchbackvalue", _price] call AP_fnc_handleQuest;};
    if (_classname in ["B_MRAP_01_F", "I_MRAP_03_F", "O_MRAP_02_F", "O_APC_Wheeled_02_rcws_v2_F"]) then {
        ["buy", "inarmorvalue", _price] call AP_fnc_handleQuest;};};
if !(_success) exitWith {};
if (AP_effSide isEqualTo independent) then {["buy", "vehicle", 1] spawn AP_fnc_handleQuest;};
if !(_ndBuy) then {[6] call AP_fnc_ClupdatePartial;};
// owner 2026-07-30: read the marker's OWN height. `getMarkerPos _m` returns z = 0 -- the z is only
// returned by the [_m, true] syntax -- so an ELEVATED spawn point (a helipad on a structure, a deck)
// resolved to [x, y, 0] and the vehicle was placed at terrain level, i.e. INSIDE whatever the pad sits
// on. That is the rebel outpost heli spawning in the composition floor and exploding. The existing
// gangboatrebel branch below already worked around exactly this for the boat spawns with the [_m, true]
// syntax; this generalises it so a new elevated spawn point does not need adding to a hardcoded list.
// Ground spawns are unaffected: their markers carry z = 0, so this reads the same value it always did.
private _markerPos =
if (_spawnPoint isEqualType objNull) then {getPosATL _spawnPoint} else {getMarkerPos [_spawnPoint, true]};
_markerPos set[2, (_markerPos select 2) + 1.5];
private _vehicle = createVehicle[_classname, [random 999, random 999, 999], [], 0, "CAN_COLLIDE"];
// owner 2026-06-27: TT AMV-7 Marshall is parade/blocking armor only -- keep the 40mm visible but issue it
// with NO ammo and block rearm (strip all turret mags, zero ammo, re-zero on any reload attempt).
if (typeOf _vehicle isEqualTo "B_APC_Wheeled_01_cannon_F") then {
    _vehicle animate ["HideTurret", 1];   // owner 2026-07-04: hide the 40mm turret entirely (like the Marid's cop_apc), not just ammo-strip
    { _vehicle removeMagazinesTurret [_x select 0, _x select 1] } forEach (magazinesAllTurrets _vehicle);
    _vehicle setVehicleAmmo 0;
    _vehicle addEventHandler ["Reloaded", { (_this select 0) setVehicleAmmo 0 }];};
waitUntil {!isNil "_vehicle" && {!isNull _vehicle}};
_vehicle lock true;
_vehicle allowDamage false;
if (_spawnPoint isEqualType objNull) then {
    _vehicle setDir([((direction _spawnPoint) - 90), direction _spawnPoint] select("VR" in typeOf _spawnPoint))} else {
    _vehicle setDir(markerDir _spawnPoint)};
// owner 2026-09-06: civ_air_carrier_1..3 are bare object names that are not defined on Malden (the
// carriers are Altis). An undefined name inside an array literal throws, and the throw skips the
// whole test. Resolve each name to the object if it exists, else keep the string so a marker-named
// spawn still matches.
private _carrierSpawns = (["civ_air_carrier_1", "civ_air_carrier_2", "civ_air_carrier_3"] apply { missionNamespace getVariable [_x, _x] });
if (_spawnPoint in (_carrierSpawns + ["gangboatrebel_air_1", "gangboatrebel_car_1"])) then {
    if (_spawnPoint in ["gangboatrebel_air_1", "gangboatrebel_car_1"]) then {private _boatSpawnPos = getMarkerPos[_spawnPoint, true];
        _boatSpawnPos set[2, (_boatSpawnPos select 2) + 0.2];
        _vehicle setPosATL _boatSpawnPos;} else {_vehicle setPosATL _markerPos;
        _vehicle setVectorUp(surfaceNormal _markerPos);};} else {
    // owner 2026-07-30: setPos is AGL, so it drops the vehicle onto the terrain and throws the marker's
    // height away again. Any spawn whose marker is meaningfully above the ground is placed with
    // setPosATL instead, which is the frame that height is in. 0.5 m rather than 0 so a marker nudged a
    // few centimetres by the editor still counts as a ground spawn and keeps the old behaviour exactly.
    // No setVectorUp on the elevated path: surfaceNormal is the TERRAIN's normal, so on a pad over a
    // slope it would tilt the vehicle to match ground it is not standing on.
    if ((_markerPos select 2) > 0.5) then { _vehicle setPosATL _markerPos;
        // owner 2026-08-02: an elevated marker's stored height is a hand-entered GUESS (terrain under a
        // structure can't be measured offline), and guessing high made helis fall onto the ER HQ pad and
        // damage themselves. Ray straight down from 5 m above the vehicle: first structure surface wins,
        // vehicle sits 0.6 m over it. Marker height now only needs to be "above the pad, below the next
        // deck". Ray misses (bad data, no structure) -> keeps the plain setPosATL placement.
        private _aslTop = (getPosASL _vehicle) vectorAdd [0, 0, 5];
        private _hits = lineIntersectsSurfaces [_aslTop, _aslTop vectorAdd [0, 0, -30], _vehicle, objNull, true, 1, "GEOM", "NONE"];
        if (_hits isNotEqualTo []) then {private _srf = (_hits select 0) select 0;
            _vehicle setPosASL [_srf select 0, _srf select 1, (_srf select 2) + 0.6];};} else {
        _vehicle setPos _markerPos;
        _vehicle setVectorUp(surfaceNormal _markerPos);};};
diag_log format ["-VEHSPAWN- %1 spawn=%2 markerZ=%3 elevated=%4",
    _classname, _markerPos, (_markerPos select 2), (_markerPos select 2) > 0.5];
private _tax =
if (!(_ndBuy) && !(_shopVar in ["reb_car", "nd_car"])) then {(_price * (call AP_fnc_getGovTax))} else {0};
private _extra =
if (!(_ndBuy) && !(_shopVar in ["reb_car", "nd_car"])) then {format[", including a tax of $%1", [_tax] call AP_fnc_numberText]} else {
    ""};
playSound "purchase";
if (_ndBuy) then {
    [format["You bought a %1 for %2 ND. Press U while looking at the vehicle to unlock it or relock it.", getText(configFile >> "CfgVehicles" >> _className >> "displayName"), [_ndPricePaid] call AP_fnc_ndText], "basic"] spawn AP_fnc_handleMessage;
} else {
    [format["You bought a %1 for $%2%3. Press U while looking at the vehicle to unlock it or relock it.", getText(configFile >> "CfgVehicles" >> _className >> "displayName"), [_price] call AP_fnc_numberText, _extra], "basic"] spawn AP_fnc_handleMessage;
    ["payGovernor", [_tax]] spawn AP_fnc_govSystem;};
call _shopClose;
private _rebelOutposts = ["Rebelop_1", "Rebelop_2", "Rebelop_3", "Rebelop_4", "Rebelop_5", "Rebelop_6"];
if !(({player distance(getMarkerPos _x) <= 200}
count _rebelOutposts) isEqualTo 0) then {["moneyspentrebel", _price] call AP_fnc_statArrUpdate;};
["vehiclesbought", 1] call AP_fnc_statArrUpdate;
[_vehicle] call AP_fnc_clearVehicleAmmo;
clearItemCargoGlobal _vehicle;
clearBackpackCargoGlobal _vehicle;
uiSleep 1;
private _mods =
if (_alarm isEqualTo 1 || (AP_effSide isEqualTo west && 91 in AP_side_talents)) then {
    [1, _mTrunk, _mHandling, _mHorn, _mNitro, _mTracker, _mChameleon, _mLocks, _mDoors, _mAutopilot]} else {
    [0, _mTrunk, _mHandling, _mHorn, _mNitro, _mTracker, _mChameleon, _mLocks, _mDoors, _mAutopilot]};
private _side = [] call AP_fnc_sideString;
[_vehicle, _mods, _skinID, "", [0, 1], _isMaxTac, false, _isFirefighter, _isSRT] spawn AP_fnc_prepareVehicle;   // owner 2026-06-13: new vehicles spawn FULL fuel (was 0.5 = the "all vehicles half fuel" bug)
[
    [player, _vehicle, getPlayerUID player, _side, _skinID, _alarm, _isMaxTac, _isFirefighter, _isSRT, _mods], "APS_fnc_vehicleCreate", 2] spawn AP_fnc_MP;