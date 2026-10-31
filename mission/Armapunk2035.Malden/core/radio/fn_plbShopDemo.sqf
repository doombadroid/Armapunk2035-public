/*
    AP_fnc_plbShopDemo  (LooneyBin, ui branch, PROOF) -- NIGHT CITY shop, mockup-exact. Custom PAA chrome
    (dialog\plbShop.hpp). LEFT: weapon rows (faction badge + name/sub + gold mono price; magenta selection).
    RIGHT: focused detail card (preview, mint price PLATE, meta, segmented LOAD meter, cyan BUY) + a scrollable
    MAGAZINES / ACCESSORIES list built from the selected weapon's REAL compatible mags
    (AP_fnc_fetchWeaponMagazines) + WeaponSlotsInfo>>compatibleItems attachments (demo prices).
    Owner test: !shopdemo (ESC closes). Does NOT touch live shops.
    Modes:  []  open+build  |  ["row",_i]  select weapon  |  ["acc",_i]  select addon  |  ["buy"]  demo purchase
*/
params [["_mode", "open", [""]], ["_arg", 0, [0]]];
disableSerialization;
if (!hasInterface) exitWith {};

#define NC_BLUE  [0.255, 0.478, 0.800, 1]
#define NC_OLIVE [0.463, 0.569, 0.329, 1]
#define NC_MAGEN [0.945, 0.239, 0.659, 1]
#define NC_CLEAR [0, 0, 0, 0]

// [ class, name, sub, price, weightKg, badgeColour ]
private _items = [["srifle_DMR_03_F", "DMR-03 Marksman", "7.62 - marksman", 9000,  6.0,  NC_BLUE],
    ["arifle_Katiba_F", "Katiba 6.5",      "6.5 - illegal",   5000,  5.5,  NC_OLIVE],
    ["arifle_AK12_F",   "AK-12",           "7.62 - illegal",  5000,  5.5,  NC_BLUE],
    ["SMG_03_TR_black", "P90 SMG",         "5.7 - compact",   7000,  3.0,  NC_BLUE],
    ["launch_RPG7_F",   "RPG-7",           "launcher",        30000, 9.0,  NC_BLUE],
    ["LMG_Zafir_F",     "Zafir LMG",       "7.62 - belt-fed", 50000, 12.0, NC_OLIVE],
    ["srifle_EBR_F",    "MK-1 EMR",        "7.62 - marksman", 8000,  6.5,  NC_BLUE],
    ["arifle_TRG21_F",  "TRG-21",          "5.56 - carbine",  4000,  4.5,  NC_OLIVE],
    ["arifle_SPAR_01_blk_F", "SPAR-16",    "5.56 - illegal",  7500,  4.8,  NC_BLUE],
    ["SMG_02_F",        "Sting",           "9mm - smg",       4000,  2.8,  NC_OLIVE],
    ["sgun_HunterShotgun_01_F", "12Ga Shotgun", "12ga - illegal", 6000, 5.0, NC_BLUE],
    ["hgun_Rook40_F",   "Rook-40",         "9mm sidearm",     1500,  1.2,  NC_OLIVE]];
// rebel shop deals in literal cash-on-hand
private _bank = missionNamespace getVariable ["AP_cash", 1279500];

// truncate a display string so it can't wrap/overflow its column
private _fnTrunc = {params ["_s", "_n"];
    if (count _s > _n) then { (_s select [0, _n - 2]) + ".." } else { _s }};

// demo accessory pool [class, price] -- filtered per weapon by WeaponSlotsInfo compatibility
private _accPool = [["optic_ACO", 250], ["optic_Holosight", 250], ["optic_MRCO", 1000], ["optic_Arco", 1000],
    ["optic_Hamr", 1000], ["optic_DMS", 30000], ["acc_flashlight", 250], ["acc_pointer_IR", 250],
    ["muzzle_snds_L", 20000], ["muzzle_snds_M", 20000], ["muzzle_snds_H", 20000], ["muzzle_snds_B", 80000], ["bipod_01_F_blk", 0]];

