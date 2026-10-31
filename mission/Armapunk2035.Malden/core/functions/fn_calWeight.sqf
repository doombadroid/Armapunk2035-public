private _calcWeight = 0;
private _val = 0;
private _itemWeight = 0;
private _shortName = ""; {
    _val = missionNameSpace getVariable [_x, 0];   // owner 2026-06-25: was `getVariable _x` (NO default) -> nil for any
    if (_val > 0) then {                            // uninitialized AP_inv_* -> `nil > 0` threw "Undefined variable" EVERY weight calc (3452x/24h, 55 players)
        _shortName = ["getShortName", _x] call AP_fnc_virtItemCfg;
        _itemWeight = (["getItemWeight", _shortName] call AP_fnc_virtItemCfg) * _val;
        _calcWeight = _calcWeight + _itemWeight;};}
forEach([1] call AP_fnc_virtItemCfg);
AP_carryWeight = _calcWeight;