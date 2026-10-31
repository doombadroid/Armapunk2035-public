/*
    fn_lootBridge.sqf — LOOT CARD's bridge half (web dialog 1530).

    fn_pickupItem stays the take engine: its guards (medic-illegal, locked
    vault gold, treasure map, the dirty-money launder clock), its money path,
    and its weight-partial handling all run unchanged -- its listbox writes
    aim at display 1520, which does not exist here, and every one of them is
    null-safe.

    QUANTITY rides a PRE-SPLIT: to take n from a stack of N, the row is set to
    n, pickupItem consumes it whole (or weight-partial), and the remainder is
    merged back afterwards. The case var is republished after every take, so a
    second player opening the case after this one closes sees the truth.
*/

params [["_display", displayNull, [displayNull]]];
if (isNull _display) exitWith {};
disableSerialization;

private _ctrl = _display displayCtrl 1531;
if (isNull _ctrl) exitWith { diag_log "[LOOT] control missing" };
if !([_ctrl] call webui_fnc_init) exitWith { diag_log "[LOOT] bridge init failed" };
// Let the SERVER replace this page's markup if it holds a newer copy, so UI ships
// without a client repack. No-op unless AP_fnc_webServeInit registered a fetcher and
// the server actually has the file -- otherwise the PBO page you just loaded stands.
[_ctrl, "ui\html\loot.html"] call webui_fnc_serve;

// windowed by the phone slider, parked right of the crosshair like the design
private _s = profileNamespace getVariable ["AP_deckScale", 1];
private _gw = 2.5 * pixelW * pixelGrid; private _gh = 2.5 * pixelH * pixelGrid;
private _w = 13 * _gw * _s;  private _h = 16 * _gh * _s;
_ctrl ctrlSetPosition [0.54, 0.24, _w, _h];
_ctrl ctrlCommit 0;

private _data = {
    private _obj = uiNamespace getVariable ["AP_lootCase", objNull];
    private _items = [];
    {
        _x params ["_nm", "_qty"];
        // "getItemWeight", not "getWeight": fn_virtItemCfg has no such case, and its `_return` is
        // `private "_return"` with no default branch, so the miss returned nil and the guard below
        // silently turned every loot item's weight into 0.
        private _wt = ["getItemWeight", _nm] call AP_fnc_virtItemCfg;
        if !(_wt isEqualType 0) then { _wt = 0 };
        _items pushBack (createHashMapFromArray [
            ["id",    _nm],
            ["name",  if (_nm isEqualTo "money") then { "Cash" } else { ["getName", _nm] call AP_fnc_virtItemCfg }],
            ["qty",   _qty],
            ["wt",    _wt],
            ["money", _nm isEqualTo "money"]
        ]);
    } forEach AP_pickMenuItems;
    private _until = if (isNull _obj) then { 0 } else { _obj getVariable ["AP_dropUntilSrv", 0] };
    createHashMapFromArray [
        ["id",      "case"],
        ["label",   if (!isNull _obj && { _obj getVariable ["AP_questloot", false] }) then { "QUEST CACHE" } else { "SUITCASE" }],
        ["dist",    if (isNull _obj) then { 0 } else { round (player distance _obj) }],
        ["despawn", if (_until > 0) then { round (_until - serverTime) max 0 } else { -1 }],
        ["youWt",   AP_carryWeight],
        ["youCap",  AP_maxWeight],
        ["items",   _items]
    ]
};

[_ctrl, "loot", _data] call webui_fnc_on;

private _take = {
    params ["_nm", "_qty"];
    private _obj = uiNamespace getVariable ["AP_lootCase", objNull];
    if (isNull _obj) exitWith { createHashMapFromArray [["ok", false], ["msg", "the case is gone"]] };
    if (player distance _obj > 6) exitWith { createHashMapFromArray [["ok", false], ["msg", "too far"]] };
    private _i = AP_pickMenuItems findIf { (_x select 0) isEqualTo _nm };
    if (_i < 0) exitWith { createHashMapFromArray [["ok", false], ["msg", "already gone"]] };
    private _have = (AP_pickMenuItems select _i) select 1;
    _qty = (_qty min _have) max 1;
    private _rem = _have - _qty;
    // pre-split: pickupItem consumes the row whole (or weight-partial and
    // writes its own remainder); ours merges back after
    (AP_pickMenuItems select _i) set [1, _qty];
    AP_pickingUpItems = true;
    [_obj, _nm, _qty] call AP_fnc_pickupItem;
    AP_pickingUpItems = false;
    if (_rem > 0) then {
        private _j = AP_pickMenuItems findIf { (_x select 0) isEqualTo _nm };
        if (_j > -1) then {
            (AP_pickMenuItems select _j) set [1, ((AP_pickMenuItems select _j) select 1) + _rem];
        } else {
            AP_pickMenuItems pushBack [_nm, _rem];
        };
    };
    // republish the truth -- a second viewer reconciles on this
    if (!isNull _obj) then { _obj setVariable ["AP_droppedItems", AP_pickMenuItems, true] };
    [] call AP_fnc_calWeight;
    createHashMapFromArray [["ok", true], ["msg", ""], ["cash", AP_cash]]
};
uiNamespace setVariable ["AP_lootTake", _take];

[_ctrl, "lootTake", {
    params [["_case", "", [""]], ["_id", "", [""]], ["_qty", 1, [0]]];
    private _r = [_id, _qty] call (uiNamespace getVariable "AP_lootTake");
    private _c = uiNamespace getVariable ["WEBUI_ctrl", controlNull];
    if (!isNull _c) then { [_c, "loot", (call (uiNamespace getVariable "AP_lootData"))] call webui_fnc_push };
    _r
}] call webui_fnc_on;

[_ctrl, "lootAll", {
    private _take = uiNamespace getVariable "AP_lootTake";
    private _left = [];
    {
        _x params ["_nm", "_qty"];
        [_nm, _qty] call _take;
    } forEach (+AP_pickMenuItems);
    { _left pushBack (_x select 0) } forEach AP_pickMenuItems;
    private _c = uiNamespace getVariable ["WEBUI_ctrl", controlNull];
    if (!isNull _c) then { [_c, "loot", (call (uiNamespace getVariable "AP_lootData"))] call webui_fnc_push };
    createHashMapFromArray [["ok", true], ["taken", true], ["left", _left]]
}] call webui_fnc_on;

uiNamespace setVariable ["AP_lootData", _data];

_display displayAddEventHandler ["KeyDown", { params ["", "_k"]; if (_k isEqualTo 1) then { closeDialog 0 }; false }];
_display displayAddEventHandler ["Unload", {
    private _obj = uiNamespace getVariable ["AP_lootCase", objNull];
    if (!isNull _obj) then {
        if ((_obj getVariable ["AP_inUse", objNull]) isEqualTo player) then { _obj setVariable ["AP_inUse", nil, true] };
    };
}];

[_ctrl, "loot", (call _data)] call webui_fnc_push;
diag_log "[LOOT] card ready";
