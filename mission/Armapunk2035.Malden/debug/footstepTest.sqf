/*
    debug/footstepTest.sqf -- ask the ENGINE what surface is under your feet.

    createSimpleObject was ruled out as the cause (a stock house spawned that way has footsteps), so
    the fault is the roadway surface on our models. Rather than guess at the convention again, this
    reads it back: lineIntersectsSurfaces returns the intersected object AND the surface type Arma
    resolved for that face.

    Stand on the floor and run it. Do it in three places and compare:
        1. inside the stock test house (known-good)
        2. inside the palace       (silent)
        3. on open terrain         (known-good, for reference)

        [] execVM "debug\footstepTest.sqf";
*/
if (!hasInterface) exitWith {};
private _p = getPosASL player;
private _res = lineIntersectsSurfaces [
    _p vectorAdd [0,0,1.2], _p vectorAdd [0,0,-2.0],
    player, objNull, true, 8, "GEOM", "NONE"];

diag_log format ["[SURF] --- at %1, %2 hit(s) ---", getPosATL player, count _res];
["<t color='#e7c757'>[SURF]</t> " + str (count _res) + " hit(s) -- see RPT", "basic"] spawn AP_fnc_handleMessage;
{
    _x params ["_pos","_norm","_obj","_parent","_sel","_surf"];
    diag_log format ["[SURF]  hit%1 obj=%2 model=%3 isTerrain=%4 selections=%5 SURFACETYPE=%6",
        _forEachIndex,
        if (isNull _obj) then {"(terrain)"} else {typeOf _obj},
        if (isNull _obj) then {""} else {(getModelInfo _obj) param [0,""]},
        isNull _obj, _sel, _surf];
} forEach _res;

// what Arma reports for the terrain underneath, for comparison
diag_log format ["[SURF]  terrain surfaceType here = %1", surfaceType (getPosATL player)];
