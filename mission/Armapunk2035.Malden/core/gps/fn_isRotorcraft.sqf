/*
    AP_fnc_isRotorcraft -- is this object or classname a helicopter or a VTOL?
    The autopilot flies both and never a plane. VTOLs inherit Plane_Base_F, so a
    plain "isKindOf Plane" catches them; and their own base class name is not
    something this codebase has ever asserted, so walk the config chain for
    "VTOL" instead of naming it. One predicate, used by every gate.

        [_vehOrClass] call AP_fnc_isRotorcraft   -> Boolean
*/
params [["_v", "", [objNull, ""]]];
private _cls = if (_v isEqualType "") then { _v } else { typeOf _v };
if (_cls isEqualTo "") exitWith { false };
if (_cls isKindOf "Helicopter") exitWith { true };
private _cfg = configFile >> "CfgVehicles" >> _cls;
private _hit = false;
while { isClass _cfg && {!_hit} } do {
    if (((configName _cfg) find "VTOL") > -1) then { _hit = true; };
    _cfg = inheritsFrom _cfg;
};
_hit
