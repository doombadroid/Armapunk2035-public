#include "..\..\..\macro.h"
if (scriptAvailable(8)) exitWith {["You spam this action...", "basic"] spawn AP_fnc_handleMessage;};
// DECK ROUTE: slot index as a parameter; the price is recomputed from the
// loadout itself, never taken from a list the page filled.
params[["_type", "", [""]], ["_controlData", [], [[]]], ["_currency", "$", [""]], ["_deckIdx", -1, [0]]];
_controlData params["_control", "_selectedIndex"];
private _fromDeck = _deckIdx >= 0;
private _plb_display = findDisplay 39400;
if (!_fromDeck && {isNull _plb_display}) exitWith {};
private _filterList = _plb_display displayCtrl 39402;
private _mainListGroup = _plb_display displayCtrl 39404;
private _mainItemList = _mainListGroup controlsGroupCtrl 1000;
private _mainItemListBackground = _mainListGroup controlsGroupCtrl 1003;
private _sideListGroup = _plb_display displayCtrl 39405;
private _sideItemList = _sideListGroup controlsGroupCtrl 1000;
private _sideItemListButton = _sideListGroup controlsGroupCtrl 1001;
private _deleteButton = _sideListGroup controlsGroupCtrl 1005;
private _saveButton = _sideListGroup controlsGroupCtrl 1004;
private _dollarsButton = _sideListGroup controlsGroupCtrl 1006;
private _ndButton = _sideListGroup controlsGroupCtrl 1007; {_x ctrlEnable false;}
forEach[_deleteButton, _saveButton, _sideItemListButton, _dollarsButton, _ndButton];
private "_selectedLoadout"; private "_price";
if (_fromDeck) then {
    _selectedLoadout = _deckIdx;
    private _r = AP_loadoutHolder param [_deckIdx, []];
    _price = if (_r isEqualTo []) then { -1 } else {
        [_r select 1, _r select 3, _r select 4] call AP_fnc_getLoadoutPrice };
} else {
    _selectedLoadout = _sideItemList lnbValue[lbCurSel _sideItemList, 0];
    _price = (_sideItemList lnbValue[lbCurSel _sideItemList, 1]);
};
private _displayPrice =
if (_currency isEqualTo "$") then {"$" + ([_price] call AP_fnc_numberText)} else {
    ([[_price] call AP_fnc_ndFromLegacy] call AP_fnc_ndText) + " ND"   // NEW DRACHMA: bundle at 6000:1
};
if (_selectedLoadout < 0 || _price < 0) exitWith {};
(AP_loadoutHolder select _selectedLoadout) params[["_uniqueID", -10, [0]], ["_loadoutType", "", [""]], ["_loadoutName", "", [""]], ["_gearArray", [],
    [[]]], ["_virtualArray", [], [[]]], ["_skins", [-1, -1], [[]]]];
if (_uniqueID isEqualTo - 10 || _gearArray isEqualTo[] || !(_currency in ["$", "ND"])) exitWith {};
if (!_fromDeck) then {
    private _action = [format["Are you sure you want to equip the %1 loadout for %2? It will replace all your current gear.", _loadoutName, _displayPrice], "Equip Loadout", "Purchase", "Cancel"] call BIS_fnc_guiMessage;
    if !(_action) exitWith {};
};
if (_currency isEqualTo "$" && {AP_atmcash < _price}) exitWith {
    ["You don't have enough money in your bank account for this loadout.", "basic"] spawn AP_fnc_handleMessage;};
// NEW DRACHMA: pre-check on the exact ND balance (the mirror can't be compared to a legacy-denominated price). The
// authoritative charge is the AP_fnc_ndBuySync below; this is just the early UX bail.
if (_currency isEqualTo "ND" && {!([[_price] call AP_fnc_ndFromLegacy] call AP_fnc_ndAfford)}) exitWith {
    [format["You don't have enough New Drachma for this loadout. You need %1 ND.", [[_price] call AP_fnc_ndFromLegacy] call AP_fnc_ndText], "basic"] spawn AP_fnc_handleMessage;
};
if (AP_carryWeight > 5 && _virtualArray isNotEqualTo[]) exitWith {
    ["You can't equip a loadout with virtual items if you have items in your virtual inventory.", "basic"] spawn AP_fnc_handleMessage;};
