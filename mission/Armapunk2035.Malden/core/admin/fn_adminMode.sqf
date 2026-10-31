/*
    AP_fnc_adminMode  (LooneyBin) -- admin ESP toggle.
    owner 2026-06-21: GODMODE DECOUPLED. This used to bundle godmode (allowDamage/AP_aMode/hunger-thirst) WITH
    ESP; godmode now lives on its own toggle (AP_fnc_adminGodmode, the "Godmode" button). This is ESP ONLY:
      - map markers for every live player (side-colored, name + live distance) + grey [DEAD] dots for bodies,
      - a 3D wallhack (drawIcon3D label: name, health %, distance), and
      - a bounding BOX around each player (boundingBoxReal drawn as 12 drawLine3D edges, side-colored, range-faded).
    AP_adminMode stays the ESP flag (read by fn_keyDownHandler TP-facing, fn_spectateESP, fn_inventoryOpened).
    It no longer touches damage immunity -- run AP_fnc_adminGodmode for that.
*/
if ((call AP_adminLevel) <= 1) exitWith {closeDialog 0;};
if (AP_adminMode) exitWith {AP_adminMode = false;
    systemChat "Admin ESP: off";
    [["-ADMINACTION-", player, profileName, "disabled admin ESP."], "APS_fnc_logIt", 2] spawn AP_fnc_MP;};
systemChat "Admin ESP: on";
disableSerialization;
[["-ADMINACTION-", player, profileName, "enabled admin ESP."], "APS_fnc_logIt", 2] spawn AP_fnc_MP;
AP_adminMode = true;

// --- map ESP: local markers tracking every body + player while the map is open ---
[] spawn {while {true}
    do {if !(AP_adminMode) exitWith {};
        private _markers = [];
        private _marker = "";
        private _color = "";
        waitUntil {uiSleep 0.2;
            visibleMap}; {_marker = createMarkerLocal[format["%1_marker_HAX", _x], getPosATL _x];
            _marker setMarkerTypeLocal "Mil_dot";
            _marker setMarkerTextLocal format["[DEAD] - %1 - %2m", _x getVariable["AP_name", "Unknown"], round(player distance _x)];
            _marker setMarkerColorLocal "ColorGrey";
            _markers pushBack[_marker, _x];}
        forEach allDeadMen - [player]; {_marker = createMarkerLocal[format["%1_marker_HAX", _x], getPosATL _x];
            _marker setMarkerTypeLocal "Mil_dot";
            _marker setMarkerTextLocal format["%1 - %2m", name _x, round(player distance _x)];
            _markers pushBack[_marker, _x];
            _color =
            switch (side _x) do {case west: {"colorBLUFOR"};
                case independent: {"ColorGreen"};
                default {"colorCivilian"};}; _marker setMarkerColorLocal _color;}
        forEach playableUnits - [player];
        while {visibleMap && AP_adminMode}
        do {{_x params["_marker", "_unit"];
                if (!isNull _unit && !isNil "_unit") then {_marker setMarkerPosLocal(getPosATL _unit);};} forEach _markers;
            if !(visibleMap) exitWith {};
            uiSleep 0.02;}; { deleteMarkerLocal (_x select 0);}
        forEach _markers;
        _markers = [];
        if !(AP_adminMode) exitWith {};};};

// --- 3D ESP: floating label + bounding box over every player ---
[] spawn {private _handleID = addMissionEventHandler["Draw3D", {private _alpha = 0;
        private _pos = [0, 0, 0];
        private _damage = 0;
        private _name = "";
        private _color = [0, 0, 0, 1]; {if (isPlayer _x) then {if !(name _x isEqualTo profileName) then {_color =
                    switch (side _x) do {case civilian: {[0.467, 0, 1]};
                        case west: {[0, 0.5, 1]};
                        case independent: {[0, 0.65, 0]};
                        default {[1, 1, 1]};}; _alpha =
                    switch (true) do {case (player distance _x < 100): {1};
                        case (player distance _x < 250): {0.9};
                        case (player distance _x < 500): {0.8};
                        case (player distance _x < 750): {0.75};
                        case (player distance _x < 1250): {0.5};
                        default {0};}; _color pushBack _alpha;
                    _pos = visiblePosition _x;
                    _pos set[2, (getPosATL _x select 2) + 2];
                    _damage = damage _x;
                    _name = format["%1 (%2%3) - %4m", name _x, 100 - (ceil(_damage * 100)), "%", round(player distance _x)];
                    // owner 2026-06-21: ESP BOUNDING BOX. Draw the unit's real model bbox as 12 edges (the same
                    // side color + distance alpha as the label) so admins get a box around each player, not just
                    // the floating name. modelToWorldVisual uses the smooth render position; gated on _alpha>0 so
                    // out-of-range players (>1250m) cost nothing.
                    if (_alpha > 0) then {private _u = _x;
                        (boundingBoxReal _u) params ["_bbMin", "_bbMax"];
                        _bbMin params ["_x0", "_y0", "_z0"];
                        _bbMax params ["_x1", "_y1", "_z1"];
                        private _cn = [[_x0, _y0, _z0], [_x1, _y0, _z0], [_x1, _y1, _z0], [_x0, _y1, _z0],
                            [_x0, _y0, _z1], [_x1, _y0, _z1], [_x1, _y1, _z1], [_x0, _y1, _z1]] apply { _u modelToWorldVisual _x }; {
                            _x params ["_a", "_b"];
                            drawLine3D [_cn select _a, _cn select _b, _color];
                        } forEach [[0,1],[1,2],[2,3],[3,0],[4,5],[5,6],[6,7],[7,4],[0,4],[1,5],[2,6],[3,7]];};};};
            drawIcon3D["", _color, _pos, 0, -1, 0, _name, 1.5, 0.03, "PuristaMedium", "center", false];}
        forEach playableUnits;}];
    waitUntil {uiSleep 1;
        !AP_adminMode};
    removeMissionEventHandler["Draw3D", _handleID];};
