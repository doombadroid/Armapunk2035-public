private _preAchieve = str AP_achievements;
private _preTitle = player getVariable["AP_prefix", ""];
private _removedAchievements = [37]; {_x params[["_id", -1, [0]], ["_sides", [civilian, west, independent], [[]]
    ], ["_title", "", [""]], ["_condition", {false}, [{}]]];
    if ((_id in _removedAchievements) && (_id in AP_achievements)) then {AP_achievements deleteAt(AP_achievements find _id);
        if (_title isEqualTo _preTitle) then {player setVariable["AP_prefix", nil, true];
            [15] call AP_fnc_ClupdatePartial;};};
    if !(_id in AP_achievements) then {if (AP_effSide in _sides && (call _condition)) then {AP_achievements pushBack _id;
            ["Achievement", [format["Achievement Unlocked: %1", _title]]] call BIS_fnc_showNotification;};} else {
        if (AP_effSide in _sides && (!(call _condition) && !(_condition isEqualTo {false}))) then {
            AP_achievements deleteAt(AP_achievements find _id);
            if (player getVariable["AP_prefix", ""] isEqualTo _title) then {player setVariable["AP_prefix", nil, true];
                if (player getVariable["AP_prefix", ""] isNotEqualTo _preTitle) then {[15] call AP_fnc_ClupdatePartial;};};};};}
forEach (localNamespace getVariable "AP_achievementInfo");
private _postAchieve = str AP_achievements;
if (_preAchieve isNotEqualTo _postAchieve) then {[7] call AP_fnc_ClupdatePartial;};