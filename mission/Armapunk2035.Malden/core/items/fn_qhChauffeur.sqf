// Altis Life game mechanic — fictional in-game "quickhack" ability, game logic only.
/*
    File: fn_qhChauffeur.sqf  (AP_fnc_qhChauffeur)
    LooneyBin 2026-07-21: CHAUFFEUR OVERRIDE -- the VICTIM side. The server (APS_fnc_qhSRV "chauffeur") picked
    this client because it is the driver, and the car is LOCAL here -- so this is where the drive actually runs.
    The hacker never gets the wheel: the autopilot (AP_fnc_hcDrive, the proven driverless physics drive) takes
    the car to the hacker's destination, and the victim's only levers are:
      * WRESTLE  -- holding any movement input drains the hijack battery ~3x faster (ends it sooner).
      * KILL SWITCH (X) -- yank the fuse: stops the car and stalls the engine 15s. Dead now vs kidnapped later.
      * BAIL OUT -- just get out. The hacker CANNOT lock the doors, so this always works.
    Extra occupants fighting add drain too (lone drivers soft, convoys hard). The server owns the 300m link leash
    and pushes AP_chauffeurAbort if the hacker falls out of range.

      [_dest, _hacker, _battery]
*/
if (isRemoteExecuted && {remoteExecutedOwner != 2}) exitWith {};   // server-origin only: CfgRE allowedTargets limits the target, never the sender
params [["_dest", [0,0,0], [[]]], ["_hacker", objNull, [objNull]], ["_battery", 60, [0]]];
if (!hasInterface) exitWith {};
private _veh = vehicle player;
if (_veh isEqualTo player || {(driver _veh) isNotEqualTo player}) exitWith {};   // only the seated driver is chauffeured
if (!local _veh) exitWith {};
if (_veh getVariable ["AP_chauffeurRunning", false]) exitWith {};              // already hijacked
_veh setVariable ["AP_chauffeurRunning", true, false];

playSound "FD_Start_F";
["<t color='#ff3b1e' size='1.35'>AUTOPILOT COMPROMISED</t><br/>Someone has your drivetrain. Fight it, cut the fuse (X), or bail out.", "basic"] spawn AP_fnc_handleMessage;

// local destination marker so the victim sees where they are being taken
private _mk = createMarkerLocal [format ["AP_chauf_%1", floor diag_tickTime], _dest];
_mk setMarkerTypeLocal "mil_destroy";
_mk setMarkerColorLocal "ColorRed";
_mk setMarkerTextLocal "TAKEN HERE";

// mechanical kill switch: any press of the X key yanks the fuse. Registered on the mission display, cleared on end.
AP_chauffeurKill = false;
private _disp = findDisplay 46;
private _eh = _disp displayAddEventHandler ["KeyDown", {params ["", "_dik"];
    if (_dik isEqualTo 45) then { missionNamespace setVariable ["AP_chauffeurKill", true]; };   // DIK 0x2D = X
    false}];

// Engage the SAME seated-drive a driverless-cab feature once used (owner's suggestion 2026-07-21): flag the car chauffeured
// (gates the victim's input in fn_gpsAutopilot the same way), plot the route to the hacker's
// destination on this client, then start the proven physics autopilot. This is the drive that is already
// tested with a live player in the seat and networks smoothly -- unlike hcDrive, which was built driverless.
private _prevDest = missionNamespace getVariable ["AP_gpsDest", []];             // restore the victim's own nav after
_veh setVariable ["AP_chauffeured", true, true];
["set", _dest] call AP_fnc_gps;                                                // plot from the car's position
uiSleep 0.4;
["start", "normal"] call AP_fnc_gpsAutopilot;                                  // input gated via AP_chauffeured
uiSleep 0.6;
private _ok = missionNamespace getVariable ["AP_gpsAP", false];                 // did the autopilot actually take?

