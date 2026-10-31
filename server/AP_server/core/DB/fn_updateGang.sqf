 
if ("AP_server_training" call DB_fnc_flag) exitWith {}; 
private["_id","_inviteRank","_query","_sql","_kickRank","_bank"]; 
_id = [_this,0,"0",["0"]] call BIS_fnc_param; 
_inviteRank = [_this,1,0,[0]] call BIS_fnc_param; 
_kickRank = [_this,2,0,[0]] call BIS_fnc_param; 
_bank = [_this,3,-1,[-1]] call BIS_fnc_param; 
 
if (_bank < 0) then {_query = format["UPDATE gangs SET inviterank='%2',kickrank='%3' WHERE id='%1'",_id,_inviteRank,_kickRank];}
else {_query = format["UPDATE gangs SET bank='%2' WHERE id='%1'",_id,_bank];};
 
 
[_query] call DB_fnc_asyncQuery;