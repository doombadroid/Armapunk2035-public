if !(AP_effSide isEqualTo civilian) exitWith {};
private _talentsToRemove = AP_side_talents select {["getRowByID", _x] call AP_fnc_talentCfg isEqualTo[]};
if (_talentsToRemove isNotEqualTo[]) then {{private _talent = _x;
        AP_side_talents deleteAt(AP_side_talents findIf {_x isEqualTo _talent});}
    forEach _talentsToRemove;
    [4] call AP_fnc_ClupdatePartial;};