// selected weapon -> [ [class, displayName, price, isMagazine], ... ]
private _fnAddons = {params ["_wCls"];
    private _out = [];
    private _mags = ([_wCls] call AP_fnc_fetchWeaponMagazines) arrayIntersect ([_wCls] call AP_fnc_fetchWeaponMagazines);
    // drop tracer variants (matches the real shop's tracer strip) unless that would empty the list
    private _noTracer = _mags select { (toLower _x) find "tracer" < 0 };
    if !(_noTracer isEqualTo []) then { _mags = _noTracer; };
    // dedupe by display name (camo/box variants share names) and cap the list
    private _seen = []; {if (count _seen < 10) then {private _dn = getText (configFile >> "CfgMagazines" >> _x >> "displayName");
            if (_dn != "" && { !(_dn in _seen) }) then {_seen pushBack _dn;
                private _p = if ((toLower _x) find "rpg" >= 0) then { 25000 } else { 100 };
                _out pushBack [_x, _dn, _p, true];};};} forEach _mags;
    private _compat = []; {private _ci = _x >> "compatibleItems";
        if (isArray _ci) then { { _compat pushBack toLower _x; } forEach getArray _ci; };
        if (isClass _ci) then { { if (getNumber _x >= 1) then { _compat pushBack toLower configName _x; }; } forEach configProperties [_ci, "isNumber _x", true]; };
    } forEach configProperties [configFile >> "CfgWeapons" >> _wCls >> "WeaponSlotsInfo", "isClass _x", true]; {
        _x params ["_aCls", "_aPrice"];
        if ((toLower _aCls) in _compat) then {private _dn = getText (configFile >> "CfgWeapons" >> _aCls >> "displayName");
            if (_dn != "") then { _out pushBack [_aCls, _dn, _aPrice, false]; };};} forEach _accPool;
    _out};

// update the detail card: preview picture, name, plate price (mint if affordable / red if not), meta line
private _fnFocus = {params ["_dn", "_price", "_pic", "_meta", "_d"];
    (_d displayCtrl 515320) ctrlSetText _pic;
    (_d displayCtrl 515321) ctrlSetStructuredText parseText toUpper ([_dn, 34] call _fnTrunc);
    private _col = if (_price <= (missionNamespace getVariable ["AP_cash", 1279500])) then { "#53e39c" } else { "#ef3139" };
    (_d displayCtrl 515323) ctrlSetStructuredText parseText format ["<t color='%1'>$%2</t>", _col, [_price] call AP_fnc_numberText];
    (_d displayCtrl 515322) ctrlSetStructuredText parseText _meta;};

