params[["_item", "", [""]], ["_type", 0, [0]]];
if (_item isEqualTo "" || _type isEqualTo 0) exitWith {0};
private _ret = 0;
private _weaponArray = [primaryWeapon player, secondaryWeapon player, handgunWeapon player]; {private _weapon = _x;
    private _compatibleItems = ([_weapon] call BIS_fnc_compatibleItems) apply {toLower _x};
    if (toLower _item in _compatibleItems) exitWith {_ret =
        switch (_weapon) do {case (primaryWeapon player): {1};
            case (secondaryWeapon player): {2};
            case (handgunWeapon player): {3};
            default {0};};};}
forEach _weaponArray;
_ret;