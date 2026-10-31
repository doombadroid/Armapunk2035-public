/*
    debug\mapMigrateWorld.sqf  --  ONE-TIME frame migration read (dev instrumentation)

    Reads the true world transform of every allLocalMapEntities row so tools/mapdata_migrate.py can
    rewrite the array from setPosATL to setPosWorld. After that the array is in the same frame as
    the custom buildings and the composition zones, and mission.sqm converts to and from it entirely
    offline -- which is the whole point of the D2 pipeline (mapedit.md).

    WHY IT SPAWNS RATHER THAN READS: the client streams the array per zone
    (core/functions/fn_dynamicMapSystem.sqf), so the objects are never all in the world at once.
    This reproduces the loader's own client branch -- createSimpleObject local, or createVehicleLocal
    when the row carries an init or a loadout -- because the bounding-centre offset that separates
    ATL from world is a property of the object that gets created.

    X AND Y ARE LOGGED TOO, NOT JUST Z. getPosATL and getPosWorld differ by the transformed
    bounding-centre offset, which is only vertical for a model whose centre sits above its origin.
    Assuming x/y are unchanged would silently shift every model whose centre is offset horizontally.

    Batched with a yield so the client does not hitch; objects are deleted as it goes.
    Output: the client RPT. grep [MAPMIG].

    DEV INSTRUMENTATION -- Task 4 of mapedit_plan.md removes the initPlayerLocal.sqf call.
*/
if (!hasInterface) exitWith {};
if (isNil "allLocalMapEntities") then { [] call AP_fnc_mapData; };

private _tag = "[MAPMIG]";
diag_log format ["%1 ==== start rows=%2 ====", _tag, count allLocalMapEntities];

{
    _x params ["_cls", "_pos", "_dir", ["_code", ""], ["_srv", false], ["_loadout", []]];
    private _i = _forEachIndex;

    // the loader's client branch, verbatim in shape (core/functions/fn_createVehicleLocal.sqf)
    private _o = if (_code isEqualTo "" && {_loadout isEqualTo []}) then {
        createSimpleObject [_cls, [0, 0, 0], true]
    } else {
        _cls createVehicleLocal [0, 0, 0]
    };
    if (isNull _o) then {
        diag_log format ["%1 NULL i=%2 cls=%3", _tag, _i, _cls];
    } else {
        _o enableSimulation false;
        _o allowDamage false;
        if (_dir isEqualType []) then { _o setVectorDirAndUp _dir } else { _o setDir _dir };
        _o setPosATL _pos;                       // exactly what the loader does today
        private _w = getPosWorld _o;
        diag_log format ["%1 i=%2 cls=%3 world=%4,%5,%6", _tag, _i, _cls,
            (_w select 0) toFixed 4, (_w select 1) toFixed 4, (_w select 2) toFixed 4];
        deleteVehicle _o;
    };

    if (_i % 250 == 249) then { uiSleep 0.05 };   // yield so the client does not hitch
} forEach allLocalMapEntities;

diag_log format ["%1 ==== end rows=%2 ====", _tag, count allLocalMapEntities];
