private _data = _this select 0;
private _return = ""; {private _format = format["%1<br/>", _x select 1];
    _return = _return + _format;}
forEach _data;
_return;