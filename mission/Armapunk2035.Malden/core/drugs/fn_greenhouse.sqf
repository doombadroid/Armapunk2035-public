/*
    AP_fnc_greenhouse  (LooneyBin -- house weed grow, client side. spec: weed.md)
    Server (APS_fnc_greenhouseSRV) is authoritative for the crop + persistence; this just gathers the
    request (consume seeds, work out carry capacity) and shows status.
    Crop var on the house (global, set by the server): AP_gh_crop = [[strain,plantedUnix,count],...]
      strain "s"=Sativa (mature stage 2 / 2h), "i"=Indica (mature stage 3 / 3h).
    Cases: ["plant",[house,strain]]  ["harvest",[house]]  ["status",[house]]
*/
params [["_case", "", [""]], ["_data", [], [[]]]];
private _nowUnix = (missionNamespace getVariable ["AP_bootUnix", 0]) + serverTime;
private _stageName = {params ["_st", "_stage"];
    private _mat = if (_st isEqualTo "s") then {2} else {3};
    if (_stage >= _mat) then { "MATURE" } else {
        switch (_stage) do { case 0: {"Seed"}; case 1: {"Seedling"}; case 2: {"Juvenile"}; default {"Growing"} };};};

switch (_case) do {case "plant": {_data params [["_house", objNull, [objNull]], ["_strain", "", [""]]];
        if (isNull _house || {!(_strain in ["s", "i"])}) exitWith {};
        private _seedItem = if (_strain isEqualTo "s") then {"cannas_0"} else {"cannai_0"};
        private _sName = if (_strain isEqualTo "s") then {"Sativa"} else {"Indica"};
        private _have = missionNamespace getVariable [format ["AP_inv_%1", _seedItem], 0];
        if (_have <= 0) exitWith {
            [format ["You have no %1 seeds. Buy them at any drug dealer ($100 each).", _sName], "basic"] spawn AP_fnc_handleMessage;};
        private _crop = _house getVariable ["AP_gh_crop", []];
        private _cur = 0; { _cur = _cur + (_x param [2, 0]); } forEach _crop;
        private _maxPlants = floor ((_house getVariable ["AP_vcap", 0]) / 10);
        private _room = (_maxPlants - _cur) max 0;
        if (_room <= 0) exitWith {
            [format ["Greenhouse is full (%1 / %2 plants).", _cur, _maxPlants], "basic"] spawn AP_fnc_handleMessage;};
        private _qty = _have min _room;
        // consume the seeds locally, then ask the server to register the planting
        if !([false, _seedItem, _qty] call AP_fnc_handleInv) exitWith {
            ["Couldn't take your seeds -- try again.", "basic"] spawn AP_fnc_handleMessage;};
        [["plant", [player, _house, _strain, _qty]], "APS_fnc_greenhouseSRV", 2] spawn AP_fnc_MP;};

    case "harvest": {_data params [["_house", objNull, [objNull]]];
        if (isNull _house) exitWith {};
        private _crop = _house getVariable ["AP_gh_crop", []];
        if (_crop isEqualTo []) exitWith { ["Nothing is growing here.", "basic"] spawn AP_fnc_handleMessage; };
        // tally what's mature, then fill the player's free carry weight (bud weighs 1): Sativa first, then Indica
        private _matS = 0; private _matI = 0; {
            _x params ["_st", "_pt", "_cnt"]; if (_pt > 1000000000) then { _pt = _pt - 1700000000 };  // owner 2026-06-16: normalize PRE-#248 full-unix plant times to the epoch-offset clock so old crops still mature
            private _mat = if (_st isEqualTo "s") then {2} else {3};
            if (floor (((_nowUnix - _pt) max 0) / 3600) >= _mat) then {
                if (_st isEqualTo "s") then { _matS = _matS + _cnt } else { _matI = _matI + _cnt };};} forEach _crop;
        if (_matS + _matI <= 0) exitWith { ["No plants are mature yet -- check the greenhouse status.", "basic"] spawn AP_fnc_handleMessage; };
        private _free = floor (AP_maxWeight - AP_carryWeight);
        if (_free <= 0) exitWith { ["Your inventory is full -- make room before harvesting.", "basic"] spawn AP_fnc_handleMessage; };
        private _wantS = _matS min _free;
        private _wantI = _matI min (_free - _wantS);
        [["harvest", [player, _house, _wantS, _wantI]], "APS_fnc_greenhouseSRV", 2] spawn AP_fnc_MP;};

    case "status": {
        // owner 2026-07-15: nudge the server to re-read this house's crop from the DB (first touch per session)
        // so an Enrique run from earlier in the session shows up -- re-check the greenhouse to see it land.
        _data params [["_hSync", objNull, [objNull]]];
        if (!isNull _hSync) then { [["sync", [player, _hSync]], "APS_fnc_greenhouseSRV", 2] spawn AP_fnc_MP; };
        _data params [["_house", objNull, [objNull]]];
        if (isNull _house) exitWith {};
        private _crop = _house getVariable ["AP_gh_crop", []];
        private _maxPlants = floor ((_house getVariable ["AP_vcap", 0]) / 10);
        if (_crop isEqualTo []) exitWith {
            [format ["Greenhouse empty. Capacity: %1 plants. Buy Sativa/Indica seeds at a drug dealer and plant them here.", _maxPlants], "basic"] spawn AP_fnc_handleMessage;
        };
        private _lines = []; private _cur = 0; private _ready = 0; {
            _x params ["_st", "_pt", "_cnt"]; if (_pt > 1000000000) then { _pt = _pt - 1700000000 };  // owner 2026-06-16: normalize PRE-#248 full-unix plant times to the epoch-offset clock so old crops still mature
            _cur = _cur + _cnt;
            private _stage = floor (((_nowUnix - _pt) max 0) / 3600);
            private _mat = if (_st isEqualTo "s") then {2} else {3};
            private _nm = [_st, _stage] call _stageName;
            if (_stage >= _mat) then { _ready = _ready + _cnt; };
            private _sName = if (_st isEqualTo "s") then {"Sativa"} else {"Indica"};
            private _eta = if (_stage >= _mat) then {"ready to harvest"} else { format ["%1h left", _mat - _stage] };
            _lines pushBack format ["  %1x %2 - %3 (%4)", _cnt, _sName, _nm, _eta];} forEach _crop;
        [format ["GREENHOUSE: %1/%2 plants, %3 ready\n%4", _cur, _maxPlants, _ready, _lines joinString "\n"], "basic"] spawn AP_fnc_handleMessage;
    };};