closeDialog 0;
["Your loadout is equipping... Please stand still while we get you kitted out.", "basic"] spawn AP_fnc_handleMessage;
disableSerialization;
5 cutRsc["AP_progress", "PLAIN"];
private _ui = uiNamespace getVariable "AP_progress";
private _progress = _ui displayCtrl 38201;
private _pgText = _ui displayCtrl 38202;
private _text = "Equipping loadout...";
_pgText ctrlSetText format["%2 (1%1)...", "%", _text];
_progress progressSetPosition 0.01;
private _cP = 0.01;
AP_action_in_use = true;
private _success = false;
private _startPos = getPosATL player;
private _sleepDelay =
0.15;
for "_i"
from 0 to 1 step 0 do {uiSleep _sleepDelay;
    _cP = _cP + 0.01;
    _progress progressSetPosition _cP;
    _pgText ctrlSetText format["%3 (%1%2)...", round(_cP * 100), "%", _text];
    if ((getPosATL player) distance _startPos > 10) exitWith {};
    if !(AP_action_in_use) exitWith {};
    if (player getVariable["AP_restrained", false]) exitWith {};
    if (AP_isDowned) exitWith {};
    if !(isNull objectParent player) exitWith {};
    if !(alive player) exitWith {};
    if (_cp >= 1) exitWith {_success = true;};}; 5 cutText["", "PLAIN"];
AP_action_in_use = false;
if !(_success) exitWith {["The loadout equipping process has failed. Try again.", "basic"] spawn AP_fnc_handleMessage;};
if (_currency isEqualTo "$" && {AP_atmcash < _price}) exitWith {
    ["You don't have enough money in your bank account for this loadout.", "basic"] spawn AP_fnc_handleMessage;};
// NEW DRACHMA: a loadout is a summed BUNDLE, so its ND price is the bundle sum at 6000:1. Wallet debit
// is server-authoritative (this fn is spawned from fn_loadoutMenu -> AP_fnc_ndBuySync may block).
// owner 2026-07-24 SECURITY (free-loadout bug): the ND failure paths used `exitWith` INSIDE this `else {}`,
// which exits only the else block and not the function -- so a declined/timed-out server debit still fell
// through to the setUnitLoadout + handleInv grant below and delivered the whole loadout free. There is no
// _exit flag in this fn (the cash branch just deducts), so the branch is restructured with then/else and a
// _ndFail flag checked at function scope. NOTE the ndAfford check here is the SECOND one -- line 59 already
// gates affordability at file scope -- but ndBuySync (the authoritative server debit) is only checked here,
// and its DENIAL was the real hole.
private _ndFail = false;
if (_currency isEqualTo "$") then {AP_atmcash = (round(AP_atmcash - _price)) max 0;
    AP_atmcashCacheB = ((AP_atmcash / 4) + 11);
    [1] call AP_fnc_ClupdatePartial;} else {private _ndPrice = [_price] call AP_fnc_ndFromLegacy;
    if !([_ndPrice] call AP_fnc_ndAfford) then {
        [format["You don't have enough New Drachma for this loadout. You need %1 ND.", [_ndPrice] call AP_fnc_ndText], "basic"] spawn AP_fnc_handleMessage;
        _ndFail = true;} else {if !([_ndPrice] call AP_fnc_ndBuySync) then {
            ["New Drachma payment failed -- try again.", "basic"] spawn AP_fnc_handleMessage;
            _ndFail = true;};};};
if (_ndFail) exitWith {};
private _plb_obj = player;
_plb_obj setUnitLoadout _gearArray;
if (_virtualArray isNotEqualTo[]) then {AP_maxWeight = 96; {_x params["_item", "_amount"];
        [true, _item, _amount] call AP_fnc_handleInv;}
    forEach _virtualArray;
    [] call AP_fnc_giveMedkits;}; {if (isNil "_x") then {_skins set[_forEachIndex, -1];};}
forEach _skins;
[_skins] spawn {params["_skins"];
    private _notOwnedItems = ""; {private _skinArray = ["witz", "getRowByID", _x] call AP_fnc_clothingTextures;
        if !(_skinArray isEqualTo[]) then {
            _skinArray params["_id", "_classname", "_faction", "_coplevel", "_mediclevel", "_adminlevel", "_donorLevel", "_lootcrateid", "_uids", "_skinName"];
            private _notOwned = call {if !(AP_effSide in _faction) exitWith {true};
                if ((call AP_copLevel) < _copLevel) exitWith {true};
                if ((call AP_medicLevel) < _mediclevel) exitWith {true};
                if ((call AP_adminLevel) < _adminlevel) exitWith {true};
                if (!(_lootcrateid in AP_lootRewards) && _lootcrateid != -1) exitWith {true};
                if (!((getPlayerUID player) in _uids) && !(_uids isEqualTo[])) exitWith {true};
                if (true) exitWith {false};};
            if (_notOwned) then {_skins set[_forEachIndex, -1];
                _notOwnedItems = format["%1<br/>%2", _notOwnedItems, _skinName];};};}
    forEach _skins;
    if (_notOwnedItems != "") then {
        [format["The following skin(s) did not get applied because you do not own them:<br/><t color='#FF0000'>%1</t>", _notOwnedItems], "basic"] spawn AP_fnc_handleMessage;
    };
    uiSleep 0.5;
    [uniform player, "setIdx", _skins select 0] call AP_fnc_clothingTextures;
    [backpack player, "setIdx", _skins select 1] call AP_fnc_clothingTextures;
    AP_uniformBackpack_skins = [_skins select 0, _skins select 1];};
