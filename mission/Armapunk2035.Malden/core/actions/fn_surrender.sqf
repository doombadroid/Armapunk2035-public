if (player getVariable["AP_escorting", false] || player getVariable["AP_restrained", false]) exitWith {};
if (speed player > 1 || player getVariable["AP_downed", false]) exitWith {};
if !(isNull objectParent player) exitWith {};
if (player getVariable["AP_surrendered", false]) then {player setVariable["AP_surrendered", false, true]} else {
    player setVariable["AP_surrendered", true, true];};
waitUntil {player playMove "AmovPercMstpSnonWnonDnon_AmovPercMstpSsurWnonDnon";
    if (player getVariable["AP_downed", false] || !(alive player)) exitWith {player setVariable["AP_surrendered", false, true];
        true;};
    !(player getVariable["AP_surrendered", false]);};
player playMoveNow "AmovPercMstpSsurWnonDnon_AmovPercMstpSnonWnonDnon";