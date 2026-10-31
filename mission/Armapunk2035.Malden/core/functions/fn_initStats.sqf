waitUntil {position player distance(getMarkerPos "respawn_civilian") > 1000}; [{
    if (!AP_useStatBuffer) then { [9] call AP_fnc_ClupdatePartial; };   // singleevh.md Phase 3b: flag-on -> A_stats flushed by the unified fn_flushStats (120s + events), not this 300s PFH
    if (AP_newPlyrRev > 4) then {[
            [1, player, "Potential Revive Exploit", format["This player has done %1 revives in the last 5 minutes and could be exploiting revive fees.", AP_newPlyrRev]], "APS_fnc_discordEmbed", 2] call AP_fnc_MP;
    };
    AP_newPlyrRev = 0;
}, [], 300] call AP_fnc_addPerFrameHandler;
// singleevh.md Phase 3a: periodic durable flush of the stat buffer (flag-gated). Bounds crash loss to ~120s
// (the legacy path only flushed on respawn / sync / restart / quit, so a hard crash lost the session's deltas).
[{ if (AP_useStatBuffer) then { call AP_fnc_flushStats }; }, [], 120] call AP_fnc_addPerFrameHandler; [{params[["_args", [0], [[]]
    ], ["_handle", -1, [0]]];
    _args params[["_civTime", 0, [0]]];
    
        switch (AP_effSide) do {case west: {A_stats_copTime = A_stats_copTime + 1;
                    AP_houseTimer = AP_houseTimer + 1;};
            case civilian: {A_stats_civTime = A_stats_civTime + 1;
                    if !(AP_houses isEqualTo[]) then {AP_houseTimer = AP_houseTimer + 1;};};
            case independent: {A_stats_medTime = A_stats_medTime + 1;};
        }; if (AP_useStatBuffer) then { AP_astats_dirty = true; }; if (AP_houseTimer >= 10) then {AP_houseTimer = 0; [
                ["updateHouseTime", [player]], "APS_fnc_houseTaxSRV", 2] spawn AP_fnc_MP;};;
    if (AP_effSide isEqualTo civilian && {!isNil "A_stats_civTime"}) then {if ((A_stats_civTime - _civTime) > 360) then {[
                [player, [71, _civTime, str A_stats_civTime]], "APS_fnc_dongClient", 2] call AP_fnc_MP;};};
    AP_mpCalls = [];}, [A_stats_civTime], 60] call AP_fnc_addPerFrameHandler;