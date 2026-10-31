 
private["_array"]; 
_array = [_this,0,"",[""]] call BIS_fnc_param; 
if(_array == "") exitWith {[]}; 
_array = toArray(_array); 
 
for "_i" from 0 to (count _array)-1 do {_sel = _array select _i;
if(_sel == 96) then {
// LooneyBin: backtick(96) -> DOUBLE-quote(34), NOT single-quote(39). The encoder (mresArray) does
// str(str(x)) then 34->96; the proper inverse restores 34. Using 39 turned "" (empty strings, which
// str() to """") into '''' -> a stray ' or syntax error -> the whole decode returned nil. Arrays full
// of empty strings (gear loadouts: empty muzzle/optic/etc slots) therefore failed to decode -> player
// got the default loadout every spawn. Non-empty strings (licenses) and numbers (talents) round-trip
// fine either way, which is why only gear was broken.
_array set[_i,34];};};
 
_array = toString(_array);
// LooneyBin: DB_fnc_asyncQuery call-compiles the whole extDB3 result, which CONSUMES this value's
// outer quotes (mresArray keeps them so the column reads back as a string). So by the time we get here
// the str(str(x)) wrapping is already one level down: _array is str(x) with its quotes DOUBLED (the
// 2nd str's artifact). Compiling it directly as an array makes bareword strings (e.g. a uniform
// classname) parse as undefined variables -> nil -> []  (= naked gear, the real bug). Re-wrap in quotes
// so it parses as the intermediate STRING (un-doubling the quotes); the caller's 2nd compile (queryRequest
// _dec / gang _dec / restoreVehicles) then yields the value. Pure-number arrays (talents/position) are
// unaffected (no inner quotes to double).
// ENGINE-DEPENDENT, and this is the whole bug. The re-wrap above compensates for
// something only extDB3 does: DB_fnc_asyncQuery call-compiles the ENTIRE extDB3
// result string, and that compile consumes this value's outer quotes on the way
// past. Re-adding them here puts the value back to the intermediate string.
//
// The PostgreSQL path never does that. `apdb.query` returns real SQF values
// through PySQF, so DB_fnc_asyncQuery exits before line 87's compile and the
// outer quotes are still on the value when it arrives here. Re-wrapping then
// adds a SECOND pair, and `""[[[""marijuana"",40]...` compiles as an empty
// string followed by an array -- "Missing ;", which is exactly what the boot log
// showed four times a boot from fn_queryHouses.
//
// So the compensation is applied only when there is something to compensate for.
// This is engine-branched rather than sniffed (e.g. "does it start with a quote")
// because AP_db_postgres is authoritative and a heuristic here would silently
// mis-decode any value that legitimately began with one.
//
// Blast radius, stated plainly: this is every mres consumer -- gear loadouts,
// licences, talents, vehicles, gangs, houses. All of them were already broken on
// the PostgreSQL path, which is why house storage decodes to nothing there, so
// this can only move them from broken to working. On extDB3 the behaviour is
// byte-identical to before.
// 2026-08-20 (pg-native M4): ONE path again. The engine branch (be582da9) existed because the old
// apdb handed values over VERBATIM -- outer quotes still on -- while extDB3's compile had consumed
// them. The bridge now reproduces extDB3's wire contract exactly (apdb.py _unwrap_text, proven by
// tools/pysqf_modules/test_apdb_bridge.py), so the value arriving here is ALWAYS the post-compile
// shape: bare content, interior quotes still doubled. The re-wrap below un-doubles them; compiling
// BARE instead broke every string-bearing blob ("Missing ]" -> nil -> [], the login gear/licenses
// noise and dbSoak's roundtrip_2..4). ETL-generation jsonb rows (real-JSON documents) still need
// the M2 data normalization to pass through here -- their consumers via parseSimpleArray are fine.
_array = call compile format["""%1""", _array];
// owner 2026-06-20: belt-and-suspenders. A malformed input (e.g. a double-QUOTE'd mres column -- the houses-
// keyholders / gangfort-leaderboard bug) makes the `call compile` above return nil, which UNDEFINES _array ->
// the bare `_array;` below threw "Undefined variable in expression: _array" (was firing 76x every 5 min). Never
// throw: nil -> []. No-op on every valid decode (a good compile yields a string, never nil), so zero regression
// risk for loadouts/vehicles/gangs that round-trip this fn. The real fixes are at the callers (drop the QUOTE).
if (isNil "_array") then { _array = []; };
_array;