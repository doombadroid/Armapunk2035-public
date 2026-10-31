/*
    APS_fnc_gangGarageGetVehicles  (LooneyBin: gang-garage retrieve adapter)
    client args: [gangID, player, uid, type]
    Query the gang's STORED vehicles of _type (active=0), reshape to the index layout
    fn_gangGarageMenu / fn_gangGaragePull consume, send wrapped to AP_fnc_gangGarageMenu
    -> AP_garageData. Mirrors fn_getVehicles (personal garage); idx 4 = gang_id (the
    ownership check is `AP_gang_data param[0] isEqualTo (_x select 4)`), not pid.
    asyncQuery call-compiles the result: QUOTE the varchar (classname) or compile dies on the
    bare token; numeric cols arrive already typed (do NOT parseNumber). Sent wrapped [_out]
    because fn_gangGarageMenu does params[["_garageArr",[],[[]]]] -> reads _this#0 as the list.
*/
params [["_gangID",-1,[0]],["_player",objNull,[objNull]],["_uid","",[""]],["_type","Car",[""]]];
if (_gangID < 0 || isNull _player) exitWith {};

private _q = format ["SELECT id,classname,gang_id,plate,color,alarm FROM gang_vehicles WHERE gang_id='%1' AND active = false AND type='%2' ORDER BY classname, color", _gangID, _type];
private _rows = [_q, 2, true] call DB_fnc_asyncQuery;
if (isNil "_rows" || {!(_rows isEqualType [])}) then { _rows = []; };

// Cols pre-typed: id/gang_id/plate/color/alarm = Number, classname = String (QUOTE'd).
private _out = _rows apply {[_x select 0,                    // 0  id
        "",                             // 1
        _x select 1,                    // 2  classname
        "",                             // 3
        _x select 2,                    // 4  gang_id (ownership check)
        "",                             // 5
        "",                             // 6
        _x select 3,                    // 7  plate
        _x select 4,                    // 8  color
        "",                             // 9
        [_x select 5,0,0,0,0,0,0,0,0],  // 10 mods (slot 0 = alarm)
        [0,0.5],                        // 11 vehWear
        ""                              // 12 customPlate
    ]};

[[_out], "AP_fnc_gangGarageMenu", _player, false] spawn AP_fnc_MP;
