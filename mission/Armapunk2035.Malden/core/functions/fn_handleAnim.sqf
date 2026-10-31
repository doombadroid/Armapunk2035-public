params[["_animation", "", [""]], ["_delay", 0, [0]], ["_moveType", "", [""]], ["_player", objNull, [objNull]]];
private _moveType =
if (_moveType isEqualTo "") then {"playMoveNow"} else {_moveType};
private _player =
if (isNull _player) then {player} else {_player};
private _animationSpeed = getNumber(configfile >> "CfgMovesMaleSdr" >> "States" >> _animation >> "speed");
private _duration =
if !(_animationSpeed isEqualTo 0) then {abs(1 / _animationSpeed)} else {0};
private _exit = false;
if (_player isEqualTo player) then {if (player getVariable["AP_inAnim", false]) then {player setVariable["AP_inAnim", false];
        if (_moveType isEqualTo "switchMove") then {player switchMove "switchMove";} else {player playActionNow "stop";};} else {
        player setVariable["AP_inAnim", true];};
    if !(player getVariable["AP_inAnim", false]) exitWith {_exit = true};};
if (_exit) exitWith {};
switch (_moveType) do {case ("playMoveNow"): {while {
                alive player && (isNull objectParent player) && player getVariable["AP_inAnim", false]}
            do {player playMoveNow _animation;
                uiSleep(_duration * 0.9);
                if (_animation == "AinvPknlMstpSnonWnonDr_medic0" && player getVariable["AP_inAnim", false]) then {
                    player switchMove _animation};};}; case ("playMove"): {_player playMove _animation};
        case ("switchMove"): {_player switchMove "";
                _player switchMove _animation;
                if (_delay > 0 && !(AP_isDead)) then {uiSleep _delay;
                    if (isNull objectParent player) then {_player switchMove "";};};};
        case ("mimic"): {_player setMimic _animation};}; if (_player isEqualTo player) then {player setVariable["AP_inAnim", false];};