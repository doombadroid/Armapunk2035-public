private _uraniumProcessor = createTrigger["EmptyDetector", getMarkerPos "illegal_marker_4_1", false];
_uraniumProcessor setTriggerArea[300, 300, 0, false];
_uraniumProcessor setTriggerActivation["ANYPLAYER", "PRESENT", true];
_uraniumProcessor setTriggerStatements["((this && ((vehicle player) in thisList)) || (player in thisList))", "[thisList, thisTrigger] call AP_fnc_radiationZone", ""];
_uraniumProcessor setSoundEffect["$NONE$", "", "", "Owl"];
_uraniumProcessor setTriggerInterval 3;
private _uraniumMine = createTrigger["EmptyDetector", getMarkerPos "illegal_marker_4_0", false];
_uraniumMine setTriggerArea[200, 200, 0, false];
_uraniumMine setTriggerActivation["ANYPLAYER", "PRESENT", true];
_uraniumMine setTriggerStatements["((this && ((vehicle player) in thisList)) || (player in thisList))", "[thisList, thisTrigger] call AP_fnc_radiationZone", ""];
_uraniumMine setSoundEffect["$NONE$", "", "", "Owl"];
_uraniumMine setTriggerInterval 3; {private _markerName = format["turf_area_%1", _x];
    private _zone = createTrigger["EmptyDetector", getMarkerPos _markerName, false];
    _zone setTriggerArea[750, 750, 0, false];
    _zone setTriggerActivation["ANYPLAYER", "PRESENT", true];
    _zone setTriggerInterval 2;
    _zone setTriggerStatements["((this && ((vehicle player) in thisList)) || (player in thisList))", "[thisList, thisTrigger] call AP_fnc_enterActiveTurf", ""];
}
forEach["rodo_flag", "zaros_flag", "panagia_flag"];
if (AP_effSide isEqualTo civilian) then {{private _markerName = format["%1_cartel", _x];
        private _zone = createTrigger["EmptyDetector", getMarkerPos _markerName, false];
        _zone setTriggerArea[50, 50, 0, false];
        _zone setTriggerActivation["CIV", "PRESENT", true];
        _zone setTriggerInterval 1;
        private _statements = "(vehicle player) in thislist && !(player getVariable ['AP_isBountyHunter', false]) && license_civ_rebel && (vehicle player isEqualTo player) && !(toLower(primaryWeapon player) in AP_nonCartelGuns) && ((count AP_gang_data) > 0) && !AP_capturingCartel";
        if (_x isEqualTo "arms") then {_statements = _statements + ""};
        _zone setTriggerStatements[_statements, format["[""%1""] spawn AP_fnc_captureCartel", _x], ""];}
    forEach (([] call AP_fnc_cartelCfg) apply { _x select 0 });   // Armapunk 2035: all six, from the config
    evidenceTrigger = createTrigger["EmptyDetector", [20892, 19227, 0], false];
    evidenceTrigger setTriggerArea[200, 200, 0, false];
    evidenceTrigger setTriggerActivation["CIV", "PRESENT", true];
    evidenceTrigger setTriggerStatements["((this && ((vehicle player) in thisList)) || (player in thisList))", "[thisList, thisTrigger] call AP_fnc_evidenceDefense", ""];
    evidenceTrigger setSoundEffect["$NONE$", "", "", ""];
    evidenceTrigger setTriggerInterval 2;
    // AP_gangBoatFortressObject is defined NOWHERE -- not in any script, not as a
    // mission.sqm object name. The boat fortress is an Altis-era feature whose anchor
    // never came to Malden (its client init, fn_initGangBoatClient.sqf, is not even in
    // CfgFunctions), so this threw "undefined variable" on every client at zone
    // creation. Guarded rather than deleted: drop the anchor in and it works again.
    private _boatAnchor = missionNamespace getVariable ["AP_gangBoatFortressObject", objNull];
    if (!(SRV_gangBoatFortressData select 0) && {!isNull _boatAnchor}) then {gangBoatTrigger = createTrigger["EmptyDetector", _boatAnchor, false];
        gangBoatTrigger setTriggerArea[150, 150, 0, false];
        gangBoatTrigger setTriggerActivation["CIV", "PRESENT", true];
        gangBoatTrigger setTriggerStatements["((this && ((vehicle player) in thisList)) || (player in thisList))", "[thisList, thisTrigger] call AP_fnc_gangBoatDefense", ""];
        gangBoatTrigger setTriggerInterval 2;};
    huntingGrounds = createTrigger["EmptyDetector", [14254, 21937, 0], false];
    huntingGrounds setTriggerArea[500, 500, 0, false];
    huntingGrounds setTriggerActivation["CIV", "PRESENT", true];
    huntingGrounds setTriggerStatements["((this && ((vehicle player) in thisList)) || (player in thisList))", "[[thisList, thisTrigger], 'APS_fnc_huntingGrounds', 2, false, true] call AP_fnc_MP;", ""];
    huntingGrounds setSoundEffect["$NONE$", "", "", "Owl"];
    huntingGrounds setTriggerInterval 5; {_x params["_coords", "_area", "_speedlimit", "_areaName"];
        private _zone = createTrigger["EmptyDetector", _coords, false];
        _zone setTriggerArea _area;
        _zone setTriggerActivation["CIV", "PRESENT", true];
        _zone setTriggerStatements[format["this && (vehicle player) in thislist && (speed player) > %1", _speedlimit], format["['%1', speed player, %2] spawn AP_fnc_speedCamera", _areaName, _speedlimit], ""];
        _zone setTriggerInterval 1;}
    forEach[[[3618, 13116.8, 0], [10, 40, 5.464, true, 10], 50, "Kavala Square"], [[4496.78, 14037.7, 0],
        [10, 30, 56.8217, true, 10], 80, "Outside Kavala"], [[12440.3, 15878.2, 0], [10, 40, 82.631, true, 10], 50, "Lakka"], [
        [14365.6, 18023.7, 0], [15, 40, 332.915, true, 10], 80, "Outside Athira"], [[21399, 17288.5, 0],
        [10, 40, 45.062, true, 10], 80, "Paros"], [[23312.5, 19724, 0], [10, 40, 54.424, true, 10], 80, "Highway Patrol"], [
        [17186.3, 13096.8, 0], [10, 40, 20.351, true, 10], 50, "Pyrgos"], [[20746.1, 8970.15, 0],
        [10, 40, 145.139, true, 10], 80, "Panagia"], [[7640.39, 16192.2, 0], [10, 20, 279.822, true, 10], 80, "Kore"], [
        [19937.9, 11554.5, 0], [10, 40, 157.139, true, 10], 80, "Chalkeia"], [[16701.7, 15669.4, 0],
        [10, 40, 128.351, true, 10], 80, "The Federal Reserve"]];};
