if (isNull(uiNamespace getVariable["AP_message_hud", displayNull])) exitWith {};
if !(canSuspend) exitWith {_this spawn AP_fnc_deleteMessage};
params[["_ctrlGroup", controlNull, [controlNull]]];
for "_i"
from 0 to 1 step 0 do {if (AP_message_active isEqualTo _thisScript) exitWith {};
    waitUntil {scriptDone AP_message_active};
    AP_message_active = _thisScript;}; if (isNull _ctrlGroup) exitWith {};
_ctrlGroup ctrlSetFade 1;
_ctrlGroup ctrlCommit 0.20;
waitUntil {ctrlCommitted _ctrlGroup};
private _index = AP_message_list findIf {(_x select 1) isEqualTo _ctrlGroup};
if (_index isEqualTo - 1) exitWith {false}; {_x params["_priority", "_control"];
    if (_forEachIndex > _index) then {private _messagePadding = 0.01;
        private _controlPosition = ctrlPosition _control;
        _controlPosition set[1, parseNumber(((_controlPosition select 1) - ((ctrlPosition _ctrlGroup) select 3) - _messagePadding) toFixed 4)];
        _control ctrlSetPosition _controlPosition;
        _control ctrlCommit 0.20;};}
forEach AP_message_list;
if ((count AP_message_list) >= 1) then {waitUntil {ctrlCommitted((AP_message_list select((count AP_message_list) - 1)) select 1)}};
private _index = AP_message_list findIf {(_x select 1) isEqualTo _ctrlGroup};
if !(_index isEqualTo - 1) then {AP_message_list deleteAt _index};
if (!isNull _ctrlGroup) then {ctrlDelete _ctrlGroup};