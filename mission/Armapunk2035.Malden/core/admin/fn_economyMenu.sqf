/*
    AP_fnc_economyMenu  (LooneyBin Economy -- owner request 2026-06-11)
    Owner-only live price editor. The list shows ENGLISH names only (classnames hidden) and is
    searchable. Save -> server upserts price_overrides + re-publicVariables AP_priceOv -> every shop
    reflects it on next open, survives reboot. Modes (dialog wires these):
      "init" onLoad  -> owner-gate, build the name list, show family 'virt'
      "fam"  [.,fam] -> switch family + repopulate
      "filter"       -> repopulate with the search-box text
      "select"       -> remember the picked item + fill the price editors
      "save" / "reset"
    Override slots by family (blank = leave the config default):
      virt  p0 base/buy  p1 lowest/sell  p2 market max
      weap  p0 price      (guns, ammo, attachments)
      veh   p0 buy        p1 garage sell
      cloth p0 price      (uniforms/vests/headgear/glasses/backpacks)
*/
params [["_mode", "", [""]], ["_arg", "", [""]]];
disableSerialization;

switch (toLower _mode) do {

    case "init": {if ((call AP_adminLevel) < 5) exitWith {closeDialog 0;
            ["The Economy editor is owner-only.", "basic"] spawn AP_fnc_handleMessage;};
        private _master = [];   // [family, key, englishName, p0def, p1def, p2def]  (def -1 = unknown)
        // ---- virtual items (real names + prices) ----
        { _master pushBack ["virt", _x select 0, _x select 1, _x select 2, _x select 3, _x select 4]; } forEach (["getEconList"] call AP_fnc_virtItemCfg);
        // ---- weapons + ammo + attachments (English names, deduped) ----
        private _seen = []; {if ((getNumber (_x >> "scope")) isEqualTo 2 && {(getNumber (_x >> "type")) in [1, 2, 4]}) then {
                private _dn = getText (_x >> "displayName");
                if (_dn isNotEqualTo "" && {!(_dn in _seen)}) then { _seen pushBack _dn; _master pushBack ["weap", configName _x, _dn, -1, -1, -1]; };
            };} forEach ("true" configClasses (configFile >> "CfgWeapons")); {if ((getNumber (_x >> "scope")) >= 2) then {
                private _dn = getText (_x >> "displayName");
                if (_dn isNotEqualTo "" && {!(_dn in _seen)}) then { _seen pushBack _dn; _master pushBack ["weap", configName _x, _dn, -1, -1, -1]; };
            };} forEach ("true" configClasses (configFile >> "CfgMagazines"));
        // ---- vehicles (real names + prices) ----
        { _master pushBack ["veh", _x select 0, _x select 1, _x select 2, _x select 3, -1]; } forEach (["getEconList", "", ""] call AP_fnc_vehicleConfig);
        // ---- clothing/armor: all wearables from config so nothing is gated out ----
        private _cl = []; {
            if ((getNumber (_x >> "scope")) isEqualTo 2 && {(getNumber (_x >> "ItemInfo" >> "type")) in [801, 701, 605, 603]}) then {
                private _dn = getText (_x >> "displayName");
                private _cn = configName _x;
                if (_dn isNotEqualTo "" && {!(_cn in _cl)}) then { _cl pushBack _cn; _master pushBack ["cloth", _cn, _dn, -1, -1, -1]; };};
        } forEach ("true" configClasses (configFile >> "CfgWeapons")); {
            if ((getNumber (_x >> "scope")) isEqualTo 2 && {(getNumber (_x >> "isBackpack")) isEqualTo 1}) then {
                private _dn = getText (_x >> "displayName");
                private _cn = configName _x;
                if (_dn isNotEqualTo "" && {!(_cn in _cl)}) then { _cl pushBack _cn; _master pushBack ["cloth", _cn, _dn, -1, -1, -1]; };};
        } forEach ("true" configClasses (configFile >> "CfgVehicles"));

        uiNamespace setVariable ["AP_econMaster", _master];
        uiNamespace setVariable ["AP_econFam", "virt"];
        uiNamespace setVariable ["AP_econSel", []];
        private _disp = uiNamespace getVariable ["AP_econDisplay", displayNull];
        if (!isNull _disp) then { (_disp displayCtrl 92006) ctrlEnable false; };   // selected-name box is read-only
        ["filter"] call AP_fnc_economyMenu;};

    case "fam": {uiNamespace setVariable ["AP_econFam", _arg];
        ["filter"] call AP_fnc_economyMenu;};

    case "filter": {private _disp = uiNamespace getVariable ["AP_econDisplay", displayNull];
        if (isNull _disp) exitWith {};
        private _list = _disp displayCtrl 92020;
        private _fam = uiNamespace getVariable ["AP_econFam", "virt"];
        private _q = toLower (ctrlText (_disp displayCtrl 92010));
        private _master = uiNamespace getVariable ["AP_econMaster", []];
        lbClear _list;
        private _famName = ["virt", "weap", "veh", "cloth"];
        { (_disp displayCtrl (92051 + _forEachIndex)) ctrlSetTextColor (if ((_famName select _forEachIndex) isEqualTo _fam) then {[0.13, 0.9, 0.21, 1]} else {[1, 1, 1, 1]}); } forEach _famName;
        private _n = 0; {_x params ["_f", "_k", "_nm", "_p0"];
            if ((_f isEqualTo _fam) && {_n < 500} && {_q isEqualTo "" || {_q in (toLower _nm)}}) then {
                private _ov = [_f, _k] call AP_fnc_priceOv;
                private _shown = if (_ov isNotEqualTo [] && {(_ov select 2) >= 0}) then { format ["$%1 *", [_ov select 2] call AP_fnc_numberText] }
                    else { if (_p0 >= 0) then { format ["$%1", [_p0] call AP_fnc_numberText] } else { "set price" } };
                private _idx = _list lbAdd format ["%1   (%2)", _nm, _shown];
                _list lbSetData [_idx, format ["%1|%2", _f, _k]];
                _n = _n + 1;};} forEach _master;
        (_disp displayCtrl 92001) ctrlSetText format ["ECONOMY — %1 (%2%3)", toUpper _fam, _n, if (_n >= 500) then {"+, search to narrow"} else {" shown"}];
    };

    case "select": {private _disp = uiNamespace getVariable ["AP_econDisplay", displayNull];
        if (isNull _disp) exitWith {};
        private _sel = lbCurSel (_disp displayCtrl 92020);
        if (_sel < 0) exitWith {};
        ((_disp displayCtrl 92020) lbData _sel) splitString "|" params [["_f", ""], ["_k", ""]];
        private _master = uiNamespace getVariable ["AP_econMaster", []];
        private _row = _master param [_master findIf { ((_x select 0) isEqualTo _f) && {(_x select 1) isEqualTo _k} }, []];
        if (_row isEqualTo []) exitWith {};
        _row params ["", "", "_nm", "_p0", "_p1", "_p2"];
        uiNamespace setVariable ["AP_econSel", [_f, _k, _nm]];
        (_disp displayCtrl 92006) ctrlSetText _nm;
        // prefill edits with the active override, else blank (blank = keep default)
        private _ov = [_f, _k] call AP_fnc_priceOv;
        private _e = ["", "", ""];
        if (_ov isNotEqualTo []) then { { if ((_ov select (2 + _forEachIndex)) >= 0) then { _e set [_forEachIndex, str (_ov select (2 + _forEachIndex))]; }; } forEach _e; };
        { (_disp displayCtrl ([92031, 92032, 92033] select _forEachIndex)) ctrlSetText _x; } forEach _e;
        // labels + which slots apply per family
        private _lbls = switch (_f) do {case "virt": { ["Buy / Base $:", "Sell / Low $:", "Market Max $:", [true, true, true]] };
            case "veh":  { ["Buy $:", "Garage Sell $:", "(n/a)", [true, true, false]] };
            default      { ["Price $:", "(n/a)", "(n/a)", [true, false, false]] };};
        { (_disp displayCtrl ([92041, 92042, 92043] select _forEachIndex)) ctrlSetText _x; } forEach [_lbls select 0, _lbls select 1, _lbls select 2];
        { (_disp displayCtrl ([92031, 92032, 92033] select _forEachIndex)) ctrlEnable _x; } forEach (_lbls select 3);
        private _defTxt = if (_p0 >= 0) then {format ["Default: $%1%2%3", [_p0] call AP_fnc_numberText,
                if (_p1 >= 0 && {_f in ["virt", "veh"]}) then {format [" / $%1", [_p1] call AP_fnc_numberText]} else {""},
                if (_p2 >= 0 && {_f isEqualTo "virt"}) then {format [" / $%1", [_p2] call AP_fnc_numberText]} else {""}]
        } else { "No stored default — set an absolute price." };
        (_disp displayCtrl 92040) ctrlSetStructuredText parseText format ["<t color='#9adcff'>%1</t>", _defTxt];};

    case "save": {private _disp = uiNamespace getVariable ["AP_econDisplay", displayNull];
        if (isNull _disp) exitWith {};
        (uiNamespace getVariable ["AP_econSel", []]) params [["_fam", ""], ["_key", ""], ["_nm", ""]];
        if (_key isEqualTo "") exitWith { ["Pick an item from the list first.", "basic"] spawn AP_fnc_handleMessage; };
        private _rd = { params ["_idc"]; private _t = ctrlText (_disp displayCtrl _idc); if (_t isEqualTo "") then { -1 } else { (round (parseNumber _t)) max 0 } };
        [["set", _fam, _key, [92031] call _rd, [92032] call _rd, [92033] call _rd, _nm, player], "APS_fnc_economySRV", 2] spawn AP_fnc_MP;
        [format ["Saving %1...", _nm], "basic"] spawn AP_fnc_handleMessage;
        [_disp] spawn { params ["_disp"]; uiSleep 1.5; if (!isNull _disp) then { ["filter"] call AP_fnc_economyMenu; }; };};

    case "reset": {private _disp = uiNamespace getVariable ["AP_econDisplay", displayNull];
        if (isNull _disp) exitWith {};
        (uiNamespace getVariable ["AP_econSel", []]) params [["_fam", ""], ["_key", ""]];
        if (_key isEqualTo "") exitWith {};
        [["reset", _fam, _key, player], "APS_fnc_economySRV", 2] spawn AP_fnc_MP;
        { (_disp displayCtrl _x) ctrlSetText ""; } forEach [92031, 92032, 92033];
        [_disp] spawn { params ["_disp"]; uiSleep 1.5; if (!isNull _disp) then { ["filter"] call AP_fnc_economyMenu; }; };};};
