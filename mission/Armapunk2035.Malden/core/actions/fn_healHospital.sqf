if ([player] call AP_fnc_healBlocked) exitWith {
    ["The doctor takes one look at you and shakes their head. Whatever's in your system, they can't treat it right now.", "basic"] spawn AP_fnc_handleMessage;
};
if !([50] call AP_fnc_debitCard) exitWith {};
["The doctor is healing you... don't be scared.", "basic"] spawn AP_fnc_handleMessage;
uiSleep 7;
if (player distance(_this select 0) > 5) exitWith {
    ["You need to be within 5m while the doctor is healing you.", "basic"] spawn AP_fnc_handleMessage;};
["You are now fully healed!", "basic"] spawn AP_fnc_handleMessage;
private _plb_dmg = player;
_plb_dmg setDamage 0;
player setVariable["AP_can_revive", nil, true];
[] call AP_fnc_hudUpdate;