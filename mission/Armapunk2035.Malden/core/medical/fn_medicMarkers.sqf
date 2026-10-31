private _markers = [];
private _units = [];
private _medics = [];
private _marker = "";
private _name = "";
// This is a REGISTRATION, not a loop: there is no handle to remove and no exit condition, so once added the
// handler lives for the session. Duty (AP_fnc_dutyContext) can add it to a player who later clocks off, so
// the draw is gated on AP_effSide rather than on having been registered. The else-branch below already
// deletes AP_mapMarkers, which is why the guard rides on the _mapIsOpened test instead of exiting early --
// a clocked-off medic's last set of markers is cleaned up by the path that always cleaned them up.
// Mutually exclusive with fn_trackMarkers by design: both handlers reassign AP_mapMarkers, so a player
// holding both would leak whichever set was built first.
addMissionEventHandler["Map", {params["_mapIsOpened", "_mapIsForced"];
    if (_mapIsOpened && {AP_effSide isEqualTo independent}) then {AP_mapMarkers = [];
        _markers = AP_mapMarkers;
        _medics = allPlayers select {side _x isEqualTo independent};
        _units = allDeadMen select {_x getVariable["AP_revivable", false] && !(isNil {_x getVariable "AP_name"})}; {
            if !(isNull _x) then {_name = getText(configFile >> "CfgVehicles" >> typeOf _x >> "displayName");
                _marker = createMarkerLocal[format["%1_marker", _x], getPosATL _x];
                _marker setMarkerColorLocal "ColorGreen";
                _marker setMarkerTypeLocal "Mil_destroy";
                _marker setMarkerTextLocal format["%1", _name];
                _markers pushBack[_marker, _x];};}
        forEach AP_trackedVehicles; {_marker = createMarkerLocal[format["%1_dead_marker", _x], visiblePosition _x];
            _marker setMarkerColorLocal "ColorRed";
            _marker setMarkerTypeLocal "loc_Hospital";
            _marker setMarkerSizeLocal[1.2, 1.2];
            _marker setMarkerTextLocal format["%1 Unconscious", _x getVariable["AP_name", "Unknown Player"]];
            // owner 2026-09-16 (body drag): the body rides along as element 1 so the update loop below moves
            // this marker when the body is dragged (it was a one-element pair and never moved). The third
            // element keeps the loop from ROTATING the hospital icon to the corpse's heading.
            _markers pushBack[_marker, _x, false];}
        forEach _units;{if (_x isEqualTo player) then {_marker = createMarkerLocal[format["%1_marker", _x], getPosWorld _x];
                _marker setMarkerColorLocal "ColorBlue";
                _marker setMarkerTypeLocal "mil_arrow2";
                _marker setMarkerTextLocal "YOU";
                _marker setMarkerDirLocal(getDir _x);
                _markers pushBack[_marker, _x];} else {_marker = createMarkerLocal[format["%1_marker", _x], getPosWorld _x];
                _marker setMarkerColorLocal "ColorBlue";
                _marker setMarkerTypeLocal "Mil_dot";
                _marker setMarkerTextLocal format["%1", name _x];
                _markers pushBack[_marker, _x];};}
        forEach _medics;
        [] spawn {while {!(AP_mapMarkers isEqualTo[])}
            do {{_x params["_marker", "_veh", ["_turn", true]];
                    if !(isNil "_veh") then {if !(isNull _veh) then {_marker setMarkerPosLocal(getPosWorld _veh);
                            if (_turn) then {_marker setMarkerDirLocal(getDir _veh);};};};} forEach AP_mapMarkers;
                uiSleep 0.025;};};} else {if !(AP_mapMarkers isEqualTo[]) then {{deleteMarkerLocal(_x select 0)}
            forEach AP_mapMarkers;
            AP_mapMarkers = [];};};}];