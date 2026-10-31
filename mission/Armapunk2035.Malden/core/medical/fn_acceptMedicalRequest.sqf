params[["_requestID", -1, [-1]]];
if (_requestID isEqualTo - 1) exitWith {
    ["Error, something went wrong whilst accepting the request!", "basic"] spawn AP_fnc_handleMessage;};
(AP_medicRequestedCorpses param[_requestID, [objNull, "", "", 0]]) params[["_xCaller", objNull, [objNull]], ["_xCorpse", objNull, [objNull]], ["_xCorpseUID", "", [""]], ["_xCorpseName", "", [""]], ["_xRequestedTime", 0, [0]]];
if ((time < (AP_medicLastRequestSent param[1, -25])) && ((AP_medicLastRequestSent param[0, ""]) isEqualTo _xCorpseUID)) exitWith {
    [format["You have already sent a request to %1 in the past 25 seconds.", _xCorpseName], "basic"] spawn AP_fnc_handleMessage;};
[format["Sending acceptance request to TT dispatch for %1...", _xCorpseName], "basic"] spawn AP_fnc_handleMessage;
if !(((_xCorpse getVariable["AP_requestAcceptor", [objNull, ""]]) param[0, objNull]) in [player, objNull]) exitWith {
    [format["Another medic is already responding to %1, try someone else!", _xCorpseName], "basic"] spawn AP_fnc_handleMessage;}; [
    [player, profileName, (AP_medicLastRequest param[0, objNull]), (AP_medicLastRequest param[1, objNull])], "AP_fnc_requestMedicalConfirmation", (AP_medicLastRequest param[0, objNull]), false, false] spawn AP_fnc_MP;
AP_medicLastRequestSent = +[_xCorpseUID, time + 25];
private _maxWaitTime = time + 15;
waitUntil {time > _maxWaitTime || (((_xCorpse getVariable["AP_requestAcceptor", [objNull, ""]]) param[0, objNull]) isEqualTo player)};
if (time > _maxWaitTime) exitWith {
    [format["%1 has ignored your request for medical attention!", _xCorpseName], "basic"] spawn AP_fnc_handleMessage;};
if !(((_xCorpse getVariable["AP_requestAcceptor", [objNull, ""]]) param[0, objNull]) in [player, objNull]) exitWith {
    [format["Another medic is already responding to %1, try someone else!", _xCorpseName], "basic"] spawn AP_fnc_handleMessage;};
if (isNull(AP_medicAcceptedCorpse param[1, objNull])) then {
    AP_medicAcceptedCorpse = +[_xCaller, _xCorpse, _xCorpseUID, _xCorpseName, getPosATL player, time];
    _xCorpse setVariable["AP_requestAcceptor", [player, profileName], true];
    [format["%1 has been informed that you are en-route. Make haste!", _xCorpseName], "basic"] spawn AP_fnc_handleMessage;
    closeDialog 0;
    [_xCorpse, _xCorpseName] spawn {params[["_xCorpse", objNull, [objNull]], ["_xCorpseName", "", [""]]];
        private _handlerID = addMissionEventHandler["Draw3D", {_thisArgs params["_xCorpse", "_xCorpseName"];
            drawIcon3D["\A3\ui_f\data\map\mapcontrol\Hospital_CA.paa", [[1, 0, 0, 1], [1, 0, 0, 1]
            ], getPosATL _xCorpse, 1, 1, 0, format["%1 (%2m) - Unconscious", _xCorpseName, [round(player distance2D _xCorpse)] call AP_fnc_numberText], 1, 0.03, "RobotoCondensed", "center", true];
        }, [_xCorpse, _xCorpseName]];
        waitUntil {uiSleep 1;
            isNull _xCorpse};
        removeMissionEventHandler["Draw3D", _handlerID];};} else {
    [format["You already have a medic request active for %1", (AP_medicAcceptedCorpse param[3, "Error Name"])], "basic"] spawn AP_fnc_handleMessage;
};