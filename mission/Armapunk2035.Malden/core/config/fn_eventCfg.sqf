params[["_mode", "", [""]], ["_param", -1, [0, ""]]];
private _eventList = [[1, "Gun Game", [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17], {[
            [1, objNull, _this], "APS_fnc_eventGunGameSRV", 2] spawn AP_fnc_MP;}, false],
    [2, "Battle Royale", [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17], {[
            [_this], "APS_fnc_eventBRSRV", 2] spawn AP_fnc_MP;}, false], [4, "Graveyard", [50], {[
            [1, objNull, _this], "APS_fnc_eventGraveyardSRV", 2] spawn AP_fnc_MP;}, true], [5, "PURGE", [18, 19, 20, 21], {[
            [_this], "APS_fnc_eventPurgeSRV", 2] spawn AP_fnc_MP;}, true], [7, "Gridrunner", [1000], {[
            [1, objNull, _this], "APS_fnc_eventGridrunnerSRV", 2] spawn AP_fnc_MP;}, false],
    [8, "Chemtrail Flyover", [18, 19, 20, 21], {[[_this], "APS_fnc_eventChemtrailSRV", 2] spawn AP_fnc_MP;}, true],
    [9, "Bug Invasion", [18, 19, 20, 21], {[[_this], "APS_fnc_eventBugInvasionSRV", 2] spawn AP_fnc_MP;}, true],
    [10, "Lizard Police", [18], {[[_this], "APS_fnc_eventLizardPoliceSRV", 2] spawn AP_fnc_MP;}, true],
    [11, "Blackout", [18, 19, 20, 21], {[[_this], "APS_fnc_eventBlackoutSRV", 2] spawn AP_fnc_MP;}, true],
    // owner 2026-07-17: HC-driven dynamic events. _this = location ID -> resolve to a position (the SRVs take a
    // position). These are self-contained world events (do NOT set AP_adminEvent -> can't brick the one-event guard).
    [13, "Ice Cream Truck of Doom", [18, 19, 20, 21], {
        [[(["getLocationByID", _this] call AP_fnc_eventCfg) param [2, [0,0,0]]], "APS_fnc_eventIceCreamSRV", 2] spawn AP_fnc_MP;
    }, true], [14, "Supply Bomber", [18, 19, 20, 21], {
        [[(["getLocationByID", _this] call AP_fnc_eventCfg) param [2, [0,0,0]]], "APS_fnc_eventSupplyBomberSRV", 2] spawn AP_fnc_MP;
    }, true], [15, "Crop Duster", [18, 19, 20, 21], {
        [[(["getLocationByID", _this] call AP_fnc_eventCfg) param [2, [0,0,0]]], "APS_fnc_eventCropDusterSRV", 2] spawn AP_fnc_MP;
    }, true], [16, "Smuggler Speedboat Run", [18, 19, 20, 21], {
        [[(["getLocationByID", _this] call AP_fnc_eventCfg) param [2, [0,0,0]]], "APS_fnc_eventSmugglerBoatSRV", 2] spawn AP_fnc_MP;
    }, true]];
private _locationList = [[1, "Molos (DP17)", [27000, 23210, 0]], [2, "Galati (DP5)", [10332, 19059, 0]],
    [3, "Hunting Grounds", [14200, 22169, 0]], [4, "Factory (Lakka)", [12623, 16384, 0]], [5, "Shoreline Ruins", [21381, 10931, 0]],
    [6, "Mountain", [6358, 12358, 0]], [7, "Power Plant (Chop Shop)", [15370, 16034, 0]], [8, "Charkia Oil Processor", [18315, 15531, 0]],
    [9, "Buoy Graveyard", [21817, 6268, 0]], [10, "Resort", [3583, 14464, 0]], [11, "Military Outpost", [23569, 21101, 0]],
    [12, "Salt Flats", [23115, 18423, 0]], [13, "Land Bridge", [2675, 22094, 0]], [14, "Kavala Castle", [3054.781, 13199.787, 0]],
    [15, "Skiptracer Racetrack", [5479.19, 15000.8, 0]], [16, "Hairpin Turn", [8700.26, 15891.2, 0]],
    [17, "Kavala Checkpoint", [4498.3, 14038.9, 0]], [18, "Kavala Square", [3650.41, 13111.3, 0]],
    [19, "Athira Square", [14042.3, 18747.9, 0]], [20, "Pyrgos Square", [16756.7, 12516.5, 0]], [21, "Sofia Square", [25705.4, 21367.9, 0]],
    [50, "Halloween Graveyard", [9662, 15856, 0]], [100, "Kavala Mountains", [666, 666, 666]],
    [101, "Warzone Island", [10197.795, 7287.634, 0]], [102, "Arms (Church)", [10691.475, 9279.781, 0]],
    [1000, "Gridrunner BH Kavala", [5465.98, 14997, 0]]];
if (_mode == "") exitWith {};
private "_return";
switch (_mode) do {case "getEvents": {_return = _eventList;}; case "getEventLocationRows": {
                private _eventLocations = (_eventList param[_eventList findIf {(_x select 0) isEqualTo _param}, []]) param[2, []];
                _return = []; {if ((_x select 0) in _eventLocations) then {_return pushBack _x};}
                forEach _locationList;};
        case "getEventByID": {_return = []; {if (_param isEqualTo(_x select 0)) exitWith {_return = _x};}
                forEach _eventList;};
        case "getLocationByID": {{if (_param isEqualTo(_x select 0)) exitWith {_return = _x};}
                forEach _locationList;};}; _return ;