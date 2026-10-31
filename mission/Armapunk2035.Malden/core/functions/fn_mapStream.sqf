/*
    File: fn_mapStream.sqf  (AP_fnc_mapStream)
    The client streamer: init, then one tick every poll seconds, forever. Replaces
    fn_dynamicMapSystem (19 zone circles + a random decor cull) with per-object stream radii
    and detail tiers fed from the server's cell cache. mapdb.md D5. Spawn it.
*/
if (isDedicated) exitWith {};
[] call AP_fnc_mapStreamInit;
private _poll = (call AP_fnc_mapCfg) get "poll";
while {true} do {
    uiSleep _poll;
    if (!isNil "AP_inCombat" && {AP_inCombat} && {diag_tickTime - AP_inCombatTime >= 30}) then { AP_inCombat = false; };   // kept from the old loop
    [] call AP_fnc_mapTick;
};
