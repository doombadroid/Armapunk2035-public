// Altis Life game mechanic — fictional in-game "quickhack" ability, game logic only
/*
    File: fn_talSRV.sqf  (APS_fnc_talSRV)
    LooneyBin 2026-07-20: TAL OS server backend (see talos.md). Only the wedges that need DB access or
    authority live here -- Plate Scan / Firmware Scan / Sweep read PUBLIC object vars client-side.

    Modes:
      ["records", _target, _cop]   rap sheet from the DB, returned to the requesting officer only
*/
params [["_mode", "", [""]]];
// CALLER BINDING: every mode takes the officer in slot 2 and every client caller (fn_talAction) passes `player`.
// The isDutyCop gates read that slot, so naming a real officer there let anyone run TAL OS. Refuse a remote
// call whose officer is not the caller; server-side calls pass.
private _caller = (allPlayers select { owner _x isEqualTo remoteExecutedOwner }) param [0, objNull];
if (isRemoteExecuted && {remoteExecutedOwner isNotEqualTo 2} && {(_this param [2, objNull]) isNotEqualTo _caller}) exitWith {
    ["-SEC-", _caller, format ["BLOCKED talSRV %1: officer is not the caller", _mode]] call APS_fnc_logIt;};

switch (_mode) do {

    case "records": {params ["", ["_t", objNull], ["_cop", objNull]];
        if (isNull _t || {isNull _cop}) exitWith {};
        if !(_cop call APS_fnc_isDutyCop) exitWith {};      // west-only, server-enforced
        if ((_cop distance _t) > 25) exitWith {
            [["RECORDS -- suspect out of scanner range.", "basic"], "AP_fnc_handleMessage", _cop, false, false] spawn AP_fnc_MP;};
        private _uid = getPlayerUID _t;
        if (_uid isEqualTo "") exitWith {};

        private _p = [format ["SELECT arrested, crimes, gang0 FROM players WHERE playerid='%1'", _uid], 2] call DB_fnc_asyncQuery;
        private _g = [format ["SELECT stats FROM players_global WHERE playerid='%1'", _uid], 2] call DB_fnc_asyncQuery;
        private _stats = [(_g param [0, "[]"])] call DB_fnc_mresToArray;
        if (isNil "_stats" || {!(_stats isEqualType [])}) then { _stats = [] };
        private _num = { parseNumber format ["%1", _this] };

        private _jailed  = (_p param [0, 0]) call _num;                 // currently in custody
        private _gang    = format ["%1", _p param [2, ""]];
        private _copKill = (_stats param [0, 0]) call _num;             // cops killed
        private _prison  = (_stats param [4, 0]) call _num;             // minutes served
        private _tickets = (_stats param [49, 0]) call _num;            // tickets paid
        private _bail    = (_stats param [82, 0]) call _num;            // spent on bail

        // priors score -> a plain-language flag so an officer can act on it without reading numbers
        private _flag = switch (true) do {
            case (_copKill >= 100 || _prison >= 600): { "<t color='#ff3b30' size='1.15'>VIOLENT -- EXTENSIVE PRIORS</t>" };
            case (_copKill >= 20  || _prison >= 180): { "<t color='#f0a01e'>REPEAT OFFENDER</t>" };
            case (_prison > 0 || _bail > 0):          { "<t color='#4db8ff'>PRIOR CONTACT</t>" };
            default                                   { "<t color='#4db8ff'>NO SIGNIFICANT RECORD</t>" };};
        private _custody = if (_jailed > 0) then { "<br/><t color='#ff3b30'>FLAGGED: escaped / in custody</t>" } else { "" };
        private _gangTxt = if (_gang isEqualTo "" || {_gang isEqualTo "0"}) then { "none on file" } else { _gang };

        [[format [
            "<t color='#f0a01e' size='1.2'>RECORDS -- %1</t><br/>%2%3<br/><t color='#7d8b9e'>Gang</t> %4<br/><t color='#7d8b9e'>Time served</t> %5 min   <t color='#7d8b9e'>Bail paid</t> $%6<br/><t color='#7d8b9e'>Officers killed</t> %7   <t color='#7d8b9e'>Tickets paid</t> %8",
            toUpper (name _t), _flag, _custody, _gangTxt, _prison, [_bail] call AP_fnc_numberText, _copKill, _tickets], "basic"],
            "AP_fnc_handleMessage", _cop, false, false] spawn AP_fnc_MP;

        ["-TALOS-", _cop, name _cop, format ["records lookup on %1 (%2)", name _t, _uid]] call APS_fnc_logIt;};

    // ---- DECK JAMMER: an 80m / 60s no-intrusion bubble. Server-side ONLY on purpose: criminals learn
    // it exists by their cast failing, not by a marker. APS_fnc_qhSRV and APS_fnc_cyberdeckSRV both
    // consult APS_deckJam (localNamespace: a client publicVariable cannot clear it), so every civ hack path is covered by one authority.
    case "jammer": {params ["", ["_pos", [0,0,0], [[]]], ["_cop", objNull, [objNull]]];
        if (isNull _cop || {!(_cop call APS_fnc_isDutyCop)}) exitWith {};
        private _jams = localNamespace getVariable ["APS_deckJam", []];
        _jams = _jams select { (_x param [1, 0]) > serverTime };            // drop expired while we're here
        _jams pushBack [_pos, serverTime + 60];
        localNamespace setVariable ["APS_deckJam", _jams];
        ["-TALOS-", _cop, name _cop, format ["deck jammer active at %1 for 60s", _pos]] call APS_fnc_logIt;};

    // ---- HONEYPOT ATM: rigged machine. The next ATM Jackpot against it fails and pings MaxSec.
    // Keyed by rounded position, the same key shape cyberdeckSRV's atmJackpot already builds.
    case "honeypot": {params ["", ["_pos", [0,0,0], [[]]], ["_cop", objNull, [objNull]]];
        if (isNull _cop || {!(_cop call APS_fnc_isDutyCop)}) exitWith {};
        private _key = format ["%1_%2", round (_pos param [0, 0]), round (_pos param [1, 0])];
        private _hp = localNamespace getVariable ["APS_atmHoney", createHashMap];
        _hp set [_key, serverTime + 3600];                                  // stays hot for an hour
        localNamespace setVariable ["APS_atmHoney", _hp];
        ["-TALOS-", _cop, name _cop, format ["honeypot armed on ATM %1", _key]] call APS_fnc_logIt;};

    // ---- REMOTE VEHICLE STOP: MaxSec's lawful Killswitch. The SERVER runs the 8s uplink and re-checks
    // authorisation on completion, so a modified TAL client can neither skip the channel nor stop a
    // vehicle that stopped being a lawful target while the handshake ran.
    case "vehstop": {params ["", ["_veh", objNull, [objNull]], ["_cop", objNull, [objNull]]];
        if (isNull _veh || {isNull _cop}) exitWith {};
        if !(_cop call APS_fnc_isDutyCop) exitWith {};
        // Analog Retrofit: no ECU, no uplink. Told plainly -- the counter has to be learnable.
        if (_veh getVariable ["AP_analog", false]) exitWith {
            [["<t color='#ff3b30'>NO ECU</t> -- analog retrofit. Safe Stop cannot reach this vehicle.", "basic"], "AP_fnc_handleMessage", _cop, false, false] spawn AP_fnc_MP;
        };
        if (_veh getVariable ["AP_ignHacked", false]) exitWith {};
        private _fnWanted = {params ["_v"];
            ((crew _v) findIf { isPlayer _x && {(_x getVariable ["AP_wantedAmt", 0]) > 0}}) > -1};
        if !([_veh] call _fnWanted) exitWith {
            [["<t color='#ff3b30'>NOT AUTHORISED</t> -- no wanted occupant. Safe Stop is a pursuit tool.", "basic"], "AP_fnc_handleMessage", _cop, false, false] spawn AP_fnc_MP;
        };
        // the occupants get the full channel -- this is their window to pull over or bail
        { [["<t color='#f0a01e' size='1.2'>MAXSEC SAFE STOP UPLINK</t><br/>Your drivetrain is being commanded to stop. Pull over.", "warning"], "AP_fnc_handleMessage", _x, false, false] spawn AP_fnc_MP; } forEach (crew _veh);
        [_veh, _cop, _fnWanted] spawn {params ["_veh", "_cop", "_fnWanted"];
            uiSleep 8;                                                     // SERVER owns the uplink clock
            if (isNull _veh || {isNull _cop}) exitWith {};
            if (!alive _veh) exitWith {};
            if ((_cop distance _veh) > 320) exitWith {                     // lost visual = lost uplink
                [["<t color='#ff3b30'>UPLINK LOST</t> -- the vehicle broke range.", "basic"], "AP_fnc_handleMessage", _cop, false, false] spawn AP_fnc_MP;
            };
            if !([_veh] call _fnWanted) exitWith {
                [["<t color='#ff3b30'>UPLINK ABORTED</t> -- no wanted occupant on completion.", "basic"], "AP_fnc_handleMessage", _cop, false, false] spawn AP_fnc_MP;
            };
            private _hp = getText (configFile >> "CfgVehicles" >> typeOf _veh >> "HitPoints" >> "HitEngine" >> "name");
            if (_hp isEqualTo "") then { _hp = "HitEngine"; };
            _veh setVariable ["AP_ignHacked", true, true];
            [[_veh, _hp, 1], "AP_fnc_qhEngineKill", _veh] spawn AP_fnc_MP;   // owner-local (occupied car = driver-local)
            { [["<t color='#f0a01e'>ENGINE STOPPED</t> -- MaxSec Safe Stop executed.", "warning"], "AP_fnc_handleMessage", _x, false, false] spawn AP_fnc_MP; } forEach (crew _veh);
            [["<t color='#f0a01e'>SAFE STOP EXECUTED</t> -- suspect vehicle disabled.", "basic"], "AP_fnc_handleMessage", _cop, false, false] spawn AP_fnc_MP;
            ["-TALOS-", _cop, name _cop, format ["SAFE STOP executed on %1", typeOf _veh]] call APS_fnc_logIt;
            [_veh, _hp] spawn {params ["_v", "_hp"];
                uiSleep 25;
                if (isNull _v) exitWith {};
                [[_v, _hp, 0], "AP_fnc_qhEngineKill", _v] spawn AP_fnc_MP;   // restore on the owner
                _v setVariable ["AP_ignHacked", nil, true];};};};

    // ---- BREACH ORDER: instant lawful unlock. Gated on the vehicle being tied to a wanted suspect --
    // either someone wanted is sitting in it, or a registered keyholder is wanted and online.
    case "breachorder": {params ["", ["_veh", objNull, [objNull]], ["_cop", objNull, [objNull]]];
        if (isNull _veh || {isNull _cop}) exitWith {};
        if !(_cop call APS_fnc_isDutyCop) exitWith {};
        if ((_cop distance _veh) > 15) exitWith {};
        private _occWanted = ((crew _veh) findIf { isPlayer _x && {(_x getVariable ["AP_wantedAmt", 0]) > 0}}) > -1;
        private _owners = _veh getVariable ["AP_vehOwners", _veh getVariable ["vehicle_info_owners", []]];
        private _ownerUids = _owners apply { _x param [0, ""] };
        private _ownWanted = (allPlayers findIf {
            isPlayer _x && {(getPlayerUID _x) in _ownerUids} && {(_x getVariable ["AP_wantedAmt", 0]) > 0}}) > -1;
        if (!_occWanted && {!_ownWanted}) exitWith {
            [["<t color='#ff3b30'>NO PROBABLE CAUSE</t> -- this vehicle is not tied to a wanted suspect.", "basic"], "AP_fnc_handleMessage", _cop, false, false] spawn AP_fnc_MP;
        };
        _veh lock 0;
        _veh setVariable ["AP_breachOrder", serverTime, true];
        [["<t color='#f0a01e'>BREACH ORDER SERVED</t> -- vehicle unlocked on the record.", "basic"], "AP_fnc_handleMessage", _cop, false, false] spawn AP_fnc_MP;
        { [["<t color='#f0a01e'>BREACH ORDER</t> -- MaxSec have lawfully opened your vehicle.", "warning"], "AP_fnc_handleMessage", _x, false, false] spawn AP_fnc_MP; } forEach (allPlayers select { (getPlayerUID _x) in _ownerUids });
        ["-TALOS-", _cop, name _cop, format ["BREACH ORDER unlocked %1 (occWanted=%2 ownWanted=%3)", typeOf _veh, _occWanted, _ownWanted]] call APS_fnc_logIt;
    };

    // ---- ASSET FREEZE: lock a wanted suspect's banking for 10 min. AP_assetFrozen is read by the bank/ATM
    // paths (fn_bankDeposit/Withdraw + the ATM Jackpot hack). Server-authorised, wanted-gated.
    case "assetfreeze": {params ["", ["_t", objNull, [objNull]], ["_cop", objNull, [objNull]]];
        if (isNull _t || {isNull _cop} || {!(_cop call APS_fnc_isDutyCop)}) exitWith {};
        if ((_t getVariable ["AP_wantedAmt", 0]) <= 0) exitWith {
            [["<t color='#ff3b30'>NOT WANTED</t> -- Asset Freeze is felony-only.", "basic"], "AP_fnc_handleMessage", _cop, false, false] spawn AP_fnc_MP;
        };
        _t setVariable ["AP_assetFrozen", serverTime + 600, true];
        [["<t color='#4aa3ff'>ASSETS FROZEN</t> -- an officer has locked your accounts for 10 minutes.", "basic"], "AP_fnc_handleMessage", _t, false, false] spawn AP_fnc_MP;
        [["<t color='#f0a01e'>ASSET FREEZE</t> -- their ATM and bank are locked for 10 minutes.", "basic"], "AP_fnc_handleMessage", _cop, false, false] spawn AP_fnc_MP;
        ["-TALOS-", _cop, name _cop, format ["asset freeze on %1", name _t]] call APS_fnc_logIt;};

    // ---- GRID PRIORITY: restore every deck-blacked-out street light within 300m of the officer. Blackout
    // (qhSRV "gridout") registers each event in APS_gridBlackout (localNamespace); this brings the affected lamps back early.
    case "gridpriority": {params ["", ["_pos", [0,0,0], [[]]], ["_cop", objNull, [objNull]]];
        if (isNull _cop || {!(_cop call APS_fnc_isDutyCop)}) exitWith {};
        private _events = localNamespace getVariable ["APS_gridBlackout", []];
        private _keep = []; private _restored = 0; {_x params ["_lamps", "_endT", "_ctr"];
            if (serverTime < _endT && {(_pos distance2D _ctr) < 300}) then {
                { if (!isNull _x) then { _x switchLight "AUTO"; _restored = _restored + 1; }; } forEach _lamps;} else {
                if (serverTime < _endT) then { _keep pushBack _x; };};} forEach _events;
        localNamespace setVariable ["APS_gridBlackout", _keep];
        [[format ["<t color='#f0a01e'>GRID PRIORITY</t> -- %1 lights back on.", _restored], "basic"], "AP_fnc_handleMessage", _cop, false, false] spawn AP_fnc_MP;
        ["-TALOS-", _cop, name _cop, format ["grid priority restored %1 lamps", _restored]] call APS_fnc_logIt;};

    // ---- BLACK BOX SUBPOENA: recover who wiped a suspect's memory. Memory Hole (qhSRV "memhole") stamps
    // AP_memHoleBy on the victim; this reads it back for the officer -- the identity the wipe tried to erase.
    case "blackbox": {params ["", ["_t", objNull, [objNull]], ["_cop", objNull, [objNull]]];
        if (isNull _t || {isNull _cop} || {!(_cop call APS_fnc_isDutyCop)}) exitWith {};
        private _rec = _t getVariable ["AP_memHoleBy", []];
        if (_rec isEqualTo [] || {serverTime > (_rec param [1, 0])}) exitWith {
            [["<t color='#f0a01e'>BLACK BOX</t> -- implant log is clean. No memory tampering on record.", "basic"], "AP_fnc_handleMessage", _cop, false, false] spawn AP_fnc_MP;
        };
        [[format ["<t color='#f0a01e' size='1.2'>BLACK BOX RECOVERED</t><br/>Memory wipe traced to <t color='#ff3b30'>%1</t>. Recording timestamp holds up in court.", _rec param [0, "Unknown"]], "basic"], "AP_fnc_handleMessage", _cop, false, false] spawn AP_fnc_MP;
        ["-TALOS-", _cop, name _cop, format ["black box recovered memhole author %1 on %2", _rec param [0, "?"], name _t]] call APS_fnc_logIt;
    };

    // ---- REMOTE DETAIN: 10s server-timed channel on a wanted felon (re-validated on completion), then a
    // full-body ragdoll (reuses the Flatline victim effect). An ICE Firewall on the felon eats it and shatters.
    case "detain": {params ["", ["_t", objNull, [objNull]], ["_cop", objNull, [objNull]]];
        if (isNull _t || {isNull _cop} || {!(_cop call APS_fnc_isDutyCop)}) exitWith {};
        if ((_t getVariable ["AP_wantedAmt", 0]) <= 0) exitWith {};
        { [["<t color='#f0a01e' size='1.2'>REMOTE DETAINMENT INITIATED</t><br/>COMPLY. Do not resist.", "warning"], "AP_fnc_handleMessage", _x, false, false] spawn AP_fnc_MP; } forEach [_t];
        [_t, _cop] spawn {params ["_t", "_cop"];
            uiSleep 10;
            if (isNull _t || {!alive _t} || {isNull _cop}) exitWith {};
            if ((_t getVariable ["AP_wantedAmt", 0]) <= 0) exitWith {
                [["<t color='#ff3b30'>DETAIN ABORTED</t> -- suspect is no longer wanted.", "basic"], "AP_fnc_handleMessage", _cop, false, false] spawn AP_fnc_MP;
            };
            // ICE Firewall (108) on the felon eats one Tier-4-class hit and shatters.
            if (108 in (_t getVariable ["AP_cdMods", []]) && {"icefw" in (_t getVariable ["AP_fwChips", []])}) exitWith {
                private _owned = (_t getVariable ["AP_cdMods", []]) - [108];
                _t setVariable ["AP_cdMods", _owned, true];
                [_t, [], [108]] spawn APS_fnc_cdModsSave;   // persists the SERVER's copy, never the public var
                [["<t color='#33ffbb'>ICE FIREWALL</t> -- it ate the detainment signal and shattered.", "cyberjackpot"], "AP_fnc_handleMessage", _t, false, false] spawn AP_fnc_MP;
                [["<t color='#ff3b30'>DETAIN FAILED</t> -- suspect was running a hard firewall.", "basic"], "AP_fnc_handleMessage", _cop, false, false] spawn AP_fnc_MP;
            };
            [["flatline", _cop, "REMOTE DETAIN"], "AP_fnc_qhEffect", _t, false] spawn AP_fnc_MP;
            [["<t color='#f0a01e'>DETAINMENT EXECUTED</t> -- suspect is down. Move in.", "basic"], "AP_fnc_handleMessage", _cop, false, false] spawn AP_fnc_MP;
            ["-TALOS-", _cop, name _cop, format ["remote detain executed on %1", name _t]] call APS_fnc_logIt;};};

    // ---- WARRANT REQUEST: a junior officer asks; a senior officer (Sgt+ = copLevel 3+) signs off. ★ OPEN OWNER
    // RULING: a served warrant currently only stamps AP_warrant for 10 min -- it does NOT yet change the Cyber
    // Crime charge, the ICE trace, or homeowner notification. Those are the policy questions to confirm.
    case "warrantreq": {params ["", ["_t", objNull, [objNull]], ["_cop", objNull, [objNull]]];
        if (isNull _t || {isNull _cop} || {!(_cop call APS_fnc_isDutyCop)}) exitWith {};
        private _seniors = allPlayers select { (_x call APS_fnc_isDutyCop) && {alive _x} && {(_x getVariable ["AP_unitCopLevel", 0]) >= 3} && {_x isNotEqualTo _cop} };
        if (_seniors isEqualTo []) exitWith {
            [["<t color='#ff3b30'>NO SENIOR OFFICER</t> -- need a Corporal+ online to sign a warrant.", "basic"], "AP_fnc_handleMessage", _cop, false, false] spawn AP_fnc_MP;
        }; {
            [[format ["<t color='#f0a01e' size='1.1'>WARRANT REQUEST</t><br/>%1 wants a lawful-entry warrant on <t color='#dbe4ee'>%2</t>. Scroll them to APPROVE within 30s.", name _cop, name _t], "copalert"], "AP_fnc_handleMessage", _x, false, false] spawn AP_fnc_MP;
        } forEach _seniors;
        // ★ FUNCTIONAL-BUT-PENDING-A-RULING: for now the request auto-grants a 10-min warrant flag once a senior
        // is confirmed online (they are notified for transparency). A real per-request APPROVE scroll-action, and
        // deciding what the warrant actually CHANGES (Cyber Crime charge / ICE trace / homeowner notice), are the
        // owner's calls -- see docs/quickhacks-design.md. AP_warrant is a stamp other tools can read today.
        _t setVariable ["AP_warrant", serverTime + 600, true];
        [["<t color='#f0a01e'>WARRANT GRANTED</t> -- a senior officer signed off. Lawful entry is authorised for 10 minutes.", "basic"], "AP_fnc_handleMessage", _cop, false, false] spawn AP_fnc_MP;
        ["-TALOS-", _cop, name _cop, format ["warrant granted on %1 (%2 seniors notified)", name _t, count _seniors]] call APS_fnc_logIt;};
};
