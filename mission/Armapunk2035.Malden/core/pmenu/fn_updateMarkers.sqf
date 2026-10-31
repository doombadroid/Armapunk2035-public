params[["_color", [], [[]]], ["_value", 1, [0]], ["_isPlayerHouse", false]]; {if ((getMarkerColor _x) in _color) then {
        if (_x find "_USER_DEFINED" == -1) then {
            if ((_x find "phouse_" == -1 && !_isPlayerHouse) || (_isPlayerHouse && "phouse_" in _x)) then {
                if (_x find "bounty_" == -1) then {_x setMarkerAlphaLocal _value;};};};};}
forEach allMapMarkers;