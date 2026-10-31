/*
    APS_fnc_gangGarageCount  (LooneyBin: gang-garage count adapter)
    client args: [gangID, player, uid]
    Push the gang's owned-vehicle count to the client as AP_gangGarageCount.
    Was: parseNumber on a pre-typed COUNT(*) col + delivered via AP_fnc_MP (which runs a
    FUNCTION, but AP_gangGarageCount is a VARIABLE -> no-op). Now counts rows + publicVariableClient
    (same proven path as fn_garageCount / AP_garageCount).
*/
params [["_gangID",-1,[0]],["_player",objNull,[objNull]],["_uid","",[""]]];
if (_gangID < 0 || isNull _player) exitWith {};
private _rows = [format ["SELECT id FROM gang_vehicles WHERE gang_id='%1'", _gangID], 2, true] call DB_fnc_asyncQuery;
private _count = if (isNil "_rows" || {!(_rows isEqualType [])}) then { 0 } else { count _rows };
// fn_gangGarageAdd sets `AP_garageCount = -1` then waitUntil's on it (NOT AP_gangGarageCount) —
// set that one or the transfer hangs forever. Set both so any other consumer is covered too.
AP_garageCount = _count;
AP_gangGarageCount = _count;
(owner _player) publicVariableClient "AP_garageCount";
(owner _player) publicVariableClient "AP_gangGarageCount";
