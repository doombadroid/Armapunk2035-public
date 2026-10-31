params["_control", "_selectedIndex"];
private _eventID = parseNumber(_control lbData _selectedIndex);
private _display = findDisplay 3900;
private _eventLocationsList = _display displayCtrl 3902;
private _eventLocations = ["getEventLocationRows", _eventID] call AP_fnc_eventCfg;
lbClear _eventLocationsList;
private _index = -1; {_index = _eventLocationsList lbAdd format["%1", _x select 1];
    _eventLocationsList lbSetData[_index, (str(_x select 0))];}
forEach _eventLocations;