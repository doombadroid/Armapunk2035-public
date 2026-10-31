params[["_item", "", [""]], ["_value", -1, [0]], ["_cWeight", -1, [0]], ["_mWeight", -1, [0]]];
if (_item isEqualTo "" || _value isEqualTo - 1 || _cWeight isEqualTo - 1 || _mWeight isEqualTo - 1) exitWith {};
private _weight = (["getItemWeight", _item] call AP_fnc_virtItemCfg) * _value;
private _sum = _value;
if ((_cweight + _weight) > _mWeight) then {while {true}
    do {_sum = _sum - 1;
        if (_sum < 1) exitWith {};
        _weight = ((["getItemWeight", _item] call AP_fnc_virtItemCfg) * _sum);
        if ((_cWeight + _weight) <= _mWeight) exitWith {};};};
_sum;