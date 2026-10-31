/*
    File: fn_mapStreamInit.sqf  (AP_fnc_mapStreamInit)
    Per-machine streamer state and the first request (the far bucket). mapdb.md D5.
    Runs on every client and, driven by the self-test, on a headless client. Never on the server.
*/
if (isDedicated) exitWith {};
// The stores live in localNamespace, which no machine can write over the network: as missionNamespace
// globals a client's publicVariable of AP_mapRows reached every streamer's compile of row init (audit
// 2026-09-26). The maps are references -- readers bind them once and mutate in place, never reassign.
localNamespace setVariable ["AP_mapRows", createHashMap];       // id -> wire row
localNamespace setVariable ["AP_mapCellRows", createHashMap];   // cell key -> [ids]
localNamespace setVariable ["AP_mapCells", createHashMap];      // cell key -> "wanted" | "loaded"
localNamespace setVariable ["AP_mapCellAsked", createHashMap];  // cell key -> tick when requested
localNamespace setVariable ["AP_mapCellRev", createHashMap];    // cell key -> rev of the blob we hold
localNamespace setVariable ["AP_mapPending", createHashMap];    // cell key -> [[rev, op, payload]] edits that raced the fetch
localNamespace setVariable ["AP_mapLive", createHashMap];       // id -> this machine's local object
localNamespace setVariable ["AP_mapDirty", []];                 // ids whose live object must be deleted next tick
AP_mapReady = false;              // far bucket received
AP_mapFarDone = false;            // first create pass after the far bucket has run
AP_mapT0 = diag_tickTime;
if (isNil "AP_dynamicMap_lastVehicle") then { AP_dynamicMap_lastVehicle = objNull; };
// Detail tier from settings slot 7 (0 = unset -> 2). 1 normal, 2 + decor, 3 + never-by-default.
private _slot = (profileNamespace getVariable ["PLBClientSettings", missionNamespace getVariable ["AP_clientDefaultSettings", []]]) param [7, 0];
if (!(_slot isEqualType 0)) then { _slot = 0; };
AP_mapDetail = if (_slot < 1) then { 2 } else { (round _slot) min 3 };
(localNamespace getVariable "AP_mapCells") set ["far", "wanted"];
(localNamespace getVariable "AP_mapCellAsked") set ["far", diag_tickTime];
[["far", [], player], "APS_fnc_mapFetch", 2, false] call AP_fnc_MP;
