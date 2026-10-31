params[["_id", -1, [-1]]];
if (_id in AP_achievements) exitWith {};
if (_id < 0) exitWith {};
private _achievement = (localNamespace getVariable "AP_achievementInfo") param[(localNamespace getVariable "AP_achievementInfo") findIf {_id isEqualTo(_x select 0)}, []];
if !(AP_effSide in (_achievement select 1)) exitWith {};
AP_achievements pushBack _id;
["Achievement", [format["Achievement Unlocked: %1", _achievement select 2]]] call BIS_fnc_showNotification;
[7] call AP_fnc_ClupdatePartial;