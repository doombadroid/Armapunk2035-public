if (AP_revive_fatigue > 0) exitWith {["This item has no effect due to revive fatigue.", "basic"] spawn AP_fnc_handleMessage;};
if (AP_inv_goldbar > 0) exitWith {["This item has no effect when carrying a goldbar.", "basic"] spawn AP_fnc_handleMessage;};
private _effectDuration = 3;
if (AP_effSide isEqualTo civilian && 451 in AP_completedLifetimeQuests) then {_effectDuration = 4;};
if (7 in AP_infamy_talents && license_civ_rebel) then {_effectDuration = _effectDuration + 1;};
if ([false, "redgull", 1] call AP_fnc_handleInv) then {if (AP_redgull_effect select 0) then {AP_redgull_effect = [true, time];
    } else {AP_redgull_effect = [true, time];
        [_effectDuration] spawn {params["_effectDuration"];
            waitUntil {uiSleep 1;
                (!alive player || ((time - (AP_redgull_effect select 1)) > (_effectDuration * 60)));};
            // owner 2026-06-20: Red Gull = +10% SPRINT now (the old "run without rest" is dead -- stamina removed).
            // Revert the speed buff to base on expiry; do NOT re-enable stamina.
            AP_redgull_effect = [false, time];
            player setAnimSpeedCoef 1;};};
    APV_thirst = 100;
    [] call AP_fnc_hudUpdate;
    // owner 2026-06-20: +10% sprint speed (absolute coef -- shares the overwrite behaviour with smash/black lace/glitter)
    // plus the usual thirst top-up.
    player setAnimSpeedCoef 1.1;
    titleText[format["Red Gull kicks in: +10% sprint speed for %1 minutes!", _effectDuration], "PLAIN DOWN", -1, true, true];
    ["use", "redgull", 1] call AP_fnc_handleQuest;
    ["redgull", 1] call AP_fnc_statArrUpdate;} else {["You have no redgull to drink.", "basic"] spawn AP_fnc_handleMessage;};