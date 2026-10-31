/*
    fn_fittingOpen.sqf — FITTING ROOM's bridge half (web dialog idd 3100).

    fn_clothingMenu owns everything that matters -- the old-loadout snapshot,
    the preview camera, the control wiring, and the post-close tail that does
    cancel-restore / purchase-save / camera teardown. This fn only:
      - sizes the page to the phone slider (windowed, standing order)
      - builds the cshop payload from the same clothing_* tables the lists use
      - drives the NATIVE hidden controls for try-on and buy, so
        changeClothes/buyClothes run byte-for-byte native.

    A try-on = select the category in the real combo (fires clothingFilter,
    which populates the real list), then select the row in the real list (fires
    changeClothes). A buy = ctrlActivate on the real BUY button, whose handler
    fn_clothingMenu itself baked with the old loadout. Cancel = closeDialog;
    the menu's own tail restores.
*/

params [["_display", displayNull, [displayNull]]];
if (isNull _display) exitWith {};
disableSerialization;

// The buy needs the OLD loadout -- the thing fn_clothingMenu snapshots before
// createDialog. This onLoad runs in that same instant, before any try-on can
// change the body, so the same snapshot taken here is the same values.
uiNamespace setVariable ["AP_fitOld",
    [AP_clothing_store, uniform player, headgear player, goggles player, vest player, backpack player]];

private _ctrl = _display displayCtrl 3151;
if (isNull _ctrl) exitWith { diag_log "[FITTING] control missing" };
if !([_ctrl] call webui_fnc_init) exitWith { diag_log "[FITTING] bridge init failed" };
// Let the SERVER replace this page's markup if it holds a newer copy, so UI ships
// without a client repack. No-op unless AP_fnc_webServeInit registered a fetcher and
// the server actually has the file -- otherwise the PBO page you just loaded stands.
[_ctrl, "ui\html\fitting.html"] call webui_fnc_serve;

// windowed: the phone slider is the size (standing order 2026-08-13)
private _s = profileNamespace getVariable ["AP_deckScale", 1];
private _gw = 2.5 * pixelW * pixelGrid; private _gh = 2.5 * pixelH * pixelGrid;
// narrow card on the LEFT edge, per the design ("the compact left panel exists
// so YOUR CHARACTER stays on screen") -- the camera frames the player to the right
// owner 2026-08-13: wider than the design's 17.5rem card -- long names plus
// the [ARMOR n] suffix need the room. The fit override scales rem from width,
// so more grid means a physically wider card, same type size.
private _w = 17 * _gw * _s;  private _h = 26 * _gh * _s;
_ctrl ctrlSetPosition [safezoneX + 0.015, 0.5 - _h / 2, _w, _h];
_ctrl ctrlCommit 0;

private _data = {
    private _type = AP_clothing_store;
    // the page's contract: cats is an array of STRING ids and items[].cat
    // matches -- native filter order, the page's own vocabulary
    private _catIds = ["uniform", "headgear", "glasses", "vest", "backpack"];
    private _cats = [];
    private _items = [];
    private _worn = [uniform player, headgear player, goggles player, vest player, backpack player];
    for "_ci" from 0 to 4 do {
        private _rows = switch (_type) do {
            case "civ":      { [_ci] call AP_fnc_clothing_civ };
            case "cop":      { [_ci] call AP_fnc_clothing_cop };
            case "skip";
            case "rebcloth": { [_ci] call AP_fnc_clothing_reb };
            case "dive":     { [_ci] call AP_fnc_clothing_dive };
            case "copdive":  { [_ci] call AP_fnc_clothing_copdive };
            case "kart":     { [_ci] call AP_fnc_clothing_kart };
            case "med":      { [_ci] call AP_fnc_clothing_med };
            default          { [] };
        };
        if (_rows isNotEqualTo []) then {
            _cats pushBack (_catIds select _ci);
            {
                _x params ["_cls", ["_nm", nil], ["_price", 0], ["_texture", ""]];
                // mirror the filter's own drop: a row fetchCfgDetails cannot
                // resolve never reaches the real list, so it must not reach the
                // page either -- those were the "dead" rows
                private _det = [_cls] call AP_fnc_fetchCfgDetails;
                if !(_det params ["_dCls", "_dName"]) then { continue };
                if !(isClass (configFile >> (_det select 6) >> _cls)) then { continue };
                private _name = if (isNil "_nm") then { _dName } else { _nm };
                if (_name isEqualTo "") then { _name = _cls };
                // armor next to the listing -- highest `armor` across the item's
                // protected hitpoints, the same scan the native list runs
                private _armor = 0;
                private _hpInfo = configFile >> "CfgWeapons" >> _cls >> "ItemInfo" >> "HitpointsProtectionInfo";
                if (isClass _hpInfo) then {
                    for "_hi" from 0 to ((count _hpInfo) - 1) do {
                        private _sub = _hpInfo select _hi;
                        if (isClass _sub) then {
                            private _a = getNumber (_sub >> "armor");
                            if (_a > _armor) then { _armor = _a };
                        };
                    };
                };
                if (_armor > 0) then { _name = format ["%1  [ARMOR %2]", _name, _armor] };
                _items pushBack (createHashMapFromArray [
                    // id = cat * 1000 + row index INSIDE THE UNFILTERED LIST --
                    // the same order clothingFilter populates the real listbox
                    // with an empty search, which is how a try resolves it
                    // the id IS the row's identity -- category|class|texture --
                    // because the real list drops and shifts rows; an index can
                    // lie, the data cannot
                    ["id",    format ["%1|%2|%3", _ci, _cls, _texture]],
                    ["name",  _name],
                    ["cat",   _catIds select _ci],
                    ["price", _price],
                    ["worn",  (_worn select _ci) isEqualTo _cls && { _texture isEqualTo "" }]
                ]);
            } forEach _rows;
        };
    };
    createHashMapFromArray [
        ["name",  ctrlText ((findDisplay 3100) displayCtrl 3103)],
        ["cash",  if (AP_ndShop) then { AP_nd } else { AP_cash }],
        ["nd",    AP_ndShop],
        ["cats",  _cats],
        ["items", _items],
        ["total", { _x isNotEqualTo 0 } count AP_clothing_purchase],
        ["flair", switch (true) do {
            case (AP_effSide isEqualTo west):        { "tal" };
            case (AP_effSide isEqualTo independent): { "med" };
            default                                  { "" };
        }]
    ]
};

