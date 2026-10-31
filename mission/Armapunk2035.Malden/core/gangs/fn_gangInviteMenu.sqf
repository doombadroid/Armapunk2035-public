["gangMenuInv"] call AP_fnc_createDialog;
disableSerialization;
private _display = findDisplay 9550;
private _list = _display displayCtrl 9555;
private _players = (allPlayers - [player]) select {alive _x && side _x isEqualTo civilian && _x getVariable["gang_data", []] isEqualTo[]}
apply {name _x};
private _sorted = _players call BIS_fnc_sortAlphabetically;
lbClear _list; {private _name = _x; {if (name _x isEqualTo _name) then {private _index = _list lbAdd(name _x);
            _list lbSetData[_index, str _x];};}
    forEach allPlayers;}
forEach _sorted;
lbSetCurSel[9555, 0];