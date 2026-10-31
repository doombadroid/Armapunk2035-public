#include "..\..\macro.h"
/*
    AP_fnc_selfCharge  --  owner 2026-06-24. OWNER testing tool: add wanted charges to YOURSELF in-game via the
    LEGIT path (no DB injection). Opens the cop charge dialog (crimeChargeDiag / 5520) targeted at the owner, lists
    the manual charges, and the Apply button routes to AP_fnc_applyCharge with the OWNER's own UID -- so it fires
    exactly what a real cop citation does: APS_fnc_wantedAdd (server, capped 5/apply), the -ADDCHARGE- log, and the
    -MODFLAG-RAPE- audit row for id 110 that CLANKR pings on. Click Apply repeatedly to stack past 5. Owner-only +
    CIVILIAN (the wanted system is civ-only -- fn_wantedListAdd exits for non-civ).
*/
if ((call AP_adminLevel) < 5) exitWith { ["Owner only.", "basic"] spawn AP_fnc_handleMessage; };
if !(AP_effSide isEqualTo civilian) exitWith { ["Switch to CIVILIAN first -- charges only apply to civilians.", "basic"] spawn AP_fnc_handleMessage; };
disableSerialization;
if (!isNull (findDisplay 5520)) exitWith { closeDialog 0; };
createDialog "crimeChargeDiag";
waitUntil { !isNull (findDisplay 5520) };
private _display = findDisplay 5520;
if (isNull _display) exitWith {};
private _title  = _display displayCtrl 5521;
private _list   = _display displayCtrl 5522;
private _input  = _display displayCtrl 5523;
private _button = _display displayCtrl 5524;
{ _x ctrlEnable false } forEach [_input, _button];
_title ctrlSetText "Charge MYSELF (owner test)";
private _chargeList = ["getManualCharges"] call AP_fnc_wantedChargesConfig; {
    _x params ["_chargeID", "_ctitle", "_bounty", "_jailTime", "_isStackable"];
    private _index = _list lbAdd _ctitle;
    _list lbSetData [_index, str [_chargeID, _bounty, _isStackable]];
    if (_isStackable) then { _list lbSetTextRight [_index, "[Stackable]"]; };} forEach _chargeList;
lbSort _list;
private _chargeSelected = {private _display = findDisplay 5520;
    if (isNull _display) exitWith {};
    private _input = _display displayCtrl 5523;
    private _button = _display displayCtrl 5524;
    private _chargeText = _display displayCtrl 5525;
    private _chargeInfo = parseSimpleArray (lbData [5522, lbCurSel 5522]);
    _chargeInfo params [["_chargeID", 0], ["_bounty", 0], ["_isStackable", false]];
    _input ctrlSetText "1";
    _input ctrlEnable _isStackable;
    _button ctrlEnable true;
    _chargeText ctrlSetStructuredText (parseText format ["<t size='0.125'>&#160;</t><br/><t size='0.85'>Charge Amount: <t color='#8CFF9B'>$%1</t></t>", [_bounty] call AP_fnc_numberText]);
    if ((ctrlFade _chargeText) isEqualTo 1) then { _chargeText spawn { _this ctrlSetFade 0; _this ctrlCommit 0.10 }; };};
_list ctrlSetEventHandler ["LBSelChanged", format ["call %1", _chargeSelected]];
// Apply -> self. fn_applyCharge finds the unit by UID (excludes west), so this works while CIVILIAN; it fires
// APS_fnc_wantedAdd + the audit logs (incl. -MODFLAG-RAPE- for id 110). The dialog stays open so you can re-apply.
_button ctrlSetEventHandler ["ButtonClick", format ["['%1'] call AP_fnc_applyCharge", getPlayerUID player]];
