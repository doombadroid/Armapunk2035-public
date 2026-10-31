params[["_zone", "", [""]]];
private _zoneLocation = getMarkerPos format["%1_cartel", _zone];
private _flagObject = missionNamespace getVariable format["%1_flag", _zone];
// owner 2026-07-05: oil cartel moved to the Sea Fortress (large footprint) -> widen ITS capturable radius so
// the whole structure counts. Other cartels keep the original 50 (stay) / 60 (count).
private _stayRad = if (_zone isEqualTo "boomtown") then {85} else {50};
private _capRad  = if (_zone isEqualTo "boomtown") then {95} else {60};
if (isNil {player getVariable "gang_data"}) then {player setVariable["gang_data", AP_gang_data, true];};
// owner 2026-06-16 (#282): the `eyePos < 0.3` guard is the anti-swim check (no capping while your head is at/
// below sea level). It exempted only "oil" (legitimately over water). The DRUG cartel sits at a low coastal
// church (z=0), so standing near the waterline can read eyePos < 0.3 and block the cap -> "drug cartel can't be
// capped". Exempt drug too. (If it's STILL uncappable after this, the flag is buried/mis-placed -> move it.)
if (_zone isEqualTo "" || AP_capturingCartel || (isNil "_flagObject" || isNull _flagObject) || (player getVariable["AP_restrained", false]) || !(isNull objectParent player) || ((eyePos player select 2 < 0.3) && !(_zone in ["oil", "drug"]))) exitWith {};
if (!license_civ_rebel || player getVariable["AP_isBountyHunter", false]) exitWith {};
AP_capturingCartel = true;
player setVariable["AP_cartCap", true, true];
private _captureData = _flagObject getVariable["AP_capData", [0, "Neutral", 0.5]];
// Armapunk 2035: resolved from core/config/fn_cartelCfg.sqf. The old switches had cases for
// arms/drug/oil/wongs and NO default, so a cartel outside that set produced a nil _cartelID and an
// empty name -- Grimstone and Wreckridge could not be captured at all.
private _cartelRoster = [] call AP_fnc_cartelCfg;
private _cartelID = _cartelRoster findIf { (_x select 0) isEqualTo _zone };
if (_cartelID < 0) exitWith { AP_capturingCartel = false; };
private _zoneName = (_cartelRoster select _cartelID) select 1; private _playersGangID = AP_gang_data select 0;
private _playerGangName = AP_gang_data select 1;
private _playerGroupMembers = units group player;
private _isLeader = player isEqualTo(leader(group player));
private _nonGangGroup = ((_playerGroupMembers findIf {(_x getVariable["gang_data", [0]] param[0, 0]) isNotEqualTo _playersGangID
}) isNotEqualTo - 1);
if (_nonGangGroup && !_isLeader) exitWith {AP_capturingCartel = false;
    if (player getVariable["AP_cartCap", false]) then {player setVariable["AP_cartCap", true, true];};
    [format["This %1 is being captured for %2's gang!", _zoneName, name(leader(group player))]] spawn AP_fnc_handleMessage;};
