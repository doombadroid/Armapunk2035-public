if !([false, "blacklace", 1] call AP_fnc_handleInv) exitWith {};
AP_drug_level = selectMin[AP_drug_level + 0.2, 1];
if (AP_blackLace_effect isEqualTo 0) then {AP_blackLace_effect = time;
    [] spawn {AP_fatigueEnabled = false;
        player setAnimSpeedCoef 1.15;
        player setFatigue 0;
        player enableFatigue false;
        waitUntil {uiSleep 0.75;
            !(alive player) || ((time - AP_blackLace_effect) > (4.5 * 60))};
        player setAnimSpeedCoef 1;
        player enableFatigue true;
        AP_blackLace_effect = 0;
        AP_fatigueEnabled = true;};
    [] spawn {
        "ColorInversion"
        ppEffectEnable true;
        "ColorInversion"
        ppEffectAdjust[AP_drug_level / 5, 0, AP_drug_level / 5];
        "ColorInversion"
        ppEffectCommit 1;
        "chromAberration"
        ppEffectEnable true;
        "chromAberration"
        ppEffectAdjust[AP_drug_level / 10, AP_drug_level / 10, true];
        "chromAberration"
        ppEffectCommit 1;
        uiSleep 2.25;
        while {alive player && ((time - AP_blackLace_effect) < (4 * 60))}
        do {
            "ColorInversion"
            ppEffectEnable true;
            "ColorInversion"
            ppEffectAdjust[AP_drug_level / 5, 0, AP_drug_level / 5];
            "ColorInversion"
            ppEffectCommit 1;
            "chromAberration"
            ppEffectEnable true;
            "chromAberration"
            ppEffectAdjust[AP_drug_level / 10, AP_drug_level / 10, true];
            "chromAberration"
            ppEffectCommit 1;
            uiSleep 2;};
        "chromAberration" ppEffectEnable false;
        "ColorInversion"
        ppEffectEnable false;
        AP_blackLace_effect = 0;};} else {AP_blackLace_effect = time;};
systemChat "You feel incredible!";
[] call AP_fnc_hudUpdate;
["blacklace"] call AP_fnc_drugUsed;