// AP_fnc_jump -- the 0.32 m running hop (+2.5 m/s vertical, 2 s AP_canJump cooldown). It cannot clear a fence.
// owner 2026-09-16: REACHED ONLY THROUGH AP_fnc_parkour now. evh/fn_keyDownHandler.sqf used to call this straight
// from the GetOver (V) key above 10 km/h; that key is the parkour entry since the parkour build, and
// AP_fnc_parkour calls this hop, always only above 10 km/h, in three cases: its probe finds nothing to
// vault/mantle/drop/wall-run (the old open-ground behaviour); any of its entry guards fails (in a dialog, carrying
// a barrel, ... -- the old binding); and the server's SRV_parkourEnabled kill switch is false (the old binding,
// verbatim). No logic here changed with that move.
if !(AP_canJump && isNull objectParent player && isTouchingGround player) exitWith {};
AP_canJump = false;
private _height = 2.5;
private _maxVel =
5.3;
private _vel = (velocity player) apply {[selectMin[_maxVel, _x], selectMax[-1 * _maxVel, _x]] select(_x < 0)};
private _dir = direction player;
private _speed = 0.4;
player setVelocity[(_vel select 0) + (sin _dir * _speed), (_vel select 1) + (cos _dir * _speed), (_vel select 2) + _height];
player switchMove "AovrPercMrunSrasWrflDf"; [
    ["AovrPercMrunSrasWrflDf", 0, "switchMove", player], "AP_fnc_handleAnim", (allPlayers select {(_x distance player) <= 30}) - [player]
] spawn AP_fnc_MP;
[] spawn {uiSleep 2;
    AP_canJump = true;};