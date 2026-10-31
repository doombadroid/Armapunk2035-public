 
_uid = [_this,0,"",[""]] call BIS_fnc_param; 
_del = []; 
 {if (!isNil "_x") then {if (_x getVariable ["crateOwner", ""] == _uid) then {deleteVehicle _x;
_del pushBack _forEachIndex;};};} forEach AP_storage_array; {AP_storage_array set [_x, -1];} forEach _del;
AP_storage_array = AP_storage_array - [-1];