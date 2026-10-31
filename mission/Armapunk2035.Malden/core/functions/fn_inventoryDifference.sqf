private _old = (param[0, [[], 0]]) select 0;
private _new = (param[1, [[], 0]]) select 0;
private _change = []; {_x params["_item", "_oldAmount"];
    private _index = _new findIf {_item in _x};
    if (_index isEqualTo - 1) then {_change pushBack[_item, "-" + str _oldAmount];} else {
        (_new select _index) params["_item", "_newAmount"];
        if !(_newAmount isEqualTo _oldAmount) then {private _diff =
            if (_newAmount > _oldAmount) then {"+" + str(_newAmount - _oldAmount)} else {"-" + str(_oldAmount - _newAmount)};
            _change pushBack[_item, _diff];};};}
forEach _old; {_x params["_item", "_amount"];
    private _index = _old findIf {_item in _x};
    if (_index isEqualTo - 1) then {_change pushBack[_item, "+" + str _amount]}}
forEach _new;
if (_change isEqualTo[]) then {"None"} else {_change}