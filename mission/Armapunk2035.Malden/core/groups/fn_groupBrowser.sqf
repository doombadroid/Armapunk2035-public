disableSerialization;
waitUntil {!isNull(findDisplay 2520)};
private _dialog = findDisplay 2520;
private _list = _dialog displayCtrl 2521;
// LooneyBin #519: the browse list of player-created (custom) groups came up EMPTY.
// Root cause: `randomized_life_group_list sort true` sorts an array whose elements are
// 5-tuples [name(STRING), group(GROUP), locked(BOOL), ownerPID(STRING), password(STRING)].
// Arma's `sort` only handles Numbers/Strings/sub-arrays-of-those; a Group object + Boolean
// inside every element makes the array non-sortable -> sort silently yields a broken/empty
// result, so no custom groups were ever lbAdd'd (gang squads were never in this list, so the
// menu looked like "gangs OK, custom groups missing"). Sort a name-keyed copy instead (the
// engine only ever compares the leading STRING), which is guaranteed sortable and preserves
// the intended alphabetical ordering. (2017 original did not sort at all.)
private _names = (randomized_life_group_list apply { _x select 0 });
_names sort true; // pure array of Strings -> always sortable (alphabetical)
private _sortedPlayers = _names apply {private _n = _x;
    randomized_life_group_list param [(randomized_life_group_list findIf { (_x select 0) isEqualTo _n }), []]}; {
    _x params[["_name", "", [""]], ["_group", grpNull, [grpNull]], ["_locked", false, [false]], "_ownerPID", "_password"];
    if !(isNull _group) then {private _extra =
        if (_locked) then {"[PASS]"} else {"[UNLOCKED]"};
        private _index = _list lbAdd format["%1 [Members: %2] - %3", _name, count(units _group), _extra];
        _list lbSetData[_index, _name];};}
forEach(_sortedPlayers);
if (lbSize _list isEqualTo 0) then {_list lbAdd "No groups are available. Create one instead!";
    (_dialog displayCtrl 2522) ctrlEnable false;};