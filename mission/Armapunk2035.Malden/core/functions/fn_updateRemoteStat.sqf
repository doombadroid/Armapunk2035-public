params[["_stat", 0, [0]], ["_toAdd", 0, [0]], ["_extraNd", false, [false]], ["_arrayStats", [], [[]]], "_extra"];
if (_arrayStats isNotEqualTo[]) exitWith {{_x call AP_fnc_updateRemoteStat}
    forEach _arrayStats;};
if (AP_useStatBuffer) then { AP_astats_dirty = true; };   // singleevh.md Phase 3b: A_stats mutation -> unified flush picks it up
private _exit = false;
private _killStreakMsg = {params[["_killCount", 0, [0]], ["_killstreakType", "war", [""]]];
    if !(_killCount in [3, 5, 10, 15, 20, 25, 30]) exitWith {""};
    private _titleText =
    switch (_killCount) do {case (3): {"Triple Threat"};
        case (5): {"Bloodthirsty"};
        case (10): {"Merciless"};
        case (15): {"Ruthless"};
        case (20): {"Relentless"};
        case (25): {"Brutal"};
        case (30): {"Nuclear"};}; _titleText};
switch (_stat) do {case 1: {A_stats_civKills = A_stats_civKills + 1};
    case 2: {A_stats_warRating = A_stats_warRating + _toAdd;
            AP_gang_exp = AP_gang_exp + _toAdd;
            if (_toAdd <= 10) then {[30, true] call AP_fnc_addInfamy;};};
    case 3: {A_stats_copLethals = A_stats_copLethals + 1};
    case 4: {A_stats_warDeaths = A_stats_warDeaths + 1};
    case 5: {if (AP_effSide isNotEqualTo civilian) exitWith {_exit = true;};
            A_stats_warRating = A_stats_warRating + _toAdd;};
    case 6: {A_stats_copArrests = A_stats_copArrests + 1};
    case 7: {A_stats_civArrests = A_stats_civArrests + 1};
    case 8: {[5, _toAdd] call AP_fnc_updateRemoteStat;
            A_stats_warKills = A_stats_warKills + 1;
            private _killstreak = player getVariable["AP_warKillstreak", 0];
            player setVariable["AP_warKillstreak", _killstreak + 1, true];
            [(_killstreak + 1)] spawn _killStreakMsg;
            // NEW DRACHMA: war kill pays 0.25 ND, +0.1 on a streak kill (server credits + rate-caps;
            // the client only requests). Replaces the old 1500(+500) client-authoritative add.
            private _ndAmt = if (_extraNd) then { "0.35" } else { "0.25" };
            [_ndAmt, "warkill"] call AP_fnc_ndRequest;
            _toAdd = 1;};
    case 9: {A_stats_apbEvades = A_stats_apbEvades + 1};
    case 14: {["copkills", 1] call AP_fnc_statArrUpdate;
            if !(_extraNd) then {
                if (((getPosATL player) inPolygon AP_drugPenPoly) || ((getPosATL player) inPolygon AP_warzonePoly)) then {
                    // NEW DRACHMA: restricted-zone cop kill pays 0.25 ND (server-credited; ndSync toasts it).
                    ["0.25", "warkill"] call AP_fnc_ndRequest;};};};
    case 15: {
            _extra params[["_killedName", "", [""]], ["_isCopKill", false, [false]], ["_isWarKill", false, [false]], ["_isHeadshot", false, [false]]];
            if (_isCopKill) then {["civ_cops_headshots", 1] call AP_fnc_statArrUpdate;} else {if (_isWarKill) then {
                    ["warkill_headshots", 1] call AP_fnc_statArrUpdate;} else {["civkill_headshots", 1] call AP_fnc_statArrUpdate;};};
        };
    case 16: {_extra params[["_killedName", "", [""]], ["_isHeadshot", false, [false]], ["_isDown", false, [false]]];
            if (AP_enableKillNotifications) then {private _killType = "Killed";
                if ((random 500) <= 1) then {
                    _killType = selectRandom["Annihilated", "Terminated", "Fragged", "Destroyed", "Obliterated", "Disintegrated", "Banished"];
                };
                if (_isDown) then {_killType = "Downed"};
                private _textTitle0 = format["<t font='EtelkaNarrowMediumPro' size='1.4'>%1 %2</t>", toUpper _killType, toUpper _killedName];
                private _textTitle1 =
                if (_isHeadshot) then {format["<br/><t font='EtelkaNarrowMediumPro' color='#fb4022' size='1.2'>HEADSHOT</t>"]} else {""};
                [parseText format["%1%2", _textTitle0, _textTitle1], [0.8, 0.5, 1, 1], nil, 5, 1.3, 0] spawn BIS_fnc_textTiles;}}
}; if (A_stats_warRating < 0) then {A_stats_warRating = 0};
if (_exit) exitWith {};
if (_stat in [2, 4, 5, 6, 7, 8, 9]) then {(switch (_stat) do {case 2: {["war rating", A_stats_warRating]};
        case 4: {["war deaths", A_stats_warDeaths]};
        case 5: {["war rating", A_stats_warRating]};
        case 6: {["police arrests", A_stats_copArrests]};
        case 7: {["bounty arrests", A_stats_civArrests]};
        case 8: {["war kills", A_stats_warKills]};
        case 9: {["APB evades", A_stats_apbEvades]};
        default {["Error", 0]};}) params["_statName", "_statVar"];
    systemChat format["Your statistic for %1 has changed by %2 to %3!", _statName, _toAdd, _statVar];
    if (_stat in [4, 8, 9]) then {if (_toAdd < 0) then {
            ["StatLoss", [format["%1 decreased by %2", toUpper _statName, abs _toAdd]]] call BIS_fnc_showNotification;} else {
            if (_toAdd > 0) then {private _statText =
                switch (true) do {case (_stat isEqualTo 4): {"warDeath"};
                    case (_stat isEqualTo 8): {"warKill"};
                    default {"StatGain"};};
                [ _statText , [format["%1 increased by %2", toUpper _statName, _toAdd]]] call BIS_fnc_showNotification;};};};};
if (_stat in [2, 5]) then {A_stats_warPoints = A_stats_warPoints + _toAdd;
    player setVariable["AP_season", A_stats_warRating, true];};