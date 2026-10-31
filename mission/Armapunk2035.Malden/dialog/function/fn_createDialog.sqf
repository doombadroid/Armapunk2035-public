#include "..\..\macro.h"
params[["_dialogName", "", [""]], ["_asDisplay", false, [false]], ["_closeLast", true, [false]]];
private _dialogID = getNumber(missionconfigfile >> _dialogName >> "idd");
private _location = getText(missionconfigfile >> _dialogName >> "location");
disableSerialization;
if (_dialogName isEqualTo "" || _dialogID isEqualTo 0) exitWith {systemChat "Could not create menu, bad data";};
private _dialogControl = (findDisplay _dialogID);
private _location =
(if (_location isNotEqualTo "") then { _location } else { "noAnim" }); if (!isNull _dialogControl) then {
    // owner 2026-06-15: was `false` (= animate CLOSE). When an open action double-fired (or a stale display of
    // the same idd lingered), the 2nd createDialog hit this branch and CLOSED the just-opened dialog -> "cop
    // weapon shop flashes open then immediately closes; spam sometimes works" (race). RE-SHOW instead of close
    // so a re-trigger is harmless; ESC still closes normally.
    [_dialogID, _location, true] spawn AP_fnc_animateDialog;} else {if (AP_lastDisplay != _dialogID) then {
        if (!isNull(findDisplay AP_lastDisplay) && _closeLast) then {(findDisplay AP_lastDisplay) closeDisplay 0;
            private _waitForClose = diag_tickTime + 0.01;
            while {diag_tickTime < _waitForClose}
            do {};};};
    if (_asDisplay) then {(findDisplay 46) createDisplay _dialogName;};
    if (!_asDisplay && {!(createDialog _dialogName)}) exitWith {systemChat("Failed to open dialog " + _dialogName);};
    AP_lastDisplay = _dialogID;
    [_dialogID, _location, true] spawn AP_fnc_animateDialog;
    private _closeDialogEVH = compile format["{
			_dialog = _this select 0;_key = _this select 1;_handled = (_key isEqualTo 0x01);_location = %1; _noEscape = %2;
			if (_handled && !_noEscape) then {[(ctrlIDD _dialog), _location, false] spawn AP_fnc_animateDialog;};
			_handled;
	}", str(_location), (isNumber(missionconfigfile >> _dialogName >> "noEVH"))];};