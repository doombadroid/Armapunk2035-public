params[["_uid", "", [""]]];
if (_uid isEqualTo "") exitWith {false};
!(playableUnits findIf {(getPlayerUID _x) isEqualTo _uid}
isEqualTo - 1);