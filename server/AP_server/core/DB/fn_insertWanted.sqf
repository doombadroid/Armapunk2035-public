 
if ("AP_server_training" call DB_fnc_flag) exitWith {}; 
private["_name", "_uid", "_crimes", "_bounty", "_jail", "_query", "_sql"]; 
 
_name = [_this,0,"",[""]] call BIS_fnc_param; 
_uid = [_this,1,"",[""]] call BIS_fnc_param; 
_crimes = [_this,2,[],[[],false]] call BIS_fnc_param; 
_bounty = [_this,3,0,[0]] call BIS_fnc_param; 
_jail = [_this,4,0,[0]] call BIS_fnc_param; 
 
// owner 2026-06-23 SECURITY (security.md §2.3): the legacy KRON_Replace sanitizer is mission-only -> UNDEFINED
// on the dedicated server, so these three calls silently no-op'd (or nil-corrupted _name) and the client name +
// uid reached the INSERT raw = SQL injection. Replace with the in-repo _san strip (single-quote/backtick/quote
// removal, same as fn_logIt) and escape _uid too before it hits the query below.
private _san = { (format ["%1", _this]) splitString "\'""" joinString "" };
_name = _name call _san;
_uid  = _uid call _san;
_crimes = [_crimes] call DB_fnc_mresArray;
 
 
_query = format["INSERT INTO %6 (playerid, name, crimes, bounty, jail) VALUES ('%1', '%2', '%3', '%4', '%5') ON CONFLICT (playerid) DO UPDATE SET crimes=EXCLUDED.crimes, bounty=EXCLUDED.bounty, jail=EXCLUDED.jail", _uid, _name, _crimes, _bounty, _jail, "wanted"]; 
[_query] call DB_fnc_asyncQuery;