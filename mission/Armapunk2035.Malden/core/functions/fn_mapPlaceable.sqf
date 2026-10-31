/*
    File: fn_mapPlaceable.sqf  (AP_fnc_mapPlaceable)
    May the map editor place this class? ONE definition, two machines.

    The client's catalogue and the server's authority must agree exactly. If the
    catalogue is looser, the editor offers props the server silently refuses and the
    tool looks broken; if it is tighter, half the world becomes unplaceable for no
    visible reason. This repo has already paid for duplicated rules three times over
    in one day -- the bake key was inlined in three places and was wrong in all three.

    The server compiles BOTH CfgFunctions trees into missionNamespace, so this
    AP_fnc_* is callable from AP_server. APS_fnc_mapEditSRV calls it; the client
    catalogue calls it; nothing re-derives it.

    THE RULE: inert world geometry only. Anything alive, drivable or lootable is
    refused, because an ungated editor is otherwise a vehicle and crate spawner for
    whoever holds a level-5 session.

    params: 0 = classname
    returns: true if placeable
*/
params [["_class", "", [""]]];
if (_class isEqualTo "") exitWith { false };
if !(isClass (configFile >> "CfgVehicles" >> _class)) exitWith { false };

// Inert geometry. Land_* props are Static or Thing; buildings are Building.
private _ok = (_class isKindOf "Building")
           || (_class isKindOf "Static")
           || (_class isKindOf "Thing");

// Anything that moves, breathes, drives or holds loot. ReammoBox_F and WeaponHolder
// are Thing descendants, so they pass the check above and must be named here.
private _bad = (_class isKindOf "AllVehicles")
            || (_class isKindOf "CAManBase")
            || (_class isKindOf "ReammoBox_F")
            || (_class isKindOf "WeaponHolder")
            || (_class isKindOf "WeaponHolderSimulated")
            || (_class isKindOf "Bag_Base")
            || (_class isKindOf "TimeBombCore")
            || (_class isKindOf "MineBase");

_ok && !_bad
