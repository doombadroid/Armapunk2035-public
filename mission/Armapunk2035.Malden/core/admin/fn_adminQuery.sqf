disableSerialization;
private _display = findDisplay 12900;
private _text = _display displayCtrl 12944;
private _info = lbData[12901, lbCurSel 12901];
_info = missionNamespace getVariable _info;
if (isNil "_info") exitWith {_text ctrlSetText "Player no longer exists?";};
if (isNull _info) exitWith {_text ctrlSetText "Player no longer exists?";}; [
    [player], "AP_fnc_adminPlayerQuery", _info, false] spawn AP_fnc_MP;
_text ctrlSetText "Querying player...";