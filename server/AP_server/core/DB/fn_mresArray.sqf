 
private["_array"]; 
_array = [_this,0,[],[[]]] call BIS_fnc_param; 
_array = str(str(_array));
_array = toArray(_array);
_array = _array - [96, 39];   // SECURITY (root): drop any SOURCE backtick(96) before it becomes this codec's delimiter. Otherwise a backtick in free-text (e.g. a loadout/gang/name) survives encode and mresToArray turns it into a " that breaks out at a consumer's call compile = server RCE (Lystic class). Legit data never contains backticks.
// SECURITY 2026-09-26 (audit srvdb-0-2): drop single quotes(39) too. str(str()) leaves ' untouched and ~40 callers format this output into a '...' SQL literal, many of them from client-supplied arrays (updatePartial/updateRequest packets) or client-settable public vars (AP_vinv/AP_vehOwners on the vehicle snapshot) -> `x' WHERE playerid='<victim>' --` rewrote other rows. Dropping it here closes every caller at once; the cost is that an apostrophe in free text (a loadout name) is lost.

for "_i" from 0 to (count _array)-1 do {_sel = _array select _i;
if((_i != 0 && _i != ((count _array)-1))) then {if(_sel == 34) then {_array set[_i,96];};};};
 
_array = toString(_array); 
_array;