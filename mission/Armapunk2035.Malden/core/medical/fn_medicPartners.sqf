params[["_mode", -1, [0]], ["_object", objNull, [objNull]]];
if (_mode isEqualTo - 1) exitWith {};
private _exit = false;
if !(isNull _object) then {if !(side _object isEqualTo independent) exitWith {_exit = true;};
    if !(alive _object) exitWith {_exit = true;};
    if !(isPlayer _object) exitWith {_exit = true;};};
if (_exit) exitWith {};
private _getPlyr = {params["_uid"];
    allPlayers param[allPlayers findIf {(getPlayerUID _x) isEqualTo _uid && (side _x) isEqualTo independent}, objNull];};
switch (_mode) do {case 1: {
            private _action = [format["Are you sure you want to partner up with %1. You will split your potential earnings with them.", name _object], "Partner Up?", "Yes", "No"] call BIS_fnc_guiMessage;
            if !(_action) exitWith {};
            if !(isNull _object) then {[[2, player], "AP_fnc_medicPartners", _object] call AP_fnc_MP;};};
    case 2: {
            private _action = [format["%1 would like to be partnered with you. You will split your potential earnings with them. Do you accept?", name _object], "Partner Up?", "Yes", "No"] call BIS_fnc_guiMessage;
            if !(_action) exitWith {if !(isNull _object) then {[
                        [format["%1 has declined your request to partner up.", name player], "basic"], "AP_fnc_handleMessage", _object] call AP_fnc_MP;
                };};
            AP_medPartners pushBackUnique[name _object, getPlayerUID _object];
            [format["You have successfully partnered up with %1", name _object], "basic"] spawn AP_fnc_handleMessage;
            if !(isNull _object) then {[[3, player], "AP_fnc_medicPartners", _object] call AP_fnc_MP;};};
    case 3: {AP_medPartners pushBackUnique[name _object, getPlayerUID _object];
            [format["You have successfully partnered up with %1", name _object], "basic"] spawn AP_fnc_handleMessage;};
    case 4: {private _builtMsg = "";
            private _arr = AP_medPartners; {if !(isNull([_x select 1] call _getPlyr)) then {
                    _builtMsg = _builtMsg + format["%1<br/>", _x select 0]} else {AP_medPartners deleteAt _forEachIndex};}
            forEach _arr;
            [format["<t color='#009BFF'><t size='1.5'><t align='center'>Partnered Medics:<br/></t></t></t><t align='center'>%1", _builtMsg], "basic"] spawn AP_fnc_handleMessage;
        };
    case 5: {
            private _action = [format["Are you sure you want to remove your %1 partners?", count AP_medPartners], "Remove Partners?", "Yes", "No"] call BIS_fnc_guiMessage;
            if !(_action) exitWith {};
            private _partners = [];
            if !(AP_medPartners isEqualTo[]) then {_partners = [7, objNull] call AP_fnc_medicPartners;}; [
                [6, player], "AP_fnc_medicPartners", _partners] call AP_fnc_MP;
            AP_medPartners = [];};
    case 6: {private _index = AP_medPartners findIf {(_x select 1) == getPlayerUID _object};
            if (_index == -1) exitWith {};
            AP_medPartners deleteAt _index;};
    case 7: {private _partnerObjects = [];
            private _arr = AP_medPartners; {private _playerObject = [_x select 1] call _getPlyr;
                if !(isNull _playerObject) then {_partnerObjects pushBack _playerObject;} else {AP_medPartners deleteAt _forEachIndex};}
            forEach _arr;
            _partnerObjects;};
    default {["Some error happened while trying to partner up. Try again.", "basic"] spawn AP_fnc_handleMessage;};};