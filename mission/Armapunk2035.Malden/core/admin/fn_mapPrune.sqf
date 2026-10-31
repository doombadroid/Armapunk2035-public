/*
    File: fn_mapPrune.sqf  (AP_fnc_mapPrune)
    Delete the map object you are looking at.

    The one thing 3DEN is bad at: you are standing in the world, a prop is in the
    wrong place or should not exist, and finding it again in the editor means
    matching a position by eye. This asks the server to hide it, right now.

    It is a REQUEST. The world does not change here -- APS_fnc_mapEditSRV decides,
    persists, and the change arrives back through AP_fnc_mapEditApply like any
    other edit, so the admin sees exactly what every other player sees.

    Level 5 is re-checked server-side; the client-side check only decides whether the
    action does anything locally, so a modified client gains nothing by lying to itself.
    Read it with `call AP_adminLevel` -- it is a FUNCTION in this codebase, not a plain
    mission variable, and getVariable on that name returns 0 for everyone.
*/
if (!hasInterface) exitWith {};
if ((call AP_adminLevel) < 5) exitWith {};

private _obj = cursorObject;
if (isNull _obj) exitWith { hint "Prune: nothing under the cursor."; };

private _id = _obj getVariable ["AP_mapId", -1];
if (_id < 1) exitWith { hint "Prune: that is not a map object (no AP_mapId) -- mission content, a vehicle or a player."; };
[["del", [_id]], "APS_fnc_mapEditSRV", 2, false] spawn AP_fnc_MP;
hint format ["Prune: requested delete of row %1", _id];