[_ctrl, "cshop", _data] call webui_fnc_on;

// try-on: drive the REAL controls so changeClothes runs native
[_ctrl, "cTry", {
    params [["_id", "", [""]]];
    private _parts = _id splitString "|";
    if (count _parts < 2) exitWith { createHashMapFromArray [["ok", false], ["msg", "no item"]] };
    private _cat = parseNumber (_parts select 0);
    private _cls = _parts select 1;
    private _tex = if (count _parts > 2) then { _parts select 2 } else { "" };
    private _d = findDisplay 3100;
    if (isNull _d) exitWith { createHashMapFromArray [["ok", false], ["msg", "shop closed"]] };
    private _filter = _d displayCtrl 3102;
    private _list   = _d displayCtrl 3101;
    private _search = _d displayCtrl 3110;
    _search ctrlSetText "";
    private _fIdx = -1;
    for "_i" from 0 to (lbSize _filter - 1) do {
        if ((_filter lbValue _i) isEqualTo _cat) exitWith { _fIdx = _i };
    };
    if (_fIdx < 0) exitWith { createHashMapFromArray [["ok", false], ["msg", "no such rack"]] };
    _filter lbSetCurSel _fIdx;              // -> clothingFilter populates 3101
    // find the row by ITS DATA -- the list drops unresolvable rows, so indices
    // shift; the [class, texture] pair painted into lbData cannot
    private _row = -1;
    for "_i" from 0 to (lbSize _list - 1) do {
        private _rd = parseSimpleArray (_list lbData _i);
        if (_rd isEqualType [] && { (_rd param [0, ""]) isEqualTo _cls }
            && { (_rd param [1, ""]) isEqualTo _tex }) exitWith { _row = _i };
    };
    if (_row < 0) exitWith { createHashMapFromArray [["ok", false], ["msg", "not in stock"]] };
    _list lbSetCurSel _row;                 // -> changeClothes equips, prices
    private _r = createHashMapFromArray [["ok", true], ["msg", ""]];
    _r set ["total", { _x isNotEqualTo 0 } count AP_clothing_purchase];
    _r set ["sum", 0]; { _r set ["sum", (_r get "sum") + _x] } forEach AP_clothing_purchase;
    _r
}] call webui_fnc_on;

[_ctrl, "cBuy", {
    // the page sends [[ids]] for an atomic outfit; the native buy charges
    // exactly what is tried on (AP_clothing_purchase), which is the same set
    private _d = findDisplay 3100;
    if (isNull _d) exitWith { createHashMapFromArray [["ok", false], ["msg", "shop closed"]] };
    // the handler fn_clothingMenu baked onto 1001 carries the old loadout; fire it
    // receipt BEFORE the buy: buyClothes zeroes the tally as it settles, and
    // the page prints F(receipt) -- absent, that renders $NaN
    private _receipt = 0;
    { _receipt = _receipt + _x } forEach AP_clothing_purchase;
    // ctrlActivate does NOT fire script-set ButtonClick handlers -- the click
    // was a no-op and buyClothes never ran ("the outfit is yours", nothing
    // given). Call it directly with the same old-loadout argument the native
    // button carries; spawned, exactly as the menu wires it, so the async ND
    // debit can block.
    [uiNamespace getVariable ["AP_fitOld", []]] spawn AP_fnc_buyClothes;
    createHashMapFromArray [["ok", true], ["msg", "purchasing"], ["receipt", _receipt], ["cash", AP_cash]]
}] call webui_fnc_on;

[_ctrl, "cCancel", {
    // closeDialog; fn_clothingMenu's tail sees no AP_clothesPurchased and restores
    [] spawn { closeDialog 0 };
    createHashMapFromArray [["ok", true], ["msg", ""]]
}] call webui_fnc_on;

[_ctrl, "cVision", {
    [] call AP_fnc_changeVision;
    createHashMapFromArray [["ok", true], ["msg", ""]]
}] call webui_fnc_on;

_display displayAddEventHandler ["KeyDown", { params ["", "_k"]; if (_k isEqualTo 1) then { closeDialog 0 }; false }];

// clothingMenu wires the native controls AFTER createDialog returns; give it a
// beat so the filter combo is populated before the first payload reads the title
[_ctrl, _data] spawn {
    params ["_ctrl", "_data"];
    uiSleep 0.3;
    [_ctrl, "cshop", (call _data)] call webui_fnc_push;
};
diag_log "[FITTING] room ready";
