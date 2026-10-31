/*
    AP_fnc_trunkCloseSettle -- the trunk session CLOSE choreography, extracted
    from fn_openInventory so the native dialog and the deck trunk app run the
    SAME copy. This block carries two paid-for lessons and must never fork:

      Jeff Stall dupe (2026-06-19): a take fired just before close had not
      propagated when the server snapshotted -- so the CLIENT-authoritative
      post-take inventory is passed to the save, the trunk locks first, and
      the save happens after a 1.25s settle.
      #542 (2026-06-25): the session GEN (bumped by each hydrate) rides the
      save so a newer open during the settle no-ops this stale close instead
      of wiping the live session.

    [_object, _fromDeck] -- _fromDeck waits on the deck session flag instead
    of dialog 4500. Everything after the wait is identical.
*/
params [["_object", objNull, [objNull]], ["_fromDeck", false, [false]]];
if (isNull _object) exitWith {};

private _oldVirt = +(_object getVariable ["AP_vinv", [[], 0]]);
private _oldPhys = +(_object getVariable ["AP_pinv", [[], 0]]);
if (_fromDeck) then {
    waitUntil { uiSleep 0.25;
        isNull (findDisplay 937500) || {!(missionNamespace getVariable ["AP_trunkDeckOpen", false])} };
} else {
    waitUntil { isNull (findDisplay 4500) };
};
AP_trunk_vehicle setVariable ["AP_activeTrunk", nil, true];
AP_action_in_use = false;
if (AP_inventoryInteraction) then {
    [true] call AP_fnc_saveGear;
    AP_inventoryInteraction = false;
};
if (AP_movedItem) then {
    AP_trunk_vehicle setVariable ["AP_vinv", (AP_trunk_vehicle getVariable "AP_vinv"), true];
    AP_trunk_vehicle setVariable ["AP_pinv", (AP_trunk_vehicle getVariable "AP_pinv"), true];
    AP_movedItem = false;
};
[_object] call AP_fnc_slingAndMass;
private _get_inv = {
    private _array = [];
    private _val = 0;
    {
        _val = missionNamespace getVariable [format ["AP_inv_%1", _x], 0];
        if (_val > 0) then { _array pushBack [_x, _val]; };
    } forEach ([2] call AP_fnc_virtItemCfg);
    _array
};
private _newVirt = _object getVariable ["AP_vinv", [[], 0]];
private _newPhys = _object getVariable ["AP_pinv", [[], 0]];
if (_object isKindOf "House_F") then {
    [["-HOUSEINV-", player, (profileName), format ["closed storage of house (HouseID: %1 | Owner: %2 | Position: %3). Virtual change: %4, Physical change: %5, Player Virtual Inventory: %6, Player Physical Inventory: %7",
        _object getVariable ["AP_houseID", -1], _object getVariable ["AP_homeOwner", "NoPidVar"], getPosATL _object,
        [_oldVirt, _newVirt] call AP_fnc_inventoryDifference, [_oldPhys, _newPhys] call AP_fnc_inventoryDifference,
        [] call _get_inv, getUnitLoadout player]], "APS_fnc_logIt", 2] spawn AP_fnc_MP;
} else {
    [["-VEHINV-", player, (profileName), format ["closed vehicle trunk (Vehicle: %1 | Owner: %2 | Position: %5). Virtual change: %3, Player Virtual Inventory: %4",
        typeOf _object, _object getVariable ["AP_dbInfo", "NoVehData"],
        [_oldVirt, _newVirt] call AP_fnc_inventoryDifference, [] call _get_inv, getPosATL player]], "APS_fnc_logIt", 2] spawn AP_fnc_MP;
};
AP_trunk_vehicle = objNull;
if (_object isKindOf "House_F") then {
    // Jeff Stall + #542, verbatim -- see header
    _object setVariable ["AP_trunkLock", true, true];
    private _gen = _object getVariable ["AP_invGen", 0];
    [player, _object, _newVirt, _newPhys, _gen] spawn {
        params ["_pl", "_obj", "_v", "_p", "_g"];
        uiSleep 1.25;
        [[_pl, _obj, _v, _p, _g], "APS_fnc_updateHouseTrunk", false, false] spawn AP_fnc_MP;
        uiSleep 0.75;
        if (!isNull _obj) then { _obj setVariable ["AP_trunkLock", false, true]; };
    };
};
