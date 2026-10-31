if (AP_clothing_purchase isEqualTo[0, 0, 0, 0]) exitWith {titleText["You didn't choose the clothes you wanted to buy", "PLAIN"]};
private _oldLoadout = parseSimpleArray format["%1", _this select 0];
if !(_oldLoadout isEqualType[]) exitWith {};
_oldLoadout params["_type", "_oldUniform", "_oldHeadgear", "_oldGlasses", "_oldVest", "_oldBackpack"];
private _price = 0;
private _exit = false;
private _needCashItems = ["V_HarnessOGL_brn"];
private _currencyVar =
if !(AP_ndShop) then {AP_cash} else {AP_nd};
private _currency =
if !(AP_ndShop) then {"cash"} else {"New Drachma"};
private _govTaxed = ["civ", "cop", "skip", "dive", "copdive", "kart", "barber", "faces", "med"]; {if !(_x isEqualTo 0) then {
        _price = _price + _x}}
forEach AP_clothing_purchase;
private _currencyText =
if !(AP_ndShop) then {format["$%1", [_price] call AP_fnc_numberText]} else {format["%1", [_price] call AP_fnc_numberText]};
if (_type == "rebcloth") then {
    // owner 2026-07-05: same exitWith footgun as #272 -- exitWith aborted the whole clothing buy (before the
    // debit) whenever the arms cartel was neutral, so rebel clothing couldn't be bought at all when unowned.
    private _pointData = arms_flag getVariable["AP_capData", [0, "Neutral", -1]];
    _pointData params["_flagGangID", "", "_progress"];
    AP_armsCartel = [false, 0, -1];
    if !(_flagGangID isEqualTo 0) then {AP_armsCartel set[2, _flagGangID];
        if ((count AP_gang_data) > 0) then {if ((_flagGangID isEqualTo(AP_gang_data select 0)) && (_progress >= 0)) then {
                AP_armsCartel set[0, true];};};};}; {private _oldItem =
    switch (_x) do {case (uniform player): {_oldUniform};
        case (headgear player): {_oldHeadgear};
        case (goggles player): {_oldGlasses};
        case (vest player): {_oldVest};
        case (backpack player): {_oldBackpack};
        default {_x};
    }; if ((_x in _needCashItems) && !(_oldItem isEqualTo _x) && (AP_cash < _price)) exitWith {   // NEW DRACHMA: needCash items always gate on real cash (the ND mirror can't be compared to a cash price)
        [format["You do not have enough cash on you to pay for this. You need $%1.", [_price] call AP_fnc_numberText], "basic"] spawn AP_fnc_handleMessage;
        _exit = true;};}
forEach[vest player, uniform player, backpack player, headgear player];
if (_exit) exitWith {closeDialog 0};
// NEW DRACHMA: clothing is a summed BUNDLE (uniform+headgear+vest+backpack), so its ND price is the
// bundle sum at 6000:1 (per-item ND overrides don't apply to a summed purchase). Wallet debit is
// server-authoritative; fn_clothingMenu now spawns buyClothes so AP_fnc_ndBuySync can block.
if !(AP_ndShop) then {if !([_price] call AP_fnc_debitCard) exitWith {_exit = true};} else {
    private _ndPrice = [_price] call AP_fnc_ndFromLegacy;
    // owner 2026-07-24 SECURITY (free-clothes bug): both bails MUST set _exit. `exitWith` inside this
    // `else {}` exits only the else block, not the function, so a REFUSED payment fell through to the skin
    // application, saveGear, and AP_clothesPurchased = true -- the very flag that suppresses the shop's
    // revert-on-cancel, making the free outfit permanent. The cash branch above always set _exit.
    if !([_ndPrice] call AP_fnc_ndAfford) exitWith {closeDialog 0;
        [format["You do not have enough New Drachma. You need %1 ND.", [_ndPrice] call AP_fnc_ndText], "basic"] spawn AP_fnc_handleMessage;
        _exit = true;};
    if !([_ndPrice] call AP_fnc_ndBuySync) exitWith {closeDialog 0;
        ["New Drachma payment failed -- try again.", "basic"] spawn AP_fnc_handleMessage;
        _exit = true;};};
if (_exit) exitWith {closeDialog 0;};
private _rebelOutposts = ["Rebelop_1", "Rebelop_2", "Rebelop_3", "Rebelop_4", "Rebelop_5", "Rebelop_6"];
if !(({player distance(getMarkerPos _x) <= 200}
count _rebelOutposts) isEqualTo 0) then {["moneyspentrebel", _price] call AP_fnc_statArrUpdate;};
private _extra = "";
private _cut = 0;
if ((_type isEqualTo "rebcloth") && !(AP_armsCartel select 0)) then {_cut = floor((_price) * 0.08);
    private _updateVal = (AP_armsCartel select 1);
    _updateVal = _updateVal + _cut;
    AP_armsCartel set[1, _updateVal];
    _extra = format[", with $%1 going to the owner of the Arms Dealer", [_cut] call AP_fnc_numberText];};
