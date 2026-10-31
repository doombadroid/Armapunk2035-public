#include "..\..\macro.h"
/*
    AP_fnc_houseToVehicleStore  (owner 2026-07-06) -- from the HOUSE STORAGE dialog, one-click bulk-dump the
    house's VIRTUAL inventory into the NEAREST vehicle you have KEYS to. Progress bar, 10 units/sec. Won't store
    more than the vehicle can hold (stops at AP_vcap) and stops when the house is empty.

    Anti-dupe / persistence model: the house side is ALREADY reserved (fn_openInventory set AP_activeTrunk=player
    on open); we reserve the TARGET vehicle (AP_activeTrunk + AP_veh_in_use) + raise AP_action_in_use so the
    player can't open another trunk mid-run. The HOUSE side is held in a local copy (safe: its buttons are disabled
    below + reopen is trunkLocked). The VEHICLE side is RE-READ LIVE and MERGED every tick (never a held copy) so a
    concurrent manual take from the target trunk can't be clobbered -- we only ever ADD this tick's units onto
    whatever the vehicle currently holds. Abort checks run BEFORE each tick's move, so the last broadcast is always
    a consistent snapshot and there is no clobbering final flush. Called from the trunk dialog "Store All -> Vehicle"
    button (idc 4523), civ/keyholder view only.
*/
disableSerialization;
if (missionNamespace getVariable ["AP_bulkStore", false]) exitWith { ["You're already moving items into a vehicle.", "basic"] spawn AP_fnc_handleMessage; };
private _house = AP_trunk_vehicle;
if (isNull _house) exitWith { ["You must have storage open.", "basic"] spawn AP_fnc_handleMessage; };
if !(_house isKindOf "House_F") exitWith { [] spawn AP_fnc_vehicleToHouseStore; };   // a VEHICLE trunk is open -> deposit the highlighted item into a nearby house instead
if !(AP_is_virtual) exitWith { ["Switch to the Virtual Inventory to bulk-store into a vehicle.", "basic"] spawn AP_fnc_handleMessage; };
if (AP_effSide isEqualTo west) exitWith {};                       // cop seize view -> no bulk store
if (isNull (findDisplay 4500)) exitWith {};

// only the HIGHLIGHTED house item (trunk listbox 4502), NOT the whole inventory
private _selIdx = lbCurSel 4502;
if (_selIdx < 0) exitWith { ["Highlight the item you want to store first.", "basic"] spawn AP_fnc_handleMessage; };
private _selCls = lbData [4502, _selIdx];
if (_selCls isEqualTo "") exitWith { ["Highlight the item you want to store first.", "basic"] spawn AP_fnc_handleMessage; };

// nearest vehicle you have KEYS to (uid anywhere in AP_vehOwners), within 25m, unlocked + free
private _uid = getPlayerUID player;
private _near = nearestObjects [player, ["Car", "Air", "Ship"], 25];
private _veh = objNull; {if (alive _x) then {
        private _cand = _x;                                       // bind before the inner findIf overwrites _x
        private _hasKey = ((_cand getVariable ["AP_vehOwners", []]) findIf { (_x param [0, ""]) isEqualTo _uid }) > -1;
        if (_hasKey
            && {(_cand getVariable ["AP_activeTrunk", objNull]) isEqualTo objNull}
            && {(_cand getVariable ["AP_veh_in_use", objNull]) isEqualTo objNull}
            && {!(_cand getVariable ["AP_trunkLock", false])}
            && {!(_cand getVariable ["AP_seizing", false])}) exitWith { _veh = _cand; };};} forEach _near;
if (isNull _veh) exitWith { ["No vehicle you have keys to is parked within 25m, unlocked and free.", "basic"] spawn AP_fnc_handleMessage; };

// per-item transport eligibility for the TARGET vehicle (mirror fn_storeInventory's gates; the house can't even
// hold gold/raw-uranium/jewels, but guard the target anyway so nothing illegal-to-transport ever slips through)
private _vehIsAir = _veh isKindOf "Air";
private _vehIsBox = (typeOf _veh) in ["B_Truck_01_box_F", "C_Van_01_box_F"];
private _fnCanRide = {params ["_cls"];
    if (_cls in ["goldbar", "bank_money"]) exitWith { !_vehIsAir };
    if (_cls in ["uraniumu", "uraniump"]) exitWith { _vehIsBox };
    if (_cls in ["jewelHope", "jewelRolex", "jewelAP", "jewelDiamonds", "jewelGoldBag", "jewelExoJewels", "jewelRing", "jewelBling", "jewelBag"]) exitWith { !_vehIsAir };
    true;};

