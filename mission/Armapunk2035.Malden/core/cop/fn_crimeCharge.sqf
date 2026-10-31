params["_target", "_caller", "_actionId", "_arguments"];
_arguments params[["_unit", objNull, [objNull]]];
disableSerialization;
if ((isNull _unit) || (!isPlayer _unit) || (!alive _unit) || ((side _unit) isEqualTo west)) exitWith {};
if (!isNull(findDisplay 5520)) exitWith {closeDialog 0;};
// DECK ROUTE (UI overhaul 2026-08-26): charging opens the MAXSEC INTAKE terminal.
if (missionNamespace getVariable ["AP_deckApps", true]) exitWith {
    ["Intake", _unit] call AP_fnc_deckOpenApp;
};
createDialog "crimeChargeDiag";
waitUntil {!isNull(findDisplay 5520)};
private _display = findDisplay 5520;
if (isNull _display) exitWith {};
private _title = _display displayCtrl 5521;
private _list = _display displayCtrl 5522;
private _input = _display displayCtrl 5523;
private _button = _display displayCtrl 5524; {_x ctrlEnable false}
forEach[_input, _button];
_title ctrlSetText format["Charge Citizen: %1", name _unit];
private _chargeList = ["getManualCharges"] call AP_fnc_wantedChargesConfig; {
    _x params["_chargeID", "_title", "_bounty", "_jailTime", "_isStackable"];
    private _index = _list lbAdd _title;
    _list lbSetData[_index, str[_chargeID, _bounty, _isStackable]];
    if (_isStackable) then {_list lbSetTextRight[_index, "[Stackable]"]};}
forEach _chargeList;
lbSort _list;
if ((isNull _unit) || (!isPlayer _unit) || (!alive _unit) || ((side _unit) isEqualTo west)) exitWith {closeDialog 0;};
private _chargeSelected = {private _display = findDisplay 5520;
    if (isNull _display) exitWith {};
    private _input = _display displayCtrl 5523;
    private _button = _display displayCtrl 5524;
    private _chargeText = _display displayCtrl 5525;
    private _chargeInfo = parseSimpleArray(lbData[5522, lbCurSel 5522]);
    _chargeInfo params[["_chargeID", 0], ["_bounty", 0], ["_isStackable", false]];
    _input ctrlSetText "1";
    _input ctrlEnable _isStackable;
    _button ctrlEnable true;
    _chargeText ctrlSetStructuredText(parseText format["<t size='0.125'>&#160;</t><br/><t size='0.85'>Charge Amount: <t color='#8CFF9B'>$%1</t></t>", [_bounty] call AP_fnc_numberText]);
    if ((ctrlFade _chargeText) isEqualTo 1) then {_chargeText spawn {_this ctrlSetFade 0;
            _this ctrlCommit 0.10}};};
_list ctrlSetEventHandler["LBSelChanged", format["call %1", _chargeSelected]];
_button ctrlSetEventHandler["ButtonClick", format["['%1'] call AP_fnc_applyCharge", getPlayerUID _unit]];