params[["_inventoryArray", [], []], ["_itemShort", "", [""]], ["_amount", 0, [0]], ["_add", true, [true]]];
if (_inventoryArray isEqualTo[] || _itemShort isEqualTo "" || _amount isEqualTo 0) exitWith {};
_inventoryArray params["_items", "_totalWeight"];
private _index = _items findIf {_itemShort in _x};
private _itemWeight = ["getItemWeight", _itemShort] call AP_fnc_virtItemCfg;
if (_add) then {if (_index isEqualTo - 1) then {_items pushBack[_itemShort, _amount];} else {
        private _oldAmount = (_items select _index) select 1;
        (_items select _index) set[1, _oldAmount + _amount];};
    _totalWeight = _totalWeight + (_itemWeight * _amount);} else {if !(_index isEqualTo - 1) then {
        if (_amount isEqualTo((_items select _index) select 1)) then {_items deleteAt _index;} else {
            private _oldAmount = (_items select _index) select 1;
            (_items select _index) set[1, _oldAmount - _amount];};
        _totalWeight = _totalWeight - (_itemWeight * _amount);};};
[_items, _totalWeight]