[_veh, _hacker, _battery, _eh, _mk, _ok, _prevDest] spawn {params ["_veh", "_hacker", "_batMax", "_eh", "_mk", "_ok", "_prevDest"];
    private _bat = _batMax;
    private _dt = 0.2;
    private _reason = if (_ok) then { "" } else { "the autopilot wouldn't take the wheel"; };
    while { _reason isEqualTo "" } do {if (isNull _veh || {!alive _veh}) exitWith { _reason = "the vehicle is gone"; };
        if ((driver _veh) isNotEqualTo player) exitWith { _reason = "you bailed out"; };
        if (AP_chauffeurKill) exitWith { _reason = "KILL"; };
        if ((_veh getVariable ["AP_chauffeurAbort", 0]) > 0) exitWith { _reason = "the link dropped -- they lost you"; };
        // the autopilot disengaged for one of ITS own reasons (arrived / route ended / damaged / out of fuel)
        if !(missionNamespace getVariable ["AP_gpsAP", false]) exitWith { _reason = "ARRIVED"; };

        // WRESTLE: any movement input drains ~3x. Each extra player in the car adds half a share of drain.
        private _wrestle = (inputAction "carForward" > 0) || {inputAction "carBack" > 0} || {inputAction "carLeft" > 0}
            || {inputAction "carRight" > 0} || {inputAction "carFastForward" > 0};
        private _extra = (({isPlayer _x} count (crew _veh)) - 1) max 0;
        // CO-PILOT GUARDIAN: a stamped car fights on its own -- doubles the base drain even when you sit still.
        private _coPilot = if (_veh getVariable ["AP_coPilot", false]) then { 2 } else { 1 };
        private _mult = (if (_wrestle) then { 3 } else { _coPilot }) * (1 + (0.5 * _extra));
        _bat = _bat - (_dt * _mult);
        if (_bat <= 0) exitWith { _reason = "the hijack battery drained"; };

        private _pct = round ((_bat / _batMax) * 100);
        titleText [format ["AUTOPILOT COMPROMISED  --  hijack battery %1%2\n%3   [X: cut the fuse]",
            _pct, "%", (if (_wrestle) then { "you're fighting it down FAST" } else { "hold movement to fight it" })], "PLAIN DOWN"];
        uiSleep _dt;};

    // ---- teardown: always release the car and clean up, whatever ended it ----
    (findDisplay 46) displayRemoveEventHandler ["KeyDown", _eh];
    deleteMarkerLocal _mk;
    AP_chauffeurKill = nil;
    // disengage the autopilot if it is still running (arrival/damage already stopped it themselves). Clearing
    // AP_chauffeured hands input control back to the victim -- from here the car is theirs again.
    if (missionNamespace getVariable ["AP_gpsAP", false]) then { ["stop", ""] call AP_fnc_gpsAutopilot; };
    _veh setVariable ["AP_chauffeured", nil, true];
    if (!isNull _veh) then {_veh setVariable ["AP_chauffeurActive", false, true];
        _veh setVariable ["AP_chauffeurRunning", false, false];};
    // restore the victim's own GPS destination (the hijack overwrote it to plot the kidnap route)
    if (_prevDest isEqualTo []) then { AP_gpsDest = []; } else { ["set", _prevDest] call AP_fnc_gps; };
    titleText ["", "PLAIN"];

    // KILL SWITCH: stop dead + stall the engine for 15s (keeps blocking a restart the whole time). Local to the
    // victim's car -- the same "fried engine" feel as the ignition hack, done client-side because it's the
    // victim's own choice on their own local vehicle.
    if (_reason isEqualTo "KILL") then {
        ["<t color='#c9e21a'>FUSE CUT</t> -- engine dead. It'll be 15 seconds before it turns over.", "basic"] spawn AP_fnc_handleMessage;
        if (!isNull _veh && {local _veh}) then {[_veh] spawn {params ["_v"];
                private _end = time + 15;
                while { !isNull _v && {alive _v} && {time < _end} } do {if (isEngineOn _v) then { _v engineOn false; };
                    _v setVelocityModelSpace [(velocityModelSpace _v select 0) * 0.7, (velocityModelSpace _v select 1) * 0.5, velocityModelSpace _v select 2];
                    uiSleep 0.25;};};};} else {private _msg = switch (_reason) do {
            case "ARRIVED": { "<t color='#ff3b1e'>YOU'VE BEEN DELIVERED</t> -- the car stopped where they wanted you." };
            case "you bailed out": { "<t color='#c9e21a'>YOU BAILED</t> -- out of the car, off the hook." };
            default { format ["<t color='#c9e21a'>AUTOPILOT RELEASED</t> -- %1.", _reason] };};
        [_msg, "basic"] spawn AP_fnc_handleMessage;};};
