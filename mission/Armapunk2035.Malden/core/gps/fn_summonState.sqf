/*
    AP_fnc_summonState  (client, from the server) -- SUMMON VEHICLE progress.
    Merges the server's hashmap into AP_summonState, pushes the deck's `summon`
    channel when the phone is open, and says the milestones in chat.
*/
params [["_in", createHashMap, [createHashMap]]];
if (remoteExecutedOwner isNotEqualTo 2 && {remoteExecutedOwner isNotEqualTo 0}) exitWith {};
private _st = missionNamespace getVariable ["AP_summonState", createHashMapFromArray [["state", "idle"], ["msg", ""], ["dist", 0], ["eta", 0], ["cooldown", 0], ["info", createHashMap]]];
{ _st set [_x, _in get _x]; } forEach keys _in;
AP_summonState = _st;

private _state = _st getOrDefault ["state", "idle"];
private _msg = _st getOrDefault ["msg", ""];
if (_state in ["arrived", "failed"] && {_msg isNotEqualTo ""}) then {
    [format ["<t color='#54b0ff'>SUMMON:</t> %1", _msg], "basic"] spawn AP_fnc_handleMessage;
};
private _disp = findDisplay 937500;
if (!isNull _disp) then {
    private _c = _disp displayCtrl 937501;
    if (!isNull _c) then { [_c, "summon", _st] call webui_fnc_push; };
};
