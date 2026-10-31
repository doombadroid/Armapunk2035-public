params[["_string", "shitstaincunt", [""]]];
if (_string isEqualTo "shitstaincunt") exitWith {false};
private _chrByte = toArray _string;
private _allowed = toArray("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_ ");
_chrByte findIf {!(_x in _allowed)}
isEqualTo - 1