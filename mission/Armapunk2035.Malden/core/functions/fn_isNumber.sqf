params["_value"];
private _valid = ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9"];
private _array = _value splitString "";
private _return = (({!(_x in _valid)}
count _array) isEqualTo 0);
_return;