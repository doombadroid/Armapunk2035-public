/*
    fn_armoryOpen.sqf — ARMORY, the HTML weapon shop (dialog 930460).

    NOTHING NEW DECIDES A PRICE. The rows come from the same
    AP_fnc_weaponShopCfg call the native dialog uses -- side/licence/rank
    gates evaluated inside it, the dynamic rebel/MaxSec catalogue, the MaxSec 25%
    rule, owner overrides, all of it -- and the side pane from
    AP_fnc_weaponAddons. A buy resolves its price from a FRESH catalogue
    call, then rides fn_weaponShopBuy's direct mode: the identical licence /
    space / DLC / replace / payment / cartel-cut / gov-tax chain, cash or ND.

    The page's hero preview is the weapon's real .paa, fetched by the page
    itself with A3API.RequestTexture from the picture path shipped per row.

    uiNamespace AP_armoryShop carries the shop type from the NPC hook.
*/

params [["_display", displayNull, [displayNull]]];
if (isNull _display) exitWith { diag_log "[ARMORY] null display" };
disableSerialization;

private _shop = uiNamespace getVariable ["AP_armoryShop", ""];
if (_shop isEqualTo "") exitWith { closeDialog 0 };

private _ctrl = _display displayCtrl 930461;
if (isNull _ctrl) exitWith { diag_log "[ARMORY] control missing" };
if !([_ctrl] call webui_fnc_init) exitWith { diag_log "[ARMORY] bridge init failed" };
// NOT fullscreen. Windowed web UIs honour the phone's size slider (owner
// standing order 2026-08-13): base 40x22 grid scaled by AP_deckScale, centred.
private _s = profileNamespace getVariable ["AP_deckScale", 1];
private _gw = 2.5 * pixelW * pixelGrid; private _gh = 2.5 * pixelH * pixelGrid;
private _w = 40 * _gw * _s;  private _h = 22 * _gh * _s;
_ctrl ctrlSetPosition [0.5 - _w / 2, 0.5 - _h / 2, _w, _h];
_ctrl ctrlCommit 0;