// plan the transfer up front: greedy over the house inv in order, capped by remaining vehicle room + eligibility
private _hInv = +((_house getVariable ["AP_vinv", [[], 0]]) select 0);   // [[cls,qty],...]
private _vData = +(_veh getVariable ["AP_vinv", [[], 0]]);
private _vWeight = _vData select 1;
private _vcap = _veh getVariable ["AP_vcap", 100];
if (_vcap <= 0) then { _vcap = 100; };
private _room = _vcap - _vWeight;

private _plan = [];                                               // [[cls, unitsToMove], ...]  -- ONLY the highlighted item
{_x params ["_cls", "_qty"];
    if (_cls isEqualTo _selCls && {_qty > 0} && {[_cls] call _fnCanRide}) then {
        private _w = ["getItemWeight", _cls] call AP_fnc_virtItemCfg;
        private _fit = if (_w <= 0) then { _qty } else { floor (_room / _w) };
        _fit = _fit min _qty;
        if (_fit > 0) then {_plan pushBack [_cls, _fit];
            _room = _room - (_fit * _w);};};} forEach _hInv;

if (_plan isEqualTo []) exitWith {
    ["That vehicle can't take that item -- no room, or it can't be transported in that vehicle.", "basic"] spawn AP_fnc_handleMessage;};
private _total = 0; { _total = _total + (_x select 1); } forEach _plan;

// reserve the target + take the run-lock
_veh setVariable ["AP_activeTrunk", player, true];
_veh setVariable ["AP_veh_in_use", player, true];
missionNamespace setVariable ["AP_bulkStore", true];
AP_action_in_use = true;                                        // block the player opening another trunk mid-run
// lock out the other trunk buttons so a manual Take/Store can't mutate the same house AP_vinv mid-run (dupe/loss)
{ if (!isNull (findDisplay 4500)) then { ((findDisplay 4500) displayCtrl _x) ctrlEnable false; }; } forEach [4507, 4508, 4519, 4520, 4521, 4518, 4523];

// HOUSE side: held local copy (its buttons are disabled + reopen is trunkLocked -> nothing else mutates it).
private _hLive = +((_house getVariable ["AP_vinv", [[], 0]]) select 0);
private _fnWeight = { params ["_arr"]; private _w = 0; { _w = _w + ((_x select 1) * (["getItemWeight", _x select 0] call AP_fnc_virtItemCfg)); } forEach _arr; _w; };

// remove up to _n of _cls from the house-local copy; return units actually removed
private _fnHouseTake = {params ["_cls", "_n"];
    private _i = _hLive findIf { (_x param [0, ""]) isEqualTo _cls };
    if (_i < 0) exitWith { 0 };
    private _have = (_hLive select _i) param [1, 0];
    private _got = _n min _have;
    if (_got < 1) exitWith { 0 };
    private _rem = _have - _got;
    if (_rem > 0) then { _hLive set [_i, [_cls, _rem]]; } else { _hLive deleteAt _i; };
    _got;};

// broadcast the house side + refresh the open dialog
private _fnHouseFlush = {private _hw = [_hLive] call _fnWeight;
    _house setVariable ["AP_vinv", [_hLive, _hw], true];
    if (!isNull (findDisplay 4500) && {AP_trunk_vehicle isEqualTo _house} && {AP_is_virtual}) then {
        [_house, true] call AP_fnc_refreshInventory;
        ((findDisplay 4500) displayCtrl 4504) ctrlSetText format ["Weight: %1/%2", _hw, (_house getVariable ["AP_vcap", 100])];};};

// VEHICLE side: RE-READ the live trunk and ADD this tick's units onto it (never a held copy) -> a concurrent
// manual take can't be clobbered; we only ever add the newly-moved units.
private _fnVehMerge = {params ["_adds"];
    if (count _adds < 1) exitWith {};
    private _vCur = +((_veh getVariable ["AP_vinv", [[], 0]]) select 0); {_x params ["_c", "_q"];
        private _j = _vCur findIf { (_x param [0, ""]) isEqualTo _c };
        if (_j < 0) then { _vCur pushBack [_c, _q]; } else { _vCur set [_j, [_c, ((_vCur select _j) param [1, 0]) + _q]]; };
    } forEach _adds;
    _veh setVariable ["AP_vinv", [_vCur, [_vCur] call _fnWeight], true];};

