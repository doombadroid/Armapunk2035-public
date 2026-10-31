/*
    APS_fnc_eventGraveyardSRV  (LooneyBin -- implemented from stub 2026-06-09)
    Admin event: GRAVEYARD (Halloween bone-gathering at location 50). Start = [1, objNull, _locID].
    Scoring/digging is fully client-side (fn_eventGraveyardClient + setupActions grave actions, keyed on
    AP_adminEvent select 2 == 4 + AP_inEvent). Server = open joins, 20-min round, close.
*/
params [["_mode", -1, [0]], ["_x1", objNull, [objNull]], ["_locID", 50, [0]]];
if !(_mode isEqualTo 1) exitWith {};
if !([4, "eventGraveyardSRV START"] call APS_fnc_isAdminCaller) exitWith {};   // admin-menu event (eventCfg owner-only row, client gate >= 4): the caller's DB adminlevel, never the payload
if (AP_adminEvent param [0, false]) exitWith {};
if (isNil "AP_event_queue") then { AP_event_queue = []; };
AP_event_queue = [];
AP_adminEvent = [true, false, 4, _locID];
publicVariable "AP_adminEvent";
[[0, "ADMIN EVENT: GRAVEYARD SHIFT! Civilians -- press your event key to join the dig!"], "AP_fnc_broadcast", -2, false, false] spawn AP_fnc_MP;
[] spawn {uiSleep 1200;   // 20-min round
    if (AP_adminEvent param [0, false] && {(AP_adminEvent param [2, 0]) isEqualTo 4}) then {
        AP_adminEvent = [false, false, 0, 0]; publicVariable "AP_adminEvent";
        AP_event_queue = [];
        [[0, "The Graveyard Shift admin event has ended!"], "AP_fnc_broadcast", -2, false, false] spawn AP_fnc_MP;};};
