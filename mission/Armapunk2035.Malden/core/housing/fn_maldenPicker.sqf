/*
    AP_fnc_maldenPicker  (LooneyBin, owner 2026-07-11)
    MALDEN MAKEOVER skin picker -- client side (replaces the on/off fn_maldenToggle). Opens from the house
    menu, lists the 6 Malden colors + "Original Altis", hands the choice to APS_fnc_maldenSRV mode "apply"
    (owner re-verified server-side). Free; look persists in houses.malden/malden_skin until changed, turned
    off, sold or transferred. Every color carries the same damage model (blast sensors + heavy-caliber
    scoring ride the swap itself).

    ["open", _house]   from fn_houseMenu (gated there: eligible type + owner)
    ["apply"]          APPLY button / double-click
*/
#define IDD_PICKER  515800
#define IDC_SKINS   515810
#define IDC_STATUS  515820

params [["_action", "open", [""]], ["_house", objNull, [objNull]]];

if (_action isEqualTo "open") exitWith {if (isNull _house) exitWith {};
    if !(["eligible", typeOf _house] call AP_fnc_maldenMap) exitWith {
        ["No Malden variant exists for this building type.", "basic"] spawn AP_fnc_handleMessage;};
    if ((_house getVariable ["AP_homeOwner", ""]) isNotEqualTo (getPlayerUID player)) exitWith {
        ["Only the owner can remodel this property.", "basic"] spawn AP_fnc_handleMessage;};
    AP_maldenPickTarget = _house;
    closeDialog 0;   // leave the house menu
    if (!createDialog "AP_MaldenPicker") exitWith {};
    private _disp = findDisplay IDD_PICKER;
    private _lb = _disp displayCtrl IDC_SKINS;
    lbClear _lb;
    private _current = ["colorOf", typeOf _house] call AP_fnc_maldenMap;   // "" when on the Altis look
    {_x params ["_key", "_label"];
        private _i = _lb lbAdd ([_label, format ["%1   (current)", _label]] select (_key isEqualTo _current));
        _lb lbSetData [_i, _key];
        if (_key isEqualTo _current) then { _lb lbSetCurSel _i; };} forEach (["colors"] call AP_fnc_maldenMap);
    private _i = _lb lbAdd (["Original Altis", "Original Altis   (current)"] select (_current isEqualTo ""));
    _lb lbSetData [_i, "off"];
    if (_current isEqualTo "") then { _lb lbSetCurSel _i; };
    (_disp displayCtrl IDC_STATUS) ctrlSetStructuredText parseText
        "<t color='#8993a0'>Shows for everyone. Stays until changed, sold or transferred.</t>";};

if (_action isEqualTo "apply") exitWith {private _disp = findDisplay IDD_PICKER;
    if (isNull _disp) exitWith {};
    private _tgt = missionNamespace getVariable ["AP_maldenPickTarget", objNull];
    if (isNull _tgt) exitWith { closeDialog 0; };
    private _lb = _disp displayCtrl IDC_SKINS;
    private _sel = lbCurSel _lb;
    if (_sel < 0) exitWith { ["Pick a look first.", "basic"] spawn AP_fnc_handleMessage; };
    private _key = _lb lbData _sel;
    private _isOff = _key isEqualTo "off";
    private _curOff = (["colorOf", typeOf _tgt] call AP_fnc_maldenMap) isEqualTo "";
    if (_isOff && _curOff) exitWith { ["That's already this property's look.", "basic"] spawn AP_fnc_handleMessage; };
    [["apply", player, _tgt, _key], "APS_fnc_maldenSRV", 2] spawn AP_fnc_MP;
    closeDialog 0;
    ["The remodeling crew is on it...", "basic"] spawn AP_fnc_handleMessage;};
