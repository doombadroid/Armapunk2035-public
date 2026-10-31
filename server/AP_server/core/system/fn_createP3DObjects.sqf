// File: fn_createP3DObjects.sqf
// Author: Infamous
// Description: creates police objects from the server side.

// params
params ["_vehicle"];

private _positions = [[-0.04,2.15,-0.8],[-0.04,-0.1,0.2]];
private _pos = getPosWorld _vehicle;

_pushbar = createSimpleObject [getMissionPath "custom_p3ds\pushbar.p3d", _pos];
_pushbar attachTo [_vehicle,(_positions select 0)];

// adds lightbar to police vehicles
_lightbar = createSimpleObject [getMissionPath "custom_p3ds\lightbar.p3d", _pos];
_lightbar attachTo [_vehicle,(_positions select 1)];

diag_log format["P3D Objects created for vehicle: %1 with objects %2 and %3", _vehicle, _pushbar, _lightbar];