disableSerialization;
5 cutRsc["AP_progress", "PLAIN"];
private _cpRate = 0;
private _ui = uiNamespace getVariable "AP_progress";
private _progressBar = _ui displayCtrl 38201;
private _titleText = _ui displayCtrl 38202;
private _title = format["You have entered the %1 zone.", _zoneName];
_titleText ctrlSetText _title;
private _currentCaptureProgress = ((round((_captureData select 2) * 3000)) / 3000);
_progressBar progressSetPosition _currentCaptureProgress;
private _cP = _currentCaptureProgress;
private _updateTime = time + 10;
while {true}
do {if !(alive player) exitWith {};
    if ([getPos player select 0, getPos player select 1, 0] distance2D _zoneLocation > _stayRad) exitWith {};
    if !(AP_capturingCartel) exitWith {};
    if (player getVariable["AP_restrained", false]) exitWith {};
    if !(isNull objectParent player) exitWith {};
    if (isNull _ui) then {5 cutRsc["AP_progress", "PLAIN"];
        _ui = uiNamespace getVariable "AP_progress";
        _progressBar = _ui displayCtrl 38201;
        _titleText = _ui displayCtrl 38202;};
    uiSleep 1;
    _captureData = _flagObject getVariable["AP_capData", [0, "Neutral", 0.5]];
    _captureData params["_currentDataID", "_currentGangName"];
    _currentCaptureProgress = ((round((_captureData select 2) * 3000)) / 3000);
    private _cartelMarker = format["%1_cartel", _zone];
    private _cartelMarkerText = markerText _cartelMarker;
    private _newCartelMarkerText = _cartelMarkerText;
    // LooneyBin: nearEntities is a 3D sphere -- at the oil cartel a diver collecting rubber on the
    // seabed fell out of the 60m ball, vanished from his own gang's presence list and the capture
    // stuck on "currently contested". Widen the sphere, gate on 2D distance like the loop's own
    // stay-in-zone check (distance2D 50 above).
    private _nearbyPlayers = (_zoneLocation nearEntities[["CAManBase"], 200]) select {
        (([getPos _x select 0, getPos _x select 1, 0] distance2D _zoneLocation) <= _capRad) && isPlayer _x && isNull objectParent _x && side _x isEqualTo civilian && alive _x && !(_x getVariable["gang_data", [0]] isEqualTo 0) && (!(toLower(primaryWeapon _x) in AP_nonCartelGuns) || _zone isEqualTo "oil") && _x getVariable["AP_cartCap", false] && !(_x getVariable["AP_isBountyHunter", false])
    };
    private _nearbyGangs = []; {_nearbyGangs pushBackUnique(_x getVariable["gang_data", [0]] select 0);}
    forEach _nearbyPlayers;
    private _playerGroupMembers = units group player;
    private _isLeader = player isEqualTo(leader(group player));
    private _nonGangGroup = ((_playerGroupMembers findIf {(_x getVariable["gang_data", [0]] param[0, 0]) isNotEqualTo _playersGangID
    }) isNotEqualTo - 1);
    private _groupGangIDs = _playerGroupMembers apply {_x getVariable["gang_data", [0]] param[0, 0]};
    private _isContested = ((_nearbyGangs findIf {(_x isNotEqualTo - 1) && !(_x in _groupGangIDs)}) isNotEqualTo - 1);
    if (!_isLeader && _nonGangGroup) exitWith {AP_capturingCartel = false;
        if (player getVariable["AP_cartCap", false]) then {player setVariable["AP_cartCap", true, true];};
        [format["This %1 is being captured for %2's gang!", _zoneName, name(leader(group player))]] spawn AP_fnc_handleMessage;};
    private _upCappedButNotCappedFully = (_currentDataID isEqualTo _playersGangID && _currentCaptureProgress < 1);
    private _notOwnedByUs = (_currentDataID isNotEqualTo _playersGangID);
    private _onlyUsInRadius = (((count _nearbyGangs) isEqualTo 1) && ((_nearbyGangs param[0, 0]) isEqualTo(_playersGangID)));
    if ((_upCappedButNotCappedFully || _notOwnedByUs) && (_onlyUsInRadius || (_nonGangGroup && !_isContested))) then {
        if (serverTime < (_flagObject getVariable["AP_capture_cooldown", serverTime - 100])) exitWith {
            _title = format["Capture cooldown - %1 + minutes remaining.", round(((_flagObject getVariable["AP_capture_cooldown", serverTime - 100]) - serverTime) / 60)];
            _titleText ctrlSetText format["%1", _title];};
        if (((_currentDataID) isNotEqualTo _playersGangID) && _cp > 0) then {_cpRate = -0.0017;
            _title = format["Your gang is taking ownership of %1.", _zoneName];
            _newCartelMarkerText = format["%1 - %2 (Contested)", _zoneName, _currentGangName];} else {
            if !(_currentDataID isEqualTo _playersGangID) then {[
                    [1, _cartelID, -1, _captureData select 0], "APS_fnc_cartelSRV", false, false] spawn AP_fnc_MP;
                _captureData set[0, _playersGangID];
                _captureData set[1, _playerGangName];
                _captureData set[2, 0];
                _flagObject setVariable["AP_capData", _captureData, true];};
            _newCartelMarkerText = format["%1 - %2 (Contested)", _zoneName, _currentGangName];
            _title = format["Your gang is capturing %1.", _zoneName];
            _cpRate = 0.0017;};
        _cP = _cP + _cpRate;
        _cP = (round((_cP) * 3000)) / 3000;
        if (_cP > 1) then {_cP = 1} else {if (_cP < 0) then {_cp = 0};};
        _progressBar progressSetPosition _cP;
        _titleText ctrlSetText format["%3 (%1%2)", round(_cP * 100), "%", _title];
        if (_currentDataID isEqualTo _playersGangID && _cp >= 1) exitWith {_captureData set[0, _currentDataID];
            _captureData set[1, _currentGangName];
            _captureData set[2, _cP];
            _flagObject setVariable["AP_capData", _captureData, true];
            _flagObject setVariable["AP_capture_cooldown", serverTime + 1800, true];
            _newCartelMarkerText = format["%1 - %2", _zoneName, _playerGangName]; [
                [3, _cartelID, -1, _captureData select 0], "APS_fnc_cartelSRV", false, false] spawn AP_fnc_MP;
            private _myGangID = AP_gang_data select 0;
            private _myGangBois = []; {if (_x isKindOf "CAManBase") then {
                    if (isNull objectParent _x && isPlayer _x && ((_x getVariable["gang_data", [0]] select 0) isEqualTo _myGangID)) then {
                        _myGangBois pushBack _x};} else {if !(crew _x isEqualTo[]) then {_myGangBois append(crew _x select {
                            isPlayer _x && (_x getVariable["gang_data", [0]] select 0) isEqualTo _myGangID})};};}
            forEach(_zoneLocation nearEntities[["CAManBase", "Car"], 250]);
            [2, 5] call AP_fnc_updateRemoteStat;
            if !(_myGangBois isEqualTo[]) then {[[2, 5], "AP_fnc_updateRemoteStat", _myGangBois] call AP_fnc_MP;
                ["cartelscaptured", 1] remoteExec["AP_fnc_statArrUpdate", _myGangBois];};
            AP_gang_exp = AP_gang_exp + 5; [[
                    [AP_gang_exp, AP_gang_talents], AP_gang_data select 0], "APS_fnc_updateGangTalents", 2] call AP_fnc_MP;
            // owner 2026-07-04: cartel-capture loot crate (APS_fnc_airDrop) removed.
            [["cartel", player], "APS_fnc_qhLootSRV", 2] spawn AP_fnc_MP;   // deck-loot roll (server-side, throttled)
        };
        if (_updateTime <= time) then {
            if (((_currentCaptureProgress < _cp) && _cpRate > 0) || ((_currentCaptureProgress > _cp) && _cpRate < 0)) then {
                _captureData set[0, _currentDataID];
                _captureData set[2, _cP];
                _flagObject setVariable["AP_capData", _captureData, true];
                if (isNil {_flagObject getVariable "AP_last_alert"}) then {_flagObject setVariable["AP_last_alert", serverTime, true];};
                if ((_flagObject getVariable["AP_last_alert", serverTime]) < (serverTime - 90)) then {
                    if !(_currentDataID isEqualTo _playersGangID) then {private _enemyGang = playableUnits select {
                            // owner 2026-06-19 (#336): only notify gang members currently playing as CIVILIAN -- a
                            // gang member on MEDIC/COP duty was wrongly getting their gang's cartel-capture alert.
                            (side _x isEqualTo civilian) && {_currentDataID isEqualTo(_x getVariable["gang_data", [0]] select 0)}};
                        [_zoneName, "cartelcapture"] remoteExec["AP_fnc_handleMessage", _enemyGang];
                        _flagObject setVariable["AP_last_alert", serverTime, true];};};} else {_cP = _currentCaptureProgress;};
            _updateTime = time + 10;};} else {if (_currentDataID isEqualTo _playersGangID && _currentCaptureProgress > 0.99) then {
            _title = format["Your gang currently owns %1.", _zoneName];
            _newCartelMarkerText = format["%1 - %2", _zoneName, _playerGangName];} else {
            if (serverTime < (_flagObject getVariable["AP_capture_cooldown", serverTime - 100])) then {
                _title = format["Capture cooldown - %1 + minutes remaining.", round(((_flagObject getVariable["AP_capture_cooldown", serverTime - 100]) - serverTime) / 60)];
                _titleText ctrlSetText format["%1", _title];} else {_title = format["%1 is currently contested.", _zoneName];};};
        _titleText ctrlSetText format["%3 (%1%2)", round(_cP * 100), "%", _title];
        _updateTime = time + 10;};
    if (_newCartelMarkerText isNotEqualTo _cartelMarkerText) then {_cartelMarker setMarkerText _newCartelMarkerText;};
}; private _nearbyPlayers = []; {if (_x isKindOf "CAManBase") then {if (isNull objectParent _x && isPlayer _x) then {
            _nearbyPlayers pushBack _x};} else {if !(crew _x isEqualTo[]) then {_nearbyPlayers append(crew _x select {isPlayer _x})};};}
forEach(_zoneLocation nearEntities[["CAManBase", "Car"], 60]);
private _nearbyGangs = (_nearbyPlayers select {
    alive _x && !(_x getVariable["gang_data", [0]] isEqualTo 0) && !(toLower(primaryWeapon _x) in AP_nonCartelGuns) && _x getVariable["AP_cartCap", false] && !(_x getVariable["AP_isBountyHunter", false]) && side _x isEqualTo civilian
}) apply {_x getVariable["gang_data", [0]] select 0};
if (_nearbyGangs isEqualTo[]) then {_captureData = _flagObject getVariable["AP_capData", [0, "Neutral", 0.5]];
    private _currentGangName = _captureData select 1;
    private _cartelMarker = format["%1_cartel", _zone];
    _cartelMarker setMarkerText format["%1 - %2", _zoneName, _currentGangName];};
5 cutText["", "PLAIN"];
AP_capturingCartel = false;
player setVariable["AP_cartCap", false, true];