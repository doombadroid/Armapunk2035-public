 
if ("AP_server_training" call DB_fnc_flag) exitWith {}; 
private["_uid","_side","_type","_className","_color","_plate", "_fuel", "_damage","_query","_sql"]; 
_uid = [_this,0,"",[""]] call BIS_fnc_param; 
_side = [_this,1,"",[""]] call BIS_fnc_param; 
_type = [_this,2,"",[""]] call BIS_fnc_param; 
_className = [_this,3,"",[""]] call BIS_fnc_param; 
_color = [_this,4,-1,[0]] call BIS_fnc_param; 
_plate = [_this,5,-1,[0]] call BIS_fnc_param; 
_fuel = [_this,6,-1,[0]] call BIS_fnc_param; 
_damage = [_this,7,-1,[0]] call BIS_fnc_param; 
_alarm = [_this,8,false,[false]] call BIS_fnc_param; 
_mods = [_this,9,[],[[]]] call BIS_fnc_param; 
_rigKind = [_this,10,"",[""]] call BIS_fnc_param; 
_rigKind = _rigKind splitString "\'""`" joinString ""; 
if !(_rigKind in ["", "extractor", "processor"]) then { _rigKind = ""; }; 
 
if(_uid == "" OR _side == "" OR _type == "" OR _className == "" OR _color == -1 OR _plate == -1) exitWith {}; 
 
 
_fuel = _fuel * 100; 
_damage = _damage * 100; 
_alarm = [_alarm,0] call DB_fnc_bool; 

_modsStr = if ((count _mods) isEqualTo 9) then { str (_mods apply { round parseNumber format ["%1", _x] }) } else { format["[%1,0,0,0,0,0,0,0,0]", _alarm] }; 
_modsStr = _modsStr splitString "\'""`" joinString ""; 
 
_query = format["INSERT INTO %10 (side, classname, type, pid, alive, active, inventory, color, plate, fuel, damage, alarm, mods, rig_kind) VALUES ('%1', '%2', '%3', '%4', '1','1','[]', '%5', '%6', '%7', '%8', '%9', '%11', '%12')",_side,_className,_type,_uid,_color,_plate,_fuel,_damage,_alarm,"vehicles",_modsStr,_rigKind]; 
[_query] call DB_fnc_asyncQuery;