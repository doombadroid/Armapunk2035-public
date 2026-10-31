private _markers = [];
private _deadUnits = [];
private _marker = "";
private _name = "";
private _down = false;
private _vehicleName = "";
// Registered by fn_initCiv.sqf:222 -- the only caller left, since PR7 deleted the cop lobby init that was
// the other one. Like fn_medicMarkers it is a registration with no handle and no exit condition, so once
// per session is all anyone gets, and that one registration now covers a player's whole life including
// their shifts. The independent exclusion keeps a civilian who clocked in to Trauma Team from running BOTH
// Map handlers, which would leak markers because they each reassign AP_mapMarkers. Everything else in the
// body was already AP_effSide-gated.
addMissionEventHandler["Map", {params["_mapIsOpened", "_mapIsForced"];
    if (_mapIsOpened && {!(AP_effSide isEqualTo independent)}) then {AP_mapMarkers = [];
        _markers = AP_mapMarkers; {if !(isNull _x) then {
                _vehicleName = getText(configFile >> "CfgVehicles" >> typeOf _x >> "displayName");
                _marker = createMarkerLocal[format["%1_marker", _x], getPosATL _x];
                _marker setMarkerColorLocal "ColorGreen";
                _marker setMarkerTypeLocal "Mil_destroy";
                _marker setMarkerTextLocal format["%1", _vehicleName];
                _markers pushBack[_marker, _x];};}
        forEach AP_trackedVehicles;
        if (((serverTime - serverStartTime) < 600)) then {{if !(_x in AP_trackedVehicles) then {
                    _vehicleName = getText(configFile >> "CfgVehicles" >> typeOf _x >> "displayName");
                    _marker = createMarkerLocal[format["%1_marker", _x], getPosATL _x];
                    _marker setMarkerColorLocal "ColorGreen";
                    _marker setMarkerTypeLocal "mil_dot";
                    _marker setMarkerTextLocal format["%1%2", "Owned Vehicle - ", _vehicleName];
                    _markers pushBack[_marker, _x];};}
            forEach(AP_vehicles select {!isNull _x && {alive _x && (_x isKindOf "Car" || _x isKindOf "Air" || _x isKindOf "Ship")
                    // owner 2026-06-15 (#241/#244): the post-restart "Owned Vehicle" map sweep is a CIVILIAN
                    // find-my-car QoL. #189 gated it to the viewer's side, but that still showed a COP their
                    // cop-side cars ("vehicle markers on the map on cop"). Cop/med vehicles spawn at HQ and
                    // should NEVER get a map marker -> only civ-side (and legacy "") owned vehicles are marked.
                    && {(_x getVariable ["AP_side", ""]) in ["", "civ"]}}});};
        if (AP_effSide isEqualTo west && {AP_copRole in ["medic", "all"]}) then {_deadUnits = allDeadMen select {
                _x getVariable["AP_revivable", false] && !(isNil {_x getVariable "AP_name"})}; {
                _marker = createMarkerLocal[format["%1_dead_marker", _x], visiblePosition _x];
                _marker setMarkerColorLocal "ColorRed";
                _marker setMarkerTypeLocal "loc_Hospital";
                _marker setMarkerTextLocal format["%1 Unconscious", _x getVariable["AP_name", "Unknown Player"]];
                _markers pushBack[_marker, _x];}
            forEach _deadUnits;};
        if (AP_effSide isEqualTo civilian) then {   // owner 2026-07-13: Sixth Sense (71) baked to core -- all civs see group death markers
            {if ((_x getVariable["AP_group", grpNull]) isEqualTo group player) then {
                    _marker = createMarkerLocal[format["%1_groupDead_marker", _x], visiblePosition _x];
                    _marker setMarkerColorLocal "ColorRed";
                    _marker setMarkerTypeLocal "loc_Hospital";
                    _marker setMarkerTextLocal format["%1 Unconscious", _x getVariable["AP_name", "Unknown Player"]];
                    _markers pushBack[_marker, _x];};}
            forEach allDeadMen;};
 {if (_x isEqualTo player) then {_marker = createMarkerLocal[format["%1_marker", _x], getPosWorld _x];
                    _marker setMarkerColorLocal "ColorBlue";
                    _marker setMarkerTypeLocal "mil_arrow2";
                    _marker setMarkerTextLocal "YOU";
                    _marker setMarkerDirLocal(getDir _x);
                    _markers pushBack[_marker, _x];} else {
                    if (AP_effSide isEqualTo west && side _x isEqualTo west && !(_x getVariable["AP_blinded", false])) then {
                        _marker = createMarkerLocal[format["%1_marker", _x], getPosWorld _x];
                        _marker setMarkerColorLocal "ColorBlue";
                        _marker setMarkerTypeLocal "Mil_dot";
                        _marker setMarkerTextLocal format["%1", name _x];
                        _markers pushBack[_marker, _x];};
                    if (!(AP_effSide isEqualTo west) && !(side _x isEqualTo west) && !(_x getVariable["AP_blinded", false]) && !(_x getVariable["AP_restrained", false]) && !AP_inEvent) then {
                        if (!isNull(group player)) then {if (group player isEqualTo group _x) then {
                                _marker = createMarkerLocal[format["%1_marker", _x], getPosWorld _x];
                                _marker setMarkerColorLocal "ColorBlue";
                                _marker setMarkerTypeLocal "Mil_dot";
                                _marker setMarkerTextLocal format["%1", name _x];
                                _markers pushBack[_marker, _x];};};
                        if !(AP_gang_data isEqualTo[] && !AP_inEvent) then {if !(_x getVariable["gang_data", []] isEqualTo[]) then {
                                if ((AP_gang_data select 0) isEqualTo((_x getVariable["gang_data", []]) select 0)) then {
                                    _marker = createMarkerLocal[format["%1_marker", _x], getPosWorld _x];
                                    _marker setMarkerColorLocal "ColorBlue";
                                    _marker setMarkerTypeLocal "Mil_dot";
                                    _marker setMarkerTextLocal format["%1", name _x];
                                    _markers pushBack[_marker, _x];};};};};};}
            forEach allPlayers;;
        if (SRV_governorData param[3, false]) then {
            "Weed_p_2"
            setMarkerAlphaLocal 1;} else {
            "Weed_p_2"
            setMarkerAlphaLocal 0;};
        [] spawn {while {visibleMap}
            do {{
                    _x getVariable["AP_turf_data", [-1, "Unknown", false, "Unknown"]] params[["_gangID", -1, [0]], ["_gangName", "Unknown", [""]], ["_active", false, [false]]];
                    private _countLabel = "";
                    private _marker = format["turf_label_%1", _x];
                    private _markerPos = getMarkerPos _marker;
                    if ((AP_gang_data select 0) isEqualTo _gangID) then {private _inTurf = allPlayers select {
                            _x distance _markerPos < 750};
                        _countLabel = format[" (%1)", count _inTurf];};
                    if !(_gangID isEqualTo - 1) then {_marker setMarkerTextLocal format["Turf of %1%2", _gangName, _countLabel];
                        private _markerColor =
                        if (_active) then {"ColorRed"} else {"ColorUNKNOWN"};
                        _marker setMarkerColorLocal _markerColor;
                        (format["turf_area_%1", _x]) setMarkerColorLocal _markerColor;} else {_marker setMarkerTextLocal "Uncontrolled";};
                } forEach [rodo_flag, zaros_flag, panagia_flag];
                if !(visibleMap) exitWith {};
                uiSleep 4;};};
        [] spawn {while {visibleMap}
            do {{
                    _x getVariable["AP_boatflag_data", ["", -1, "Uncontrolled"]] params[["_captureTarget", "", [""]], ["_gangID", -1, [0]], ["_gangName", "Uncontrolled", [""]]];
                    private _countLabel = "";
                    private _marker = format["boat_capture_label_%1", _captureTarget];
                    if !(_gangID isEqualTo - 1) then {if ((AP_gang_data select 0) isEqualTo _gangID) then {
                            _marker setMarkerColorLocal "ColorGreen";} else {_marker setMarkerColorLocal "ColorRed";};
                        _marker setMarkerTextLocal format["%1 - %2", _captureTarget, _gangName];} else {
                        _marker setMarkerTextLocal format["%1 - Uncontrolled", _captureTarget];};
                } forEach (SRV_gangBoatFortressData select 1);
                if !(visibleMap) exitWith {};
                uiSleep 4;}};
        [] spawn {while {!(AP_mapMarkers isEqualTo[])}
            do {{_x params["_marker", "_veh"];
                    if !(isNil "_veh") then {if !(isNull _veh) then {_marker setMarkerPosLocal(getPosWorld _veh);
                            _marker setMarkerDirLocal(getDir _veh);};};} forEach AP_mapMarkers;
                uiSleep 0.025;};};} else {if !(AP_mapMarkers isEqualTo[]) then {{deleteMarkerLocal(_x select 0)}
            forEach AP_mapMarkers;
            AP_mapMarkers = [];};};}];