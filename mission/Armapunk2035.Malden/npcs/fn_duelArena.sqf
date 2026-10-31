params["_obj_main", "_stance"];
if (_obj_main isKindOf "CAManBase") then {};
_obj_main addAction["Invite someone to duel", {
    if (missionNamespace getVariable ["AP_deckApps", true]) then { ["Duel"] call AP_fnc_deckOpenApp; }
    else { ["promptMenu"] spawn AP_fnc_duelArenaSystem; }
}, nil, 1.5, false, false, "", 'AP_effSide isEqualTo civilian', 5];
_obj_main addAction["Accept a duel", {["acceptInvite"] spawn AP_fnc_duelArenaSystem
}, nil, 1.5, false, false, "", 'AP_effSide isEqualTo civilian', 5];