// owner 2026-06-13: re-hide an invisible backpack on respawn/loadout-equip (AP_invisBag persists on the unit)
if ((profileNamespace getVariable ["AP_invisBag", false]) && {(backpack player) isNotEqualTo ""}) then {[true] call AP_fnc_invisBag;};
private _var =
switch (AP_effSide) do {case civilian: {"AP_clothingSkinsCiv"};
    case west: {"AP_clothingSkinsCop"};
    case independent: {"AP_clothingSkinsMed"};}; profileNamespace setVariable[_var, AP_uniformBackpack_skins];
if (_type isEqualTo "rebel") then {private _pointData = arms_flag getVariable["AP_capData", [0, "Neutral", -1]];
    _pointData params["_flagGangID", "", "_progress"];
    if (_flagGangID isEqualTo 0) exitWith {};
    AP_armsCartel = [false, 0, _flagGangID];
    if ((count AP_gang_data) > 0) then {if ((_flagGangID isEqualTo(AP_gang_data select 0)) && (_progress >= 0)) then {
            AP_armsCartel set[0, true];};};};
private _extra = "";
private _cut =
switch (true) do {case ((_type isEqualTo "rebel") && !(AP_armsCartel select 0) && ((call AP_adminLevel) <= 2)): {floor(_price * 0.08)};
    case !(_type isEqualTo "rebel"): {floor(_price * (call AP_fnc_getGovTax))};
    default {0};}; private _govTaxedShops = ["skiptracer", "medic", "cop"];
if ((_type isEqualTo "rebel") && !(AP_armsCartel select 0) && ((call AP_adminLevel) <= 2)) then {
    private _updateVal = (AP_armsCartel select 1);
    _updateVal = _updateVal + _cut;
    AP_armsCartel set[1, _updateVal];
    _extra = format[", with $%1 going to the owner of the Arms Dealer", [_cut] call AP_fnc_numberText];};
if ((_type in _govTaxedShops) && ((call AP_adminLevel) <= 2)) then {private _updateVal = (AP_govTax select 1);
    _updateVal = _updateVal + _cut;
    AP_govTax set[1, _updateVal];
    _extra = format[", including a tax of $%1", [_cut] call AP_fnc_numberText];};
if (!((AP_armsCartel select 2) isEqualTo - 1) && !((AP_armsCartel select 1) isEqualTo 0)) then {[
        [0, 0, AP_armsCartel select 1], "APS_fnc_cartelSRV", false, false] spawn AP_fnc_MP;
    AP_armsCartel = [false, 0, -1];};
if (((_govTaxedShops find _type) isNotEqualTo - 1) && !(AP_govTax param[0, false])) then {
    if (!((AP_govTax select 2) isEqualTo - 1) && !((AP_govTax select 1) isEqualTo 0)) then {
        ["payGovernor", [(AP_govTax param[1, 0])]] spawn AP_fnc_govSystem;
        AP_turfTax set[1, 0];};};
private _rebelOutposts = ["Rebelop_1", "Rebelop_2", "Rebelop_3", "Rebelop_4", "Rebelop_5", "Rebelop_6"];
if !(({player distance(getMarkerPos _x) <= 200}
count _rebelOutposts) isEqualTo 0) then {["moneyspentrebel", _price] call AP_fnc_statArrUpdate;};
["You have equipped your selected loadout" + _extra + ".", "basic"] spawn AP_fnc_handleMessage;
["action", "equiploadout", 1] call AP_fnc_handleQuest; [
    ["-LOADOUTEQUIP-", player, (profileName), format["equipped a loadout for $%1 at POS: %2 - %3 - %4", _price, getPosATL player, _gearArray, _virtualArray]], "APS_fnc_logIt", 2] spawn AP_fnc_MP;