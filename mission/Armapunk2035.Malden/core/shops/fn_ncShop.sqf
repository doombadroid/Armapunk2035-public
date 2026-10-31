/*
    AP_fnc_ncShop (LooneyBin, ui branch) -- the NIGHT CITY weapon shop, LIVE. Drives dialog AP_Shop
    (dialog\plbShop.hpp, idd 515300) with the REAL shop pipeline:
      catalogue  = AP_fnc_weaponShopCfg (licence/side gates + dynamic gun catalog + price overrides)
      discounts  = AP_fnc_getDiscount
      side list  = AP_fnc_weaponAddons pool filtered per weapon (fetchWeaponMagazines + WeaponSlotsInfo),
                   with the rebel/turf tracer strip
      purchase   = same guards + money path as fn_weaponShopBuy (cash-only for rebel/turf, New Drachma branch,
                   canAdd space check, DLC + duplicate-weapon prompts, handleItem grant, APS_fnc_logIt,
                   arms-cartel 8% cut) and the same close-time settlement as fn_weaponShopMenu
                   (saveGear + gear sync, cartel remit, purchase receipt).
    Routed for ALL weapon shops (fn_weaponShopMenu intercept): rebel/gun/turf/hunting/bounty/skiptracer +
    MaxSec/MaxTac/SRT armories + TT equipment; rebel/turf stay literal-cash, everything else cash+bank w/ gov tax.
    fn_plbShopDemo (!shopdemo) stays the visual sandbox. Modes:
      ["open", _shopType, _nd]  (scheduled -- called from the addAction chain)
      ["row", _i] | ["acc", _i]         (UI EHs)
      ["buy"]                           (SPAWNED -- uses BIS_fnc_guiMessage prompts)
*/
#define NC_BLUE  [0.255, 0.478, 0.800, 1]
#define NC_OLIVE [0.463, 0.569, 0.329, 1]
#define NC_SLATE [0.537, 0.576, 0.627, 1]
#define NC_MAGEN [0.945, 0.239, 0.659, 1]
#define NC_CLEAR [0, 0, 0, 0]
params [["_mode", "", [""]], "_a1", "_a2"];
disableSerialization;
if (!hasInterface) exitWith {};

private _fnTrunc = {params ["_s", "_n"];
    if (count _s > _n) then { (_s select [0, _n - 2]) + ".." } else { _s }};
// current wallet for this shop: ND variant = New Drachma wallet; rebel/turf = literal cash-on-hand;
// every other shop = cash + bank -- stock affordability parity
private _fnWallet = {if (uiNamespace getVariable ["AP_NC_ND", false]) exitWith { AP_nd };
    if ((uiNamespace getVariable ["AP_NC_Shop", "rebelwep"]) in ["rebelwep", "turf"]) then {AP_cash} else {
        AP_cash + AP_atmcash}};
private _fnWalletText = {
    // NEW DRACHMA: wallet shop shows the exact ND balance string; cash shops unchanged.
    if (uiNamespace getVariable ["AP_NC_ND", false]) exitWith {format ["<t align='right'>%1 ND</t>", [AP_ndStr] call AP_fnc_ndText]};
    format ["<t align='right'>$%1</t>", [call _fnWallet] call AP_fnc_numberText]};
private _fnPriceText = {params ["_p"];
    if (uiNamespace getVariable ["AP_NC_ND", false]) then {
        // display at 6000:1 (matches the per-item charge's fallback for seeded prices; the authoritative
        // debit in the buy branch still uses fn_ndPriceCfg by classname)
        format ["%1 ND", [[_p] call AP_fnc_ndFromLegacy] call AP_fnc_ndText]} else {format ["$%1", [_p] call AP_fnc_numberText]}};
// detail card: preview / name / plate (mint if affordable, red if not) / meta
private _fnFocus = {params ["_dn", "_price", "_pic", "_meta", "_d"];
    (_d displayCtrl 515320) ctrlSetText _pic;
    (_d displayCtrl 515321) ctrlSetStructuredText parseText toUpper ([_dn, 34] call _fnTrunc);
    // NEW DRACHMA: afford colour compares the exact ND balance to the ND price in the wallet shop.
    private _afford = if (uiNamespace getVariable ["AP_NC_ND", false]) then {[[_price] call AP_fnc_ndFromLegacy] call AP_fnc_ndAfford
    } else {_price <= (call _fnWallet)};
    private _col = if (_afford) then { "#53e39c" } else { "#ef3139" };
    (_d displayCtrl 515323) ctrlSetStructuredText parseText format ["<t color='%1'>%2</t>", _col, [_price] call _fnPriceText];
    (_d displayCtrl 515322) ctrlSetStructuredText parseText _meta;};

