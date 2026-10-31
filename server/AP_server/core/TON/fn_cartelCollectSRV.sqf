/*
    APS_fnc_cartelCollectSRV  --  authority for collecting a cartel's accrued payout at its flag.

    Client args: [_cartelId]   -- an ID ONLY. The client never sends an amount.

    That is deliberate. fn_cartelSRV shipped with an unbounded client-supplied _value that let a gang
    holding a cartel credit itself ~1B per call (security.md 2.1 HIGH). Here the server reads the
    stock off the flag itself, decides the amount, decrements it, and then tells the client what it
    got -- so there is no number on the wire to tamper with.

    Validates: cartel exists, flag exists, the caller's gang FULLY owns it (progress >= 1), the
    caller is alive and within 8m of the flag (server-side distance -- a client claim would be
    forgeable), and there is stock to take.
*/
params [["_cartelId", "", [""]], ["_unit", objNull, [objNull]]];
if (isNull _unit) exitWith {};
if !(alive _unit) exitWith {};

private _roster = [] call AP_fnc_cartelCfg;
private _idx = _roster findIf { (_x select 0) isEqualTo _cartelId };
if (_idx < 0) exitWith {};
(_roster select _idx) params ["_id", "_name", "_flagVar", "", "", "", "_payout", ""];

private _flag = missionNamespace getVariable [_flagVar, objNull];
if (isNull _flag) exitWith {};
if ((_unit distance2D _flag) > 8) exitWith {
    [["You need to be at the flag to collect.", "basic"], "AP_fnc_handleMessage", _unit, false, false] spawn AP_fnc_MP;};

(_flag getVariable ["AP_capData", [0, "Neutral", 0]]) params [["_gangID", 0], ["_gangName", ""], ["_progress", 0]];
private _myGang = (_unit getVariable ["gang_data", [0]]) param [0, 0];
if (_progress < 1 || {(format ["%1", _gangID]) isEqualTo "0"}
    || {(format ["%1", _myGang]) isNotEqualTo (format ["%1", _gangID])}) exitWith {
    [[format ["%1 is not held by your gang.", _name], "basic"], "AP_fnc_handleMessage", _unit, false, false] spawn AP_fnc_MP;};

private _mode = _payout param [0, ""];

if (_mode isEqualTo "money") exitWith {
    if ((_payout param [3, "flag"]) isEqualTo "bank") exitWith {
        [[format ["%1 pays straight into the gang bank -- nothing to collect here.", _name], "basic"],
         "AP_fnc_handleMessage", _unit, false, false] spawn AP_fnc_MP;};
    private _cash = _flag getVariable ["AP_cartelCash", 0];
    if (_cash <= 0) exitWith {
        [[format ["%1 has nothing banked yet.", _name], "basic"], "AP_fnc_handleMessage", _unit, false, false] spawn AP_fnc_MP;};
    _flag setVariable ["AP_cartelCash", 0, true];
    [[_name, [], _cash], "AP_fnc_cartelGrant", _unit, false, false] spawn AP_fnc_MP;
    [[998, objNull, format ["Cartel collect: %1 took $%2 from %3", name _unit, _cash, _name]], "APS_fnc_logIt", 2] spawn AP_fnc_MP;
};

if !(_mode isEqualTo "items") exitWith {};

private _stock = +(_flag getVariable ["AP_cartelStock", []]);
private _give = _stock select { (_x select 1) > 0 };
if (_give isEqualTo []) exitWith {
    [[format ["%1 has produced nothing yet.", _name], "basic"], "AP_fnc_handleMessage", _unit, false, false] spawn AP_fnc_MP;};

// zero the flag here; the client applies what its inventory can actually carry and hands back the
// remainder via AP_fnc_cartelGrant -> APS_fnc_cartelReturnSRV, so nothing is duplicated or lost.
{ _x set [1, 0]; } forEach _stock;
_flag setVariable ["AP_cartelStock", _stock, true];
[[_name, _give, 0, _cartelId], "AP_fnc_cartelGrant", _unit, false, false] spawn AP_fnc_MP;
[[998, objNull, format ["Cartel collect: %1 took %2 from %3", name _unit, str _give, _name]], "APS_fnc_logIt", 2] spawn AP_fnc_MP;
