/*
    AP_fnc_loonyBin  --  CLIENT half of the Loony Bin heist (Malden rework, owner spec 2026-08-01).
    Server: APS_fnc_loonyBinSRV. Scene mirror: AP_fnc_lbScene. Actions: core/fn_setupActions.sqf.

    Every case here is FEEDBACK plus a minigame; the server re-validates all of it (caller identity
    from remoteExecutedOwner, distance to the prop, phase order, cop count, cooldowns). Nothing in
    this file is a security boundary -- it exists so a player learns why an action refused before
    they burn a two-minute minigame on it.

    The props are client-local mapData objects that exist HERE and nowhere on the server, so we send
    the STEP, never the object. Proximity is tested with AP_fnc_lbAt on BOTH sides: these props are
    placed with setPosWorld, and mixing that frame with a unit's AGL position reads ~28 m at
    point-blank range. cursorObject is deliberately NOT used to gate the actions -- most of these
    props are simple objects and aiming at them exactly is a scavenger hunt. See fn_lbScene's header.
*/
params [["_caseType", "", [""]], ["_data", [], [[]]]];

private _st = { missionNamespace getVariable ["AP_lbState", [false, 0, false, 0, false, false, false, false]] };
private _msg = { params ["_t"]; [_t, "basic"] spawn AP_fnc_handleMessage; };

