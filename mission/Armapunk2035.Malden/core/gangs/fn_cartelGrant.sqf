/*
    AP_fnc_cartelGrant  --  apply what APS_fnc_cartelCollectSRV decided this player collected.

    The server has ALREADY zeroed the flag, so nothing here may be dropped silently: whatever the
    inventory cannot carry is handed straight back with APS_fnc_cartelReturnSRV. Zeroing first is
    what stops two players racing the same pile; returning the remainder is what stops the overflow
    vanishing.

    Args: [_cartelName, _items, _cash, _cartelId]
*/
if (isRemoteExecuted && {remoteExecutedOwner != 2}) exitWith {};   // server-origin only: CfgRE allowedTargets limits the target, never the sender
params [["_name", "", [""]], ["_items", [], [[]]], ["_cash", 0, [0]], ["_cartelId", "", [""]]];

if (_cash > 0) then {
    AP_atmcash = AP_atmcash + _cash;
    [format ["<t color='#e7c757'>%1:</t> collected $%2 into your bank account.", _name, [_cash] call AP_fnc_numberText], "basic"] spawn AP_fnc_handleMessage;
    [1] call AP_fnc_ClupdatePartial;   // was AP_fnc_updatePartial, which does not exist (security 2026-09-26)
};

private _left = [];
private _got = [];
{
    _x params [["_cls", ""], ["_qty", 0]];
    if (_cls isEqualTo "" || {_qty <= 0}) then { continue };
    // calWeightDiff returns how many of _cls actually fit in the remaining carry weight
    private _fit = ([_cls, _qty, AP_carryWeight, AP_maxWeight] call AP_fnc_calWeightDiff) max 0;
    private _take = _qty min _fit;
    if (_take > 0) then {
        if ([true, _cls, _take] call AP_fnc_handleInv) then { _got pushBack [_cls, _take]; } else { _take = 0; };
    };
    if ((_qty - _take) > 0) then { _left pushBack [_cls, _qty - _take]; };
} forEach _items;

if !(_got isEqualTo []) then {
    private _txt = "";
    { _txt = _txt + format ["%1 x %2  ", _x select 1, ["getName", _x select 0] call AP_fnc_virtItemCfg]; } forEach _got;
    [format ["<t color='#e7c757'>%1:</t> collected %2", _name, _txt], "basic"] spawn AP_fnc_handleMessage;
};

if !(_left isEqualTo []) then {
    [[_cartelId, _left], "APS_fnc_cartelReturnSRV", 2] spawn AP_fnc_MP;
    [format ["<t color='#e7c757'>%1:</t> you could not carry it all -- the rest was left at the flag.", _name], "basic"] spawn AP_fnc_handleMessage;
};
