/*
    APS_fnc_eventPurgeSRV  (LooneyBin -- implemented from stub 2026-06-09)
    Admin event: THE PURGE (lawless square, locations 18-21). Start = [_locID] from the eventCfg lambda.
    Client behaviour (fn_eventPurgeClient, initClient'd at spawn) keys on AP_adminEvent select 2 == 5;
    kills inside the event add no charges (onPlayerKilled gates on AP_inEvent). Server = announce,
    20-min round, close.
*/
params [["_locID", -1, [0]]];
if !([4, "eventPurgeSRV START"] call APS_fnc_isAdminCaller) exitWith {};   // admin-menu event (eventCfg owner-only row, client gate >= 4): the caller's DB adminlevel, never the payload
if (AP_adminEvent param [0, false]) exitWith {};
if (isNil "AP_event_queue") then { AP_event_queue = []; };
AP_event_queue = [];
AP_adminEvent = [true, false, 5, _locID];
publicVariable "AP_adminEvent";
private _locData = (["getLocationByID", _locID] call AP_fnc_eventCfg);
private _locName = _locData param [1, "?"];
private _purgePos = _locData param [2, [0,0,0]];
// owner 2026-06-24: AUTO-ZONE PURGE. Build the global redzone (map + inArea) + center dot and publish AP_purgeZone
// for the server-side no-charge gate (APS_fnc_wantedAdd). NO remoteExec to init clients -- CfgRE mode=1 would
// silently block an un-whitelisted server->client call; instead the client watcher in initPlayerLocal sees
// AP_adminEvent select 2 == 5 (publicVariable, reliable) and runs fn_eventPurgeClient locally.
deleteMarker "PurgeRedzone"; deleteMarker "PurgeDot";
createMarker ["PurgeRedzone", _purgePos];
"PurgeRedzone" setMarkerShape "ELLIPSE";
"PurgeRedzone" setMarkerSize [450, 450];
"PurgeRedzone" setMarkerBrush "DiagGrid";
"PurgeRedzone" setMarkerColor "ColorRed";
"PurgeRedzone" setMarkerAlpha 0.55;
"PurgeRedzone" setMarkerText "THE PURGE";
createMarker ["PurgeDot", _purgePos];
"PurgeDot" setMarkerType "mil_warning";
"PurgeDot" setMarkerColor "ColorRed";
"PurgeDot" setMarkerText "Purge";
localNamespace setVariable ["AP_purgeZone", [_purgePos, 450]]; AP_purgeZone = [_purgePos, 450]; publicVariable "AP_purgeZone";   // APS_fnc_wantedAdd reads localNamespace (Lsec-0-1)
[[0, format ["ADMIN EVENT: THE PURGE at %1! All crime is legal inside the red zone for 20 minutes!", _locName]], "AP_fnc_broadcast", -2, false, false] spawn AP_fnc_MP;
[] spawn {uiSleep 1200;
    if (AP_adminEvent param [0, false] && {(AP_adminEvent param [2, 0]) isEqualTo 5}) then {
        AP_adminEvent = [false, false, 0, 0]; publicVariable "AP_adminEvent";
        AP_event_queue = [];
        [[0, "The PURGE has ended. Law and order resume!"], "AP_fnc_broadcast", -2, false, false] spawn AP_fnc_MP;};
    deleteMarker "PurgeRedzone"; deleteMarker "PurgeDot";
    AP_purgeZone = nil; localNamespace setVariable ["AP_purgeZone", nil]; publicVariable "AP_purgeZone";};
