private["_endPosition", "_hiddenPos"];
params[["_dialogID", 0, [0]], ["_location", "", [""]], ["_mode", true, [false]]];
if (_dialogID isEqualTo 0) exitWith {};
disableSerialization;
private _dialogControl = (findDisplay _dialogID);
if (_location == "noAnim") exitWith {if (!_mode) then {closeDialog 0;} else {{_x ctrlSetFade 0;
            _x ctrlCommit 0;}
        forEach(allControls(findDisplay _dialogID));};};
if (isNull _dialogControl) exitWith {}; {_endPosition = ctrlPosition _x;
    _hiddenPos =
    switch (_location) do {case "top": {[(_endPosition select 0), (_endPosition select 1) - 1]}; case "bottom": {
                    [(_endPosition select 0), (_endPosition select 1) + 1]};
            case "left": {[(_endPosition select 0) - 1, (_endPosition select 1)]};
            case "right": {[(_endPosition select 0) + 1, (_endPosition select 1)]};
            case "fadeOnly": {[(_endPosition select 0), (_endPosition select 1)]};
            case "grow": {
                    [(_endPosition select 0) + ((_endPosition select 2) / 2), (_endPosition select 1) + ((_endPosition select 3) / 2)]};
            case "leftAndRight": {if ((_endPosition select 0) > (safeZoneW / 4)) then {
                        [(_endPosition select 0) + 1, (_endPosition select 1)];} else {
                        [(_endPosition select 0) - 1, (_endPosition select 1)];};};
            default {[(_endPosition select 0), (_endPosition select 1)]};}; if (_mode) then {if (_location == "grow") then {
            _x ctrlSetScale 0;};
        _x ctrlSetPosition _hiddenPos;
        _x ctrlSetFade 1;
        _x ctrlCommit 0;
        if (_location == "grow") then {_x ctrlSetScale 1;};
        _x ctrlSetPosition[_endPosition select 0, _endPosition select 1];
        _x ctrlSetFade 0;
        _x ctrlCommit 0.275;} else {if (_location == "grow") then {_x ctrlSetScale 0;};
        _x ctrlSetPosition _hiddenPos;
        _x ctrlSetFade 1;
        _x ctrlCommit 0.14;};}
forEach(allControls _dialogControl);
if (!_mode) then {uiSleep 0.14;
    closeDialog 0;};