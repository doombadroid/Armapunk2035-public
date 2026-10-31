// Altis Life game mechanic — fictional in-game "quickhack" ability, game logic only
/*
    File: fn_talAction.sqf  (AP_fnc_talAction)
    LooneyBin 2026-07-20: TAL OS wedge dispatcher -- the MaxSec half of the visor ring (see talos.md).
    Cops get INFORMATION + COUNTERS, never auto-wins; every action logs via APS_fnc_logIt.

    id: 0 RECORDS  1 PLATE  2 FIELD TEST  5 SWEEP  6 DISPATCH  7 BACKUP
    owner 2026-09-05: 3 FIRMWARE SCAN and 4 FACTORY RESET are GONE. ICEBREAKER is standard on every
    civilian phone now, so a scan could only ever read "ILLEGAL" and a reset could not take anything
    away. Ids 3 and 4 fall through this switch to nothing; 5-7 keep their slots, unrenumbered.
    Rank gates are applied in the ring's vector table (fn_cyberdeckRing.sqf); this is the executor.
*/
params [["_id", -1, [0]]];
if !(AP_effSide isEqualTo west) exitWith {};
private _t = missionNamespace getVariable ["AP_cdTarget", objNull];

switch (_id) do {

    // ---- RECORDS: rap sheet on the player you're aiming at (server reads the DB) ----
    case 0: {if (isNull _t || {!(_t isKindOf "CAManBase")} || {!(isPlayer _t)}) exitWith {};
        ["<t color='#4db8ff'>RECORDS</t> -- querying...", "basic"] spawn AP_fnc_handleMessage;
        [["records", _t, player], "APS_fnc_talSRV", 2] spawn AP_fnc_MP;};

    // ---- PLATE: registered owner + whether the current driver is on the keys (all public vars) ----
    case 1: {if (isNull _t) exitWith {};
        // Plate Ghost quickhack: [expiry, fakeName, detectable]. The roll was fixed at cast time --
        // rescanning the same ghost never changes the answer, so scan-spam can't brute-force it.
        private _ghost = _t getVariable ["AP_plateGhost", []];
        if (_ghost isNotEqualTo [] && {serverTime < (_ghost param [0, 0])}) exitWith {
            private _gdn = getText (configFile >> "CfgVehicles" >> (typeOf _t) >> "displayName");
            if (_ghost param [2, false]) then {
                [format ["<t color='#ff3b30' size='1.2'>PLATE MISMATCH</t><br/>%1<br/>Registry checksum failed -- these plates are <t color='#ff3b30'>SPOOFED</t>.", toUpper _gdn], "basic"] spawn AP_fnc_handleMessage;
                ["-TALOS-", player, name player, format ["plate scan -> %1 / SPOOF DETECTED", _gdn]] call AP_fnc_talLog;} else {
                [format ["<t color='#f0a01e'>PLATE SCAN</t><br/>%1<br/>Registered to <t color='#dbe4ee'>%2</t><br/><t color='#4db8ff'>driver is a keyholder</t>", toUpper _gdn, _ghost param [1, "Unknown"]], "basic"] spawn AP_fnc_handleMessage;
                ["-TALOS-", player, name player, format ["plate scan -> %1 / owner %2 (ghosted, undetected)", _gdn, _ghost param [1, ""]]] call AP_fnc_talLog;
            };};
        private _owners = _t getVariable ["AP_vehOwners", _t getVariable ["vehicle_info_owners", []]];
        private _dn = getText (configFile >> "CfgVehicles" >> (typeOf _t) >> "displayName");
        if (_owners isEqualTo []) exitWith {
            [format ["<t color='#f0a01e'>PLATE SCAN</t><br/>%1<br/><t color='#ff3b30'>NO REGISTRATION ON FILE</t> -- unregistered or stolen plates.", toUpper _dn], "basic"] spawn AP_fnc_handleMessage;
        };
        private _nm = ((_owners select 0) param [1, "Unknown"]);
        private _drv = driver _t;
        private _flag = if (isNull _drv) then { "<t color='#7d8b9e'>unoccupied</t>" } else {private _duid = getPlayerUID _drv;
            if ((_owners findIf { (_x param [0,""]) isEqualTo _duid }) > -1)
                then { "<t color='#4db8ff'>driver is a keyholder</t>" }
                else { format ["<t color='#ff3b30'>DRIVER NOT ON KEYS</t> -- %1", name _drv] };};
        [format ["<t color='#f0a01e'>PLATE SCAN</t><br/>%1<br/>Registered to <t color='#dbe4ee'>%2</t><br/>%3", toUpper _dn, _nm, _flag], "basic"] spawn AP_fnc_handleMessage;
        ["-TALOS-", player, name player, format ["plate scan -> %1 / owner %2", _dn, _nm]] call AP_fnc_talLog;};

    // ---- FIELD TEST: breathalyser + drug screen. The values live on THEM, so ask their client. ----
    case 2: {if (isNull _t || {!(_t isKindOf "CAManBase")} || {!(isPlayer _t)}) exitWith {};
        ["<t color='#4db8ff'>FIELD TEST</t> -- sampling...", "basic"] spawn AP_fnc_handleMessage;
        [[player], "AP_fnc_talFieldReply", _t, false] spawn AP_fnc_MP;
        ["-TALOS-", player, name player, format ["field test on %1", name _t]] call AP_fnc_talLog;};

    // ---- ids 3 (FIRMWARE SCAN) and 4 (FACTORY RESET) deleted 2026-09-05 -- see the header. ----

    // ---- SWEEP: contraband hardware nearby -- mining rigs + planted ATM skimmers (both public) ----
    case 5: {if (diag_tickTime < (missionNamespace getVariable ["AP_talSweepCd", 0])) exitWith {};
        AP_talSweepCd = diag_tickTime + 60;
        private _hits = []; {
            if (_x getVariable ["AP_cryptoRig", false]) then { _hits pushBack [getPosATL _x, "ColorOrange", "MINING RIG"]; };
        } forEach (nearestObjects [player, [], 300]);
        private _skim = missionNamespace getVariable ["AP_atmSkim", createHashMap]; {(_x splitString "_") params ["_sx", "_sy"];
            private _p = [parseNumber _sx, parseNumber _sy, 0];
            if ((player distance2D _p) < 300) then { _hits pushBack [_p, "ColorRed", "ATM SKIMMER"]; };} forEach (keys _skim);
        if (_hits isEqualTo []) exitWith { ["<t color='#4db8ff'>SWEEP CLEAR</t> -- no contraband hardware within 300m.", "basic"] spawn AP_fnc_handleMessage; };
        {_x params ["_p", "_col", "_lab"];
            private _m = createMarkerLocal [format ["tal_sweep_%1_%2", _forEachIndex, round diag_tickTime], _p];
            _m setMarkerTypeLocal "hd_warning";
            _m setMarkerColorLocal _col;
            _m setMarkerTextLocal _lab;
            [_m] spawn { uiSleep 45; deleteMarkerLocal (_this select 0); };} forEach _hits;
        [format ["<t color='#f0a01e'>SWEEP</t> -- %1 contraband device(s) marked for 45s.", count _hits], "basic"] spawn AP_fnc_handleMessage;
        ["-TALOS-", player, name player, format ["contraband sweep -> %1 hit(s)", count _hits]] call AP_fnc_talLog;};

    // ---- DISPATCH PIN: mark your position for every officer on the net ----
    case 6: {if (diag_tickTime < (missionNamespace getVariable ["AP_talPinCd", 0])) exitWith {};
        AP_talPinCd = diag_tickTime + 20;
        [[getPosATL player, format ["%1 MARK", toUpper (name player)], "ColorBlue", false], "AP_fnc_talMarker", west, false] spawn AP_fnc_MP;
        ["<t color='#f0a01e'>DISPATCH PIN</t> -- position marked on the MaxSec net.", "basic"] spawn AP_fnc_handleMessage;
        ["-TALOS-", player, name player, "dispatch pin"] call AP_fnc_talLog;};

    // ---- BACKUP BEACON: panic button. Red marker + alert to every cop AND every medic. ----
    case 7: {if (diag_tickTime < (missionNamespace getVariable ["AP_talBackupCd", 0])) exitWith {};
        AP_talBackupCd = diag_tickTime + 30;
        [[getPosATL player, format ["%1 -- BACKUP", toUpper (name player)], "ColorRed", true], "AP_fnc_talMarker", west, false] spawn AP_fnc_MP;
        [[getPosATL player, format ["%1 -- BACKUP", toUpper (name player)], "ColorRed", true], "AP_fnc_talMarker", independent, false] spawn AP_fnc_MP;
        [[format ["<t color='#ff3b30' size='1.2'>OFFICER NEEDS ASSISTANCE</t><br/>%1 has hit the backup beacon.", name player], "copalert"], "AP_fnc_handleMessage", west, false, false] spawn AP_fnc_MP;
        ["<t color='#ff3b30'>BACKUP BEACON</t> -- all units and medics notified.", "basic"] spawn AP_fnc_handleMessage;
        ["-TALOS-", player, name player, "BACKUP BEACON"] call AP_fnc_talLog;};

    // ---- DECK JAMMER (Captain+): 80m no-hack bubble for 60s. Park it on the Fed mid-heist. ----
    // The bubble itself is server state (APS_fnc_talSRV "jammer") -- a client-side field would be
    // invisible to the server's cast validation and therefore no field at all.
    case 8: {if (diag_tickTime < (missionNamespace getVariable ["AP_talJamCd", 0])) exitWith {};
        AP_talJamCd = diag_tickTime + 180;
        [["jammer", getPosATL player, player], "APS_fnc_talSRV", 2] spawn AP_fnc_MP;
        ["<t color='#f0a01e'>DECK JAMMER</t> -- 80m intrusion blackout for 60 seconds.", "basic"] spawn AP_fnc_handleMessage;
        ["-TALOS-", player, name player, "deck jammer deployed"] call AP_fnc_talLog;};

    // ---- HONEYPOT ATM (Captain+): rig the machine you're facing. Next jackpot attempt fails loudly. ----
    case 9: {private _atm = cursorObject;
        if (isNull _atm || {!((typeOf _atm) in ["Land_Atm_01_F", "Land_Atm_02_F"])}) exitWith {
            ["<t color='#ff3b30'>NO ATM</t> -- face the machine you want to rig.", "basic"] spawn AP_fnc_handleMessage;};
        if ((player distance _atm) > 6) exitWith {
            ["<t color='#ff3b30'>TOO FAR</t> -- get to the machine.", "basic"] spawn AP_fnc_handleMessage;};
        [["honeypot", getPosATL _atm, player], "APS_fnc_talSRV", 2] spawn AP_fnc_MP;
        ["<t color='#f0a01e'>HONEYPOT ARMED</t> -- the next deck that touches this machine burns itself.", "basic"] spawn AP_fnc_handleMessage;
        ["-TALOS-", player, name player, "honeypot ATM armed"] call AP_fnc_talLog;};

    // ---- REMOTE VEHICLE STOP (Sgt+): the lawful half of Killswitch. Stalls a fleeing WANTED suspect's
    // vehicle after an 8s uplink the occupants SEE -- they get the whole channel to bail out, pull over or
    // break line of sight, which is what keeps it a pursuit tool rather than an auto-win. Authorisation
    // (occupant wanted) and the Analog Retrofit immunity are BOTH re-checked server-side.
    case 10: {if (isNull _t || {!((_t isKindOf "Car") || (_t isKindOf "Ship") || (_t isKindOf "Air") || (_t isKindOf "Tank"))}) exitWith {
            ["<t color='#ff3b30'>NO VEHICLE</t> -- lock the suspect vehicle first.", "basic"] spawn AP_fnc_handleMessage;};
        if ((player distance _t) > 250) exitWith {
            ["<t color='#ff3b30'>OUT OF RANGE</t> -- close on the vehicle.", "basic"] spawn AP_fnc_handleMessage;};
        if (diag_tickTime < (missionNamespace getVariable ["AP_talStopCd", 0])) exitWith {
            [format ["<t color='#ff3b30'>UPLINK COOLING</t> -- %1s.", ceil ((missionNamespace getVariable ["AP_talStopCd", 0]) - diag_tickTime)], "basic"] spawn AP_fnc_handleMessage;
        };
        AP_talStopCd = diag_tickTime + 180;
        [["vehstop", _t, player], "APS_fnc_talSRV", 2] spawn AP_fnc_MP;
        ["<t color='#f0a01e'>SAFE STOP UPLINK</t> -- 8 second handshake. Hold visual.", "basic"] spawn AP_fnc_handleMessage;
        ["-TALOS-", player, name player, format ["remote vehicle stop -> %1", typeOf _t]] call AP_fnc_talLog;};

    // ---- BREACH ORDER (Sgt+): warranted entry. Instant unlock on a vehicle tied to a WANTED suspect --
    // no minigame, because the lawful version's whole point is that it is fast and on the record. The
    // Deadbolt Chip does NOT stop this (a deadbolt is a counter to burglary, not to a warrant).
    case 11: {if (isNull _t || {!((_t isKindOf "Car") || (_t isKindOf "Ship") || (_t isKindOf "Air") || (_t isKindOf "Tank"))}) exitWith {
            ["<t color='#ff3b30'>NO VEHICLE</t> -- lock the vehicle you are serving on.", "basic"] spawn AP_fnc_handleMessage;};
        if ((player distance _t) > 12) exitWith {
            ["<t color='#ff3b30'>TOO FAR</t> -- you have to be at the vehicle.", "basic"] spawn AP_fnc_handleMessage;};
        [["breachorder", _t, player], "APS_fnc_talSRV", 2] spawn AP_fnc_MP;
        ["-TALOS-", player, name player, format ["breach order served on %1", typeOf _t]] call AP_fnc_talLog;};

    // ---- ASSET FREEZE (Sgt+): lock a wanted suspect's ATM + bank for 10 minutes. The counter to a criminal
    // economy running on ATM Jackpot / Skim Daemon. Server sets the freeze; the bank/ATM paths honour it.
    case 12: {if (isNull _t || {!(_t isKindOf "CAManBase")} || {!(isPlayer _t)}) exitWith {
            ["<t color='#ff3b30'>NO SUSPECT</t> -- aim at the person.", "basic"] spawn AP_fnc_handleMessage;};
        if ((player distance _t) > 25) exitWith { ["<t color='#ff3b30'>OUT OF RANGE</t>.", "basic"] spawn AP_fnc_handleMessage; };
        [["assetfreeze", _t, player], "APS_fnc_talSRV", 2] spawn AP_fnc_MP;
        ["-TALOS-", player, name player, format ["asset freeze -> %1", name _t]] call AP_fnc_talLog;};

    // ---- GRID PRIORITY (Sgt+): the Blackout counter. Restore every street light a deck killed within 300m.
    case 13: {[["gridpriority", getPosATL player, player], "APS_fnc_talSRV", 2] spawn AP_fnc_MP;
        ["<t color='#f0a01e'>GRID PRIORITY</t> -- routing backup power to the block.", "basic"] spawn AP_fnc_handleMessage;
        ["-TALOS-", player, name player, "grid priority restore"] call AP_fnc_talLog;};

    // ---- BLACK BOX SUBPOENA (Sgt+, restrained suspect): pull the implant recording to recover who wiped their
    // memory. The Memory Hole counter -- it recovers the hacker's identity the wipe was meant to erase.
    case 14: {if (isNull _t || {!(_t isKindOf "CAManBase")} || {!(isPlayer _t)}) exitWith {
            ["<t color='#ff3b30'>NO SUSPECT</t>.", "basic"] spawn AP_fnc_handleMessage;};
        [["blackbox", _t, player], "APS_fnc_talSRV", 2] spawn AP_fnc_MP;
        ["-TALOS-", player, name player, format ["black box subpoena -> %1", name _t]] call AP_fnc_talLog;};

    // ---- REMOTE DETAIN (Sgt+, wanted + LOS): a loud 10s channel that ends in a full-body ragdoll on the felon.
    // MaxSec's answer to Flatline -- announced, authorised, and defeated by an ICE Firewall.
    case 15: {if (isNull _t || {!(_t isKindOf "CAManBase")} || {!(isPlayer _t)}) exitWith {
            ["<t color='#ff3b30'>NO SUSPECT</t>.", "basic"] spawn AP_fnc_handleMessage;};
        if ((_t getVariable ["AP_wantedAmt", 0]) <= 0) exitWith { ["<t color='#ff3b30'>NOT WANTED</t> -- Remote Detain is felony-only.", "basic"] spawn AP_fnc_handleMessage; };
        if (!([objNull, "VIEW"] checkVisibility [eyePos player, eyePos _t] > 0.3)) exitWith { ["<t color='#ff3b30'>NO LINE OF SIGHT</t>.", "basic"] spawn AP_fnc_handleMessage; };
        if ((player distance _t) > 60) exitWith { ["<t color='#ff3b30'>OUT OF RANGE</t>.", "basic"] spawn AP_fnc_handleMessage; };
        [["detain", _t, player], "APS_fnc_talSRV", 2] spawn AP_fnc_MP;
        ["<t color='#f0a01e'>REMOTE DETAIN</t> -- 10 second channel. Keep them in sight.", "basic"] spawn AP_fnc_handleMessage;
        ["-TALOS-", player, name player, format ["remote detain -> %1", name _t]] call AP_fnc_talLog;};

    // ---- WARRANT REQUEST (any rank): request a lawful-entry warrant on a suspect. A senior officer (Sgt+)
    // online approves it. ★ OPEN OWNER RULING (docs): what a served warrant actually CHANGES is a policy call --
    // right now it just stamps AP_warrant on the suspect for 10 min for other tools to read. It does NOT yet
    // drop the Cyber Crime charge, suppress the ICE trace, or decide homeowner notification. Confirm the rules.
    case 16: {if (isNull _t || {!(_t isKindOf "CAManBase")} || {!(isPlayer _t)}) exitWith {
            ["<t color='#ff3b30'>NO SUSPECT</t>.", "basic"] spawn AP_fnc_handleMessage;};
        [["warrantreq", _t, player], "APS_fnc_talSRV", 2] spawn AP_fnc_MP;
        ["<t color='#f0a01e'>WARRANT REQUESTED</t> -- waiting on a senior officer to sign off.", "basic"] spawn AP_fnc_handleMessage;
        ["-TALOS-", player, name player, format ["warrant request -> %1", name _t]] call AP_fnc_talLog;};

    default {};};
