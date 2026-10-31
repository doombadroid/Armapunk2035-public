/*
    fn_mapWpHud.sqf — the waypoint OUTSIDE the map: a Draw3D icon with live
    distance, exactly what the native map's custom waypoint gives you.

    One waypoint, mission-global on this client (AP_mapWaypoint = [x,y] or []).
    The Draw3D handler lives across dialog opens and closes -- the whole point
    is that the marker is there while you PLAY -- and removes itself when the
    waypoint clears, so an empty state costs nothing per frame.

        [[4200, 7800]] call AP_fnc_mapWpHud;   // set / move
        [[]]           call AP_fnc_mapWpHud;   // clear
*/

params [["_pos", [], [[]]]];

AP_mapWaypoint = _pos;

// native-map parity: the same point as a local marker, so M shows it too
if (_pos isEqualTo []) then {
    deleteMarkerLocal "AP_mapwp";
} else {
    if (getMarkerColor "AP_mapwp" isEqualTo "") then {
        createMarkerLocal ["AP_mapwp", _pos];
        "AP_mapwp" setMarkerTypeLocal "mil_objective";
        "AP_mapwp" setMarkerColorLocal "ColorCIV";
        "AP_mapwp" setMarkerTextLocal "WP";
    } else {
        "AP_mapwp" setMarkerPosLocal _pos;
    };
};

private _id = uiNamespace getVariable ["AP_mapWpDraw", -1];

if (_pos isEqualTo []) exitWith {
    if (_id > -1) then { removeMissionEventHandler ["Draw3D", _id]; uiNamespace setVariable ["AP_mapWpDraw", -1]; };
    true
};

if (_id isEqualTo -1) then {
    _id = addMissionEventHandler ["Draw3D", {
        private _p = missionNamespace getVariable ["AP_mapWaypoint", []];
        if (_p isEqualTo []) exitWith {};
        // drawIcon3D takes PositionAGL, whose z is ABOVE THE SURFACE (ATL over
        // land, water level at sea) -- not ASL. Feeding it terrain ASL + 2 put
        // the icon ~170 m up over the palace plaza (owner, 2026-09-02: "it
        // should be ground level, not in the air"). 2 m over the surface, and
        // the same over water where ATL would be the sea floor.
        private _w = [_p select 0, _p select 1, 2];
        private _d = player distance2D _w;
        private _txt = if (_d >= 1000) then { format ["%1km", (_d / 1000) toFixed 1] } else { format ["%1m", round _d] };
        drawIcon3D [
            "\A3\ui_f\data\map\markers\military\objective_CA.paa",
            [0.79, 0.89, 0.10, 0.9],
            _w,
            0.9, 0.9, 0, _txt, 2, 0.032, "RobotoCondensed", "center"
        ];
    }];
    uiNamespace setVariable ["AP_mapWpDraw", _id];
};
true
