disableSerialization;
private _group = AP_my_gang;
if (isNull _group) exitWith {[] spawn AP_fnc_groupMenu;};
private _gangIndex = randomized_life_group_list findIf {_group in _x};
// LooneyBin: stale AP_my_gang (entry already deleted while this client lagged) -> select -1 threw.
if (_gangIndex isEqualTo -1) exitWith {AP_my_gang = objNull;
    [] spawn AP_fnc_groupMenu;};
(randomized_life_group_list select _gangIndex) params["_name", "_group", "_locked", "_ownerID", "_password"];
waitUntil {!isNull(findDisplay 2620)};
private _dialog = findDisplay 2620;
private _members = _dialog displayCtrl 2621;
lbClear _members;
switch (true) do {case (player isEqualTo(leader(group player))): {ctrlShow[2623, true];};
    case ((getPlayerUID player) isEqualTo _ownerID): {ctrlShow[2623, true];};
    default {ctrlShow[2623, false];
        ctrlShow[2624, false];
        ctrlShow[2625, false];
        ctrlShow[2626, false];
        ctrlShow[2627, false];};}; if (_locked) then {ctrlEnable[2627, false];} else {ctrlEnable[2626, false];};
ctrlSetText[2628, (format["Group: %1 | Pass: %2", _name, _password])]; {private _extra =
    switch (true) do {case (_x isEqualTo(leader(group player))): {"[Leader]"};
        case (_ownerID isEqualTo(getPlayerUID _x)): {"[Founder]"};
        default {""};}; private _index = _members lbAdd format["%1 %2", name _x, _extra];
    _members lbSetData[_index, str _x];}
forEach(units(group player));