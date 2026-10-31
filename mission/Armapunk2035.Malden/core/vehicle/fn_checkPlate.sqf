params[["_string", "", [""]]];
if (_string isEqualTo "") exitWith {true};
if (count _string > 9) exitWith {
    ["Your custom license plate contains too many characters. The character limit is 9. You must fix it before purchasing your modifications.", "basic"] spawn AP_fnc_handleMessage;
    false};
private _allowedChars = toArray "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_ ";
private _chrByte = toArray _string;
private _allowed = _chrByte findIf {!(_x in _allowedChars)}
isEqualTo - 1;
if !(_allowed) exitWith {
    ["Your custom license plate contains unsupported characters. You must fix it before purchasing your modifications.", "basic"] spawn AP_fnc_handleMessage;
    false};
private _badWords = ["call ", "spawn ", "execVM", "nigg", "chink", "fag", "server", "admin", "adm1n", "n1g"];
private _allowed = _badWords findIf {(toLower _x) in (toLower _string)}
isEqualTo - 1;
if !(_allowed) exitWith {
    ["Your custom license plate contains disallowed content. You must fix it before purchasing your modifications.", "basic"] spawn AP_fnc_handleMessage;
    false};
_allowed