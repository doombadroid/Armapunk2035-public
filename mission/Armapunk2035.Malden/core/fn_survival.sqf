private _fnc_food = {if (isNull(findDisplay 38500) && !(player getVariable["AP_restrained", false])) then {private _change =
        switch (true) do {case (61 in AP_side_talents): {3};
            case (90 in AP_side_talents): {5};
            case (89 in AP_side_talents): {7};
            default {10};}; APV_hunger = selectMax[APV_hunger - (floor _change), 0];
        [] call AP_fnc_hudUpdate;
        switch (APV_hunger) do {case 30: {
                    ["You haven't eaten anything in awhile. You should find something to eat soon!", "basic"] spawn AP_fnc_handleMessage
                };
            case 20: {["You are starting to starve, you need to find something to eat.", "basic"] spawn AP_fnc_handleMessage};
            case 10: {["You are now starving, you must eat something", "basic"] spawn AP_fnc_handleMessage;
                    player setFatigue 1};};};};
private _fnc_water = {if (isNull(findDisplay 38500) && !(player getVariable["AP_restrained", false])) then {private _change =
        switch (true) do {case (61 in AP_side_talents): {3};
            case (90 in AP_side_talents): {5};
            case (89 in AP_side_talents): {7};
            default {10};}; APV_thirst = selectMax[APV_thirst - (floor _change), 0];
        [] call AP_fnc_hudUpdate;
        switch (APV_thirst) do {case 30: {
                    ["You haven't had anything to drink in a while. You should find something to drink soon.", "basic"] spawn AP_fnc_handleMessage
                };
            case 20: {
                    ["You haven't had anything to drink in a long time. You should find something to drink soon.", "basic"] spawn AP_fnc_handleMessage;
                    player setFatigue 1};
            case 10: {
                    ["You are now suffering from severe dehydration find something to drink quickly!", "basic"] spawn AP_fnc_handleMessage;
                    player setFatigue 1};};};};
private _fnc_regen = {
    // PR13: the SAME seven clauses, evaluated ONCE and published, so the web HUD's REGEN+ chip
    // (core\web\fn_hudWebPush.sqf) reads the real regen state instead of carrying a second copy
    // of this predicate that would drift the first time one clause here changes. The condition
    // and the body below are otherwise untouched -- this adds an assignment and reads it back.
    AP_regenActive = (APV_thirst >= 75 && {APV_hunger >= 75} && {damage player > 0} && {damage player <= 0.25} && {
        player getHit "legs" < 0.5} && {!(player getVariable["AP_downed", false])} && {
        time > (player getVariable["AP_can_revive", -1000])} && {!([player] call AP_fnc_healBlocked)});
    if (AP_regenActive) then {private _plb_dmg = player;
        _plb_dmg setDamage(damage player - 0.01);};};
[] spawn {private _oldDamage = 0;
    private _canRevive = 0;
    private _plb_dmg = player;
    for "_i"
    from 0 to 1 step 0 do {_oldDamage = damage player;
        _canRevive = player getVariable["AP_can_revive", 0];
        waitUntil {uiSleep 1;
            (_oldDamage != damage player) || _canRevive != (player getVariable["AP_can_revive", 0]) || (player getVariable["AP_can_revive", -1000]) > serverTime
        };
        if (damage player < 0.25 && ((player getVariable["AP_can_revive", -1000]) > time)) then {_plb_dmg setDamage 0.25};
        if ((player getVariable["AP_can_revive", -1000]) > time) then {[] call AP_fnc_hudUpdate;};};};
[] spawn {waitUntil {AP_session_completed};
    player setCustomAimCoef 0.25; {  // LoonyBin: default weapon sway reduced 75% vs vanilla (was 0.7)
        private _new = _x;
        if (_new > 0) then {_new = selectMax[0, _new - 0.02];
            AP_addiction set[_forEachIndex, _new]; (switch AP_effSide do {case civilian: {["AP_addictionCiv", "AP_drugsUsedCiv"]};
                case west: {["AP_addictionCop", "AP_drugsUsedCop"]};
                case independent: {["AP_addictionMedic", "AP_drugsUsedMedic"]};
                default {["", ""]};}) params["_addictionVariable", "_drugsUsedVariable"];
            if !(_addictionVariable isEqualTo "") then {profileNamespace setVariable[_addictionVariable, AP_addiction];};
            if (_new > 0 && (abs(time - (AP_used_drug select _forEachIndex))) > 600) then {switch (true) do {case (_new > 0.9): {
                            systemChat "You feel shakey and anxious! You need a fix!";
                            if !(AP_drug_withdrawl) then {[] spawn {while {AP_drug_withdrawl}
                                    do {resetCamShake;
                                        addCamShake[1, 4, 10];
                                        uiSleep 3.5;}; resetCamShake ;};};
                            AP_drug_withdrawl = true;};
                    case (_new > 0.6): {systemChat "Getting high occupies all of your thoughts.";
                            AP_drug_withdrawl = false;};
                    case (_new > 0.4): {systemChat "You are craving a high.";
                            AP_drug_withdrawl = false;};};};};}
    forEach AP_addiction;
    uiSleep 240;
    AP_drug_level = selectMax[0, AP_drug_level - 0.05];};
