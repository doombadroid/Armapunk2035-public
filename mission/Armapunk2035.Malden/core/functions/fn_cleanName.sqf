params[["_rawName", "", [""]], ["_type", 0, [0]]];
private _return =
switch (_type) do {case 0: {private _replace = false;
            private _repChars = ["<", ">", '"', "&"];
            private _arrayName = _rawName splitString ""; {if (_x in _repChars) exitWith {_replace = true};}
            forEach _arrayName;
            if (_replace) then {private _name = []; {if (_x in _repChars) then {_x = "-"};
                    _name pushBack _x;}
                forEach _arrayName;
                _name joinString "";} else {_rawName;};};
    case 1: {private _arrayName = _rawName splitString "";
            private _replace = false;
            private _allowedChars = "aAbBcCdDeEfFgGhHiIjJkKlLmMnNoOpPqQrRsStTuUvVwWxXyYzZ0123456789[]()-= "
            splitString ""; {if !(_x in _allowedChars) exitWith {_replace = true};}
            forEach _arrayName;
            if (_replace) then {private _newname = []; {if !(_x in _allowedChars) then {_x = ""};
                    _newname pushBack _x;}
                forEach _arrayName;
                _newname joinString "";} else {_rawName;};};
    case 2: {private _arrayName = _rawName splitString "";
            private _replace = false;
            private _allowedChars = "aAbBcCdDeEfFgGhHiIjJkKlLmMnNoOpPqQrRsStTuUvVwWxXyYzZ"
            splitString ""; {if !(_x in _allowedChars) exitWith {_replace = true};}
            forEach _arrayName;
            if (_replace) then {private _newname = []; {if !(_x in _allowedChars) then {_x = ""};
                    _newname pushBack _x;}
                forEach _arrayName;
                _newname joinString "";} else {_rawName;};};
    default {_rawName};}; _return ;