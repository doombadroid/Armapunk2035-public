private _plb_display = findDisplay 39400;
if (isNull _plb_display) exitWith {};
private _sideListGroup = _plb_display displayCtrl 39405;
private _sideItemListButton = _sideListGroup controlsGroupCtrl 1001;
private _dollarsButton = _sideListGroup controlsGroupCtrl 1006;
private _ndButton = _sideListGroup controlsGroupCtrl 1007;
_sideItemListButton ctrlEnable false;
_sideItemListButton ctrlShow false; {_x ctrlEnable true;
    _x ctrlShow true;}
forEach[_dollarsButton, _ndButton];