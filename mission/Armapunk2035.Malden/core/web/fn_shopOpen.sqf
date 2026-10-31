/*
    fn_shopOpen.sqf — boot the web virtual shop (dialog 39600, ui\html\shop.html).

    Same shape as fn_deckOpen but much smaller: one screen, three verbs.

    Both trading verbs go STRAIGHT THROUGH fn_virtualShopManage. Every guard it
    carries runs unchanged -- the 0.275s spam limiter
    at the drug dealer, weight and cash checks, the goldbar outpost rule, and the
    sell side's anti-arbitrage caps. The page picks an item and an amount and
    nothing else; in particular it never sends a price, because the cost is
    recomputed inside that function.

    Usage:  [_shopType] spawn AP_fnc_shopOpen;      (from fn_virtualShopMenu)
            [_this select 0] spawn AP_fnc_shopOpen; (dialog onLoad)
*/

params [["_arg", "", ["", displayNull]]];

// Called two ways: with a shop type to open the dialog, and again by the dialog's
// own onLoad with the display. The type is stashed between the two.
if (_arg isEqualType "") exitWith {
    if (_arg isEqualTo "") exitWith { diag_log "[SHOP] no shop type"; };
    if (!isNull (findDisplay 39600)) exitWith { closeDialog 0 };
    if (!alive player) exitWith {};
    uiNamespace setVariable ["AP_webShopType", _arg];
    diag_log format ["[SHOP] createDialog AP_web_shop (%1)", _arg];
    createDialog "AP_web_shop";
};

private _display = _arg;
if (isNull _display) exitWith { diag_log "[SHOP] open: null display"; };

disableSerialization;
private _ctrl = _display displayCtrl 39601;
if (isNull _ctrl) exitWith { diag_log "[SHOP] open: browser control 39601 missing"; };
if !([_ctrl] call webui_fnc_init) exitWith { diag_log "[SHOP] open: bridge init failed"; };
// Let the SERVER replace this page's markup if it holds a newer copy, so UI ships
// without a client repack. No-op unless AP_fnc_webServeInit registered a fetcher and
// the server actually has the file -- otherwise the PBO page you just loaded stands.
[_ctrl, "ui\html\shop.html"] call webui_fnc_serve;

private _shopType = uiNamespace getVariable ["AP_webShopType", ""];

[_ctrl, "shop", {
    private _t = uiNamespace getVariable ["AP_webShopType", ""];
    [_t] call AP_fnc_shopData
}] call webui_fnc_on;

// One handler for both directions -- fn_virtualShopManage already branches on
// the manage type, and duplicating that split here would buy nothing.
private _trade = {
    params [["_verb", "", [""]], ["_item", "", [""]], ["_qty", 0, [0]]];
    private _t = uiNamespace getVariable ["AP_webShopType", ""];
    if (_t isEqualTo "" || { _item isEqualTo "" }) exitWith {
        createHashMapFromArray [["ok", false], ["msg", "nothing selected"]]
    };
    if (_qty < 1) exitWith { createHashMapFromArray [["ok", false], ["msg", "amount must be at least 1"]] };
    [_t, controlNull, _verb, _item, _qty] call AP_fnc_virtualShopManage;
    // fn_virtualShopManage reports its own refusals through handleMessage and does
    // not answer, so the refreshed payload is what actually tells the page what
    // happened -- cash, weight and the owned count all move or they do not.
    private _r = createHashMapFromArray [["ok", true], ["msg", ""]];
    _r set ["shop", ([_t] call AP_fnc_shopData)];
    _r
};

// The page sends [item, qty]; the shared handler wants [verb, item, qty].
uiNamespace setVariable ["AP_webShopTrade", _trade];
[_ctrl, "shopBuy",  { (["buyItem"]  + _this) call (uiNamespace getVariable "AP_webShopTrade") }] call webui_fnc_on;
[_ctrl, "shopSell", { (["sellItem"] + _this) call (uiNamespace getVariable "AP_webShopTrade") }] call webui_fnc_on;

// Esc closes, same as any shop. No stow animation here -- this is a counter, not
// the handset, and it has no chassis to roll away.
_display displayAddEventHandler ["KeyDown", {
    params ["", "_key"];
    if (_key isEqualTo 1) then { closeDialog 0 };
    false
}];

[_ctrl, "shop", ([_shopType] call AP_fnc_shopData)] call webui_fnc_push;
diag_log format ["[SHOP] opened %1 t=%2", _shopType, diag_tickTime toFixed 1];
