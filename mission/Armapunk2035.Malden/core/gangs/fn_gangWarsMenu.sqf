disableSerialization;
if (AP_gang_data isEqualTo[]) exitWith {};
waitUntil {!isNull(findDisplay 9580)};
private _display = findDisplay 9580;
private _gangList = _display displayCtrl 9581;
lbClear _gangList;
ctrlSetText[9585, (format["Gang War Management - %1", AP_gang_data select 1])];
ctrlEnable[9582, false];
ctrlEnable[9583, false];
ctrlEnable[9584, false];
private _gangIDs = [AP_gang_data select 0]; {private _xGangData = _x getVariable["gang_data", [-1, ""]] params["_xGangID", "_xGangName"];
    if !((_xGangID in _gangIDs) || (_xGangID isEqualTo - 1) || (_xGangName isEqualTo "")) then {_gangIDs pushBack _xGangID;
        private _label = _xGangName;
        if (_xGangID in AP_gang_wars) then {_label = "[WARRING] " + _label;};
        if (_xGangID in AP_gang_challenges) then {_label = "[CHALLENGED] " + _label};
        private _index = _gangList lbAdd _label;
        private _color =
        if (_xGangID in AP_gang_wars) then {[0.87, 0.24, 0.14, 1]} else {[1, 1, 1, 1]};
        _gangList lbSetColor[_index, _color];
        _gangList lbSetSelectColor[_index, _color];
        _gangList lbSetData[_index, str _xGangID];};}
forEach(allPlayers select {side _x isEqualTo civilian});
lbSort _gangList;
lbSetCurSel[9581, -1];