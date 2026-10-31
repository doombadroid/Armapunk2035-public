params[["_item", "", [""]]];
if (_item isEqualTo "") exitWith {};
if !([false, _item, 1] call AP_fnc_handleInv) exitWith {};
private _addInc =
switch _item do {case "beer": {0.10}; default {0.15};}; AP_alcohol_level = selectMin[1, AP_alcohol_level + _addInc];
APV_thirst = selectMin[100, APV_thirst + 10];
[] call AP_fnc_hudUpdate;
private _center = selectMax[0.2, 0.5 - (AP_alcohol_level / 2)];
"RadialBlur"
ppEffectEnable true;
"RadialBlur"
ppEffectAdjust[0.05, 0.05, _center, _center];
"RadialBlur"
ppEffectCommit 1;
"chromAberration"
ppEffectEnable true;
"chromAberration"
ppEffectAdjust[AP_alcohol_level / 20, AP_alcohol_level / 20, true];
"chromAberration"
ppEffectCommit 1;
uiSleep 180;
AP_alcohol_level = selectMax[0, AP_alcohol_level - 0.10];
if (AP_alcohol_level > 0) then {
    "RadialBlur"
    ppEffectEnable true;
    "RadialBlur"
    ppEffectAdjust[0.05, 0.05, _center, _center];
    "RadialBlur"
    ppEffectCommit 1;
    "chromAberration"
    ppEffectEnable true;
    "chromAberration"
    ppEffectAdjust[AP_alcohol_level / 20, AP_alcohol_level / 20, true];
    "chromAberration"
    ppEffectCommit 1;} else {
    "RadialBlur"
    ppEffectEnable false;
    "chromAberration"
    ppEffectEnable false;};
private _updatedSway = selectMax[AP_alcohol_level * 35, 0.25];  // LoonyBin: sober floor = 0.25 default (was 0.7); alcohol still adds sway on top
player setCustomAimCoef _updatedSway;