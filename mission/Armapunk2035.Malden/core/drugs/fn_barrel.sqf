/*
    AP_fnc_barrel  (LooneyBin -- house spirit aging, client side. Clone of core/drugs/fn_greenhouse.sqf.
    owner 2026-06-21: scotch/whiskey/rum age in the house aging barrel exactly like house weed.)
    Server (APS_fnc_barrelSRV) is authoritative for the crop + persistence; this gathers the request
    (consume new-make, work out carry capacity) and shows status.
    Crop var on the house (global, set by the server): AP_barrel_crop = [[type, laidUnix, count], ...]
      type "scotch"/"whiskeyc"/"whiskeyr"/"rum"; auto-ages 0->1->2 at 6h/stage, capped at stage 2 (15-Year).
    Each spirit unit weighs 3. Cap = floor(AP_vcap / 30) units. Requires the Aging Barrel upgrade.
    Cases: ["laydown",[house]]  ["collect",[house]]  ["status",[house]]
*/
params [["_case", "", [""]], ["_data", [], [[]]]];
private _nowUnix = (missionNamespace getVariable ["AP_bootUnix", 0]) + serverTime;
private _types = ["scotch", "whiskeyc", "whiskeyr", "rum"];
private _typeName = {params ["_t", "_stage"];
    private _names = switch (_t) do {case "scotch":   { ["New Make Scotch", "Scotch", "15 Year Scotch"] };
        case "whiskeyc": { ["White Dog Corn", "Corn Whiskey", "Aged Corn Whiskey"] };
        case "whiskeyr": { ["White Dog Rye", "Rye Whiskey", "Aged Rye Whiskey"] };
        case "rum":      { ["New Make Rum", "Rum", "Aged Rum"] };
        default { ["?", "?", "?"] };};
    _names param [_stage min 2, "?"]};

switch (_case) do {case "laydown": {_data params [["_house", objNull, [objNull]]];
        if (isNull _house) exitWith {};
        private _crop = _house getVariable ["AP_barrel_crop", []];
        private _cur = 0; { _cur = _cur + (_x param [2, 0]); } forEach _crop;
        private _maxUnits = floor ((_house getVariable ["AP_vcap", 0]) / 30);
        private _room = (_maxUnits - _cur) max 0;
        if (_room <= 0) exitWith {
            [format ["The aging barrel is full (%1 / %2 units).", _cur, _maxUnits], "basic"] spawn AP_fnc_handleMessage;};
        // lay down every NEW-MAKE (stage-0) spirit the player carries, oldest-spirit-line first, up to capacity
        private _laidAny = false; {private _t = _x;
            private _have = missionNamespace getVariable [format ["AP_inv_%1_0", _t], 0];
            if (_have > 0 && {_room > 0}) then {private _qty = _have min _room;
                if ([false, format ["%1_0", _t], _qty] call AP_fnc_handleInv) then {
                    [["laydown", [player, _house, _t, _qty]], "APS_fnc_barrelSRV", 2] spawn AP_fnc_MP;
                    _room = _room - _qty;
                    _laidAny = true;};};} forEach _types;
        if !(_laidAny) then {
            ["You have no new-make spirits (New Make Scotch / White Dog Corn or Rye / New Make Rum) to lay down. Distill them at a distillery first.", "basic"] spawn AP_fnc_handleMessage;
        };};

    case "collect": {_data params [["_house", objNull, [objNull]]];
        if (isNull _house) exitWith {};
        private _crop = _house getVariable ["AP_barrel_crop", []];
        if (_crop isEqualTo []) exitWith { ["The aging barrel is empty.", "basic"] spawn AP_fnc_handleMessage; };
        private _free = floor (AP_maxWeight - AP_carryWeight);
        private _want = floor (_free / 3);   // each spirit bottle weighs 3
        if (_want <= 0) exitWith { ["Your inventory is full -- make room before collecting.", "basic"] spawn AP_fnc_handleMessage; };
        [["collect", [player, _house, _want]], "APS_fnc_barrelSRV", 2] spawn AP_fnc_MP;};

    case "status": {_data params [["_house", objNull, [objNull]]];
        if (isNull _house) exitWith {};
        private _crop = _house getVariable ["AP_barrel_crop", []];
        private _maxUnits = floor ((_house getVariable ["AP_vcap", 0]) / 30);
        if (_crop isEqualTo []) exitWith {
            [format ["Aging barrel empty. Capacity: %1 units. Lay down new-make spirits (distilled at a distillery) to age them.", _maxUnits], "basic"] spawn AP_fnc_handleMessage;
        };
        private _lines = []; private _cur = 0; {_x params ["_t", "_lt", "_cnt"];
            _cur = _cur + _cnt;
            private _stage = (floor (((_nowUnix - _lt) max 0) / 21600)) min 2;
            private _nm = [_t, _stage] call _typeName;
            private _eta = if (_stage >= 2) then { "fully aged (15yr)" } else {private _next = (_lt + ((_stage + 1) * 21600)) - _nowUnix;
                format ["~%1h to next stage", (_next / 3600) toFixed 1]};
            _lines pushBack format ["  %1x %2 (stage %3/2 - %4)", _cnt, _nm, _stage, _eta];} forEach _crop;
        [format ["AGING BARREL: %1/%2 units\n%3", _cur, _maxUnits, _lines joinString "\n"], "basic"] spawn AP_fnc_handleMessage;};};
