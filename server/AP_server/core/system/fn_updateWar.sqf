 
private["_gang1","_gang2","_new","_query","_status"];
// owner 2026-06-23 ("can't accept gang wars"): the type filters here were ["0"] = STRING, but fn_acceptWar /
// fn_surrenderWar pass the gang IDs as NUMBERS (AP_gang_data select 0 + parseNumber). Numbers failed the string
// filter -> BIS_fnc_param returned the default "0" for BOTH -> every accept INSERTed ('0','0') (proven in extDB3
// logs: 9/9 war inserts were ('0','0')) AND fn_warStatus rejected the "0" strings (it wants scalars) -> exitWith
// -> no in-memory war either. Accept a SCALAR now so real gang IDs flow through to the query + warStatus.
_gang1 = [_this,0,-1,[0]] call BIS_fnc_param;
_gang2 = [_this,1,-1,[0]] call BIS_fnc_param;
_new = [_this,2,true,[true]] call BIS_fnc_param;
if (_gang1 < 1 || _gang2 < 1 || _gang1 isEqualTo _gang2) exitWith {};   // never write garbage (the old ('0','0') rows) or a gang at war with itself
_query = ""; 
_status = false; 
 
if (_new) then {_query = format["INSERT INTO wars (gang1,gang2) VALUES ('%1','%2')", _gang2, _gang1, AP_server_instance];
_status = true;}
else {
_query = format["DELETE FROM wars WHERE (gang1 = '%1' AND gang2 = '%2') OR (gang1 = '%2' AND gang2 = '%1')", _gang1, _gang2, AP_server_instance]; 
}; {
private _pGang = (_x getVariable ["gang_data", [-1]]) param [0, -1];   // owner 2026-06-27 ("can't accept wars" / persist): the loop read the unset "gang" var (always "0") and compared it `==` to the NUMERIC _gang1/_gang2 (after the 06-23 numeric-id fix) -> a String-vs-Number type error that ABORTED the fn before the INSERT below ran -> 0 wars rows. Match the real numeric gang id from gang_data so the two warring gangs get AP_fnc_warStatus AND the DB write happens.
if (_pGang isEqualTo _gang1 || _pGang isEqualTo _gang2) then {[[_gang1, _gang2, _status],"AP_fnc_warStatus",_x,false] spawn AP_fnc_MP;
};} forEach allPlayers;
 
[_query] call DB_fnc_asyncQuery;