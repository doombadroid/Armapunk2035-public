/*
    APS_fnc_cartelReturnSRV  --  put back what a collector could not carry.

    fn_cartelCollectSRV zeroes the flag's stock at the moment of collection so two players cannot
    race the same pile. The client then adds only what its weight limit allows and returns the
    remainder here, which is added back to the flag (still capped).

    The client can only ever RETURN goods, never take them, so an inflated value costs the caller
    inventory it already spent -- there is nothing to gain by lying. The per-item cap is re-read from
    the config server-side so a returned amount cannot push a flag above its configured maximum.
*/
params [["_cartelId", "", [""]], ["_left", [], [[]]]];
if (_left isEqualTo []) exitWith {};

private _roster = [] call AP_fnc_cartelCfg;
private _idx = _roster findIf { (_x select 0) isEqualTo _cartelId };
if (_idx < 0) exitWith {};
(_roster select _idx) params ["", "", "_flagVar", "", "", "", "_payout", ""];
private _flag = missionNamespace getVariable [_flagVar, objNull];
if (isNull _flag) exitWith {};

private _caps = _payout param [1, []];
private _stock = +(_flag getVariable ["AP_cartelStock", []]);
{   _x params [["_cls", ""], ["_qty", 0]];
    if (_cls isEqualTo "" || {_qty <= 0}) then { continue };
    private _ci = _caps findIf { (_x select 0) isEqualTo _cls };
    if (_ci < 0) then { continue };                      // not a good this cartel produces -- refuse
    private _cap = (_caps select _ci) select 2;
    private _i = _stock findIf { (_x select 0) isEqualTo _cls };
    if (_i < 0) then { _stock pushBack [_cls, _qty min _cap]; }
    else { (_stock select _i) set [1, (((_stock select _i) select 1) + _qty) min _cap]; };
} forEach _left;
_flag setVariable ["AP_cartelStock", _stock, true];
