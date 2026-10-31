// Altis Life game mechanic — fictional in-game "quickhack" ability, game logic only
/*
    File: fn_qhSRV.sqf  (APS_fnc_qhSRV)
    LooneyBin 2026-07-21: QUICKHACK authority. The server -- not the caster -- runs the upload channel,
    re-validates on completion, applies the effect, arms the victim's trace window and routes the whole
    thing through ICE TRACE so a burned Proxy Chain still buys silence.

      [_id, _target, _hacker]        cast a quickhack
      ["trace", _hacker, _victim]    victim's trace-back
*/
params [["_a", "", [""]], ["_b", objNull, [objNull]], ["_c", objNull, [objNull]], ["_aim", [], [[]]]];
// CALLER BINDING: both client callers put `player` in slot 2 (fn_qhCast: the hacker, fn_qhTrace: the victim). A remote
// call naming anyone else there (casting AS another player, faking their trace) is refused; server-side calls pass.
private _caller = (allPlayers select { owner _x isEqualTo remoteExecutedOwner }) param [0, objNull];
if (isRemoteExecuted && {remoteExecutedOwner isNotEqualTo 2} && {_c isNotEqualTo _caller}) exitWith {
    ["-SEC-", _caller, format ["BLOCKED qhSRV %1: actor is not the caller", _a]] call APS_fnc_logIt;};

// ---------- trace-back ----------
if (_a isEqualTo "trace") exitWith {private _h = _b; private _v = _c;
    if (isNull _h || {isNull _v}) exitWith {};
    // a hacker running a live Proxy Chain reroutes the trace (and burns the charge doing it)
    if (_h getVariable ["AP_proxyActive", false]) exitWith {_h setVariable ["AP_proxyActive", false, true];
        [[[]], "AP_fnc_qhTraceResult", _v, false] spawn AP_fnc_MP;
        [["<t color='#33ffbb'>PROXY BURNED</t> -- a trace-back was rerouted.", "basic"], "AP_fnc_handleMessage", _h, false, false] spawn AP_fnc_MP;
    };
    [[getPosATL _h], "AP_fnc_qhTraceResult", _v, false] spawn AP_fnc_MP;
    [["<t color='#ff3b1e'>YOU HAVE BEEN TRACED</t> -- they know where you are.", "basic"], "AP_fnc_handleMessage", _h, false, false] spawn AP_fnc_MP;
    ["-QUICKHACK-", _h, name _h, format ["traced by %1", name _v]] call APS_fnc_logIt;};

// ---------- cast ----------
private _id = _a; private _t = _b; private _hacker = _c;
if (isNull _hacker) exitWith {};
private _cop = _hacker call APS_fnc_isDutyCop;
private _cfg = ([(if (_cop) then {"cop"} else {"civ"})] call AP_fnc_qhCfg) select { (_x select 0) isEqualTo _id };
if (_cfg isEqualTo []) exitWith {};
(_cfg select 0) params ["", "_name", "", "", "", "_upload", "_cd", "_range", "", "_auth", "_kind", "", ["_reqMod", -1]];

// civilians need the illegal firmware; officers run TAL (issued)
if (!_cop && {!(0 in (_hacker getVariable ["AP_cdMods", []]))}) exitWith {};
// drop-only hacks need their chip installed (server-checked -- a modified client can't skip the gate)
if (_reqMod > -1 && {!(_reqMod in (_hacker getVariable ["AP_cdMods", []]))}) exitWith {};

// ---------- PERSISTENT, SERVER-OWNED COOLDOWN ----------
// Every other hack keys its cooldown off diag_tickTime in the CLIENT's missionNamespace (fn_qhCast) and
// this file never checks it -- so a relog clears it and a modified client never had it. That is tolerable
// for an 18-minute non-lethal hack; it is not tolerable for the one hack that kills people. Hacks listed
// in _cdPersist are gated HERE instead, against an expiry persisted in players.qh_cooldowns, so the
// cooldown survives both a reconnect and a scheduled restart.
// Cache shape: AP_qhCdCache is a hashmap uid -> [[id, unixExpiry], ...]. Loaded lazily on first cast of
// the session so a repeat cast is not a DB round trip.
// NB: the resolve-then-exitWith-at-file-scope dance is required -- an exitWith inside the `if...then`
// below would only leave that block and the cast would carry on off-cooldown (same trap documented on
// the jammer check under this one).
// The DATABASE owns the clock: TIMESTAMPDIFF against NOW() returns the seconds remaining, so there is no
// date arithmetic in SQF (Arma has no clean epoch, and serverTime resets every restart) and the
// box/DB timezone split cannot skew it. 0 or NULL means off cooldown.
private _uid = getPlayerUID _hacker;
private _onCd = false; private _cdLeft = 0;
if (_id isEqualTo "detonate" && {_uid isNotEqualTo ""}) then {
    private _q = [format ["SELECT GREATEST(0, COALESCE(trunc(extract(epoch from (qh_detonate_cd - NOW())) / 1)::bigint, 0)) AS qh_detonate_cd FROM players WHERE playerid='%1'", _uid], 2] call DB_fnc_asyncQuery;
    // Unwrap defensively: extDB3 mode 2 hands back a row-shaped [[v]] for some selects and a bare [v] for
    // others, and the two existing precedents in this codebase disagree about which (fn_queryRequest
    // destructures `_r select 0` as a ROW, fn_gangBHistory reads it as a SCALAR). Guessing wrong here fails
    // OPEN -- the read yields 0, the gate never trips and the 2h cooldown quietly does nothing -- so accept
    // both shapes rather than trusting either precedent.
    private _left = 0;
    if (_q isEqualType [] && {count _q > 0}) then {private _v = _q select 0;
        if (_v isEqualType []) then { _v = _v param [0, 0]; };
        _left = parseNumber (format ["%1", _v]);};
    if (_left > 0) then { _onCd = true; _cdLeft = _left; };
};
if (_onCd) exitWith {
    [[format ["<t color='#ff3b1e'>%1</t> -- firmware still recharging (%2 min).", toUpper _name, ceil (_cdLeft / 60)], "basic"], "AP_fnc_handleMessage", _hacker, false, false] spawn AP_fnc_MP;
};

