params[["_class", "", [""]]];
if (_class isEqualTo "") exitWith {};
private _wcfg = configfile >> "CfgWeapons" >> _class;
private _magazineWellsMagazines = [];
private _magazineWells = +getArray(_wcfg >> "magazineWell");
private _magazines = +getArray(_wcfg >> "magazines");
// LooneyBin 2026-07-23: include SECONDARY / UNDERBARREL muzzles. A weapon's `muzzles[]` lists each firing
// muzzle; every muzzle except "this" carries its OWN magazines + magazineWell (e.g. the Type 115 ARX .50
// Beowulf underbarrel mag, or a GL's grenade rounds). Reading only the root weapon missed all of them, so
// the shop side-list never showed an underbarrel mag.
{if ((toLower _x) != "this") then {private _mzl = _wcfg >> _x;
        { _magazines pushBackUnique _x; } forEach getArray(_mzl >> "magazines");
        { _magazineWells pushBackUnique _x; } forEach getArray(_mzl >> "magazineWell");};} forEach getArray(_wcfg >> "muzzles"); {
    _magazineWellsMagazines append(getArray(configfile >> "CfgMagazineWells" >> _x >> "BI_Magazines"))}
forEach _magazineWells; {_magazineWellsMagazines append(getArray(configfile >> "CfgMagazineWells" >> _x >> "BI_Enoch_Magazines"))}
forEach _magazineWells; {_magazines pushBackUnique _x}
forEach _magazineWellsMagazines;
_magazines
