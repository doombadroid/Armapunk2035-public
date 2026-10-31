if ((call AP_adminLevel) <= 2) exitWith {closeDialog 0;};
if (isnil "AP_admin_showVeh") exitWith {systemChat "Admin Vehicle Display: OFF";};
disableSerialization;
systemChat "Loading admin vehicle locations...";
private _vehCount = 0; {if (_x getVariable["AP_adminVehicle", false]) then {_vehCount = _vehCount + 1;};
    uiSleep 0.001;}
forEach vehicles;
systemChat format["Admin Vehicle Display: ON - Currently %1 active admin spawned vehicles.", _vehCount];
[] spawn {while {true}
    do {if (isnil "AP_admin_showVeh") exitWith {};
        private _markers = [];
        private _marker = "";
        waitUntil {uiSleep 0.2;
            visibleMap}; {if (_x getVariable["AP_adminVehicle", false]) then {
                _marker = createMarkerLocal[format["%1_marker_AVEH", _x], getPos _x];
                _marker setMarkerTypeLocal "Mil_destroy";
                private _occupants = "";
                if ((count crew _x) isEqualTo 0) then {_occupants = "EMPTY";} else {{_occupants = _occupants + (name _x);}
                    forEach(crew _x);};
                _marker setMarkerTextLocal format["%1 - %2m - (%3)", getText(configFile >> "CfgVehicles" >> (typeOf _x) >> "displayName"), round(player distance _x), _occupants];
                _markers pushBack[_marker, _x];
                _marker setMarkerColorLocal "ColorPink";
                uiSleep 0.001;};}
        forEach vehicles;
        while {visibleMap}
        do {{_x params["_marker", "_unit"];
                if (!isNull _unit && !isNil "_unit") then {_marker setMarkerPosLocal(getPos _unit);};} forEach _markers;
            if !(visibleMap) exitWith {};
            uiSleep 0.02;}; { deleteMarkerLocal (_x select 0);}
        forEach _markers;
        _markers = [];
        if (isnil "AP_admin_showVeh") exitWith {};};};