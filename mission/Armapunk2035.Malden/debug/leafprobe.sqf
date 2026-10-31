/*
    debug\leafprobe.sqf -- SERVER ONLY, one-shot. Measures the door-leaf origin
    policy in-engine: bounding box symmetry (autocenter or not), setPosASL
    round-trip, and the real height of spawner leaf 0 vs its hinge.
    grep [LEAFPROBE].
*/
if (!isServer) exitWith {};
private _tag = "[LEAFPROBE]";
uiSleep 25;

// 1) controlled spawn on flat ground far from the tower
private _base = [7400, 10400, 0];
private _z = getTerrainHeightASL _base;
private _l = createSimpleObject [(getMissionPath "custom_p3ds\") + "door_leaf_wide2.p3d", [0,0,0], true];
_l setDir 0;
_l setPosASL [_base select 0, _base select 1, _z + 5];
uiSleep 0.5;
diag_log format ["%1 fresh leaf: getPosASL=%2 bbReal=%3 modelInfo=%4",
    _tag, getPosASL _l, boundingBoxReal _l, getModelInfo _l];
deleteVehicle _l;

// 2) spawner leaf 0: where did it actually land relative to its hinge?
waitUntil { !isNil "AP_SKYDOOR_LEAVES" && { count AP_SKYDOOR_LEAVES > 0 } };
(AP_SKYDOOR_LEAVES select 0) params ["_leaf", "_hingeASL"];
diag_log format ["%1 leaf0: hingeASL=%2 leafPosASL=%3 bbReal=%4",
    _tag, _hingeASL, getPosASL _leaf, boundingBoxReal _leaf];
diag_log format ["%1 leaf0 bottom question: posZ-hingeZ=%2",
    _tag, ((getPosASL _leaf) select 2) - (_hingeASL select 2)];
diag_log format ["%1 done", _tag];