if (_type in _govTaxed) then {private _updateVal = (AP_govTax select 1);
    _cut = floor((_price) * (call AP_fnc_getGovTax));
    _updateVal = _updateVal + _cut;
    AP_govTax set[1, _updateVal];
    _extra = format[", including a tax of $%1", [_cut] call AP_fnc_numberText];};
if (!((AP_armsCartel select 2) isEqualTo - 1) && !((AP_armsCartel select 1) isEqualTo 0)) then {[
        [0, 0, AP_armsCartel select 1], "APS_fnc_cartelSRV", false, false] spawn AP_fnc_MP;
    AP_armsCartel = [false, 0, -1];};
if (!(_type isEqualTo "rebcloth") && !(AP_govTax param[0, false])) then {
    if (!((AP_govTax select 2) isEqualTo - 1) && !((AP_govTax select 1) isEqualTo 0)) then {
        ["payGovernor", [(AP_govTax param[1, 0])]] spawn AP_fnc_govSystem;
        AP_turfTax set[1, 0];};};
// %2 had no argument -- _extra is concatenated OUTSIDE the format -- so every
// purchase threw "1 elements provided, 2 expected" (harmless, message still
// assembled). Pre-existing; the format string simply lied about its arity.
[format["You have purchased your clothing for %1", (if (AP_ndShop) then { format["%1 ND", [[_price] call AP_fnc_ndFromLegacy] call AP_fnc_ndText] } else { format["$%1", [_price] call AP_fnc_numberText] })] + _extra + ".", "basic"] spawn AP_fnc_handleMessage;
[
    ["-CLOTHESBOUGHT-", player, (profileName), format["purchased clothes for $%1, Uniform: %2, Headgear: %3, Goggles: %4, Vest: %5, Backpack: %6, POS: %7", [_price] call AP_fnc_numberText, (uniform player), (headgear player), (goggles player), (vest player), (backpack player), getPosATL player]], "APS_fnc_logIt", 2, false, false] spawn AP_fnc_MP;
AP_clothingShop_skins params["_uniformTexture", "_backpackTexture"];
if !(_uniformTexture isEqualTo "") then {player setObjectTextureGlobal[0, _uniformTexture];
    private _idx = [uniform player, "getID", _uniformTexture] call AP_fnc_clothingTextures;
    private _textureRow = [uniform player, "getRowByID", _idx] call AP_fnc_clothingTextures;
    AP_uniformBackpack_skins set[0, _idx];
    if !(_textureRow param[11, ""] isEqualTo "") then {player setObjectTextureGlobal[1, _textureRow select 11];};} else {
    if !(_oldUniform isEqualTo uniform player) then {AP_uniformBackpack_skins set[0, -1];};};
if (_backpackTexture isEqualTo "AP_INVIS_BAG") then {
    // invisible backpack: hide the worn pack globally (everyone sees it gone), storage intact. AP_invisBag
    // persists on the unit so fn_equipLoadout re-hides it on respawn. No skin ID (it's not a registered skin).
    [true] call AP_fnc_invisBag;   // empty-texture invisibility (robust vs hideObject; see fn_invisBag)
    AP_uniformBackpack_skins set[1, -1];
    profileNamespace setVariable ["AP_invisBag", true];} else {if !(_backpackTexture isEqualTo "") then {
        unitBackpack player setObjectTextureGlobal[0, _backpackTexture];
        private _idx = [backpack player, "getID", _backpackTexture] call AP_fnc_clothingTextures;
        AP_uniformBackpack_skins set[1, _idx];
        profileNamespace setVariable ["AP_invisBag", false];} else {if !(_oldBackpack isEqualTo backpack player) then {
            AP_uniformBackpack_skins set[1, -1];
            profileNamespace setVariable ["AP_invisBag", false];   // swapped to a normal pack -> not invisible
        };};};
saveProfileNamespace;   // #555: flush AP_invisBag to disk NOW so the invisible carryall survives a full relog/crash
private _var =
switch (AP_effSide) do {case civilian: {"AP_clothingSkinsCiv"};
    case west: {"AP_clothingSkinsCop"};
    case independent: {"AP_clothingSkinsMed"};}; profileNamespace setVariable[_var, AP_uniformBackpack_skins];
[true] call AP_fnc_saveGear;
AP_clothingShop_skins = ["", ""];
AP_clothesPurchased = true;
while {dialog}
do {closeDialog 0};