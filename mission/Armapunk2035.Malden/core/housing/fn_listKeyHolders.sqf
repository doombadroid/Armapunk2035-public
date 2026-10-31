if !(isNull AP_pInact_curTarget) then {private _displayText = "";
    private _keyholders = AP_pInact_curTarget getVariable["AP_house_keys", []]; {_x params["_playerUID", "_playerRank", "_playerName"];
        _displayRank =
        switch (_playerRank) do {case (1): {"Both"};
            case (2): {"Inv"};
            case (3): {"Keys"};}; private _player = allPlayers param[allPlayers findIf {(getPlayerUID _x) isEqualTo _playerUID}, objNull];
        private _onlineText =
        if (isNull _player) then {"Offline"} else {"Online"};
        _displayText = _displayText + (format["%1 (%2) (%3) - %4<br/>", _playerName, _displayRank, _playerUID, _onlineText]);}
    forEach _keyholders;
    if (_displayText isEqualTo "") then {_displayText = "None."};
    [format["<t size='0.85' align='center'>%1</t>", _displayText], "basic"] spawn AP_fnc_handleMessage};