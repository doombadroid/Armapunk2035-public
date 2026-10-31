params[["_caller", objNull, [objNull]], ["_corpse", objNull, [objNull]]];
if (isNull _caller || isNull _corpse) exitWith {};
if (AP_effSide isEqualTo west && !(AP_copRole in ["medic", "all"])) exitWith {};
private _deadPlayerUID = _corpse getVariable["AP_steamid", (getPlayerUID _corpse)];
private _deadPlayerName = _corpse getVariable["AP_name", [name _corpse] call AP_fnc_cleanName];
AP_medicLastRequest = +[_caller, _corpse, _deadPlayerUID, _deadPlayerName];
private _oldCorpseIDX = AP_medicRequestedCorpses findIf {(_x param[1, objNull]) isEqualTo _corpse};
if (_oldCorpseIDX isNotEqualTo - 1) then {
    AP_medicRequestedCorpses set[_oldCorpseIDX, [_caller, _corpse, _deadPlayerUID, _deadPlayerName, time]];} else {
    AP_medicRequestedCorpses pushBack[_caller, _corpse, _deadPlayerUID, _deadPlayerName, time];};
["MedicalRequestEmerg", [format["%1 is requesting Trauma Team.", [name _caller] call AP_fnc_cleanName]]] call BIS_fnc_showNotification;
[format["You have received a new revive request from %1 who is %2 meters away. Press 8 to accept.", name _caller, [floor(player distance _corpse)] call AP_fnc_numberText], "basic"] spawn AP_fnc_handleMessage;
