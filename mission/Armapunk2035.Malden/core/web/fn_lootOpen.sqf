/*
    fn_lootOpen.sqf — LOOT CARD entry. The native menu's guards, verbatim in
    order — ufo cooldown, the double-checked AP_inUse reservation with the
    anti-race jitter, the lagCheck roundtrip — then the web dialog instead of
    1520. First call wins the case exactly as before; the reservation IS the
    reconciliation.
*/
params [["_obj", objNull, [objNull]]];
if (isNull _obj) exitWith {};
if (AP_pickingUpItems) exitWith {["You are still in the process of picking up items!", "basic"] spawn AP_fnc_handleMessage};
if ((_obj getVariable ["AP_ufoLoot", false]) && ((SRV_ufoCrash select 2) > serverTime - 900)) exitWith {
    [format ["This radiated loot is unstable right now. Try in another %1 minutes. Check back frequently!",
        ceil ((((SRV_ufoCrash select 2) + 900) - serverTime) / 60)], "basic"] spawn AP_fnc_handleMessage;
};
private _nearUnits = player nearEntities ["CAManBase", 8] select { isPlayer _x && !(_x isEqualTo player) };
if !(isNull (_obj getVariable ["AP_inUse", objNull])) exitWith {
    ["Someone is already accessing these items.", "basic"] spawn AP_fnc_handleMessage;
};
if !(_nearUnits isEqualTo []) then { uiSleep (random 1.5) };
if !(isNull (_obj getVariable ["AP_inUse", objNull])) exitWith {
    ["Someone is already accessing these items.", "basic"] spawn AP_fnc_handleMessage;
};
_obj setVariable ["AP_inUse", player, true];

AP_didServerRespond = false;
private _maxDelayTime = time + 5;
[[player], "APS_fnc_lagCheck", 2] spawn AP_fnc_MP;
waitUntil { time > _maxDelayTime || AP_didServerRespond };
if (time > _maxDelayTime) exitWith {
    ["Menu failed, try again.", "basic"] spawn AP_fnc_handleMessage;
    if (_obj getVariable ["AP_inUse", objNull] isEqualTo player) then { _obj setVariable ["AP_inUse", nil, true] };
};

AP_pickMenuItems = +(_obj getVariable ["AP_droppedItems", []]);
uiNamespace setVariable ["AP_lootCase", _obj];
if (dialog) then { closeDialog 0; uiSleep 0.12 };
createDialog "AP_web_loot";