switch (_mode) do {

    case "open": {if (isNull (findDisplay 515300)) then { createDialog "AP_Shop"; };
        private _d = uiNamespace getVariable ["AP_Shop", displayNull];
        if (isNull _d) exitWith {};
        uiNamespace setVariable ["AP_ShopItems", _items];
        uiNamespace setVariable ["AP_ShopAccCtrls", []];
        uiNamespace setVariable ["AP_ShopBuyFn", { ["buy"] call AP_fnc_plbShopDemo }];
        uiNamespace setVariable ["AP_NC_IsLive", false];   // guard the live shop's tab handler
        { private _c = _d displayCtrl _x; if (!isNull _c) then { _c ctrlShow false; }; } forEach [515350, 515351, 515352, 515353, 515354, 515355];

        (_d displayCtrl 515301) ctrlSetStructuredText parseText "REBEL ARMS";
        (_d displayCtrl 515302) ctrlSetStructuredText parseText format ["<t align='right'>$%1</t>", [_bank] call AP_fnc_numberText];

        private _grp = _d displayCtrl 515310;
        private _bgs = []; private _badges = []; {_x params ["_cls", "_nm", "_sub", "_pr", "_wt", "_bcol"];
            private _i  = _forEachIndex;
            private _yy = _i * 0.0986;

            private _bg = _d ctrlCreate ["AP_ShopRowBg", -1, _grp];
            _bg ctrlSetPosition [0, _yy, 0.7178, 0.0870]; _bg ctrlCommit 0; _bgs pushBack _bg;

            private _bd = _d ctrlCreate ["AP_RscText", -1, _grp];
            _bd ctrlSetPosition [0, _yy, 0.0087, 0.0870]; _bd ctrlSetBackgroundColor _bcol; _bd ctrlCommit 0; _badges pushBack _bd;

            private _nc = _d ctrlCreate ["AP_ShopRowName", -1, _grp];
            _nc ctrlSetStructuredText parseText _nm; _nc ctrlSetPosition [0.0290, _yy + 0.0116, 0.4350, 0.0464]; _nc ctrlCommit 0;

            private _sc = _d ctrlCreate ["AP_ShopRowSub", -1, _grp];
            _sc ctrlSetStructuredText parseText _sub; _sc ctrlSetPosition [0.0290, _yy + 0.0493, 0.4350, 0.0319]; _sc ctrlCommit 0;

            private _pc = _d ctrlCreate ["AP_ShopRowPrice", -1, _grp];
            _pc ctrlSetStructuredText parseText format ["<t align='right'>$%1</t>", [_pr] call AP_fnc_numberText];
            _pc ctrlSetPosition [0.4713, _yy + 0.0261, 0.2291, 0.0435]; _pc ctrlCommit 0;

            private _hit = _d ctrlCreate ["AP_RscButtonInvisible", -1, _grp];
            _hit ctrlSetPosition [0, _yy, 0.7178, 0.0870]; _hit ctrlCommit 0;
            _hit setVariable ["ridx", _i];
            _hit ctrlAddEventHandler ["ButtonClick", { ["row", (_this select 0) getVariable ["ridx", 0]] call AP_fnc_plbShopDemo; }];
        } forEach _items;
        uiNamespace setVariable ["AP_ShopRowBgs", _bgs];
        uiNamespace setVariable ["AP_ShopRowBadges", _badges];

        ["row", 0] call AP_fnc_plbShopDemo;};

    case "row": {private _d = uiNamespace getVariable ["AP_Shop", displayNull];
        if (isNull _d) exitWith {};
        private _itemsS = uiNamespace getVariable ["AP_ShopItems", []];
        (_itemsS param [_arg, ["", "", "", 0, 0, NC_BLUE]]) params ["_cls", "_nm", "_sub", "_pr", "_wt"];
        uiNamespace setVariable ["AP_ShopWepIdx", _arg];
        uiNamespace setVariable ["AP_ShopSel", ["w", _arg]];

        // row visuals: magenta badge + sel texture on the pick, faction colours elsewhere
        { _x ctrlSetText (["images\ui\nc_row.paa", "images\ui\nc_row_sel.paa"] select (_forEachIndex isEqualTo _arg)); } forEach (uiNamespace getVariable ["AP_ShopRowBgs", []]);
        { _x ctrlSetBackgroundColor ([(_itemsS param [_forEachIndex, [0,0,0,0,0,NC_BLUE]]) param [5, NC_BLUE], NC_MAGEN] select (_forEachIndex isEqualTo _arg)); } forEach (uiNamespace getVariable ["AP_ShopRowBadges", []]);

        // detail card
        [_nm, _pr, getText (configFile >> "CfgWeapons" >> _cls >> "picture"), "Catalogue price <t color='#c7a24e'>- owned x0</t>", _d] call _fnFocus;

        // LOAD meter (fill width; the nc_seg overlay makes it read as discrete segments)
        private _frac = ((_wt / 15) min 1) max 0;
        private _lf = _d displayCtrl 515324;
        _lf ctrlSetPosition [0.7929, 0.4616, _frac * 0.2291, 0.0145]; _lf ctrlCommit 0;
        (_d displayCtrl 515325) ctrlSetStructuredText parseText format ["<t align='right'>%1</t>", _wt];

        // rebuild the addon list for this weapon
        { ctrlDelete _x; } forEach (uiNamespace getVariable ["AP_ShopAccCtrls", []]);
        private _accs = [_cls] call _fnAddons;
        uiNamespace setVariable ["AP_ShopAccs", _accs];
        private _aGrp = _d displayCtrl 515340;
        private _all = []; private _aBgs = []; private _aBadges = []; {_x params ["_aCls", "_aNm", "_aPr"];
            private _i  = _forEachIndex;
            private _yy = _i * 0.0609;

            private _bg = _d ctrlCreate ["AP_ShopRowBg", -1, _aGrp];
            _bg ctrlSetPosition [0, _yy, 0.3625, 0.0537]; _bg ctrlCommit 0; _all pushBack _bg; _aBgs pushBack _bg;

            private _bd = _d ctrlCreate ["AP_RscText", -1, _aGrp];
            _bd ctrlSetPosition [0, _yy, 0.0073, 0.0537]; _bd ctrlSetBackgroundColor NC_CLEAR; _bd ctrlCommit 0; _all pushBack _bd; _aBadges pushBack _bd;

            private _nc = _d ctrlCreate ["AP_AccRowName", -1, _aGrp];
            _nc ctrlSetStructuredText parseText ([_aNm, 26] call _fnTrunc); _nc ctrlSetPosition [0.0203, _yy + 0.0102, 0.2300, 0.0348]; _nc ctrlCommit 0; _all pushBack _nc;

            private _pc = _d ctrlCreate ["AP_AccRowPrice", -1, _aGrp];
            _pc ctrlSetStructuredText parseText format ["<t align='right'>$%1</t>", [_aPr] call AP_fnc_numberText];
            _pc ctrlSetPosition [0.2560, _yy + 0.0109, 0.1000, 0.0319]; _pc ctrlCommit 0; _all pushBack _pc;

            private _hit = _d ctrlCreate ["AP_RscButtonInvisible", -1, _aGrp];
            _hit ctrlSetPosition [0, _yy, 0.3625, 0.0537]; _hit ctrlCommit 0; _all pushBack _hit;
            _hit setVariable ["ridx", _i];
            _hit ctrlAddEventHandler ["ButtonClick", { ["acc", (_this select 0) getVariable ["ridx", 0]] call AP_fnc_plbShopDemo; }];
        } forEach _accs;
        uiNamespace setVariable ["AP_ShopAccCtrls", _all];
        uiNamespace setVariable ["AP_ShopAccBgs", _aBgs];
        uiNamespace setVariable ["AP_ShopAccBadges", _aBadges];};

    case "acc": {private _d = uiNamespace getVariable ["AP_Shop", displayNull];
        if (isNull _d) exitWith {};
        private _accs = uiNamespace getVariable ["AP_ShopAccs", []];
        (_accs param [_arg, ["", "", 0, true]]) params ["_aCls", "_aNm", "_aPr", "_isMag"];
        uiNamespace setVariable ["AP_ShopSel", ["a", _arg]];

        { _x ctrlSetText (["images\ui\nc_row.paa", "images\ui\nc_row_sel.paa"] select (_forEachIndex isEqualTo _arg)); } forEach (uiNamespace getVariable ["AP_ShopAccBgs", []]);
        { _x ctrlSetBackgroundColor ([NC_CLEAR, NC_MAGEN] select (_forEachIndex isEqualTo _arg)); } forEach (uiNamespace getVariable ["AP_ShopAccBadges", []]);
        // one-magenta rule: weapon row keeps its highlight texture as context but its badge returns to faction colour
        private _itemsS = uiNamespace getVariable ["AP_ShopItems", []];
        { _x ctrlSetBackgroundColor ((_itemsS param [_forEachIndex, [0,0,0,0,0,NC_BLUE]]) param [5, NC_BLUE]); } forEach (uiNamespace getVariable ["AP_ShopRowBadges", []]);

        private _wIdx = uiNamespace getVariable ["AP_ShopWepIdx", 0];
        private _wNm  = (_itemsS param [_wIdx, ["", ""]]) param [1, ""];
        private _root = if (_isMag) then { configFile >> "CfgMagazines" >> _aCls } else { configFile >> "CfgWeapons" >> _aCls };
        [_aNm, _aPr, getText (_root >> "picture"), format ["Fits %1 <t color='#c7a24e'>- addon</t>", _wNm], _d] call _fnFocus;};

    case "buy": {private _d = uiNamespace getVariable ["AP_Shop", displayNull];
        if (isNull _d) exitWith {};
        (uiNamespace getVariable ["AP_ShopSel", ["w", 0]]) params ["_kind", "_idx"];
        private _nm2 = ""; private _pr2 = 0;
        if (_kind isEqualTo "w") then {
            ((uiNamespace getVariable ["AP_ShopItems", []]) param [_idx, ["", "", "", 0]]) params ["_c", "_n", "_s", "_p"];
            _nm2 = _n; _pr2 = _p;} else {
            ((uiNamespace getVariable ["AP_ShopAccs", []]) param [_idx, ["", "", 0]]) params ["_c", "_n", "_p"];
            _nm2 = _n; _pr2 = _p;};
        (_d displayCtrl 515322) ctrlSetStructuredText parseText format ["<t color='#53e39c'>Bought %1 - $%2</t> <t color='#8993a0'>(demo)</t>", _nm2, [_pr2] call AP_fnc_numberText];
        // bank readout: one-shot red flash, settles back to gold (colour pulse on text = engine-legal)
        private _bv = _d displayCtrl 515302;
        _bv ctrlSetStructuredText parseText format ["<t align='right' color='#ef3139'>$%1</t>", [_bank] call AP_fnc_numberText];
        [_bv, _bank] spawn {params ["_bv", "_bank"];
            uiSleep 0.35;
            if (!isNull _bv) then {
                _bv ctrlSetStructuredText parseText format ["<t align='right'>$%1</t>", [_bank] call AP_fnc_numberText];};};};};