private _data = {
    private _shop = uiNamespace getVariable ["AP_armoryShop", ""];
    private _cfg = [_shop] call AP_fnc_weaponShopCfg;
    private _rows = [];
    private _cats = [];
    private _wMags = createHashMap;   // weapon id -> its magazine set, for addon fits
    {
        _x params ["_cls", "_nameOv", "_price"];
        private _d = [_cls] call AP_fnc_fetchCfgDetails;
        private _cw = configFile >> "CfgWeapons" >> _cls;
        private _cat = switch (true) do {
            case (_cls isKindOf ["Rifle", configFile >> "CfgWeapons"]):    { "rifles" };
            case (_cls isKindOf ["Launcher", configFile >> "CfgWeapons"]): { "launchers" };
            case (_cls isKindOf ["Pistol", configFile >> "CfgWeapons"]):   { "pistols" };
            default { "gear" };
        };
        _cats pushBackUnique _cat;
        private _mags = (getArray (_cw >> "magazines")) apply { toLower _x };
        if (_mags isNotEqualTo []) then { _wMags set [_cls, _mags] };
        // detail line, best effort from config: mag capacity + a calibre guess
        private _magTxt = "";
        if (_mags isNotEqualTo []) then {
            private _cnt = getNumber (configFile >> "CfgMagazines" >> (_mags select 0) >> "count");
            if (_cnt > 0) then { _magTxt = format ["%1 RND", _cnt] };
        };
        // config picture paths lead with a backslash; RequestTexture wants the
        // game path WITHOUT it (same rule as RequestFile) -- with it, every
        // texture 404s silently and the thumbs render broken
        private _paa = _d param [2, ""];
        if ((_paa select [0, 1]) isEqualTo "\") then { _paa = _paa select [1] };
        _rows pushBack (createHashMapFromArray [
            ["id",    _cls],
            ["name",  if (isNil "_nameOv") then { _d param [1, _cls] } else { _nameOv }],
            ["cat",   _cat],
            ["price", _price],
            ["cal",   ""], ["mag", _magTxt], ["range", ""],
            ["paa",   _paa],
            // the catalogue is pre-gated: everything shipped is buyable by this
            // player right now. Rows the gates rejected never arrive, so there is
            // nothing honest to mark unlicensed yet.
            ["licensed", true], ["licName", ""]
        ]);
    } forEach (_cfg param [1, []]);

    private _side = [_shop] call AP_fnc_weaponAddons;
    if (isNil "_side") then { _side = [] };
    private _addons = [];
    if (_side isEqualType []) then {
        {
            _x params ["_cls", "_nameOv", "_price"];
            private _d = [_cls] call AP_fnc_fetchCfgDetails;
            private _lc = toLower _cls;
            private _isMag = isClass (configFile >> "CfgMagazines" >> _cls);
            private _kind = switch (true) do {
                case (_isMag):                      { "MAG" };
                case ((_lc select [0, 7]) isEqualTo "muzzle_"): { "MUZZLE" };
                default { "OPTIC" };
            };
            // fits: for a magazine, every listed weapon whose mag set holds it;
            // for optics/muzzles config compat is a deep dive -- they fit ALL
            // weapons here (the page filters by fits, so empty would mean never)
            private _fits = [];
            if (_isMag) then {
                { if (_lc in _y) then { _fits pushBack _x } } forEach _wMags;
            } else {
                _fits = keys _wMags;
            };
            _addons pushBack (createHashMapFromArray [
                ["id", _cls],
                ["name", if (isNil "_nameOv") then { _d param [1, _cls] } else { _nameOv }],
                ["kind", _kind], ["price", _price], ["fits", _fits]
            ]);
        } forEach _side;
    };

    createHashMapFromArray [
        // same page, three uniforms: MaxSec shops in TAL amber, TT in medic green,
        // everyone else keeps the armory gold
        ["flair", switch (true) do {
            case (_shop in ["police_weapons", "police_equipment", "swat_weapons", "srt_weapons"]): { "tal" };
            case (_shop isEqualTo "med_basic"): { "med" };
            default { "" };
        }],
        ["name",   toUpper (_cfg param [0, "ARMORY"])],
        ["cash",   AP_cash],
        ["cats",   _cats],
        ["items",  _rows],
        ["addons", _addons]
    ]
};

[_ctrl, "wshop", _data] call webui_fnc_on;

private _buy = {
    params ["_kind", "_cls"];
    private _shop = uiNamespace getVariable ["AP_armoryShop", ""];
    if (_shop isEqualTo "" || { _cls isEqualTo "" }) exitWith {
        createHashMapFromArray [["ok", false], ["msg", "no shop"]] };
    private _price = -1;
    if (_kind isEqualTo "side") then {
        private _side = [_shop] call AP_fnc_weaponAddons;
        if (!isNil "_side" && { _side isEqualType [] }) then {
            private _i = _side findIf { (_x select 0) isEqualTo _cls };
            if (_i > -1) then { _price = (_side select _i) select 2 };
        };
    } else {
        private _list = ([_shop] call AP_fnc_weaponShopCfg) param [1, []];
        private _i = _list findIf { (_x select 0) isEqualTo _cls };
        if (_i > -1) then { _price = (_list select _i) select 2 };
    };
    if (_price < 0) exitWith { createHashMapFromArray [["ok", false], ["msg", "not sold to you here"]] };
    [_shop, controlNull, [_cls, _price]] call AP_fnc_weaponShopBuy;
    private _c = uiNamespace getVariable ["WEBUI_ctrl", controlNull];
    if (!isNull _c) then { [_c, "cash", AP_cash] call webui_fnc_push };
    createHashMapFromArray [["ok", true], ["msg", ""], ["cash", AP_cash]]
};
uiNamespace setVariable ["AP_armoryBuy", _buy];

[_ctrl, "wsBuy",      { ["main", _this param [0, ""]] call (uiNamespace getVariable "AP_armoryBuy") }] call webui_fnc_on;
[_ctrl, "wsBuyAddon", { ["side", _this param [0, ""]] call (uiNamespace getVariable "AP_armoryBuy") }] call webui_fnc_on;

_display displayAddEventHandler ["KeyDown", { params ["", "_k"]; if (_k isEqualTo 1) then { closeDialog 0 }; false }];

[_ctrl, "wshop", (call _data)] call webui_fnc_push;
diag_log format ["[ARMORY] %1 ready", _shop];
