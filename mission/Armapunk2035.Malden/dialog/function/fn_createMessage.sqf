params[["_insertIndex", 0], ["_text", ""], ["_duration", 5], ["_priority", 5], ["_color", [0.50, 0, 0]], ["_condition", {true}]];
if (_text isEqualTo "") exitWith {};
private["_control", "_progress"];
if !(call AP_fnc_initMessageHUD) exitWith {};
disableSerialization;
private _plb_display = uiNamespace getVariable["AP_message_hud", displayNull];
if (isNull _plb_display) exitWith {};
private _mainCtrlGroup = _plb_display displayCtrl 245001;
private _mainCtrlGroupSize = ctrlPosition _mainCtrlGroup;
_mainCtrlGroupSize params["_mainCtrlGroupX", "_mainCtrlGroupY", "_mainCtrlGroupW", "_mainCtrlGroupH"];
private _ctrlGroup = _plb_display ctrlCreate["AP_RscControlsGroupNoScrollbars", -1, _mainCtrlGroup];
_ctrlGroup ctrlSetPosition[0, 0, _mainCtrlGroupW, _mainCtrlGroupH];
_ctrlGroup ctrlSetFade 1;
_ctrlGroup ctrlCommit 0;
private _ctrlGroupSize = ctrlPosition _ctrlGroup;
_ctrlGroupSize params["_ctrlGroupX", "_ctrlGroupY", "_ctrlGroupW", "_ctrlGroupH"];
_color pushBack 0.80;
private _colorBackground = [0.157, 0.196, 0.247, 0.9];   // NC raised track behind the type line
// LooneyBin 2026-07-18: build the dark track FIRST so the coloured progress bar draws ON TOP of it
// (it was created after -> covered the bar -> bars flashed their colour for a frame then went dark).
_control = _plb_display ctrlCreate["AP_RscText", -1, _ctrlGroup];
_control ctrlSetPosition[0, 0, _ctrlGroupW, 0.01];
_control ctrlSetBackgroundColor _colorBackground;
_control ctrlCommit 0;
_progress = _plb_display ctrlCreate["RscProgress", 1001, _ctrlGroup];
_progress ctrlSetPosition[0, 0, _ctrlGroupW, 0.01];
_progress ctrlSetTextColor _color;
_progress progressSetPosition 1;
_progress ctrlCommit 0;
_control = _plb_display ctrlCreate["AP_RscStructuredText", 1000, _ctrlGroup];
_control ctrlSetStructuredText(parseText format["<t size='0.90' font='PuristaMedium'>%1</t>", _text]);
_control ctrlSetPosition[0, 0.01, _ctrlGroupW, 0.05];
_control ctrlSetBackgroundColor[0.075, 0.102, 0.145, 0.96];   // NC surface slab
_control ctrlSetTextColor[0.922, 0.937, 0.957, 1];   // NC ink
_control ctrlCommit 0;
private _messageHeight = 0.00;
_control ctrlSetPosition[0, 0.01, _ctrlGroupW, (ctrlTextHeight _control) + 0.01];
_control ctrlCommit 0; {if !(_forEachIndex isEqualTo 1) then {_messageHeight = _messageHeight + ((ctrlPosition _x) select 3);};}
forEach((allControls _plb_display) select {(ctrlParentControlsGroup _x) isEqualTo _ctrlGroup});
_ctrlGroup ctrlSetPosition[0, 0, _mainCtrlGroupW, _messageHeight];
_ctrlGroup ctrlSetFade 1;
_ctrlGroup ctrlCommit 0;
private _startPositionY = 0; {_x params["_priority", "_control"];
    private _messagePadding = 0.01;
    if (_forEachIndex >= _insertIndex) then {private _controlPosition = ctrlPosition _control;
        _controlPosition set[1, parseNumber(((_controlPosition select 1) + ((ctrlPosition _ctrlGroup) select 3) + _messagePadding) toFixed 4)];
        _control ctrlSetPosition _controlPosition;
        _control ctrlCommit 0.20;} else {_startPositionY = _startPositionY + ((ctrlPosition _control) select 3) + _messagePadding;};}
forEach AP_message_list;
if ((count AP_message_list) >= 1) then {waitUntil {ctrlCommitted((AP_message_list select((count AP_message_list) - 1)) select 1)}};
AP_message_list = [AP_message_list, [_priority, _ctrlGroup], _insertIndex] call AP_fnc_insertElement;
private _currentPosition = ctrlPosition _ctrlGroup;
_currentPosition set[1, _startPositionY];
_ctrlGroup ctrlSetPosition _currentPosition;
_ctrlGroup ctrlCommit 0;
_ctrlGroup ctrlSetFade 0;
_ctrlGroup ctrlCommit 0.20;
waitUntil {ctrlCommitted _ctrlGroup};
[_ctrlGroup controlsGroupCtrl 1001, _duration, _condition] spawn {params[["_progress", controlNull], ["_duration", 5], ["_condition", {true
    }]];
    if (isNull _progress) exitWith {};
    private _endTime = time + _duration;
    for "_i"
    from 0 to 1 step 0 do {waitUntil {(ctrlFade(ctrlParentControlsGroup _progress)) isEqualTo 0};
        _progress progressSetPosition((_endTime - time) / _duration);
        if ((isNull _progress) || (time >= _endTime)) exitWith {};
        if !(call _condition) exitWith {};
        uiSleep 0.01;};
    [ ctrlParentControlsGroup _progress] call AP_fnc_deleteMessage;};
_ctrlGroup;