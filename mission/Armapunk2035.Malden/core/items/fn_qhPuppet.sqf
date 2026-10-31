// Altis Life game mechanic — fictional in-game "quickhack" ability, game logic only.
/*
    File: fn_qhPuppet.sqf  (AP_fnc_qhPuppet)
    LooneyBin 2026-07-21 (v3, owner-chosen "seat + decoy"): PUPPET STRINGS -- the apex hijack, HACKER side.
    The server has already SEATED the hacker in the target car's driver seat, so from here the hacker drives
    with the game's NATIVE PhysX (smooth -- the old setVelocity override fought the suspension and felt janky),
    and a slumped DECOY "meat body" is standing at the cast spot (server-owned). This client only SUPERVISES:
      * governor -- caps top speed with limitSpeed (native, no jank),
      * Asimov lock -- crawls the speed cap toward water / a >8m drop / a person, so you can't plow through,
      * battery countdown + HUD + X to jack out, and the end conditions (thrown from seat / body hit / battery).
    Ending sets AP_puppetActive false; the SERVER then pulls the hacker out, snaps them back to the decoy's
    spot, deletes the decoy, and hands the wheel back to any bumped victim.

      [_veh, _dur]
*/
if (isRemoteExecuted && {remoteExecutedOwner != 2}) exitWith {};   // server-origin only: CfgRE allowedTargets limits the target, never the sender
params [["_veh", objNull, [objNull]], ["_dur", 50, [0]], ["_origin", [0,0,0], [[]]]];
if (!hasInterface) exitWith {};
if (isNull _veh) exitWith {};

disableSerialization;
private _cap = ((getNumber (configOf _veh >> "maxSpeed")) * 0.6) min 70;        // km/h governor -- controllable

// X = jack out (do NOT consume other keys -- native driving needs W/A/S/D)
AP_puppetEnd = false;
private _eh = (findDisplay 46) displayAddEventHandler ["KeyDown", {params ["", "_dik"];
    if (_dik isEqualTo 45) then { missionNamespace setVariable ["AP_puppetEnd", true]; };   // X
    false}];

[_veh, _dur, _cap, _eh, _origin] spawn {params ["_veh", "_dur", "_cap", "_eh", "_origin"];
    // ★ SEAT HERE, not on the server: moveInDriver must run where the UNIT is local, and a player is local to
    // their OWN client -- the server's moveInDriver did nothing (that was the "JACK-IN FAILED" bug). Forcing
    // the driver seat also ejects any current occupant, so an occupied car's victim is bumped out here.
    player moveInDriver _veh;
    private _seatT = time + 5;
    waitUntil { uiSleep 0.1; ((driver _veh) isEqualTo player) || {isNull _veh} || {!alive player} || {time > _seatT} };
    if (isNull _veh || {(driver _veh) isNotEqualTo player}) exitWith {(findDisplay 46) displayRemoveEventHandler ["KeyDown", _eh];
        AP_puppetEnd = nil;
        if (!isNull _veh) then { _veh setVariable ["AP_puppetActive", false, true]; };
        ["<t color='#ff3b1e'>JACK-IN FAILED</t> -- couldn't take the seat. Try again.", "basic"] spawn AP_fnc_handleMessage;};
    // invisible driver: your body is the decoy back at the cast spot, so the car reads as driverless to
    // everyone. hideObjectGlobal must run where the unit is LOCAL -- the player is local to this client, so
    // running it here hides them globally. Undone in teardown.
    player hideObjectGlobal true;
    private _end = time + _dur;                                             // battery starts once we're actually seated
    private _dmg0 = damage player;
    private _reason = "";
    while { _reason isEqualTo "" && {!isNull _veh} && {_veh getVariable ["AP_puppetActive", false]} } do {
        if (!alive player) exitWith { _reason = "DEAD"; };
        if ((driver _veh) isNotEqualTo player) exitWith { _reason = "you were thrown from the seat"; };
        if ((damage player) > (_dmg0 + 0.02)) exitWith { _reason = "your body took a hit"; };
        if (AP_puppetEnd) exitWith { _reason = "you jacked out"; };
        if (time > _end) exitWith { _reason = "the hijack battery drained"; };

        // ---- ASIMOV LOCK via the speed cap: crawl toward a hazard rather than force-braking (which re-adds jank) ----
        private _spd = speed _veh;                                          // km/h
        private _look = (((abs _spd) / 3.6) * 1.6) max 6;
        private _fw = (getPosATL _veh) vectorAdd ((vectorDir _veh) vectorMultiply _look);
        private _hazard = surfaceIsWater _fw;
        if (!_hazard) then {
            private _dz = (getTerrainHeightASL [_fw select 0, _fw select 1]) - (getTerrainHeightASL [(getPosATL _veh) select 0, (getPosATL _veh) select 1]);
            if (_dz < -8) then { _hazard = true; };};
        if (!_hazard && {(abs _spd) > 20}) then {
            if (((_fw nearEntities ["CAManBase", 6]) select { alive _x && {isNull objectParent _x} && {_x isNotEqualTo player} }) isNotEqualTo []) then { _hazard = true; };
        };
        _veh limitSpeed (if (_hazard) then { 4 } else { _cap });

        titleText [format ["JACKED IN  --  %1s left\nDrive it · X: jack out%2", ceil (_end - time),
            (if (_hazard) then { "\n<t color='#ff3b30'>SAFETY GOVERNOR: hazard ahead</t>" } else { "" })], "PLAIN DOWN"];
        uiSleep 0.1;};

    // ---- teardown (this client): release the governor, get OUT of the seat and snap back to the body's spot.
    // moveOut / setPos run here because the player is local to this client (the server can't move them). The
    // server manager just deletes the decoy once it sees AP_puppetActive go false. ----
    (findDisplay 46) displayRemoveEventHandler ["KeyDown", _eh];
    AP_puppetEnd = nil;
    titleText ["", "PLAIN"];
    player hideObjectGlobal false;                                        // visible again -- back in your body
    if (!isNull _veh) then {_veh limitSpeed -1;                                                // lift the speed cap (engine "no limit")
        if (player in (crew _veh)) then { moveOut player; };};
    if (alive player) then { player setPosATL _origin; };                 // consciousness returns to the meat body
    if (!isNull _veh) then { _veh setVariable ["AP_puppetActive", false, true]; };   // -> server deletes the decoy
    if (_reason isEqualTo "DEAD") exitWith {};                             // dead men get no toast
    private _msg = if (_reason isEqualTo "you jacked out") then {"<t color='#c9e21a'>JACKED OUT</t> -- you're back in your body."} else {
        format ["<t color='#ff3b1e'>LINK LOST</t> -- %1. You're back in your body.", _reason]};
    [_msg, "basic"] spawn AP_fnc_handleMessage;};