// DECK JAMMER (TAL, Captain+): an 80m MaxSec blackout bubble. Kills CIVILIAN quickhacks only -- it is an
// MaxSec tool, so it never jams the officers running it.
// NB: resolve to a value first, then exitWith at FILE scope -- an exitWith inside the `if...then` block
// would only leave that block and the cast would carry on jammed (same trap that bit fn_qhCast).
private _jammed = false;
if (!_cop) then {private _jams = (localNamespace getVariable ["APS_deckJam", []]) select { (_x param [1, 0]) > serverTime };
    localNamespace setVariable ["APS_deckJam", _jams];
    _jammed = (_jams findIf { ((getPosATL _hacker) distance2D (_x param [0, [0,0,0]])) < 80 }) > -1;};
if (_jammed) exitWith {
    [["<t color='#ff3b1e'>SIGNAL JAMMED</t> -- MaxSec counter-intrusion field. Move clear of it.", "warning"], "AP_fnc_handleMessage", _hacker, false, false] spawn AP_fnc_MP;
};

private _validate = {if (isNull _hacker || {!alive _hacker}) exitWith { false };
    if (_kind isEqualTo "area") exitWith { true };
    if (isNull _t || {!alive _t}) exitWith { false };
    if ((_hacker distance _t) > (_range * 1.25)) exitWith { false };     // small grace for movement
    if (_kind isEqualTo "vehicle") exitWith {
        // must be a vehicle the hacker holds keys to (AP_vehOwners rows are [uid, name])
        if (!((_t isKindOf "Car") || (_t isKindOf "Air") || (_t isKindOf "Ship") || (_t isKindOf "Tank"))) exitWith { false };
        private _owners = _t getVariable ["AP_vehOwners", _t getVariable ["vehicle_info_owners", []]];
        (_owners findIf { (_x param [0, ""]) isEqualTo (getPlayerUID _hacker) }) > -1};
    if (_kind isEqualTo "occupied") exitWith {
        // Chauffeur Override: an OCCUPIED enemy car with a live player driver, a working autopilot, and NOT an
        // analog retrofit (no computer to command). All re-checked here so a modified client can't forge any of it.
        if (!((_t isKindOf "Car") || (_t isKindOf "Ship") || (_t isKindOf "Tank"))) exitWith { false };
        if (_t getVariable ["AP_analog", false]) exitWith { false };
        if !(_t getVariable ["AP_autopilot", false]) exitWith { false };
        private _drv = driver _t;
        (!isNull _drv) && {isPlayer _drv} && {_drv isNotEqualTo _hacker} && {alive _drv}};
    if (_kind isEqualTo "drivable") exitWith {
        // Puppet Strings: any car (empty OR occupied) with a working autopilot, not analog, and not the seat the
        // hacker is in. Server-authoritative -- a modified client can't forge autopilot/analog/seat.
        if (!((_t isKindOf "Car") || (_t isKindOf "Ship") || (_t isKindOf "Tank"))) exitWith { false };
        if (_t getVariable ["AP_analog", false]) exitWith { false };
        if !(_t getVariable ["AP_autopilot", false]) exitWith { false };
        _t isNotEqualTo (vehicle _hacker)};
    if (_kind isEqualTo "anyveh") exitWith {
        // Leech: any vehicle in range. No autopilot needed -- you're siphoning the tank, not commanding the ECU.
        ((_t isKindOf "Car") || (_t isKindOf "Air") || (_t isKindOf "Ship") || (_t isKindOf "Tank"))};
    if (!(_t isKindOf "CAManBase") || {!(isPlayer _t)}) exitWith { false };   // player-kind: humans only, no AI
    // AUTHORISATION -- cop tools are gated by legality, not rarity
    switch (_auth) do {case "wanted":      { if ((_t getVariable ["AP_wantedAmt", 0]) <= 0) exitWith { false }; true };
        case "restrained":  { if (!((_t getVariable ["AP_restrained", false]) || (_t getVariable ["AP_civRestrained", false]))) exitWith { false }; true };
        case "wantedArmed": {if ((_t getVariable ["AP_wantedAmt", 0]) <= 0) exitWith { false };
            if ((currentWeapon _t) isEqualTo "") exitWith { false };
            true};
        default { true };};};
if !(call _validate) exitWith {
    [["Quickhack rejected -- target no longer valid.", "basic"], "AP_fnc_handleMessage", _hacker, false, false] spawn AP_fnc_MP;};

// victim sees the channel for its full length -- this is the counterplay window
if (_kind isEqualTo "player") then {
    [[format ["<t color='#ff3b1e'>INTRUSION DETECTED</t> -- incoming %1...", toUpper _name], "basic"], "AP_fnc_handleMessage", _t, false, false] spawn AP_fnc_MP;
};