switch (_caseType) do {

    // ── STEP 1: Sequence-Breach the explosives on the bomb trolley ──────────────────────────────
    case "lbTrolley": {
        if (AP_action_in_use) exitWith {};
        if !(AP_effSide isEqualTo civilian) exitWith {};
        if !(call AP_fnc_hasDeck) exitWith { ["You need a Cyberdeck to slice the detonator!"] call _msg; };
        if ((primaryWeapon player) isEqualTo "") exitWith { ["You'll need a bigger gun to pull this off..."] call _msg; };
        if ((call _st) param [0, false]) exitWith { ["The Loony Bin gates have already been blown!"] call _msg; };
        if ((call _st) param [7, false]) exitWith { ["That charge is already fizzing -- get clear!"] call _msg; };
        if !([SRV_loonyBinData param [6, 0]] call AP_fnc_policeRequired) exitWith {};
        if ([] call AP_fnc_activeFederalEvent) exitWith { ["There is already another Federal Event happening."] call _msg; };
        if ((SRV_loonyBinData param [0, -2700]) > serverTime - 2700) exitWith {
            [format ["The Loony Bin was recently breached! Try again in %1 minute(s).", ceil ((((SRV_loonyBinData param [0, -2700]) + 2700) - serverTime) / 60)]] call _msg;
        };
        if (SRV_lastRobbery > (serverTime - (60 * 15))) exitWith {
            [2, format ["Security is high due to a recent robbery. Try again in %1 minute(s).", ceil ((SRV_lastRobbery - (serverTime - (60 * 15))) / 60)]] call AP_fnc_broadcast;
        };
        ["Slicing the detonator..."] call _msg;
        AP_action_in_use = true;
        private _ok = (([8] call AP_fnc_cyberdeckSeq) isEqualTo 1);
        AP_action_in_use = false;
        if !(_ok) exitWith { ["The detonator locked you out. Try again."] call _msg; };
        [["lbTrolley", []], "APS_fnc_loonyBinSRV", 2, false, false] spawn AP_fnc_MP;
    };

    // ── STEP 2: Sequence-Breach the courtyard laptop -> arms the door satchel (5 min) ───────────
    case "lbDoorHack": {
        if (AP_action_in_use) exitWith {};
        if !(AP_effSide isEqualTo civilian) exitWith {};
        if !(call AP_fnc_hasDeck) exitWith { ["You need a Cyberdeck to arm the door charge!"] call _msg; };
        private _s = call _st;
        if !(_s param [0, false]) exitWith { ["Blow the compound gates first!"] call _msg; };
        if ((_s param [1, 0]) > 0) exitWith { ["The charge is already counting down -- hold the building!"] call _msg; };
        if (_s param [2, false]) exitWith { ["The main door is already open."] call _msg; };
        ["Arming the door charge..."] call _msg;
        AP_action_in_use = true;
        private _ok = (([10] call AP_fnc_cyberdeckSeq) isEqualTo 1);
        AP_action_in_use = false;
        if !(_ok) exitWith { ["The firing circuit rejected your payload. Try again."] call _msg; };
        [["lbDoorHack", []], "APS_fnc_loonyBinSRV", 2, false, false] spawn AP_fnc_MP;
    };

    // ── STEP 3: Terminal-Breach the rugged laptop -> patient record database (10 min) ───────────
    case "lbDbHack": {
        if (AP_action_in_use) exitWith {};
        if !(AP_effSide isEqualTo civilian) exitWith {};
        if !(call AP_fnc_hasDeck) exitWith { ["You need a Cyberdeck to breach the database!"] call _msg; };
        private _s = call _st;
        if !(_s param [2, false]) exitWith { ["The main door is still sealed."] call _msg; };
        if ((_s param [3, 0]) > 0) exitWith { ["The database breach is already running."] call _msg; };
        if (_s param [4, false]) exitWith { ["The database is already cracked -- go enter the code."] call _msg; };
        ["Establishing a shell on the records terminal..."] call _msg;
        AP_action_in_use = true;
        private _ok = (([3] call AP_fnc_cyberdeckTerm) isEqualTo 1);   // difficulty 3 = 9 commands, the federal tier
        AP_action_in_use = false;
        if !(_ok) exitWith { ["The terminal traced you and dropped the session. Try again."] call _msg; };
        [["lbDbHack", []], "APS_fnc_loonyBinSRV", 2, false, false] spawn AP_fnc_MP;
    };

    // ── STEP 4: keycode at the tablet (called from dialog/mental_input.hpp) ─────────────────────
    case "enterKeyCode": {
        private _dlg = findDisplay 782000;
        if (isNull _dlg) exitWith {};
        private _entered = ctrlText 782002;
        if !(AP_effSide isEqualTo civilian) exitWith {};
        if !([_entered] call AP_fnc_isAlphanumeric) exitWith { ["Enter a real number/letter!"] call _msg; };
        private _s = call _st;
        if !(_s param [4, false]) exitWith { ["There is no transfer code yet -- breach the database first."] call _msg; };
        if (_s param [5, false]) exitWith { ["The tomb is already open."] call _msg; };
        if !(["AP_lbPos_tablet", [4269.54, 3931.75, 27.74], 8] call AP_fnc_lbAt) exitWith {};
        closeDialog 0;
        [["enterKeyCode", [_entered]], "APS_fnc_loonyBinSRV", 2, false, false] spawn AP_fnc_MP;
    };

    // ── MAXSEC COUNTER: re-enable the firewall on the rugged laptop ───────────────────────────────
    case "lbFirewall": {
        if (AP_action_in_use) exitWith {};
        if !(AP_effSide isEqualTo west) exitWith { ["You must be an officer to do this action!"] call _msg; };
        private _s = call _st;
        if !(_s param [0, false]) exitWith {};
        if (_s param [6, false]) exitWith { ["The Loony Bin firewall has already been reactivated!"] call _msg; };
        disableSerialization;
        5 cutRsc ["AP_progress", "PLAIN"];
        private _display = uiNameSpace getVariable ["AP_progress", displayNull];
        private _progressBar = _display displayCtrl 38201;
        private _progressText = _display displayCtrl 38202;
        AP_action_in_use = true;
        private _increment = 1;
        private _totalTime = 85;
        private _currentPoint = 0;
        private _loopDelay = _totalTime / (floor (100 / _increment));
        private _text = "Restarting Loony Bin Firewall";
        _progressBar progressSetPosition 0;
        _progressText ctrlSetText format ["%1 (0%2)", _text, "%"];
        [["Acts_TerminalOpen", _totalTime, "switchMove", player], "AP_fnc_handleAnim", (allPlayers select { (_x distance player) <= 100 })] spawn AP_fnc_MP;
        private _isSuccess = for "_i" from 0 to 1 step 0 do {
            uiSleep _loopDelay;
            if (isNull _progressBar) exitWith { false };
            _currentPoint = (progressPosition _progressBar) + (_increment / 100);
            _progressBar progressSetPosition _currentPoint;
            _progressText ctrlSetText format ["%1 (%2%3)", _text, round (_currentPoint * 100), "%"];
            if (_currentPoint >= 1) exitWith { true };
            if ((speed player) >= 3) exitWith { false };
            if !(isNull objectParent player) exitWith { false };
            if (!AP_action_in_use || !alive player) exitWith { false };
            if ((call _st) param [6, false]) exitWith { false };   // another officer beat you to it
            false;
        };
        ["", 0, "switchMove", player] spawn AP_fnc_handleAnim;
        AP_action_in_use = false;
        5 cutText ["", "PLAIN"];
        if !(_isSuccess) exitWith { ["You have failed to reactivate the firewall"] call _msg; };
        [["lbFirewall", []], "APS_fnc_loonyBinSRV", 2, false, false] spawn AP_fnc_MP;
    };

    // ── loot the patient remains (unchanged -- the locked, dupe-safe pickup menu) ───────────────
    case "lootPatientsRemains": {
        _data params [["_remainsObject", objNull, [objNull]]];
        if (isNull _remainsObject) exitWith {};
        if ((player distance _remainsObject) > 5) exitWith {};
        if ((_remainsObject getVariable ["AP_droppedItems", []]) isEqualTo []) exitWith {
            ["These remains have already been looted."] call _msg;
        };
        [_remainsObject] call AP_fnc_menuPickupItems;
    };

    default { diag_log format ["[LooneyBin][heist][client] unhandled case: %1", _this]; };
};
