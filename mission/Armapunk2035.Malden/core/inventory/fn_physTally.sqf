/*
    fn_physTally.sqf  (AP_fnc_physTally)  --  the player's physical gear, tallied by class.

    Returns [[classname, qty], ...] -- the same shape AP_pinv holds, and the same shape
    fn_refreshInventory builds into its `_pCache` before writing TrunkMenu's player list.

    WHY IT IS ITS OWN FUNCTION. This walk existed in three places already
    (fn_refreshInventory's _pCache, fn_refreshAdminInventory, and the STORAGE bridge's own
    data builder) and a fourth was needed: fn_storeInventory's physical branch takes a
    quantity CEILING from its caller now (_deckMax), and the caller has to know how many of
    a class the player is actually holding. A ceiling computed from a tally that disagrees
    with the one the mover uses is worse than no ceiling.

    THE SET IS DELIBERATELY fn_refreshInventory's, NOT a superset. It walks worn slots,
    container contents, the three weapons with their attachments and loaded magazines, and
    assigned items -- and it does NOT walk `weaponsItemsCargo (unitBackpack player)`, the
    weapons carried INSIDE a backpack. Those cannot be stored individually: the store
    switch's default case is gated on `_playerItemSelected in (itemsWithMagazines player)`,
    which a backpack-cargo weapon is not, so it exits before touching anything. (It fails
    closed -- nothing is duplicated -- but listing a row nobody can move is a bug report
    waiting to happen.) They still store WITH the bag: fn_storeInventory's Backpack case
    walks weaponsItemsCargo itself and folds those classes in before removeBackpackGlobal.

    fn_refreshInventory keeps its own copy. Rewriting how TrunkMenu paints its list is not
    this function's business, and that copy is load-bearing for the dialog's lbValue writes.
*/
private _tally = createHashMap;
private _fnAdd = {
    params [["_cls", "", [""]]];
    if (_cls isEqualTo "") exitWith {};
    _tally set [_cls, (_tally getOrDefault [_cls, 0]) + 1];
};

// worn
[headgear player] call _fnAdd;
[goggles player]  call _fnAdd;
[uniform player]  call _fnAdd;
[vest player]     call _fnAdd;
[backpack player] call _fnAdd;

// container contents
{ [_x] call _fnAdd; } forEach (uniformItems player);
{ [_x] call _fnAdd; } forEach (vestItems player);
{ [_x] call _fnAdd; } forEach (backpackItems player);

// the three weapons, each with its attachments and its loaded magazine
private _fnWpn = {
    params [["_wpn", "", [""]], ["_items", [], [[]]], ["_mags", [], [[]]]];
    if (_wpn isEqualTo "") exitWith {};
    { [_x] call _fnAdd; } forEach _items;
    { [_x] call _fnAdd; } forEach _mags;
    [_wpn] call _fnAdd;
};
[primaryWeapon player,   primaryWeaponItems player,   primaryWeaponMagazine player]   call _fnWpn;
[secondaryWeapon player, secondaryWeaponItems player, secondaryWeaponMagazine player] call _fnWpn;
[handgunWeapon player,   handgunItems player,         handgunMagazine player]         call _fnWpn;

// map, compass, watch, radio, GPS, NVGs
{ [_x] call _fnAdd; } forEach (assignedItems player);

// `toArray false` -> [key, value] pairs. The operand is NOT optional: a bare `toArray` is a
// syntax error that takes the whole function down at compile time, not just this line.
_tally toArray false