private _warningMarkers = allMapMarkers select {
    ("illegal_marker" in _x || "turtle" in _x || "chop_shop" in _x || "Rebelop" in _x || "factory_3" in _x || "spirit_distillery_area" in _x || "drugrunner" in _x || "Dealer" in _x || "turf_drug" in _x || "process_area_weed" in _x || "wong_" in _x) && ((getMarkerSize _x) select 1) isEqualTo 1
};
private _warningSizes = [300, 50, 6]; {private _warningTriggerSize =
    switch (true) do {case ("drugrunner" in _x): {_warningSizes select 1};
        case ("Dealer" in _x || "turf_drug" in _x || "wong_" in _x): {_warningSizes select 2};
        default {_warningSizes select 0};}; private _zone = createTrigger["EmptyDetector", getMarkerPos _x, false];
    _zone setTriggerArea[_warningTriggerSize, _warningTriggerSize, 0, false];
    _zone setTriggerActivation["ANYPLAYER", "PRESENT", true];
    _zone setTriggerInterval 2;
    _zone setTriggerStatements["((this && ((vehicle player) in thisList)) || (player in thisList))", "['You are entering a KOS (Kill on Sight) Zone! RDM rules do not apply here and you may be killed without warning! Proceed at your own risk!', 'shortwarning'] spawn AP_fnc_handleMessage; if (AP_passiveMode) then {['disable', [2]] spawn AP_fnc_passiveMode;};", ""];
}
forEach _warningMarkers; {private _zone = createTrigger["EmptyDetector", getMarkerPos _x, false];
    _zone setTriggerArea[300, 300, 0, false];
    _zone setTriggerActivation["ANYPLAYER", "PRESENT", true];
    _zone setTriggerInterval 2;
    _zone setTriggerStatements["(((this && ((vehicle player) in thisList)) || (player in thisList))) && !(environmentEnabled select 0)", "enableEnvironment [true, AP_envSounds];", "enableEnvironment [AP_ambientLifeEnabled, AP_envSounds];"];
}
forEach["turtle_1", "turtle_2"];