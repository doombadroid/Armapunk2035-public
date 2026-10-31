/*
    AP_fnc_vehicleShopTotal (LooneyBin, ui branch) -- recompute the vehicle shop TOTAL readout (idc 100117):
    base purchase price (incl tax, stashed by fn_vehicleShopLBChange) + alarm + the configure-grid mod costs
    (flat, untaxed -- garage parity). Display only; fn_vehicleShopBuy recomputes authoritatively on purchase.
*/
disableSerialization;
private _d = findDisplay 100100;
if (isNull _d) exitWith {};
private _base = uiNamespace getVariable ["AP_VehShopBase", -1];
if (_base < 0) exitWith {};
private _alarm = if (ctrlChecked (_d displayCtrl 100106)) then { 500 } else { 0 };
private _mods = 0; {private _c = _d displayCtrl _x;
    if ((lbSize _c) > 0 && { (lbCurSel _c) >= 0 }) then {_mods = _mods + parseNumber (_c lbData (lbCurSel _c));};
} forEach [100110, 100111, 100112, 100113, 100114, 100115, 100116, 100118];
// NEW DRACHMA: the nd_car shop pays ND. Show ND = 6000:1 of the aggregate (matches the table for the
// seeded vehicle prices; if a vehicle's ND price is later hand-tuned in fn_ndPriceCfg the authoritative
// charge in fn_vehicleShopBuy still wins). Cash shops unchanged.
if (AP_ndShop) then {
    // NEW DRACHMA: base ND from the independent price table (matches what fn_vehicleShopBuy actually charges);
    // mods/alarm convert 6000:1 and add on top. Falls back to 6000:1 of the whole total if the item has no
    // table entry (keeps display == charge for seeded vehicles).
    private _ndBaseStr = [uiNamespace getVariable ["AP_VehShopClass", ""]] call AP_fnc_ndPriceCfg;
    private _ndTotal = if (_ndBaseStr isEqualTo "") then {parseNumber ([round (_base + _alarm + _mods)] call AP_fnc_ndFromLegacy)} else {
        (parseNumber _ndBaseStr) + (parseNumber ([round (_alarm + _mods)] call AP_fnc_ndFromLegacy))};
    (_d displayCtrl 100117) ctrlSetStructuredText parseText format ["<t size='1' font='PuristaSemibold' color='#53e39c'>%1 ND</t>",
        [((round (_ndTotal * 10000)) / 10000) toFixed 4] call AP_fnc_ndText];} else {
    (_d displayCtrl 100117) ctrlSetStructuredText parseText format ["<t size='1' font='PuristaSemibold' color='#53e39c'>$%1</t>",
        [round (_base + _alarm + _mods)] call AP_fnc_numberText];};