[_id, _t, _hacker, _name, _upload, _kind, _cop, _validate, _aim, _range, _auth, _uid, _cd] spawn {
    params ["_id", "_t", "_hacker", "_name", "_upload", "_kind", "_cop", "_validate", "_aim", "_range", "_auth", "_uid", "_cd"];
    // _auth MUST ride into this scope: `call _validate` below re-runs the closure, and its player-kind branch
    // reads _auth (undefined here before -- "Undefined variable _auth" on every cop wanted/restrained hack).
    uiSleep _upload;                                   // SERVER owns the clock
    if !(call _validate) exitWith {
        [["Upload failed -- the target broke the link.", "basic"], "AP_fnc_handleMessage", _hacker, false, false] spawn AP_fnc_MP;};
    // ArmaQuest "qhcast" (First Cast, Noise Floor): counted here, once the server's own upload clock ran and
    // the target re-validated. It used to be the caster's client saying so, which any client could forge.
    [_hacker, "qhcast"] spawn APS_fnc_aqFact;   // spawn: a completing fact pays out (DB), which must not delay the hack

    // a civilian quickhack is a hack like any other: ICE Trace pings nearby TAL officers unless a
    // Proxy Chain is burned. Cop tools are lawful and never self-report.
    // EXCEPT hacks that carry their OWN, more specific detection: Valet/Recall trace from the vehicle
    // position (below), and Eye Spy uses Loop Detection at the camera. Double-tracing them would fire two
    // alerts for one action.
    if (!_cop && {!(_id in ["valet", "recall", "eyespy"])}) then { [_hacker, format ["QUICKHACK: %1", toUpper _name], getPosATL _hacker] call APS_fnc_iceTrace; };

    // ---- ICE FIREWALL (chip 108): eats exactly ONE Tier 4 hack, then shatters. Resolved server-side because
    // the chip has to be destroyed and persisted -- a client-side block would leave the chip intact forever.
    // The caster still pays: a burned Flatline charge is gone whether or not the ICE ate the hit.
    private _iced = false;
    if (_kind isEqualTo "player" && {_id in ["flatline", "memhole"]}) then {private _vMods = _t getVariable ["AP_cdMods", []];
        if (108 in _vMods && {"icefw" in (_t getVariable ["AP_fwChips", []])}) then {_iced = true;
            _vMods = _vMods - [108];
            _t setVariable ["AP_cdMods", _vMods, true];
            // re-arm cooldown (owner 2026-07-23): after a shatter you can't slot another ICE Firewall for 5 min,
            // so a rich player can't chain-replace a pocket-change hard counter to Tier-4-rarity hacks. Published
            // so the client install gate (fn_useItem) can read it.
            _t setVariable ["AP_iceRearm", serverTime + 300, true];
            [_t, [], [108]] spawn APS_fnc_cdModsSave;   // persists the SERVER's copy, never the public var
            [["<t color='#33ffbb'>ICE FIREWALL</t> -- it ate the intrusion and shattered doing it. Firmware needs ~5 min before it can seat another.", "cyberjackpot"], "AP_fnc_handleMessage", _t, false, false] spawn AP_fnc_MP;
            [["<t color='#ff3b1e'>ICE</t> -- they were running a hard firewall. Your hack died on it.", "basic"], "AP_fnc_handleMessage", _hacker, false, false] spawn AP_fnc_MP;
        };};

    if (_kind isEqualTo "player" && {!_iced}) then {[[_id, _hacker, _name], "AP_fnc_qhEffect", _t, false] spawn AP_fnc_MP;};

    // Web deck (owner 2026-08-12): tell the caster's PAGE how this ended. Every
    // other thing the ICEBREAKER screen needs is already client-side; whether the
    // cast died on an ICE Firewall is not, because chip 108 is resolved here so
    // the chip can be destroyed and persisted. Without this the screen would show
    // a clean hit for a hack that was eaten. The handleMessage reports above are
    // unchanged -- this is the same news on a second channel.
    if (_kind isEqualTo "player") then {
        [[_id, _name, _iced], "AP_fnc_deckQhResult", _hacker, false] spawn AP_fnc_MP;
    };

    switch (_id) do {
        // Ping / Pursuit Tag: server streams the position so a Scrambler Chip can feed a believable lie
        case "ping"; case "pursuit": {private _lie = "scrambler" in (_t getVariable ["AP_fwChips", []]);
            private _off = if (_lie) then {private _a = random 360; private _d = 100 + random 100;
                [_d * cos _a, _d * sin _a, 0]} else { [0,0,0] };
            [_t, _hacker, _off, name _t] spawn {params ["_t", "_hacker", "_off", "_nm"];
                for "_i" from 0 to 9 do {if (isNull _t || {isNull _hacker}) exitWith {};
                    private _p = (getPosATL _t) vectorAdd _off;
                    [[_p, _nm, _i isEqualTo 9], "AP_fnc_qhPing", _hacker, false] spawn AP_fnc_MP;
                    uiSleep 1;};};};
        // Distract / PA: noise at the SOURCE -- the vehicle or player the caster had locked when they
        // fired (AP_cdTarget rides through _t even for area-kind), else the caster's own position.
        // Vehicle lock -> car alarm AT that vehicle; player lock -> their phone rings. Misdirection.
        case "distract"; case "pa": {private _srcPos = getPosATL _hacker;
            private _variant = "alarm";
            if (!isNull _t && {(_hacker distance _t) < 60}) then {         // cfg range 50m + grace
                if ((_t isKindOf "Car") || (_t isKindOf "Air") || (_t isKindOf "Ship") || (_t isKindOf "Tank")) then {
                    _srcPos = getPosATL _t; _variant = selectRandom ["alarm", "horn"];};
                if ((_t isKindOf "CAManBase") && {isPlayer _t}) then {_srcPos = getPosATL _t; _variant = "ringtone";};};
            private _near = allPlayers select { (_x distance _srcPos) < 180 };
            { [[_id, _hacker, _name, [_srcPos, _variant]], "AP_fnc_qhEffect", _x, false] spawn AP_fnc_MP; } forEach _near;};
        // Plate Ghost: spoof the vehicle's registry readout for 5 minutes. The detection roll is fixed
        // at cast time (stored with the ghost) so a cop can't spam Plate Scan until it flips -- one
        // ghost instance is either clean or busted. [expiry, fakeName, detectable]
        case "plateghost": {private _fakes = ["Sam Porter", "Alex Mercer", "Jordan Reyes", "Casey Nova", "Riley Vance",
                              "Morgan Steele", "Dakota Lane", "Quinn Harlow", "Jamie Sixx", "Rowan Hale"];
            _t setVariable ["AP_plateGhost", [serverTime + 300, selectRandom _fakes, (random 1) < 0.5], true];
            [["<t color='#c9e21a'>PLATE GHOSTED</t> -- registry readout spoofed for 5 minutes.", "basic"], "AP_fnc_handleMessage", _hacker, false, false] spawn AP_fnc_MP;
        };

        // ---- JAM.EXE / NEGOTIATION BLACKOUT: a 50m comms blackout. Reuses the Silence Cell gate
        // (AP_qhSilencedUntil) so there is exactly ONE mute mechanism in the codebase rather than two that
        // drift apart. Everyone caught in it is told what happened -- an unexplained dead radio reads as a bug.
        case "jam"; case "blackout": {private _centre = getPosATL _hacker;
            private _caught = allPlayers select { (_x distance2D _centre) < 50 && {_x isNotEqualTo _hacker} };
            { [[_id, _hacker, _name], "AP_fnc_qhEffect", _x, false] spawn AP_fnc_MP; } forEach _caught;
            [[format ["<t color='#c9e21a'>JAM FIELD UP</t> -- %1 handset(s) inside the bubble.", count _caught], "basic"], "AP_fnc_handleMessage", _hacker, false, false] spawn AP_fnc_MP;
        };

        // ---- WIRETAP / WARRANT TAP: a 3-minute read on the target's texts. The tap lives on the SERVER
        // (APS_fnc_handlePhoneMsg mirrors matching traffic to the tapper) because the messages never touch
        // the tapper's client otherwise. An Encrypted SIM turns the feed to garbage AND tells the victim.
        case "wiretap"; case "warranttap": {private _enc = "encsim" in (_t getVariable ["AP_fwChips", []]);
            private _taps = (localNamespace getVariable ["APS_wiretaps", []]) select { (_x param [2, 0]) > serverTime };
            _taps pushBack [getPlayerUID _hacker, getPlayerUID _t, serverTime + 180, _enc];
            localNamespace setVariable ["APS_wiretaps", _taps];   // localNamespace: a published AP_wiretaps row tapped anyone
            if (_enc) then {
                [["<t color='#33ffbb'>ENCRYPTED SIM</t> -- someone just tried to tap your line. Their feed is garbage.", "basic"], "AP_fnc_handleMessage", _t, false, false] spawn AP_fnc_MP;
            };
            [["<t color='#c9e21a'>TAP LIVE</t> -- 3 minutes of their traffic mirrors to your phone.", "basic"], "AP_fnc_handleMessage", _hacker, false, false] spawn AP_fnc_MP;
        };

        // ---- CRYBABY: a fake 911 at the caster's aim point. The abuse meter is the counter (spec's Dispatch
        // Verification): three fakes inside 15 minutes and dispatch resolves the sender for MaxSec. The aim
        // point is re-clamped to the catalogue range here, so a spoofed one can still only be a legal one.
        case "crybaby": {private _pos = if (_aim isEqualTo []) then { getPosATL _hacker } else { _aim };
            if ((_hacker distance2D _pos) > (_range * 1.25)) then { _pos = getPosATL _hacker; };
            private _fakes = (_hacker getVariable ["AP_crybabyLog", []]) select { _x > (serverTime - 900) };
            _fakes pushBack serverTime;
            _hacker setVariable ["AP_crybabyLog", _fakes];
            private _burned = (count _fakes) >= 3;
            private _who = if (_burned) then { format ["%1 (TRACE: %2)", selectRandom ["Unknown caller", "Withheld number", "Payphone"], name _hacker] } else { selectRandom ["Unknown caller", "Withheld number", "Payphone"] };
            private _bar = format ["<t size='1.3' color='#4aa3ff'>911 - %1</t><br/><t size='1.05'>%2</t>", _who, selectRandom [
                "Shots fired, I heard shots fired!", "There's a guy with a rifle out here.",
                "Someone's breaking into a car, hurry.", "I think that's a body in the road."]]; {
                [[_bar, "copalert"], "AP_fnc_handleMessage", _x, false, false] spawn AP_fnc_MP;
                [[_pos, "911 CALL", "ColorBlue", false], "AP_fnc_talMarker", _x, false] spawn AP_fnc_MP;
            } forEach (allPlayers select { _x call APS_fnc_isDutyCop });
            if (_burned) then {
                [["<t color='#ff3b1e'>DISPATCH VERIFICATION</t> -- that was your third fake call. They traced it back to you.", "warning"], "AP_fnc_handleMessage", _hacker, false, false] spawn AP_fnc_MP;
            };
            ["-QUICKHACK-", _hacker, name _hacker, format ["CRYBABY fake 911 at %1 (fakes in window: %2, burned: %3)", _pos, count _fakes, _burned]] call APS_fnc_logIt;
        };

        // ---- DECOY UNIT: poisons the illegal scanner net with a patrol blip that is not there. Only players
        // running illegal firmware see it -- they are the ones listening in, so they are the ones who can be lied to.
        case "decoy": {private _pos = if (_aim isEqualTo []) then { getPosATL _hacker } else { _aim };
            if ((_hacker distance2D _pos) > (_range * 1.25)) then { _pos = getPosATL _hacker; };
            private _listeners = allPlayers select { (side _x) isEqualTo civilian && {0 in (_x getVariable ["AP_cdMods", []])} };
            { [[_pos, "MAXSEC UNIT", "ColorBlue", false], "AP_fnc_talMarker", _x, false] spawn AP_fnc_MP; } forEach _listeners;
            [[format ["<t color='#f0a01e'>DECOY PLACED</t> -- %1 scanner(s) took the bait.", count _listeners], "basic"], "AP_fnc_handleMessage", _hacker, false, false] spawn AP_fnc_MP;
        };

        // ---- VALET PROTOCOL / IMPOUND RECALL: the autopilot suite's entry tier. You never get the steering
        // wheel -- you get the autopilot's clipboard, and only for an EMPTY car. Everything the spec calls the
        // ASIMOV LOCK is enforced by the supervisor below: no water, no cliffs, no driving through people.
        // Valet needs the caster's keys; Recall needs an abandoned (crewless, unowned-nearby) vehicle.
        case "valet"; case "recall": {private _uid = getPlayerUID _hacker;
            private _cands = (nearestObjects [getPosATL _hacker, ["LandVehicle"], _range]) select {alive _x
                && {canMove _x}
                && {(crew _x) isEqualTo []}                                   // EMPTY only -- occupied cars are Tier 3+
                && {!(_x getVariable ["hc_ap_driving", false])}};
            if (_id isEqualTo "valet") then {_cands = _cands select {
                    private _owners = _x getVariable ["AP_vehOwners", _x getVariable ["vehicle_info_owners", []]];
                    (_owners findIf { (_x param [0, ""]) isEqualTo _uid }) > -1};} else {
                // Impound Recall: only vehicles nobody is standing with -- an abandoned car, not somebody's ride
                // they just stepped out of. 40m of clear space around it is the "abandoned" test.
                // NB: capture the outer vehicle before the inner findIf -- a nested select/findIf rebinds _x,
                // so testing `_x distance2D _x` would silently compare each player to themselves (always 0)
                // and mark every vehicle abandoned.
                _cands = _cands select {private _v = _x;
                    (allPlayers findIf { (_x distance2D _v) < 40 }) isEqualTo -1};};
            if (_cands isEqualTo []) exitWith {
                [[format ["<t color='#ff3b1e'>NOTHING TO CALL</t> -- no eligible empty vehicle inside %1m.", _range], "basic"], "AP_fnc_handleMessage", _hacker, false, false] spawn AP_fnc_MP;
            };
            private _veh = _cands select 0;
            { if ((_x distance2D _hacker) < (_veh distance2D _hacker)) then { _veh = _x; }; } forEach _cands;
            if (_veh getVariable ["AP_analog", false]) exitWith {
                [["<t color='#ff3b1e'>NO AUTOPILOT</t> -- that one is an analog retrofit. Nothing to call.", "basic"], "AP_fnc_handleMessage", _hacker, false, false] spawn AP_fnc_MP;
            };
            if !(_veh getVariable ["AP_autopilot", false]) exitWith {
                [["<t color='#ff3b1e'>NO AUTOPILOT MODULE</t> -- that vehicle has no self-drive hardware fitted.", "basic"], "AP_fnc_handleMessage", _hacker, false, false] spawn AP_fnc_MP;
            };

            _veh setOwner 2;                                                  // drive it from the server (hcDrive needs it LOCAL)
            _veh setVariable ["hc_ap_arrive", 8, true];
            _veh setVariable ["AP_valetBy", _uid, true];
            [_veh, _hacker, _id, _name] spawn {params ["_veh", "_hacker", "_id", "_name"];
                uiSleep 1.5;                                                  // let the locality handover settle
                if (isNull _veh || {isNull _hacker}) exitWith {};
                private _ok = [_veh, getPosATL _hacker, "sloth"] call AP_fnc_hcDrive;   // cautious ~50km/h
                if (!_ok) exitWith {
                    [["<t color='#ff3b1e'>ROUTE FAILED</t> -- the autopilot could not plot a way to you.", "basic"], "AP_fnc_handleMessage", _hacker, false, false] spawn AP_fnc_MP;
                    _veh setVariable ["AP_valetBy", nil, true];};
                if (sunOrMoon < 0.5) then { _veh setPilotLight true; };       // headlights at night: a valet is not a ghost

                // ---- ASIMOV LOCK ---- read-only safety firmware. The hacker forges instructions to the car's
                // autopilot; they never get the wheel, and these three limits are not purchasable away.
                [_veh] spawn {params ["_v"];
                    while { !isNull _v && {_v getVariable ["hc_ap_driving", false]} } do {private _spd = (speed _v) max 0;
                        private _look = ((_spd / 3.6) * 2.2) max 9;           // ~2s of stopping distance, min 9m
                        private _p  = getPosATL _v;
                        private _fw = _p vectorAdd ((vectorDir _v) vectorMultiply _look);
                        private _stop = "";
                        if (surfaceIsWater _fw) then { _stop = "water ahead"; };
                        if (_stop isEqualTo "") then {
                            // cliff: a big terrain step inside the look-ahead is a drop the autopilot refuses
                            private _dz = (getTerrainHeightASL [_fw select 0, _fw select 1]) - (getTerrainHeightASL [_p select 0, _p select 1]);
                            if (_dz < -8) then { _stop = "drop ahead"; };};
                        if (_stop isEqualTo "" && {_spd > 12}) then {
                            private _ppl = (_fw nearEntities ["CAManBase", 7]) select { alive _x && {isNull objectParent _x} };
                            if (_ppl isNotEqualTo []) then { _stop = "person in the road"; };};
                        if (_stop isNotEqualTo "") then {_v setVariable ["hc_ap_abort", true, true];
                            _v setVariable ["AP_asimov", _stop, true];};
                        uiSleep 0.4;};};

                // report the outcome, and always clear the valet tag so the car can be called again
                waitUntil { uiSleep 1; (isNull _veh) || {(_veh getVariable ["hc_ap_done", ""]) isNotEqualTo ""} };
                if (isNull _veh) exitWith {};
                private _done = _veh getVariable ["hc_ap_done", ""];
                private _why  = _veh getVariable ["AP_asimov", ""];
                _veh setVariable ["AP_valetBy", nil, true];
                _veh setVariable ["AP_asimov", nil, true];
                if (isNull _hacker) exitWith {};
                private _msg = switch (true) do {
                    case (_done isEqualTo "arrived"): { "<t color='#c9e21a'>VALET ARRIVED</t> -- it is parked on you." };
                    case (_why isNotEqualTo ""): { format ["<t color='#f0a01e'>AUTOPILOT STOPPED</t> -- safety firmware: %1. Go the rest of the way yourself.", _why] };
                    default { format ["<t color='#ff3b1e'>VALET ENDED</t> -- %1.", _done] };};
                [[_msg, "basic"], "AP_fnc_handleMessage", _hacker, false, false] spawn AP_fnc_MP;};
            // a driverless car is a rolling trace beacon: MaxSec hear it move (spec lever). Cop Recall is lawful.
            if (!_cop) then { [_hacker, "AUTOPILOT HIJACK", getPosATL _veh] call APS_fnc_iceTrace; };};

        // ---- CHAUFFEUR OVERRIDE: re-route an OCCUPIED car. The drive itself runs on the VICTIM's client (the
        // car is local to its driver), so the server's job is to kick it off on the driver, hold the link-range
        // leash, and tell the hacker. The victim owns the wrestle / kill-switch / bail because only their client
        // sees their input; the server owns the 300m link so a hacker can't kidnap from across the map.
        case "chauffeur": {private _victim = driver _t;
            if (isNull _victim || {!isPlayer _victim}) exitWith {
                [["<t color='#ff3b1e'>HIJACK FAILED</t> -- the seat emptied before the upload finished.", "basic"], "AP_fnc_handleMessage", _hacker, false, false] spawn AP_fnc_MP;
            };
            if ([_victim, _hacker] call APS_fnc_qhDeadmanSRV) exitWith {};     // Dead Man's Clutch caught it

            private _dest = if (_aim isEqualTo []) then { getPosATL _hacker } else { _aim };
            _t setVariable ["AP_chauffeurActive", true, true];
            _t setVariable ["AP_chauffeurAbort", 0, true];
            _t setVariable ["AP_chauffeurBy", getPlayerUID _hacker, true];
            [[_dest, _hacker, 60], "AP_fnc_qhChauffeur", _victim, false] spawn AP_fnc_MP;
            [["<t color='#c9e21a'>CHAUFFEUR LIVE</t> -- their autopilot is yours. Stay within 300m or the link drops.", "basic"], "AP_fnc_handleMessage", _hacker, false, false] spawn AP_fnc_MP;
            ["-QUICKHACK-", _hacker, name _hacker, format ["CHAUFFEUR OVERRIDE on %1 (driver %2) -> %3", typeOf _t, name _victim, mapGridPosition _dest]] call APS_fnc_logIt;
            // link-range leash: the server owns this because the victim client can't see the hacker's position.
            [_hacker, _t] spawn {params ["_h", "_v"];
                uiSleep 3;                                                   // let the victim client engage
                while { !isNull _v && {_v getVariable ["AP_chauffeurActive", false]} } do {
                    if (isNull _h || {!alive _h} || {(_h distance _v) > 300}) exitWith {
                        if (!isNull _v) then { _v setVariable ["AP_chauffeurAbort", serverTime, true]; };
                        if (!isNull _h) then { [["<t color='#ff3b1e'>LINK LOST</t> -- you fell out of range of the vehicle.", "basic"], "AP_fnc_handleMessage", _h, false, false] spawn AP_fnc_MP; };
                    };
                    uiSleep 2;};};};

        // ---- LEECH: siphon the target vehicle's fuel while the hacker holds within range. Server owns the drain
        // so it can't be spoofed. SEALED TANK (a firewall chip that stamps pulled cars) blocks it outright.
        case "leech": {if (_t getVariable ["AP_sealedTank", false]) exitWith {
                [["<t color='#ff3b1e'>SEALED TANK</t> -- armoured fuel system. Nothing to siphon.", "basic"], "AP_fnc_handleMessage", _hacker, false, false] spawn AP_fnc_MP;
            };
            [_t, _hacker, _range] spawn {params ["_v", "_h", "_rng"];
                private _end = time + 12;
                // Track the target fuel LOCALLY and decrement monotonically. Re-reading `fuel _v` each tick was
                // the bug: setFuel is applied on the car's OWNER (occupied = driver-local), and the server's
                // `fuel _v` lags behind that write -- so every iteration recomputed (stale_fuel - 0.06) and just
                // re-set the SAME value, draining 6% once and plateauing. A monotonic counter drains for real.
                private _tgt = fuel _v;
                while { !isNull _v && {!isNull _h} && {alive _h} && {time < _end} && {(_h distance _v) < (_rng + 6)} && {_tgt > 0.02} } do {
                    _tgt = (_tgt - 0.06) max 0;                             // setFuel runs on the vehicle's OWNER
                    [[_v, _tgt], "AP_fnc_setFuel", _v] spawn AP_fnc_MP;   // ~6%/0.8s -> gutted in ~12s
                    uiSleep 0.8;};
                if (!isNull _h) then {
                    [[format ["<t color='#c9e21a'>LEECH</t> -- tank drained to %1%2.", round (_tgt * 100), "%"], "basic"], "AP_fnc_handleMessage", _h, false, false] spawn AP_fnc_MP;
                };};
            { [["<t color='#ff9a1e'>FUEL SIPHON</t> -- someone is draining your tank.", "basic"], "AP_fnc_handleMessage", _x, false, false] spawn AP_fnc_MP; } forEach (crew _t select { isPlayer _x });
        };

        // ---- SHORT CIRCUIT: the ONE direct-damage hack -- a deliberately weak finisher. Server applies the
        // damage (client-authoritative HP is the trust boundary); Surge Protector halves it. The sparking-screen
        // half is pushed to the victim via qhEffect below.
        case "short": {private _surge = "surge" in (_t getVariable ["AP_fwChips", []]);
            private _dmg = if (_surge) then { 0.08 } else { 0.16 };        // ~8 / ~16 HP of 100
            _t setDamage ((damage _t) + _dmg min 0.95);                    // never the kill blow by itself
        };

        // ---- PUPPET STRINGS (Tier 4): full-manual deck-dive. The hacker DRIVES the car themselves, so the car
        // must be LOCAL to them -- setOwner it to the hacker and let their client run the whole dive. The chip
        // is a PERMANENT install (owner 2026-07-22 -- was burn-per-cast); the server still re-checks it so a
        // modified client can't cast uninstalled. The server holds the jam leash (a jam field cuts the dive,
        // both ways) and confirms the car survives; damage-to-the-body and battery are the hacker client's to enforce.
        case "puppet": {private _owned = _hacker getVariable ["AP_cdMods", []];
            if !(205 in _owned) exitWith {
                [["<t color='#ff3b1e'>NO CHIP</t> -- Puppet Strings chip not installed.", "basic"], "AP_fnc_handleMessage", _hacker, false, false] spawn AP_fnc_MP;
            };

            // Dead Man's Clutch: the driver's car auto-severs the hijack before it takes hold. The hack fired,
            // it just hit a hard counter, same as any other -- the cooldown is the only cost either way.
            if (!isNull (driver _t) && {[driver _t, _hacker] call APS_fnc_qhDeadmanSRV}) exitWith {
                _t setVariable ["AP_puppetActive", false, true];};
            _t setVariable ["AP_puppetActive", true, true];
            // ---- SEAT + DECOY model (owner-chosen 2026-07-21): the hacker drives with NATIVE PhysX from the
            // driver seat (smooth), and a slumped DECOY of them stands at the cast spot as the vulnerable "meat
            // body". The SEATING (moveInDriver) is done on the HACKER's client (AP_fnc_qhPuppet) because a
            // player is local to their own machine -- doing it here on the server did nothing. Forcing the seat
            // also ejects any current driver, so an occupied car's victim is bumped out on the hacker's side. ----
            private _origin = getPosATL _hacker;
            private _hdir   = getDir _hacker;
            private _empty  = isNull (driver _t);

            // decoy meat body: a slumped, shootable copy of the hacker at the cast spot. A hit to it severs.
            // createUnit is server-authoritative, so this part IS correct on the server.
            private _grp = createGroup [civilian, true];
            private _decoy = _grp createUnit [typeOf _hacker, _origin, [], 0, "NONE"];
            _decoy setDir _hdir;
            _decoy setUnitLoadout (getUnitLoadout _hacker);
            _decoy disableAI "ALL";
            _decoy setCaptive true;                                         // not a combatant, just a body
            _decoy allowDamage true;
            _decoy switchMove "amovppnemstpsnonwnondnon";

            [[_t, 50, _origin], "AP_fnc_qhPuppet", _hacker, false] spawn AP_fnc_MP;   // hacker seats + supervises
            ["-QUICKHACK-", _hacker, name _hacker, format ["PUPPET STRINGS on %1 (%2)", typeOf _t, if (_empty) then {"empty"} else {"occupied"}]] call APS_fnc_logIt;

            // SERVER MANAGER: owns the sever TRIGGERS (decoy shot / jam / battery backstop) and deletes the
            // decoy. The unit moves (get the hacker out, snap them back) are done client-side in AP_fnc_qhPuppet
            // because the player is local there -- the server can't move a remote player unit.
            [_hacker, _t, _decoy, _grp] spawn {params ["_h", "_v", "_decoy", "_grp"];
                private _d0 = damage _decoy;
                private _hard = time + 55;
                waitUntil {uiSleep 0.4;
                    private _jams = (localNamespace getVariable ["APS_deckJam", []]) select { (_x param [1, 0]) > serverTime };
                    private _jammed = isNull _h || {!alive _h} || {(_jams findIf { ((getPosATL _h) distance2D (_x param [0, [0,0,0]])) < 80 }) > -1};
                    private _bodyHit = isNull _decoy || {!alive _decoy} || {(damage _decoy) > (_d0 + 0.03)};
                    if (_bodyHit && {!isNull _h}) then { [["<t color='#ff3b1e'>LINK SEVERED</t> -- your meat body was hit.", "basic"], "AP_fnc_handleMessage", _h, false, false] spawn AP_fnc_MP; };
                    if (_jammed && {!isNull _h}) then { [["<t color='#ff3b1e'>LINK SEVERED</t> -- signal jammed.", "basic"], "AP_fnc_handleMessage", _h, false, false] spawn AP_fnc_MP; };
                    (isNull _v) || {!(_v getVariable ["AP_puppetActive", false])} || _jammed || _bodyHit || {time > _hard}};
                if (!isNull _v) then { _v setVariable ["AP_puppetActive", false, true]; };   // hacker fn sees this -> gets out
                uiSleep 1;                                                  // let the hacker's client vacate the seat first
                if (!isNull _decoy) then { deleteVehicle _decoy; };
                if (!isNull _grp) then { { deleteVehicle _x } forEach (units _grp); deleteGroup _grp; };};};

        // ---- EYE SPY: hijack the nearest CCTV in the shared registry and stream it to the caster for 30s.
        // The feed is client-local (rendered by AP_fnc_qhEyeSpy on the caster), but the SERVER owns which
        // camera, the range check and LOOP DETECTION: if any officer is within 250m of the hijacked camera,
        // dispatch gets a "camera anomaly" alert with the camera's name and location. The feed still opens --
        // casing a hot camera rats you out rather than failing.
        case "eyespy": {
            // candidates = the 14 fixed registry cams PLUS any player-placed street cameras (furn_cctv =
            // Land_Camera_01_F) near the hacker. Each is a [pos, dir, tilt, name] spec; pick the nearest in range.
            private _hp = getPosATL _hacker;
            private _cands = (missionNamespace getVariable ["AP_cctvCams", []]) apply { [_x param [0,[0,0,0]], _x param [1,0], _x param [2,-20], _x param [4,"CAMERA"]] };
            {_cands pushBack [getPosATL _x, getDir _x, -18, "Street Cam"];} forEach (nearestObjects [_hp, ["Land_Camera_01_F"], _range]);
            private _best = []; private _bd = 1e12;
            { private _d = _hp distance2D (_x param [0, [0,0,0]]); if (_d < _bd) then { _bd = _d; _best = _x; }; } forEach _cands;
            if (_best isEqualTo [] || {_bd > (_range * 1.25)}) exitWith {
                [["<t color='#ff3b1e'>NO CAMERA IN RANGE</t> -- get closer to a surveillance point.", "basic"], "AP_fnc_handleMessage", _hacker, false, false] spawn AP_fnc_MP;
            };
            private _camName = _best param [3, "CAMERA"];
            private _camPos  = _best param [0, [0,0,0]];
            [[_best, 30], "AP_fnc_qhEyeSpy", _hacker, false] spawn AP_fnc_MP;
            // Loop Detection: an officer near the tapped camera notices the anomaly.
            private _copsNear = allPlayers select { (_x call APS_fnc_isDutyCop) && {alive _x} && {(_x distance2D _camPos) < 250} };
            if (_copsNear isNotEqualTo []) then {{
                    [[format ["<t size='1.2' color='#4aa3ff'>CAMERA ANOMALY</t><br/>Unauthorised access on <t color='#dbe4ee'>%1</t>. Signal traced to the feed's location.", _camName], "copalert"], "AP_fnc_handleMessage", _x, false, false] spawn AP_fnc_MP;
                    [[_camPos, format ["TAP: %1", _camName], "ColorBlue", false], "AP_fnc_talMarker", _x, false] spawn AP_fnc_MP;
                } forEach _copsNear;
                [["<t color='#ff3b1e'>LOOP DETECTED</t> -- a unit near the camera flagged the tap. They know its location.", "basic"], "AP_fnc_handleMessage", _hacker, false, false] spawn AP_fnc_MP;
            };
            ["-QUICKHACK-", _hacker, name _hacker, format ["EYE SPY on %1 (cops near: %2)", _camName, count _copsNear]] call APS_fnc_logIt;
        };

        // ---- BLACKOUT (Tier 4): the lamp-killing technique from the admin blackout event, scoped down to one
        // block for 60s. Deliberately NOT a call into APS_fnc_eventBlackoutSRV -- that one claims the global
        // AP_adminEvent slot, broadcasts server-wide and pushes a news story, so letting a player fire it
        // would let one quickhack block every scheduled world event for ten minutes.
        case "gridout": {private _pos = getPosATL _hacker;
            // GRID PRIORITY exemption (partial): PD/hospital run backup generators, so lamps within 120m of a
            // police HQ are left alone. HQ centroids are derived from the west spawn markers present on the server.
            private _hqs = ["cop_spawn_1","cop_spawn_2","cop_spawn_3","cop_spawn_4","medic_spawn_1"] apply { getMarkerPos _x };
            private _lamps = ((_pos nearObjects ["Lamps_base_F", 150]) + (_pos nearObjects ["PowerLines_base_F", 150])) select {
                private _lp = getPosATL _x;
                (_hqs findIf { _x distance2D _lp < 120 }) isEqualTo -1};
            { _x switchLight "OFF"; } forEach _lamps; {
                [["<t color='#ff3b1e'>THE LIGHTS JUST DIED</t> -- the whole block is dark.", "basic"], "AP_fnc_handleMessage", _x, false, false] spawn AP_fnc_MP;
            } forEach (allPlayers select { (_x distance2D _pos) < 200 });
            ["-QUICKHACK-", _hacker, name _hacker, format ["BLACKOUT: %1 lamps dark at %2", count _lamps, mapGridPosition _pos]] call APS_fnc_logIt;
            // register the blackout so a cop's Grid Priority can bring it back early
            private _events = localNamespace getVariable ["APS_gridBlackout", []];
            _events pushBack [_lamps, serverTime + 60, _pos];
            localNamespace setVariable ["APS_gridBlackout", (_events select { serverTime < (_x param [1, 0]) })];
            [_lamps] spawn {params ["_lamps"];
                uiSleep 60;
                { if (!isNull _x) then { _x switchLight "AUTO"; }; } forEach _lamps;   // grid recovers -- always reversible
            };};

        // ---- MEMORY HOLE (Tier 4): the victim's own memory is wiped client-side (qhEffect). Here the server
        // records WHO did it (name + a 30-min window) so a cop's Black Box Subpoena can recover the identity the
        // wipe was meant to erase. Stored on the victim, published so the TAL query can read it.
        case "memhole": {_t setVariable ["AP_memHoleBy", [name _hacker, serverTime + 1800], true];};

        // FLATLINE (Tier 4): no server case needed since the chip became a permanent install (owner
        // 2026-07-22, chips unlock forever) -- the old case existed only to burn id 203 per cast.

        // ---- DETONATE (Tier 4 apex, owner 2026-08-03). The only LETHAL quickhack, so every part of it is
        // server-side: the fuse, the link check, the explosion, the charge and the log. A client is told what
        // happened, it never decides it.
        //
        // The upload already landed by the time we get here. Now the cell is ARMED for 3s, and the hacker has
        // to HOLD the link -- alive, inside _range, unbroken line of sight. That hold IS the counterplay
        // (there is no counter chip): shoot them, break LOS, or drive out of 20m and it fizzles. The cooldown
        // is stamped either way, so a defused cast still costs the full 2 hours.
        case "detonate": {
            // Stamp the cooldown FIRST, before the fuse can be interrupted -- otherwise disconnecting during
            // the fuse would leave the hack free to re-cast on reconnect.
            if (_uid isNotEqualTo "") then {
                [format ["UPDATE players SET qh_detonate_cd = (NOW() + interval '%2 second') WHERE playerid='%1'", _uid, round _cd]] spawn DB_fnc_asyncQuery;
            };
            [_t, _hacker, _range, _name] spawn {
                params ["_v", "_h", "_rng", "_nm"];
                // ARMED: the crew get their own warning, distinct from the intrusion bar they already saw.
                // 3 seconds is enough to bail out of a ground vehicle and not enough to be safe about it.
                {[[2, "<t color='#ff3b1e'>DEVICE ARMED</t> -- the cell is overloading. BAIL OUT."], "AP_fnc_broadcast", _x] spawn AP_fnc_MP;} forEach (crew _v);
                [[_v, "caralarm"], "AP_fnc_playSound", _v] spawn AP_fnc_MP;

                private _end = time + 3;
                private _held = true;
                private _lost = "";
                while { time < _end } do {
                    if (isNull _v || {!alive _v} || {isNull _h} || {!alive _h}) exitWith { _held = false; _lost = "hacker or target died"; };
                    if ((_h distance _v) > _rng) exitWith { _held = false; _lost = format ["out of range (%1m > %2m)", round (_h distance _v), _rng]; };
                    // LOS via lineIntersectsSurfaces, NOT checkVisibility. checkVisibility takes ONE ignore
                    // object and aimPos returns the CENTRE of the target's geometry (BIKI: "middle of the
                    // geometry"), i.e. a point inside the hull -- so the ray was occluded by the target car
                    // itself on every tick and the fuse always reported "link lost", even standing still.
                    // lineIntersectsSurfaces ignores BOTH ends explicitly; an empty result means clear.
                    if (count (lineIntersectsSurfaces [eyePos _h, aimPos _v, _h, _v, true, 1, "VIEW", "GEOM"]) > 0) exitWith {
                        _held = false; _lost = "line of sight blocked"; };
                    uiSleep 0.25;
                };
                if (!_held) exitWith {
                    [["<t color='#ff3b1e'>LINK LOST</t> -- the charge fizzled. Firmware is spent either way.", "basic"], "AP_fnc_handleMessage", _h, false, false] spawn AP_fnc_MP;
                    if (!isNull _v) then {{[[2, "The overload collapsed. Your cell holds."], "AP_fnc_broadcast", _x] spawn AP_fnc_MP;} forEach (crew _v);};
                    // log WHICH of the three hold conditions broke -- "link lost" alone gave no way to tell a
                    // real defuse from a bug in the check, which is exactly how the aimPos occlusion hid.
                    ["-DETONATE-", _h, name _h, format ["charge fizzled on a %1 -- %2", (if (isNull _v) then {"vehicle"} else {getText (configFile >> "CfgVehicles" >> (typeOf _v) >> "displayName")}), _lost]] call APS_fnc_logIt;
                };

                // ---- detonation. Capture the crew BEFORE the blast: after setDamage they are dead men and
                // `crew` no longer tells us who we killed, which is what the charge is scaled on.
                private _victims = (crew _v) select { isPlayer _x && {alive _x} && {_x isNotEqualTo _h} };
                (_v getVariable ["AP_dbInfo", []]) params [["_vehOwner", "", [""]], ["_plate", -1, [0]]];
                private _vName = getText (configFile >> "CfgVehicles" >> (typeOf _v) >> "displayName");
                private _pos = getPosATL _v;

                // same explosion the speedbomb uses, so it reads identically to anyone who has seen one
                private _bomb = "Bo_Mk82" createVehicle [0, 0, 9999];
                _bomb setPosATL _pos;
                { _x setDamage 1; } forEach (nearestObjects [_v, ["Car", "Truck", "Air", "Ship"], 10]);

                // EXPLOSIVE TERRORISM (charge 2) -- the charge speedbomb already uses for the same act.
                // Amount scales with the body count; APS_fnc_wantedAdd clamps 1..5 server-side anyway.
                [2, _h, ((count _victims) max 1) min 5] call APS_fnc_wantedAdd;

                ["-DETONATE-", _h, name _h, format ["detonated a %1, Plate: %2, owner: %3, killed: %4, POS: %5", _vName, _plate, _vehOwner, (if (_victims isEqualTo []) then {"nobody (empty)"} else {(_victims apply {name _x}) joinString ", "}), _pos]] call APS_fnc_logIt;
                [[0, format ["A vehicle has been detonated by a remote intrusion near %1.", mapGridPosition _pos]], "AP_fnc_broadcast", -2] spawn AP_fnc_MP;
                [["<t color='#c9e21a'>DETONATED</t>.", "basic"], "AP_fnc_handleMessage", _h, false, false] spawn AP_fnc_MP;
                // NO stat call here on purpose. fn_statArrUpdate maps slots up to 147, but fn_titleCfg seeds
                // APV_statTotals with `for "_i" from 0 to 144` -- 145 slots. Three mapped stats already write
                // past the end of the array, which is very likely feeding the open stat/title corruption bug.
                // Adding slot 148 for Detonate would build on that. The -DETONATE- log below is the audit
                // trail; wire a stat up only once the array bound and the slot map agree.
            };};

        default {};};

    [[format ["<t color='#c9e21a'>%1</t> -- uploaded.", toUpper _name], "basic"], "AP_fnc_handleMessage", _hacker, false, false] spawn AP_fnc_MP;
    ["-QUICKHACK-", _hacker, name _hacker, format ["%1 -> %2", _name, (if (isNull _t) then {"area"} else {name _t})]] call APS_fnc_logIt;};
