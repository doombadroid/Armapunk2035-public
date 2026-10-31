params[["_loadout", [], [[]]]];
if (_loadout isEqualTo[]) exitWith {[]};
_loadout params[["_primary", [], [[]]], ["_secondary", [], [[]]], ["_hgun", [], [[]]], ["_uniform", [], [[]]], ["_vest", [], [[]]
], ["_backpack", [], [[]]], ["_helmet", "", [""]], ["_facewear", "", [""]], ["_binos", [], [[]]], ["_assignedItems", [], [[]]]];
private _items = []; {if !(_x isEqualTo[]) then {_items pushBack[_x select 0, 1];
        if !((_x select 1) isEqualTo "") then {_items pushBack[_x select 1, 1];};
        if !((_x select 2) isEqualTo "") then {_items pushBack[_x select 2, 1];};
        if !((_x select 3) isEqualTo "") then {_items pushBack[_x select 3, 1];};
        if !((_x select 4) isEqualTo[]) then {_items pushBack[(_x select 4) select 0, 1];};
        if !((_x select 5) isEqualTo[]) then {_items pushBack[(_x select 5) select 0, 1];};
        if !((_x select 6) isEqualTo "") then {_items pushBack[_x select 6, 1];};};}
forEach[_primary, _secondary, _hgun]; {if !(_x isEqualTo[]) then {_items pushBack[_x select 0, 1];
        if !((_x select 1) isEqualTo[]) then {{_x params["_item", "_itemCount"];
                if (_item isEqualType[]) then {{if (_x isEqualType "" && {_x != ""}) then {private _count =
                            if (_forEachIndex isEqualTo 0) then {_itemCount} else {1};
                            _items pushBack[_x, _count];};
                        if (_x isEqualType[] && {!(_x isEqualTo[])}) then {_items pushBack[_x select 0, 1];};}
                    forEach _item;} else {_items pushBack[_item, _itemCount];}}
            forEach(_x select 1);};};}
forEach[_uniform, _backpack, _vest];
if !(_helmet isEqualTo "") then {_items pushBack[_helmet, 1];};
if !(_facewear isEqualTo "") then {_items pushBack[_facewear, 1];};
if !(_binos isEqualTo[]) then {_items pushBack[_binos select 0, 1];};
if !(_assignedItems isEqualTo[]) then {if !((_assignedItems select 1) isEqualTo "") then {_items pushBack[_assignedItems select 0, 1];};
    if !((_assignedItems select 5) isEqualTo "") then {_items pushBack[_assignedItems select 5, 1];};};
private _fnc_adjustArray = {params["_item", "_count", "_array"];
    if !(_item isEqualTo "") then {private _index = -1; {if !(_index isEqualTo - 1) exitWith {};
            if (_item isEqualTo(_x select 0)) exitWith {_index = _forEachIndex;};}
        forEach _array;
        if (_index isEqualTo - 1) then {_array pushBack[_item, _count];} else {
            _array set[_index, [_item, ((_array select _index) select 1) + _count]];};};
    _array;};
private _newInv = []; {_newInv = [_x select 0, _x select 1, _newInv] call _fnc_adjustArray;}
forEach _items;
_newInv;