5 cutRsc ["AP_progress", "PLAIN"];
private _ui = uiNamespace getVariable "AP_progress";
private _pg = _ui displayCtrl 38201;
private _pgT = _ui displayCtrl 38202;
_pg progressSetPosition 0.01;

private _vStart = getPosATL _veh;
private _moved = 0;
private _pIx = 0;                                                 // index into _plan
private _pRem = if (_total > 0) then { (_plan select 0) select 1 } else { 0 };

for "_loop" from 0 to 1 step 0 do {
    // abort BEFORE moving -> the prior tick's broadcast is the last consistent state (no clobber on abort)
    if (isNull (findDisplay 4500)) exitWith {};                   // house dialog closed
    if (AP_trunk_vehicle isNotEqualTo _house) exitWith {};
    if (isNull _veh || {!alive _veh}) exitWith {};
    if ((player distance _veh) > 25 || {((getPosATL _veh) distance _vStart) > 5}) exitWith {};   // vehicle driven off
    if (player getVariable ["AP_restrained", false] || {player getVariable ["AP_downed", false]}) exitWith {};

    // pull up to 10 units from the house this tick, collecting per-item adds for the vehicle merge
    private _adds = [];
    private _tick = 0;
    while { _tick < 10 && _pIx < (count _plan) } do {(_plan select _pIx) params ["_cls", "_want"];
        private _n = (10 - _tick) min _pRem;
        private _got = [_cls, _n] call _fnHouseTake;
        if (_got > 0) then {private _ai = _adds findIf { (_x select 0) isEqualTo _cls };
            if (_ai < 0) then { _adds pushBack [_cls, _got]; } else { (_adds select _ai) set [1, ((_adds select _ai) select 1) + _got]; };
            _tick = _tick + _got;
            _moved = _moved + _got;
            _pRem = _pRem - _got;};
        if (_pRem <= 0 || _got < _n) then {                      // this plan item exhausted (or house ran dry) -> next
            _pIx = _pIx + 1;
            _pRem = if (_pIx < (count _plan)) then { (_plan select _pIx) select 1 } else { 0 };};};

    [_adds] call _fnVehMerge;                                    // vehicle: live-merge + broadcast
    call _fnHouseFlush;                                          // house: broadcast + refresh
    _pg progressSetPosition ((_moved / _total) min 1);
    _pgT ctrlSetText format ["Storing to vehicle... %1/%2 items (%3%4)", _moved, _total, round (((_moved / _total) min 1) * 100), "%"];

    if (_pIx >= (count _plan) || _moved >= _total) exitWith {};   // done
    uiSleep 1;};

5 cutText ["", "PLAIN"];
[true] call AP_fnc_saveGear;

// release the vehicle reservation + run-lock
_veh setVariable ["AP_activeTrunk", nil, true];
_veh setVariable ["AP_veh_in_use", nil, true];
missionNamespace setVariable ["AP_bulkStore", false];
AP_action_in_use = false;
// re-enable the trunk buttons if the house dialog is still open
{ if (!isNull (findDisplay 4500)) then { ((findDisplay 4500) displayCtrl _x) ctrlEnable true; }; } forEach [4507, 4508, 4519, 4520, 4521, 4518, 4523];

[["-HOUSEINV-", player, profileName, format ["bulk-stored %1/%2 virtual items from house (ID: %3) into vehicle %4 (%5). POS: %6", _moved, _total, _house getVariable ["AP_houseID", -1], typeOf _veh, _veh getVariable ["AP_dbInfo", "NoVehData"], getPosATL player]], "APS_fnc_logIt", 2, false, false] spawn AP_fnc_MP;

if (_moved >= _total) then {
    titleText [format ["Stored %1 items into your %2.", _moved, getText (configFile >> "CfgVehicles" >> (typeOf _veh) >> "displayName")], "PLAIN"];
} else {titleText [format ["Stored %1 items -- the vehicle is full or you moved away. The rest stayed in your house.", _moved], "PLAIN"];};
