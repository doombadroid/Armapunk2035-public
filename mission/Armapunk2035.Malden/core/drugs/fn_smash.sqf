params[["_isForced", false, [false]]];
if ((_isForced) || ([false, "smash", 1] call AP_fnc_handleInv)) then {if (AP_smash_effect select 0) then {
        AP_smash_effect = [true, time];} else {AP_smash_effect = [true, time];
        [] spawn {waitUntil {uiSleep 1;
                (!alive player || ((time - (AP_smash_effect select 1)) > (6 * 60)));};
            // owner 2026-06-20: do NOT re-enable stamina on expiry (stamina is removed server-wide). Just clear the
            // effect flag + revert the speed buff to base.
            AP_smash_effect = [false, time];
            AP_fatigueEnabled = true;
            player setAnimSpeedCoef 1;};};
    [] call AP_fnc_hudUpdate;
    AP_fatigueEnabled = false;
    player setFatigue 0;
    player enableFatigue false;
    titleText["You feel unstoppable!", "PLAIN"];
    player setAnimSpeedCoef 1.15;   // owner 2026-06-21: smash = +15% sprint speed (was +30%, originally +10%). setAnimSpeedCoef is absolute -> overwrites/overwritten by other speed buffs (black lace/glitter/redgull), reverts to 1.0 on expiry.
    ["smash"] call AP_fnc_drugUsed;
    AP_drug_level = selectMin[1, AP_drug_level + 0.15];} else {["You have no Smash to use.", "basic"] spawn AP_fnc_handleMessage;};