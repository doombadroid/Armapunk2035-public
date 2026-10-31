params["_unit", "_group"];
if (isNil "_unit" || isNil "_group") exitWith {};
openMap false;
if ((player isEqualTo _unit) && ((group player) isEqualTo _group)) then {AP_my_gang = objNull;
    [player] joinSilent(createGroup [civilian, true]);
    ["You have been kicked out of the group.", "basic"] spawn AP_fnc_handleMessage;
    if (isNil {(group player) getVariable "gang_id"} && !(AP_gang_data isEqualTo[])) then {AP_action_in_use = true;
        // the GROUP app repaints from the deck's own push
        [] spawn AP_fnc_initGang;};};