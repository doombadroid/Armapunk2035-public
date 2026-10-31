if !(params[["_array", [], [[]]], ["_element", nil], ["_index", -1, [0]]]) exitWith {};
private _return = []; {_return append _x}
forEach[_array select[0, _index], [_element], _array select[_index, count _array]];
_return;