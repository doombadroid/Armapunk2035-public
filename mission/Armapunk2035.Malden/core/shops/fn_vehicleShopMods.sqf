/*
    AP_fnc_vehicleShopMods (LooneyBin, ui branch) -- fill the vehicle shop's buy-time CONFIGURE grid for the
    selected vehicle. Options + prices come from the SAME sources as the garage mod menu
    (AP_fnc_vehicleModConfig / AP_fnc_hornCfg), so shop and garage can never disagree on pricing.
    Each combo entry: lbValue = mod value (what goes in the 9-slot mods array), lbData = str price.
    _this = [_classname]
*/
params [["_classname", "", [""]]];
disableSerialization;
private _d = findDisplay 100100;
if (isNull _d) exitWith {};

private _cfg = call AP_fnc_vehicleModConfig;
// compact the price suffix so it fits the combo column ("+50 Storage - $5,000" -> "+50 Storage $5k")
private _fnCompact = {params ["_s"];
    private _out = (_s regexReplace [" - \$", " $"]) regexReplace [",000", "k"];
    (_out regexReplace [",500", ".5k"])};
// [ modSlot, comboIdc ]
private _map = [[1, 100110], [2, 100111], [3, 100112], [4, 100113], [5, 100114], [7, 100115], [8, 100116], [9, 100118]]; {
    _x params ["_slot", "_idc"];
    private _c = _d displayCtrl _idc;
    lbClear _c;
    if (_slot isEqualTo 3) then {
        // horns come from hornCfg: rows [id, name, price, ...]
        {private _i = _c lbAdd ([format ["%1 - $%2", _x select 1, [_x select 2] call AP_fnc_numberText]] call _fnCompact);
            _c lbSetValue [_i, _x select 0];
            _c lbSetData [_i, str (_x select 2)];} forEach ([1] call AP_fnc_hornCfg);} else {
        private _opts = ((_cfg select { (_x select 0) isEqualTo _slot }) param [0, [0, "", []]]) select 2;
        // MOTORIST -- Autopilot Certified (201): the autopilot module (slot 9) is free at the dealer
        private _apFree = _slot isEqualTo 9 && {201 in AP_side_talents}; {_x params ["_label", "_val", "_cost"];
            // owner 2026-07-21: value 1 ONLY. Slot 9 gained a third option (2 = Analog Retrofit, $45k) and a
            // `_val > 0` test would have handed that out free as well -- the talent waives the AUTOPILOT, not
            // the retrofit that removes it.
            if (_apFree && {_val isEqualTo 1}) then { _cost = 0; _label = "Autopilot Module - FREE"; };
            private _i = _c lbAdd ([_label] call _fnCompact);
            _c lbSetValue [_i, _val];
            _c lbSetData [_i, str _cost];} forEach _opts;};
    _c lbSetCurSel 0;
    _c ctrlEnable ((lbSize _c) > 1);} forEach _map;

// autopilot: ground vehicles and rotorcraft (helis + VTOLs); planes and boats never
private _apCombo = _d displayCtrl 100118;
if !((_classname isKindOf "LandVehicle") || {[_classname] call AP_fnc_isRotorcraft}) then {_apCombo lbSetCurSel 0;
    _apCombo ctrlEnable false;};
// doors are an LSV-only mod (vehicleAnimate door rails); lock the combo for everything else
private _doors = _d displayCtrl 100116;
if ((toLower _classname) find "lsv" < 0) then {_doors lbSetCurSel 0;
    _doors ctrlEnable false;};
