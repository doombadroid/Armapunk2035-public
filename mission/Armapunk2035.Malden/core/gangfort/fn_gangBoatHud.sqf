if !(SRV_gangBoatFortressData select 0) exitWith {};
if (AP_gangFortHudID != -1) then {removeMissionEventHandler["Draw3D", AP_gangFortHudID];
    AP_gangFortHudID = -1;};
disableSerialization;
412 cutRsc["AP_gangFortHUD", "PLAIN", -1, true];
private _plb_display = uiNamespace getVariable "AP_gangFortHUD";
private _gangFortSelfPlace = _plb_display displayCtrl 123401;
private _gangFortTopBar = _plb_display displayCtrl 123402;
private _gangFortFirstPlace = _plb_display displayCtrl 123403;
private _gangFortSecondPlace = _plb_display displayCtrl 123404;
private _gangFortThirdPlace = _plb_display displayCtrl 123405;
private _gangBoatFlags = _plb_display displayCtrl 123406; {_x ctrlCommit 0}
forEach[_gangFortSelfPlace, _gangFortTopBar, _gangFortFirstPlace, _gangFortSecondPlace, _gangFortThirdPlace];
_handlerID = addMissionEventHandler["Draw3D", {
    // #561 mirror: self-terminate when the gang-boat fortress event ends. The server flips
    // SRV_gangBoatFortressData select 0 to false globally at event end but never tore this HUD
    // down, so the scoreboard lingered every frame until the next restart. Remove our own Draw3D
    // handler + clear the cutRsc title layer (412) once the event is inactive.
    if !(SRV_gangBoatFortressData select 0) exitWith {removeMissionEventHandler["Draw3D", _thisEventHandler];
        AP_gangFortHudID = -1;
        412 cutText["", "PLAIN"];};
    _thisArgs params["_gangFortSelfPlace", "_gangFortFirstPlace", "_gangFortSecondPlace", "_gangFortThirdPlace", "_gangBoatFlags"];
    AP_gang_data params["_playerGangID", "_playerGangName"];
    private _flags = SRV_gangBoatFortressData select 1;
    private _capInfo1 =
    switch (true) do {
        case (((_flags select 0) getVariable["AP_boatflag_data", ["", -1, "Unknown"]] select 1) isEqualTo(AP_gang_data select 0)): {
                "'icons\capture\Ablufor.paa'"};
        case (((_flags select 0) getVariable["AP_boatflag_data", ["", -1, "Unknown"]] select 1) isEqualTo - 1): {
                "'icons\capture\Aneutral.paa'"};
        case (!(((_flags select 0) getVariable["AP_boatflag_data", ["", -1, "Unknown"]] select 1) isEqualTo(AP_gang_data select 0))): {
                "'icons\capture\Aopfor.paa'"};
        default {"'icons\capture\Aopfor.paa'"};}; private _capInfo2 =
    switch (true) do {
        case (((_flags select 1) getVariable["AP_boatflag_data", ["", -1, "Unknown"]] select 1) isEqualTo(AP_gang_data select 0)): {
                "'icons\capture\Bblufor.paa'"};
        case (((_flags select 1) getVariable["AP_boatflag_data", ["", -1, "Unknown"]] select 1) isEqualTo - 1): {
                "'icons\capture\Bneutral.paa'"};
        case (!(((_flags select 1) getVariable["AP_boatflag_data", ["", -1, "Unknown"]] select 1) isEqualTo(AP_gang_data select 0))): {
                "'icons\capture\Bopfor.paa'"};
        default {"'icons\capture\Bopfor.paa'"};}; private _capInfo3 =
    switch (true) do {
        case (((_flags select 2) getVariable["AP_boatflag_data", ["", -1, "Unknown"]] select 1) isEqualTo(AP_gang_data select 0)): {
                "'icons\capture\Cblufor.paa'"};
        case (((_flags select 2) getVariable["AP_boatflag_data", ["", -1, "Unknown"]] select 1) isEqualTo - 1): {
                "'icons\capture\Cneutral.paa'"};
        case (!(((_flags select 2) getVariable["AP_boatflag_data", ["", -1, "Unknown"]] select 1) isEqualTo(AP_gang_data select 0))): {
                "'icons\capture\Copfor.paa'"};
        default {"'icons\capture\Copfor.paa'"};
    }; _gangBoatFlags ctrlSetStructuredText(parseText(format["<t shadow='0'><t align='center'><t size='2.25'><img image=%1/><img image=%2/><img image=%3/></t><br/>", _capInfo1, _capInfo2, _capInfo3]));
    private _topGang1 = [-1, "N/a", -1];
    private _topGang2 = [-1, "N/a", -1];
    private _topGang3 = [-1, "N/a", -1];
    private _previousGang = [-1, "N/a", 0];
    private _currentGangFortData = SRV_gangBoatFortressData select 2; {_x params["_xGangID", "_xGangName", "_xGangPoints"];
        if (_xGangPoints > (_topGang1 select 2)) then {_topGang1 = _x;};}
    forEach _currentGangFortData; {_x params["_xGangID", "_xGangName", "_xGangPoints"];
        if (_xGangID != (_topGang1 select 0)) then {if (_xGangPoints > (_topGang2 select 2)) then {_topGang2 = _x;};};}
    forEach _currentGangFortData; {_x params["_xGangID", "_xGangName", "_xGangPoints"];
        if (_xGangID != (_topGang2 select 0) && _xGangID != (_topGang1 select 0)) then {if (_xGangPoints > (_topGang3 select 2)) then {
                _topGang3 = _x;};};}
    forEach _currentGangFortData;
    private _topGang1Name = (_topGang1 select 1);
    private _topGang1Points = (_topGang1 select 2);
    private _topGang2Name = (_topGang2 select 1);
    private _topGang2Points = (_topGang2 select 2);
    private _topGang3Name = (_topGang3 select 1);
    private _topGang3Points = (_topGang3 select 2);
    _topGang1Name = _topGang1Name select[0, 18];
    _topGang2Name = _topGang2Name select[0, 18];
    _topGang3Name = _topGang3Name select[0, 18]; {_x params["_gangText", "_gangName", "_gangPoints", "_textColor"];
        if !(_gangPoints isEqualTo - 1) then {
            _gangText ctrlSetStructuredText(parseText format["<t align='left' size='0.95' color='%1'>#%2: %3 | %4</t>", _textColor, _forEachIndex + 1, _gangName, [_gangPoints] call AP_fnc_numberText]);
        } else {_gangText ctrlSetText "";};}
    forEach[[_gangFortFirstPlace, _topGang1Name, _topGang1Points, "#FFD700"], [_gangFortSecondPlace, _topGang2Name, _topGang2Points, "#C0C0C0"], [_gangFortThirdPlace, _topGang3Name, _topGang3Points, "#CD7F32"]];
    if (_currentGangFortData isEqualTo[] || AP_gang_data isEqualTo[]) then {_gangFortSelfPlace ctrlSetText "";} else {
        private _gangFortDataIDX = _currentGangFortData findIf {(_x select 0) isEqualTo _playerGangID};
        if !(_gangFortDataIDX isEqualTo - 1) then {
            (_currentGangFortData select _gangFortDataIDX) params["_cGangID", "_cGangName", "_cGangPoints"];
            _gangFortSelfPlace ctrlSetStructuredText(parseText format["<t align='left' size='0.95' color='#FF0000' size='1.0'>%1 | %2</t>", _cGangName, [_cGangPoints] call AP_fnc_numberText]);
        } else {
            _gangFortSelfPlace ctrlSetStructuredText(parseText format["<t align='left' size='0.95'color='#FF0000' size='1.0'>%1 | %2</t>", _playerGangName, 0]);
        };};}, [_gangFortSelfPlace, _gangFortFirstPlace, _gangFortSecondPlace, _gangFortThirdPlace, _gangBoatFlags]];
AP_gangFortHudID = _handlerID;