/*
    AP_fnc_deathScreen -- the NATIVE death dialog's medic readout, once a second.

    Unchanged in what it displays. The eligible-responder rule it used to compute
    inline moved to AP_fnc_deathMedics, because the web death screen
    (ui\html\death.html) needs the same two numbers and a second copy of "who counts
    as a medic" is the drift that makes two screens disagree. The two format strings
    below, the 99999 = None distinction and the 1 Hz cadence are all as they were.

    This runs only on the native path: fn_onPlayerKilled spawns it beside
    createDialog "DeathScreen", and the web path pushes AP_fnc_deathState instead.

    BODY DRAG (owner 2026-09-16): while someone drags this player's body, " -- body being
    moved by <name>" is appended to the nearest-medic line, the native twin of the web
    screen's dragger status. Same reading rules as AP_fnc_deathState: attachedTo AP_corpse
    is the truth and only a LIVING CAManBase counts (a corpse left welded to a chair or
    parkour helper is not a drag); the public AP_draggedBy flag supplies the name only
    when its object IS the attached unit, else the attached unit's own `name`.
*/
disableSerialization;
private _medicsOnline = (findDisplay 7300) displayCtrl 7304;
private _medicsNear = (findDisplay 7300) displayCtrl 7305;
waitUntil {
    ([] call AP_fnc_deathMedics) params ["_online", "_nearby"];
    private _dragText = "";
    private _holder = if (isNull AP_corpse) then {objNull} else {attachedTo AP_corpse};
    if (!(isNull _holder) && {_holder isKindOf "CAManBase"} && {alive _holder}) then {
        private _db = AP_corpse getVariable ["AP_draggedBy", []];
        private _dn = "";
        if ((_db isEqualType []) && {(count _db) > 1} && {(_db select 0) isEqualTo _holder} && {(_db select 1) isEqualType ""}) then {_dn = _db select 1;};
        if (_dn isEqualTo "") then {_dn = name _holder;};
        _dragText = format [" -- body being moved by %1", _dn];
    };
    _medicsOnline ctrlSetText format["Trauma Team Online: %1", _online];
    if (_nearby isEqualTo 99999) then {_medicsNear ctrlSetText format["Nearest TT Medic: None%1", _dragText];} else {
        _medicsNear ctrlSetText format["Nearest TT Medic: %1m%2", [(round _nearby)] call AP_fnc_numberText, _dragText];};
    uiSleep 1;
    (isNull(findDisplay 7300))};
