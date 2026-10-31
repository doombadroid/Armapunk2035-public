/*
    APS_fnc_fedEventActive  (LooneyBin -- SERVER-SIDE authoritative federal-event mutual-exclusion check)
    owner 2026-06-16 (#302 "any federal events can be done simultaneously"): the client gate
    (AP_fnc_activeFederalEvent) is the only thing that was enforcing "one fed event at a time", and it
    reads flags that are set LATE (the fed only flips AP_fed_robbed at the alarm, ~10s after a 105s dome
    breach) -> a second event can pass the client check during that window, and NOTHING re-checked on the
    server, so both ran. This is the server-authoritative twin: each event's server activation calls it
    right before it commits and aborts if another event is already live. Reads the same flags the client
    function does (all publicVariable'd FROM the server, so the server holds them). _exclude = the event
    asking (so it doesn't block itself). Returns true if ANY OTHER federal event is active.
*/
params [["_exclude", "", [""]]];
// fed + loonybin read the server-private localNamespace copies (audit r2heist): their globals are client-writable
// display copies, so one publicVariable used to fake a live event (blocking every other heist) or hide a real one.
private _events = [["fed",      ((localNamespace getVariable ["SRV_maldenFed", [0]]) param [0, 0]) > 0],
    ["bank",     (missionNamespace getVariable ["AP_bank_robbed",       [false]])     param [0, false]],
    ["evidence", !((missionNamespace getVariable ["SRV_evidence_status",  [false,true]]) param [1, true])],
    ["prison",   (missionNamespace getVariable ["SRV_prisonData",         [0,false]])   param [1, false]],
    ["convoy",   (missionNamespace getVariable ["SRV_convoy_status",      [false]])     param [0, false]],
    ["loonybin", (localNamespace getVariable ["SRV_loonyBinData",         [0,false]])   param [1, false]],
    ["jewelry",  (missionNamespace getVariable ["SRV_jewelryEmporiumSRV", [0,false]])   param [1, false]]];
private _check = (_events select { (_x select 0) != _exclude }) apply { _x select 1 };
true in _check
