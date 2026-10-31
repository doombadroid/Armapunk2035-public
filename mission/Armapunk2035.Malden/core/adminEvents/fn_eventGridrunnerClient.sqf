/*
    fn_eventGridrunnerClient.sqf  (LooneyBin -- ported from A1013 reference + scrubbed 2026-06-28)
    Admin event mode 7: GRIDRUNNER -- a self-contained parkour mini-game at Kavala BH (loc 1000).
    Joined via the civilian event key (keyUpHandler dispatch on AP_adminEvent select 2 == 7). Space =
    a boosted jump (on cooldown); the 7 key teleports back to the last activated checkpoint. Leaving the
    280m area -- or the event ending (select 2 != 7) -- removes the key handlers and drops participation.

    Cross-scope state is shared through AP_sj* globals ON PURPOSE: the display KeyUp/KeyDown handlers run
    in their own VM scope (string-compiled) and the area watcher is a separate spawn, neither of which
    inherits caller `private`s -- so these cannot be locals. The genuinely-local handles are kept local.
    AP_gridrunnerCD is the jump/teleport cooldown -- a DEDICATED var, deliberately NOT the shared knife
    cooldown global (reusing that would scramble the knife timer).
*/
if (isRemoteExecuted && {remoteExecutedOwner != 2}) exitWith {};   // server-origin only: CfgRE allowedTargets limits the target, never the sender
if (AP_adminEvent select 1) exitWith {["You cannot join the admin event in progress.", "basic"] spawn AP_fnc_handleMessage;};
if (player getVariable["AP_downed", false] || player getVariable["AP_restrained", false] || ((AP_is_arrested param [0,0]) isEqualTo 1)) exitWith {
    ["You cannot join the admin event at this time.", "basic"] spawn AP_fnc_handleMessage;}; [
    [true, player], "APS_fnc_eventParticipants", 2] spawn AP_fnc_MP;
AP_inEvent = true;
if !(isNull objectParent player) then {moveOut player;};
if ((player getVariable['AP_restrained', false])) exitWith {hint 'CANT JOIN WHILE RESTRAINED';};
if ((AP_is_arrested param [0,0]) isEqualTo 1) exitWith {titleText[format['CANT JOIN FROM JAIL'], 'PLAIN DOWN', 2];};
if (player getVariable['AP_downed', false]) exitWith {hint 'CANT JOIN WHILE DOWNED';};
playSound "racebeep1";
sleep 1;
playSound "racebeep1";
sleep 1;
playSound "racebeep2";
waituntil {!(IsNull(findDisplay 46))};
player setPos[5465.98, 14997, 0];
player allowdammage false;
if (isNil "AP_gridrunnerCD") then { AP_gridrunnerCD = -200; };
AP_sjJumpEH = (findDisplay 46) displayAddEventHandler['KeyUp', '
	if (_this select 1 isEqualTo 57) then {
		if ((AP_adminEvent select 2) != 7) exitWith { (findDisplay 46) displayRemoveEventHandler ["KeyUp", _thisEventHandler]; };
		if (AP_gridrunnerCD > time - 3.5) exitWith {hint AP_sjText1};
		AP_gridrunnerCD = time;
		_vel = velocity player;
		_dir = direction player;
		_speed = 2.4;
		vehicle player setVelocity [
			(_vel select 0) + (sin _dir * _speed),
			(_vel select 1) + (cos _dir * _speed),
			14
		];
		hint AP_sjText2;
	}
'];
AP_sjParkourEH = (findDisplay 46) displayAddEventHandler["KeyDown", "
	if (_this select 1 isEqualTo 8) then {
		(findDisplay 46) displayRemoveEventHandler ['KeyDown', AP_sjParkourEH];
		playSound 'bombarm';
		player allowdammage false;
		player setDamage 0;[0] spawn AP_fnc_setPain;
		APV_hunger = 100;
		APV_thirst = 100;
		hint '\n\n SPACE TO JUMP! \n\n 7 KEY TO LOAD CHECKPOINT \n\n YOU CAN LEAVE THE EVENT AT ANY TIME BY LEAVING THE AREA';
		if(isNil 'AP_sjParkGame') then {AP_sjParkGame = 0};
		AP_sjText1 = 'ON COOLDOWN press 7 key to load checkpoint';
		AP_sjText2 = '';
		AP_sjText3 = 'YOU DID NOT ACTIVATE ANY CHECKPOINTS YET';
		AP_sjText4 = 'TELEPORTING TO LAST CHECKPOINT';
	}
"];
private _checkptKEY = (findDisplay 46) displayAddEventHandler['KeyUp', '
	if (_this select 1 isEqualTo 8) then {
		if ((AP_adminEvent select 2) != 7) exitWith { (findDisplay 46) displayRemoveEventHandler ["KeyUp", _thisEventHandler]; };
		[] spawn {
			if (AP_gridrunnerCD > time - 3.5) exitWith {hint AP_sjText1};
			AP_gridrunnerCD = time;

			hint AP_sjText4;
			sleep 3;
			switch (AP_sjParkGame) do {
				case 0: {hint AP_sjText3};
				case 1: {_spwnposNew = [([5503.64, 15030.3, 46]),random 4,0] call BIS_fnc_relPos; vehicle player setPos _spwnposNew};
				case 2: {_spwnposNew = [([5479.16, 15001.7, 60]),random 3,0] call BIS_fnc_relPos; vehicle player setPos _spwnposNew};
				case 3: {_spwnposNew = [([5473.86, 15068.5, 92]),random 4,0] call BIS_fnc_relPos; vehicle player setPos _spwnposNew};
				case 4: {_spwnposNew = [([5476.88, 14919.2, 125]),random 4,0] call BIS_fnc_relPos; vehicle player setPos _spwnposNew};
			};
		};
	};
'];
[] spawn {while {true}
    do {waitUntil {sleep 10;
            (player distance[5465.98, 14997, 0] > 280) || ((AP_adminEvent select 2) != 7)};
        player allowdammage true;
        private _leftEvent = 1;
        if (_leftEvent isEqualTo 1) exitWith {hint 'LEFT EVENT AREA LEFT EVENT AREA LEFT EVENT AREA';
            (findDisplay 46) displayRemoveEventHandler['KeyDown', AP_sjParkourEH];
            (findDisplay 46) displayRemoveEventHandler['KeyUp', AP_sjJumpEH]; [
                [false, player], "APS_fnc_eventParticipants", 2] spawn AP_fnc_MP;
            AP_inEvent = false;};};};