switch (_mode) do {

    // ── open + build + hold-until-closed settlement ────────────────────────────────────────────
    case "open": {private _shopType = _a1;
        private _ndMode = _a2;
        if (dialog) exitWith {};

        if (_ndMode) then { AP_ndShop = true; };
        private _preNd = AP_nd;
        // arms cartel owner-bonus state (same as fn_weaponShopMenu; see #272 note there)
        if (!_ndMode && {_shopType isEqualTo "rebelwep"} && {!isNil "arms_flag"}) then {AP_armsCartel = [false, 0, -1];
            private _pointData = arms_flag getVariable ["AP_capData", [0, "Neutral", -1]];
            _pointData params ["_flagGangID", "", "_progress"];
            if !(_flagGangID isEqualTo 0) then {AP_armsCartel set [2, _flagGangID];
                if ((count AP_gang_data) > 0) then {if ((_flagGangID isEqualTo (AP_gang_data select 0)) && (_progress >= 0)) then {
                        AP_armsCartel set [0, true];};};};};

        // real catalogue (licence/side gate lives inside -- returns nil when refused)
        private _cfg = [_shopType] call AP_fnc_weaponShopCfg;
        if (isNil "_cfg") exitWith { if (_ndMode) then { AP_ndShop = false; }; };
        _cfg params ["_titleText", "_allItems"];
        private _discount = [_shopType, true] call AP_fnc_getDiscount;
        private _taxFree = (_shopType in ["rebelwep", "turf"]) || _ndMode;
        private _govTax = call AP_fnc_getGovTax;

        // resolve rows: [class, name, sub, price, picture, badge], weapons -> throwables -> items
        private _built = [[], [], []]; {_x params [["_class", ""], ["_nameOv", ""], ["_basePrice", 0]];
            private _det = [_class] call AP_fnc_fetchCfgDetails;
            // owner 2026-07-10: a REMOVED/typo classname makes fetchCfgDetails return [] -> the old
            // `_det select 1` was nil -> `nil != ""` THREW and aborted this whole forEach, silently dropping
            // EVERY gun listed after the first bad class (police + MaxTac armories "missing tons of weapons"
            // after the Night City shop replaced the old auto-skipping listbox). Resolve the name nil-safely
            // and skip any class the engine doesn't know (unpictured/unbuyable anyway) instead of killing the
            // list. Log the bad classnames so the curated catalogue can be scrubbed of them.
            private _dn = "";
            if (_det isEqualTo []) then {
                diag_log format ["[LooneyBin][ncShop] skipped unknown classname '%1' (shop '%2') -- not in Cfg*, would have truncated the list", _class, _shopType];
            } else {_dn = if (_nameOv isEqualType "" && {_nameOv != ""}) then { _nameOv } else { _det select 1 };};
            if (_dn isEqualType "" && {_dn != ""}) then {private _type = [_class] call BIS_fnc_itemType;
                // tabs: 0 WEAPONS (guns) / 1 GRENADES (smokes + frags: the throwable magazines) / 2 GEAR
                // (toolkit, FAK, GPS/map/compass/watch, binocs, rangefinder, NVGs -- binoc-likes are
                // type "weapon" but belong in gear)
                private _bucket = switch (toLower (_type select 0)) do {
                    case "weapon": { if ((toLower (_type select 1)) in ["binocular", "lasersight", "laserdesignator", "nvgoggles"]) then { 2 } else { 0 } };
                    case "magazine": { 1 };
                    default { 2 };};
                private _badge = [NC_BLUE, NC_OLIVE, NC_SLATE] select _bucket;
                private _p = _basePrice * _discount;
                if (!_taxFree) then { _p = _p + (_p * _govTax); };
                (_built select _bucket) pushBack [_class, _dn, toLower (_type select 1), round _p, _det select 2, _badge];};
        } forEach _allItems;
        private _items = (_built select 0) + (_built select 1) + (_built select 2);
        if (_items isEqualTo []) exitWith { if (_ndMode) then { AP_ndShop = false; }; };

        createDialog "AP_Shop";
        private _d = uiNamespace getVariable ["AP_Shop", displayNull];
        if (isNull _d) exitWith { if (_ndMode) then { AP_ndShop = false; }; };
        uiNamespace setVariable ["AP_NC_Items", _items];
        uiNamespace setVariable ["AP_NC_Shop", _shopType];
        uiNamespace setVariable ["AP_NC_ND", _ndMode];
        uiNamespace setVariable ["AP_NC_Discount", _discount];
        uiNamespace setVariable ["AP_NC_AddonPool", [_shopType] call AP_fnc_weaponAddons];
        uiNamespace setVariable ["AP_NC_AccCtrls", []];
        uiNamespace setVariable ["AP_ShopBuyFn", { ["buy"] call AP_fnc_ncShop }];

        (_d displayCtrl 515301) ctrlSetStructuredText parseText toUpper _titleText;
        private _walletLbl = switch (true) do {case (_ndMode): { "NEW DRACHMA" };
            case (_shopType in ["rebelwep", "turf"]): { "CASH IN HAND" };
            default { "CASH + BANK" };};
        (_d displayCtrl 515303) ctrlSetStructuredText parseText format ["<t align='right'>%1</t>", _walletLbl];
        (_d displayCtrl 515302) ctrlSetStructuredText parseText (call _fnWalletText);

        uiNamespace setVariable ["AP_NC_All", _built];
        uiNamespace setVariable ["AP_NC_IsLive", true];
        uiNamespace setVariable ["AP_NC_RowCtrls", []];
        // owner 2026-07-10: search bar under the list. Every KeyUp re-renders the current tab through the
        // name filter (see the "tab" case). The typed text only ever feeds toLower/find -- never compile/call
        // -- so there is no script-injection surface even though it is a live edit field.
        private _se = _d displayCtrl 515360;
        _se ctrlSetText "";
        _se ctrlAddEventHandler ["KeyUp", { ["search"] call AP_fnc_ncShop; }];
        ["tab", 0] call AP_fnc_ncShop;

        // hold until closed, then settle exactly like the stock shop
        waitUntil { isNull (findDisplay 515300) };
        AP_ndShop = false;
        [false] call AP_fnc_saveGear;
        if (AP_lastSynced_gear != str (AP_gear)) then {[3] call AP_fnc_ClupdatePartial;
            [6] call AP_fnc_ClupdatePartial;};
        if (!_ndMode) then {if (!((AP_armsCartel select 2) isEqualTo -1) && !((AP_armsCartel select 1) isEqualTo 0)) then {
                [[0, 0, AP_armsCartel select 1], "APS_fnc_cartelSRV", false, false] spawn AP_fnc_MP;
                AP_armsCartel = [false, 0, -1];};};
        if (AP_purchasedGear isEqualTo []) exitWith {};
        private _gear = ""; private _totalPrice = 0; private _armsTax = 0; {_x params ["_item", "_amount", "_tax", "_itemName", "_price"];
            _gear = _gear + format ["%1 - %2<br/>", _amount, _itemName];
            _totalPrice = _totalPrice + _price;
            _armsTax = _armsTax + _tax;} forEach AP_purchasedGear;
        private _extra = switch ((AP_purchasedGear param [0, []]) param [5, "Woops"]) do {
            case ("Arms"): { format [", with <t color='#7FFF00'>$%1</t> going to the %2", [_armsTax] call AP_fnc_numberText, "Arms Dealer"] };
            case ("Tax"):  { format [", including a tax of <t color='#7FFF00'>$%1</t>", [_armsTax] call AP_fnc_numberText] };
            default { "" };};
        if (_ndMode) then { _armsTax = 0; };
        private _extra = if !(_armsTax isEqualTo 0) then { _extra } else { "" };
        private _formatText = if (!_ndMode) then {
            format ["<t align='center'>You bought:<br/>%1for <t color='#7FFF00'>$%2</t>%3", _gear, [_totalPrice] call AP_fnc_numberText, _extra]
        } else {
            format ["<t align='center'>You bought:<br/>%1for <t color='#7FFF00'>%2 ND</t>%3", _gear, [[_totalPrice] call AP_fnc_ndFromLegacy] call AP_fnc_ndText, _extra]
        };
        private _rebelOutposts = ["Rebelop_1", "Rebelop_2", "Rebelop_3", "Rebelop_4", "Rebelop_5", "Rebelop_6"];
        if !(({ player distance (getMarkerPos _x) <= 200 } count _rebelOutposts) isEqualTo 0) then {
            ["moneyspentrebel", _totalPrice] call AP_fnc_statArrUpdate;};
        [_formatText, "weppurchase"] spawn AP_fnc_handleMessage;
        AP_purchasedGear = [];};

    // ── tab switched: 0 WEAPONS / 1 GRENADES / 2 GEAR ──────────────────────────────────────────
    // ── search box changed: re-render the current tab through the name filter (owner 2026-07-10) ──
    case "search": {if !(uiNamespace getVariable ["AP_NC_IsLive", false]) exitWith {};
        ["tab", uiNamespace getVariable ["AP_NC_Tab", 0]] call AP_fnc_ncShop;};
    case "tab": {private _arg = _a1;
        if !(uiNamespace getVariable ["AP_NC_IsLive", false]) exitWith {};   // !shopdemo shares the dialog
        private _d = uiNamespace getVariable ["AP_Shop", displayNull];
        if (isNull _d) exitWith {};
        uiNamespace setVariable ["AP_NC_Tab", _arg]; {private _on = _forEachIndex isEqualTo _arg;
            private _lbl = _d displayCtrl (515350 + _forEachIndex * 2);
            _lbl ctrlShow true;
            _lbl ctrlSetStructuredText parseText format ["<t color='%1'>%2</t>", ["#8993a0", "#37e8f0"] select _on, _x];
            (_d displayCtrl (515351 + _forEachIndex * 2)) ctrlShow _on;} forEach ["WEAPONS", "GRENADES", "GEAR"];

        { ctrlDelete _x; } forEach (uiNamespace getVariable ["AP_NC_RowCtrls", []]);
        { ctrlDelete _x; } forEach (uiNamespace getVariable ["AP_NC_AccCtrls", []]);
        uiNamespace setVariable ["AP_NC_AccCtrls", []];
        uiNamespace setVariable ["AP_NC_Accs", []];
        private _items = (uiNamespace getVariable ["AP_NC_All", [[], [], []]]) param [_arg, []];
        // owner 2026-07-10: apply the search-bar filter. Substring match on the display name (row elem 1);
        // the query is lower-cased and only used with `find` -- no compile/call, so nothing typed can execute.
        // The dim placeholder (515361) shows only while the box is empty. Filter persists across tab switches.
        private _q = toLower (ctrlText (_d displayCtrl 515360));
        if (_q isNotEqualTo "") then { _items = _items select { (toLower (_x select 1)) find _q >= 0 }; };
        (_d displayCtrl 515361) ctrlShow (_q isEqualTo "");
        uiNamespace setVariable ["AP_NC_Items", _items];

        private _grp = _d displayCtrl 515310;
        private _all = []; private _bgs = []; private _badges = []; {_x params ["_cls", "_nm", "_sub", "_pr", "_pic", "_bcol"];
            private _i  = _forEachIndex;
            private _yy = _i * 0.0986;
            private _bg = _d ctrlCreate ["AP_ShopRowBg", -1, _grp];
            _bg ctrlSetPosition [0, _yy, 0.7178, 0.0870]; _bg ctrlCommit 0; _all pushBack _bg; _bgs pushBack _bg;
            private _bd = _d ctrlCreate ["AP_RscText", -1, _grp];
            _bd ctrlSetPosition [0, _yy, 0.0087, 0.0870]; _bd ctrlSetBackgroundColor _bcol; _bd ctrlCommit 0; _all pushBack _bd; _badges pushBack _bd;
            private _nc = _d ctrlCreate ["AP_ShopRowName", -1, _grp];
            _nc ctrlSetStructuredText parseText ([_nm, 30] call _fnTrunc); _nc ctrlSetPosition [0.0290, _yy + 0.0116, 0.4350, 0.0464]; _nc ctrlCommit 0; _all pushBack _nc;
            private _sc = _d ctrlCreate ["AP_ShopRowSub", -1, _grp];
            _sc ctrlSetStructuredText parseText _sub; _sc ctrlSetPosition [0.0290, _yy + 0.0493, 0.4350, 0.0319]; _sc ctrlCommit 0; _all pushBack _sc;
            private _pc = _d ctrlCreate ["AP_ShopRowPrice", -1, _grp];
            _pc ctrlSetStructuredText parseText format ["<t align='right'>%1</t>", [_pr] call _fnPriceText];
            _pc ctrlSetPosition [0.4713, _yy + 0.0261, 0.2291, 0.0435]; _pc ctrlCommit 0; _all pushBack _pc;
            private _hit = _d ctrlCreate ["AP_RscButtonInvisible", -1, _grp];
            _hit ctrlSetPosition [0, _yy, 0.7178, 0.0870]; _hit ctrlCommit 0; _all pushBack _hit;
            _hit setVariable ["ridx", _i];
            _hit ctrlAddEventHandler ["ButtonClick", { ["row", (_this select 0) getVariable ["ridx", 0]] call AP_fnc_ncShop; }];
        } forEach _items;
        uiNamespace setVariable ["AP_NC_RowCtrls", _all];
        uiNamespace setVariable ["AP_NC_RowBgs", _bgs];
        uiNamespace setVariable ["AP_NC_RowBadges", _badges];

        if (_items isEqualTo []) exitWith {(_d displayCtrl 515320) ctrlSetText "";
            (_d displayCtrl 515321) ctrlSetStructuredText parseText "NOTHING HERE";
            (_d displayCtrl 515323) ctrlSetStructuredText parseText "";
            (_d displayCtrl 515322) ctrlSetStructuredText parseText "";};
        ["row", 0] call AP_fnc_ncShop;};

    // ── weapon row selected ─────────────────────────────────────────────────────────────────────
    case "row": {private _arg = _a1;
        private _d = uiNamespace getVariable ["AP_Shop", displayNull];
        if (isNull _d) exitWith {};
        private _items = uiNamespace getVariable ["AP_NC_Items", []];
        (_items param [_arg, ["", "", "", 0, "", NC_BLUE]]) params ["_cls", "_nm", "_sub", "_pr", "_pic"];
        uiNamespace setVariable ["AP_NC_WepIdx", _arg];
        uiNamespace setVariable ["AP_NC_Sel", ["w", _arg]];

        { _x ctrlSetText (["images\ui\nc_row.paa", "images\ui\nc_row_sel.paa"] select (_forEachIndex isEqualTo _arg)); } forEach (uiNamespace getVariable ["AP_NC_RowBgs", []]);
        { _x ctrlSetBackgroundColor ([(_items param [_forEachIndex, [0,0,0,0,"",NC_BLUE]]) param [5, NC_BLUE], NC_MAGEN] select (_forEachIndex isEqualTo _arg)); } forEach (uiNamespace getVariable ["AP_NC_RowBadges", []]);

        [_nm, _pr, _pic, format ["%1 <t color='#c7a24e'>- catalogue</t>", _sub], _d] call _fnFocus;

        // LOAD = item mass (weapons: WeaponSlotsInfo>>mass, mags: mass)
        private _mass = getNumber (configFile >> "CfgWeapons" >> _cls >> "WeaponSlotsInfo" >> "mass");
        if (_mass isEqualTo 0) then { _mass = getNumber (configFile >> "CfgMagazines" >> _cls >> "mass"); };
        if (_mass isEqualTo 0) then { _mass = getNumber (configFile >> "CfgWeapons" >> _cls >> "ItemInfo" >> "mass"); };   // gear (toolkit/NVG/etc)
        private _frac = ((_mass / 150) min 1) max 0;
        private _lf = _d displayCtrl 515324;
        _lf ctrlSetPosition [0.7929, 0.4616, _frac * 0.2291, 0.0145]; _lf ctrlCommit 0;
        (_d displayCtrl 515325) ctrlSetStructuredText parseText format ["<t align='right'>%1</t>", round _mass];

        // rebuild the addon list: real pool, this weapon's compatibles, tracer strip, discount
        { ctrlDelete _x; } forEach (uiNamespace getVariable ["AP_NC_AccCtrls", []]);
        private _shopType = uiNamespace getVariable ["AP_NC_Shop", "rebelwep"];
        private _discount = uiNamespace getVariable ["AP_NC_Discount", 1];
        private _mags = [_cls] call AP_fnc_fetchWeaponMagazines;
        private _compat = []; {private _ci = _x >> "compatibleItems";
            if (isArray _ci) then { { _compat pushBack toLower _x; } forEach getArray _ci; };
            if (isClass _ci) then { { if (getNumber _x >= 1) then { _compat pushBack toLower configName _x; }; } forEach configProperties [_ci, "isNumber _x", true]; };
        } forEach configProperties [configFile >> "CfgWeapons" >> _cls >> "WeaponSlotsInfo", "isClass _x", true];
        private _accs = []; {_x params [["_aCls", ""], ["_aOv", ""], ["_aBase", 0]];
            private _lc = toLower _aCls;
            private _isTracer = ((_lc find "box" >= 0) && (_lc find "tracer" >= 0)) || (_shopType in ["rebelwep", "turf"] && {(_lc find "tracer" >= 0)});
            if (!_isTracer && {(_aCls in _mags) || (_lc in _compat)}) then {private _det = [_aCls] call AP_fnc_fetchCfgDetails;
                private _adn = if (!isNil "_aOv" && {_aOv isEqualType ""} && {_aOv != ""}) then { _aOv } else { _det select 1 };
                if (_adn != "") then {
                    _accs pushBack [_aCls, _adn, round (_aBase * _discount), (_det select 6) isEqualTo "CfgMagazines", _det select 2];};};
        } forEach (uiNamespace getVariable ["AP_NC_AddonPool", []]);
        uiNamespace setVariable ["AP_NC_Accs", _accs];

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
            _pc ctrlSetStructuredText parseText format ["<t align='right'>%1</t>", [_aPr] call _fnPriceText];
            _pc ctrlSetPosition [0.2560, _yy + 0.0109, 0.1000, 0.0319]; _pc ctrlCommit 0; _all pushBack _pc;
            private _hit = _d ctrlCreate ["AP_RscButtonInvisible", -1, _aGrp];
            _hit ctrlSetPosition [0, _yy, 0.3625, 0.0537]; _hit ctrlCommit 0; _all pushBack _hit;
            _hit setVariable ["ridx", _i];
            _hit ctrlAddEventHandler ["ButtonClick", { ["acc", (_this select 0) getVariable ["ridx", 0]] call AP_fnc_ncShop; }];
        } forEach _accs;
        uiNamespace setVariable ["AP_NC_AccCtrls", _all];
        uiNamespace setVariable ["AP_NC_AccBgs", _aBgs];
        uiNamespace setVariable ["AP_NC_AccBadges", _aBadges];};

    // ── addon row selected ──────────────────────────────────────────────────────────────────────
    case "acc": {private _arg = _a1;
        private _d = uiNamespace getVariable ["AP_Shop", displayNull];
        if (isNull _d) exitWith {};
        private _accs = uiNamespace getVariable ["AP_NC_Accs", []];
        (_accs param [_arg, ["", "", 0, true, ""]]) params ["_aCls", "_aNm", "_aPr", "_isMag", "_aPic"];
        uiNamespace setVariable ["AP_NC_Sel", ["a", _arg]];

        { _x ctrlSetText (["images\ui\nc_row.paa", "images\ui\nc_row_sel.paa"] select (_forEachIndex isEqualTo _arg)); } forEach (uiNamespace getVariable ["AP_NC_AccBgs", []]);
        { _x ctrlSetBackgroundColor ([NC_CLEAR, NC_MAGEN] select (_forEachIndex isEqualTo _arg)); } forEach (uiNamespace getVariable ["AP_NC_AccBadges", []]);
        private _items = uiNamespace getVariable ["AP_NC_Items", []];
        { _x ctrlSetBackgroundColor ((_items param [_forEachIndex, [0,0,0,0,"",NC_BLUE]]) param [5, NC_BLUE]); } forEach (uiNamespace getVariable ["AP_NC_RowBadges", []]);

        private _wIdx = uiNamespace getVariable ["AP_NC_WepIdx", 0];
        private _wNm  = (_items param [_wIdx, ["", ""]]) param [1, ""];
        [_aNm, _aPr, _aPic, format ["Fits %1 <t color='#c7a24e'>- %2</t>", [_wNm, 22] call _fnTrunc, ["accessory", "magazine"] select _isMag], _d] call _fnFocus;
    };

    // ── purchase (spawned: uses blocking prompts) -- mirrors fn_weaponShopBuy ─────────────────────
    case "buy": {private _d = uiNamespace getVariable ["AP_Shop", displayNull];
        if (isNull _d) exitWith {};
        private _shopType = uiNamespace getVariable ["AP_NC_Shop", "rebelwep"];
        private _ndMode = uiNamespace getVariable ["AP_NC_ND", false];
        (uiNamespace getVariable ["AP_NC_Sel", ["w", 0]]) params ["_kind", "_idx"];
        private _class = ""; private _price = 0; private _dn = "";
        if (_kind isEqualTo "w") then {
            ((uiNamespace getVariable ["AP_NC_Items", []]) param [_idx, ["", "", "", 0]]) params ["_c", "_n", "_s", "_p"];
            _class = _c; _dn = _n; _price = _p;} else {
            ((uiNamespace getVariable ["AP_NC_Accs", []]) param [_idx, ["", "", 0]]) params ["_c", "_n", "_p"];
            _class = _c; _dn = _n; _price = _p;};
        if (_class isEqualTo "") exitWith {};

        // tracer guard (belt/box everywhere; all tracers in rebel/turf)
        private _lc = toLower _class;
        if (((_lc find "box" >= 0) && (_lc find "tracer" >= 0)) || (_shopType in ["rebelwep", "turf"] && {(_lc find "tracer" >= 0)})) exitWith {
            ["Tracer rounds aren't sold here.", "basic"] spawn AP_fnc_handleMessage;};
        // inventory space -- flag pattern: an exitWith in the nested `then` only exits that block, the buy
        // would continue and STILL TAKE MONEY. Check the flag at this scope before any money moves.
        private _itemDetails = [_class] call AP_fnc_fetchCfgDetails;
        private _noRoom = false;
        if !((_itemDetails select 6) isEqualTo "CfgVehicles") then {
            if (((_itemDetails select 4) in [4096, 131072, 0]) || ((_itemDetails select 6) isEqualTo "CfgMagazines")) then {
                if !(player canAdd _class) then { _noRoom = true; };};};
        if (_noRoom) exitWith {["You don't have enough room for that item", "basic"] spawn AP_fnc_handleMessage;};
        // DLC warning
        private _action = true;
        private _dlcInfo = getAssetDLCInfo [_class, configFile >> "CfgWeapons"];
        if (_dlcInfo select 0 && !(_dlcInfo select 1)) then {
            _action = [format ["You need the %1 DLC in order to re-equip this weapon if you place it on the ground or into a vehicle/crate. Purchase anyway?", _dlcInfo select 5], "Purchase anyway?", "Yes", "No"] call BIS_fnc_guiMessage;
        };
        if !(_action) exitWith {};
        // duplicate weapon warning
        private _itemType = switch (true) do {
            case (_class isKindOf ["Rifle", configFile >> "CfgWeapons"]):    { [!((primaryWeapon player) isEqualTo ""), "primary weapon"] };
            case (_class isKindOf ["Launcher", configFile >> "CfgWeapons"]): { [!((secondaryWeapon player) isEqualTo ""), "secondary weapon"] };
            case (_class isKindOf ["Pistol", configFile >> "CfgWeapons"]):   { [!((handgunWeapon player) isEqualTo ""), "handgun"] };
            default { [false, ""] };};
        private _action = if (_itemType select 0) then {
            [format ["You already have a %1 equipped, buying another will replace it. Purchase anyway?", _itemType select 1], "Duplicate Item Warning", "Yes", "No"] call BIS_fnc_guiMessage;
        } else { true };
        if !(_action) exitWith {};

        // money -- identical to fn_weaponShopBuy
        private _priceText = [_price] call _fnPriceText;
        // NEW DRACHMA: the rebel/turf CASH guard applies only to the non-ND path now (the ND path checks
        // ND affordability in the debit branch below). An ND shop must not compare a legacy price to the ND mirror.
        if (!_ndMode && (_price > AP_cash) && (_shopType in ["rebelwep", "turf"])) exitWith {
            [format ["You do not have enough cash on you to pay for this. You need %1.", _priceText], "basic"] spawn AP_fnc_handleMessage;
        };
        private _exit = false;
        if (!_ndMode) then {if !([round _price] call AP_fnc_debitCard) exitWith {
                [format ["You cannot afford this item. You need $%1.", [_price] call AP_fnc_numberText], "basic"] spawn AP_fnc_handleMessage;
                _exit = true;};} else {
            // NEW DRACHMA: independent ND price by classname; server-authoritative debit (ncShop purchase
            // is spawned -> AP_fnc_ndBuySync may block).
            private _ndPrice = [_class] call AP_fnc_ndPriceCfg;
            if (_ndPrice isEqualTo "") then { _ndPrice = [_price] call AP_fnc_ndFromLegacy; diag_log format ["[LooneyBin][ND] NC shop missing price key %1 -- 6000:1 fallback", _class]; };
            // owner 2026-07-24 SECURITY (free-item bug): these two bails MUST set _exit. `exitWith` leaves
            // only the innermost scope -- inside this `else {}` it exits the else block, NOT the function --
            // so execution fell through to the AP_fnc_handleItem grant below and a REFUSED payment still
            // handed over the weapon. The cash branch above always set _exit; the ND port omitted it.
            if !([_ndPrice] call AP_fnc_ndAfford) exitWith {
                [format ["You cannot afford this item. You need %1 ND.", [_ndPrice] call AP_fnc_ndText], "basic"] spawn AP_fnc_handleMessage;
                _exit = true;};
            if !([_ndPrice] call AP_fnc_ndBuySync) exitWith {
                ["New Drachma payment failed -- try again.", "basic"] spawn AP_fnc_handleMessage;
                _exit = true;};};
        if (_exit) exitWith {};

        // grant + log
        [_class, true, false, true, false, false, false, false] call AP_fnc_handleItem;
        private _cfgClass = if ("Grenade" in _class) then { "CfgMagazines" } else { "CfgWeapons" };
        if (((_itemType select 1) in ["primary weapon", "secondary weapon", "handgun"]) || (toLower _class in ["handgrenade", "minigrenade"])) then {
            [["-WEAPONBOUGHT-", player, (profileName), format ["purchased a %1 for %2 at POS: %3", getText (configFile >> _cfgClass >> _class >> "displayName"), _priceText, getPosATL player]], "APS_fnc_logIt", 2, false, false] spawn AP_fnc_MP;
        };
        // arms cartel cut (rebel, non-ND, non-cartel-owner, non-admin)
        private _extra = ""; private _cut = 0;
        if (!_ndMode && (_shopType == "rebelwep") && !(AP_armsCartel select 0) && ((call AP_adminLevel) <= 2)) then {
            _cut = floor (_price * 0.08);
            AP_armsCartel set [1, (AP_armsCartel select 1) + _cut];
            _extra = "Arms";};
        if (!_ndMode && !(_shopType in ["rebelwep", "turf"]) && ((call AP_adminLevel) <= 2)) then {
            _cut = floor (_price * (call AP_fnc_getGovTax));
            AP_govTax set [1, (AP_govTax select 1) + _cut];
            _extra = "Tax";};
        playSound "purchase";
        private _index = AP_purchasedGear findIf { _x select 0 == _class };
        if (_index isEqualTo -1) then {AP_purchasedGear pushBack [_class, 1, _cut, _itemDetails select 1, _price, _extra];} else {
            (AP_purchasedGear select _index) params ["_item", "_amount", "_tax", "_itemName", "_prePrice"];
            AP_purchasedGear set [_index, [_item, _amount + 1, _tax + _cut, _itemName, _prePrice + _price, _extra]];};

        // refresh readout + plate affordability + confirmation line
        (_d displayCtrl 515302) ctrlSetStructuredText parseText (call _fnWalletText);
        private _col = if (_price <= (call _fnWallet)) then { "#53e39c" } else { "#ef3139" };
        (_d displayCtrl 515323) ctrlSetStructuredText parseText format ["<t color='%1'>%2</t>", _col, _priceText];
        (_d displayCtrl 515322) ctrlSetStructuredText parseText format ["<t color='#53e39c'>Bought %1 - %2</t>", [_dn, 22] call _fnTrunc, _priceText];
    };};
