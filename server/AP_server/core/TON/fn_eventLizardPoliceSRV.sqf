/*
    APS_fnc_eventLizardPoliceSRV  (LooneyBin world event -- Ben Bones canon). AP_adminEvent type 10.
    For 8 minutes the badges are SHEDDING -- every cop is cold-blooded. Server flags AP_lizardPolice; the
    client watcher (initPlayerLocal) gives cops a green reptile tint + a toast. Cosmetic + pure lore/chaos.
*/
params [["_locID", -1, [0]]];
if !([4, "eventLizardPoliceSRV START"] call APS_fnc_isAdminCaller) exitWith {};   // admin-menu event (eventCfg owner-only row, client gate >= 4): the caller's DB adminlevel, never the payload
if (AP_adminEvent param [0, false]) exitWith {};
AP_adminEvent = [true, false, 10, 0];
publicVariable "AP_adminEvent";
AP_lizardPolice = [true, serverTime + 480]; publicVariable "AP_lizardPolice";

[[0, "BEN BONES EMERGENCY BROADCAST: the badges are SHEDDING. Every cop is COLD-BLOODED for 8 minutes. Trust NO ONE with a siren."], "AP_fnc_broadcast", -2, false, false] spawn AP_fnc_MP;
["LIZARD", "POLICE CONFIRMED REPTILIAN FOR THE NEXT 8 MIN -- 'ROUTINE', SAYS FORKED TONGUE", "the COPS are LIZARDS right now. i can SEE the scales. do NOT comply, patriot."] call APS_fnc_newsPush;

[] spawn {uiSleep 480;
    AP_lizardPolice = [false, 0]; publicVariable "AP_lizardPolice";
    if (AP_adminEvent param [0, false] && {(AP_adminEvent param [2, 0]) isEqualTo 10}) then {
        AP_adminEvent = [false, false, 0, 0]; publicVariable "AP_adminEvent";
        [[0, "The lizard police have shed back to human form. Allegedly."], "AP_fnc_broadcast", -2, false, false] spawn AP_fnc_MP;};};