private _fnc_check = {[] spawn AP_fnc_calWeight;};
private _load = 0;
private _foodTime = time;
private _waterTime = time;
private _checkTime = time;
private _regenTime = time;
private _walkDis = 0;
private _lastPos = visiblePosition player;
private _curPos = visiblePosition player;
_lastPos = (_lastPos select 0) + (_lastPos select 1);
for "_i"
from 0 to 1 step 0 do {
    // owner 2026-06-20: STAMINA REMOVED server-wide -> enforce enableStamina false on the current player unit every
    // tick. Sticky per-unit, but re-applied here so it survives respawns + overrides any stray re-enable. The "can't
    // sprint" penalties (over-weight / gold bar / starving / dehydrated) are kept below via forceWalk, NOT fatigue.
    player enableStamina false;
    if ((time - _waterTime) > 750) then {[] call _fnc_water;
        _waterTime = time};
    if ((time - _foodTime) > 900) then {[] call _fnc_food;
        _foodTime = time};
    if ((time - _checkTime) > 50) then {[] call _fnc_check;
        _checkTime = time};
    if ((time - _regenTime) > 5) then {[] call _fnc_regen;
        _regenTime = time};
    if (AP_effSide isEqualTo civilian) then {if (backpack player isEqualTo "") then {AP_maxWeight = 64;} else {
            private _cfg = getNumber(configFile >> "CfgVehicles" >> backpack player >> "maximumload");
            _load = round(_cfg / 10);
            AP_maxWeight = 64 + _load;
            if ("Carryall" in (backpack player)) then {AP_maxWeight = 96;};};
        // BLUE COLLAR talents: +24 base carry (220 Blue Collar), +12 more with Mule Team (224). Recomputed each tick so it sticks.
        if (220 in AP_side_talents) then { AP_maxWeight = AP_maxWeight + 24; };
        if (224 in AP_side_talents) then { AP_maxWeight = AP_maxWeight + 12; };};
    // owner 2026-06-20: stamina is gone (enableStamina false above), so the old fatigue-based "can't sprint"
    // penalties are re-done as forceWalk (which is independent of stamina): over carry-weight OR carrying a gold bar
    // OR fully starved/dehydrated -> forced to WALK. Skipped while arrested (handled elsewhere). forceWalk is lifted
    // only when NONE apply (and not holding a barrel). Replaces the old setFatigue/enableFatigue calls (now no-ops).
    // MULE TEAM (224): gold bars no longer force a walk -- haul them at a full run.
    // owner 2026-07-21: Synapse Drag quickhack (fn_qhEffect) drops a timer here so the SAME gold-bar forceWalk
    // nerf applies for its duration and the survival loop stays the single owner of forceWalk (no fighting).
    private _penaltyWalk = (AP_carryWeight > AP_maxWeight) || (AP_inv_goldbar > 0 && {!(224 in AP_side_talents)}) || (APV_thirst <= 0) || (APV_hunger <= 0) || (diag_tickTime < (missionNamespace getVariable ["AP_qhSynapseUntil", 0]));
    // LooneyBin #525 ("walked into water and died"): NEVER forceWalk a player who is in/over water. The
    // stamina-removal rework (owner 2026-06-20) replaced the old setFatigue penalty with `forceWalk true`,
    // but a force-walked unit CANNOT swim -- it stays in a walk stance, so on entering water it sinks to the
    // bottom and drowns (engine native, no oxygen script exists). A player who is over carry-weight / holding
    // a gold bar / fully starved or dehydrated and walks into water was instakilled. Over water we skip the
    // penalty AND actively lift any existing forceWalk so they can surface/swim out. The walk penalty is a
    // land-movement nerf only; it does not need to (and must not) apply while swimming.
    private _inWater = surfaceIsWater (getPosASL player);
    if (_penaltyWalk && {(AP_is_arrested param [0,0]) isEqualTo 0} && {!_inWater}) then {player forceWalk true;
        if ((AP_carryWeight > AP_maxWeight) && {(time - AP_last_sold) > 10}) then {
            ["You are over carrying your max weight! You will not be able to run or move fast till you drop some items!", "basic"] spawn AP_fnc_handleMessage;
            AP_last_sold = time;};} else {if (isForcedWalk player && {isNull AP_holding_barrel} && {_inWater || !_penaltyWalk}) then {
            player forceWalk false;};};
    if !(AP_respawned) then {_walkDis = 0;} else {_curPos = (visiblePosition player select 0) + (visiblePosition player select 1);
        if (isNull objectParent player && {!(_curPos isEqualTo _lastPos)}) then {_walkDis = _walkDis + 1;
            AP_distanceTraveledPlayer set[1, ((AP_distanceTraveledPlayer select 1) + 1)];
            if (AP_distanceTraveledPlayer select 0 < time - 300) then {
                ["distancewalked", (AP_distanceTraveledPlayer select 1)] call AP_fnc_statArrUpdate;
                AP_distanceTraveledPlayer = [time, 0];};
            if (_walkDis isEqualTo 1200) then {_walkDis = 0;
                APV_thirst = APV_thirst - 5;
                APV_hunger = APV_hunger - 5;
                [] call AP_fnc_hudUpdate;};};
        _lastPos = (visiblePosition player select 0) + (visiblePosition player select 1);};
    uiSleep 1;};