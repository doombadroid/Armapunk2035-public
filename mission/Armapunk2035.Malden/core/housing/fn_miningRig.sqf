/*
    AP_fnc_miningRig  (client) -- scroll actions on a PLACED crypto mining rig.
      ["collect", _rig]   ask the server to grant accrued LoonyCoin
      ["move", _rig]      pack up (server auto-collects pending coins + refunds the rig item) then re-enter
                          the placement preview to reposition it
      ["delete", _rig]    confirm -> pack up: pending coins collected, the assembled rig returns to inventory
    (Install is gone: the rig is now placed via Use cryptoRig -> the placement preview -> APS_fnc_miningSRV "place".)
*/
params [["_mode", "", [""]], ["_rig", objNull, [objNull]]];
if (isNull _rig) exitWith {};
switch (toLower _mode) do {case "collect": {[["collect", player, _rig], "APS_fnc_miningSRV", 2] spawn AP_fnc_MP;};
    case "move": {
        // pack up server-side (auto-collects + refunds the rig item), then re-hold it for re-placement
        [["delete", player, _rig], "APS_fnc_miningSRV", 2] spawn AP_fnc_MP;
        [] spawn {private _t0 = time;
            waitUntil { uiSleep 0.3; ((missionNamespace getVariable ["AP_inv_cryptoRig", 0]) > 0) || {time > _t0 + 10} };
            if ((missionNamespace getVariable ["AP_inv_cryptoRig", 0]) > 0) then {
                ["Reposition your rig, then Place it.", "info"] spawn AP_fnc_handleMessage;
                ["cryptoRig"] spawn AP_fnc_holdObject;};};};
    case "delete": {
        if !([parseText "Delete this mining rig? Any pending New Drachma is collected first and the assembled rig returns to your inventory.", "Delete Mining Rig", true] call BIS_fnc_guiMessage) exitWith {};
        [["delete", player, _rig], "APS_fnc_miningSRV", 2] spawn AP_fnc_MP;};};
