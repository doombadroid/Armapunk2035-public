params[["_number", 0, [0]], ["_toFixed", 0, [0]], "_return"];
private _numberText = _number toFixed _toFixed;
private _num = (count _numberText);
for "_index"
from(_num - 3) to 1 step - 3 do {_numberText = (_numberText select[0, _index]) + "," + (_numberText select[_index]);
    _num = _num + 1;}; _numberText ;