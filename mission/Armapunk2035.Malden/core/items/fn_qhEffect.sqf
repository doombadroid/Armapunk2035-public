// Altis Life game mechanic — fictional in-game "quickhack" ability, game logic only
/*
    File: fn_qhEffect.sqf  (AP_fnc_qhEffect)
    LooneyBin 2026-07-21: runs on the VICTIM. Applies a quickhack's effect, softened (or negated) by an
    equipped firewall chip, then arms the 10s TRACE WINDOW so the victim can hit back.
    Mitigation is decided here because the effect is inherently client-local anyway.
*/
if (isRemoteExecuted && {remoteExecutedOwner != 2}) exitWith {};   // server-origin only: CfgRE allowedTargets limits the target, never the sender
params [["_id", "", [""]], ["_hacker", objNull, [objNull]], ["_name", "", [""]], ["_extra", [], [[]]]];
private _chips = call AP_fnc_fwEquipped;

// --- INTRUSION alert + trace window (targeted hacks only -- an area distraction that announced
// "INTRUSION DETECTED" to every bystander would defeat its own misdirection) ---
if !(_id in ["distract", "pa"]) then {AP_qhLastHacker = _hacker;
    AP_qhTraceUntil = diag_tickTime + 10;
    [format ["<t color='#ff3b1e' size='1.25'>INTRUSION DETECTED</t><br/>%1<br/><t color='#7f918a'>Scroll to TRACE INTRUSION -- 10s</t>", toUpper _name], "basic"] spawn AP_fnc_handleMessage;
    playSound "taskAssigned";
    if (isNil "AP_qhTraceAct") then { AP_qhTraceAct = -1 };
    if (AP_qhTraceAct isEqualTo -1) then {
        AP_qhTraceAct = player addAction ["<t color='#ff3b1e'>TRACE INTRUSION</t>", { [] spawn AP_fnc_qhTrace; },
            nil, 9, false, true, "", "diag_tickTime < (missionNamespace getVariable ['AP_qhTraceUntil', 0])", 12];};};

switch (_id) do {

    // ---- STATIC BURST / DAZZLE: heavy visual noise. Optic Filter cuts it to a 1s fuzz. ----
    case "static";
    case "dazzle": {private _soft = "optic" in _chips;
        private _dur = if (_soft) then { 1 } else { 3 };
        private _amt = if (_soft) then { 0.35 } else { 1 };
        [_dur, _amt] spawn {params ["_dur", "_amt"];
            private _cc = ppEffectCreate ["colorCorrections", 5211];
            _cc ppEffectEnable true;
            _cc ppEffectAdjust [1, 1.4 * _amt, 0.28 * _amt, [0.4,0.4,0.4,0], [1,1,1,0.9*_amt], [0.3,0.6,0.3,0]];
            _cc ppEffectCommit 0;
            private _ca = ppEffectCreate ["chromAberration", 5212];
            _ca ppEffectEnable true;
            _ca ppEffectAdjust [0.06 * _amt, 0.06 * _amt, true];
            _ca ppEffectCommit 0;
            private _fg = ppEffectCreate ["filmGrain", 5213];
            _fg ppEffectEnable true;
            _fg ppEffectAdjust [0.9 * _amt, 2.2, 1, 0.1, 1, false];
            _fg ppEffectCommit 0;
            uiSleep _dur;
            { _x ppEffectEnable false; ppEffectDestroy _x; } forEach [_cc, _ca, _fg];};};

    // ---- WHITEOUT: audio kill. Audio Limiter shortens + softens it. ----
    case "whiteout": {private _soft = "audio" in _chips;
        private _dur = if (_soft) then { 3 } else { 8 };
        private _lvl = if (_soft) then { 0.35 } else { 0 };   // owner 2026-07-21: full deafen (was 0.05)
        [_dur, _lvl] spawn {params ["_dur", "_lvl"];
            0.4 fadeSound _lvl;
            uiSleep _dur;
            1.2 fadeSound 1;};};

    // ---- SILENCE CELL: comms mute, NOT a deafen (spec: outgoing radio/phone). fn_sendText gates every
    // outgoing text/911/dispatch on AP_qhSilencedUntil. Client-local like every other effect (the shipped
    // trust model); Audio Limiter cuts the mute to a third. Voice/side chat can't be gated -- RP rule.
    case "silence": {private _dur = if ("audio" in _chips) then { 20 } else { 60 };
        AP_qhSilencedUntil = diag_tickTime + _dur;
        [format ["<t color='#ff3b1e'>COMMS MUTED</t> -- your phone and radio are jammed for %1s.", _dur], "basic"] spawn AP_fnc_handleMessage;
    };

    // ---- JAM.EXE / NEGOTIATION BLACKOUT: area comms blackout. Shares the Silence Cell gate so there is one
    // mute mechanism, not two. Freq-Hop Radio cuts it to a third. Never SHORTENS an existing mute -- a Silence
    // Cell already running would otherwise be cancelled early by walking through a weaker jam field. ----
    case "jam"; case "blackout": {private _dur = if ("freqhop" in _chips) then { 10 } else { 30 };
        private _until = diag_tickTime + _dur;
        if (_until > (missionNamespace getVariable ["AP_qhSilencedUntil", 0])) then {AP_qhSilencedUntil = _until;};
        [format ["<t color='#ff3b1e'>COMMS JAMMED</t> -- no phone, no radio for %1s.%2", _dur,
            (if ("freqhop" in _chips) then { "<br/><t color='#33ffbb'>Freq-Hop Radio cut it down.</t>" } else { "" })], "basic"] spawn AP_fnc_handleMessage;
    };

    // ---- SYNAPSE DRAG: overload the legs -- no sprint for 8s. Reuses the EXACT gold-bar penalty
    // (forceWalk, the same "can't run" nerf AP_inv_goldbar applies). Ownership stays with the survival loop
    // (fn_survival) via AP_qhSynapseUntil so the two systems never fight over forceWalk -- important, because
    // a stray forceWalk over water is the documented drown footgun (#525). We only set the timer here. ----
    case "synapse": {private _dur = if ("surge" in _chips) then { 4 } else { 8 };   // Surge Protector halves it
        AP_qhSynapseUntil = diag_tickTime + _dur;
        [format ["<t color='#ff3b1e'>SYNAPSE DRAG</t> -- your legs won't fire. No sprint for %1s.%2", _dur,
            (if ("surge" in _chips) then { "<br/><t color='#33ffbb'>Surge Protector softened it.</t>" } else { "" })], "basic"] spawn AP_fnc_handleMessage;
    };

    // ---- SHORT CIRCUIT: the server already applied the (light) damage. Here is the sparking-screen half.
    // Surge Protector halves the screen too. Deliberately brief -- this is a finisher-enabler, not a stun. ----
    case "short": {private _dur = if ("surge" in _chips) then { 1.5 } else { 3 };
        [_dur] spawn {params ["_dur"];
            private _cc = ppEffectCreate ["chromAberration", 5221];
            _cc ppEffectEnable true;
            _cc ppEffectAdjust [0.08, 0.08, true];
            _cc ppEffectCommit 0.1;
            private _fg = ppEffectCreate ["filmGrain", 5222];
            _fg ppEffectEnable true;
            _fg ppEffectAdjust [1, 3, 1, 0.2, 1, false];
            _fg ppEffectCommit 0.1;
            uiSleep _dur;
            { _x ppEffectEnable false; ppEffectDestroy _x; } forEach [_cc, _fg];};
        ["<t color='#ff3b1e'>SHORT CIRCUIT</t> -- sparks across your optics.", "basic"] spawn AP_fnc_handleMessage;};

    // ---- STICKY FINGERS / SAFETY INTERLOCK: forced holster. Hardened Firmware = immune. ----
    case "sticky";
    case "interlock": {if ("hardened" in _chips) exitWith {
            ["<t color='#33ffbb'>HARDENED FIRMWARE</t> -- weapon lock rejected.", "basic"] spawn AP_fnc_handleMessage;};
        [] spawn {player action ["hideWeapon", player, player, 100];
            AP_holstered = true;
            AP_qhWeaponLock = true;
            private _t0 = diag_tickTime;
            while { diag_tickTime - _t0 < 3 } do {
                if !((currentWeapon player) isEqualTo "") then { player action ["hideWeapon", player, player, 100]; };
                uiSleep 0.25;};
            AP_qhWeaponLock = false;};};

    // ---- DISTRACT / PA: noise at the SOURCE the server picked (targeted vehicle, targeted phone, or the
    // caster's own position as fallback). Deliberately weak -- no counter chip. A muted ringer
    // (AP_isRingEnabled, settings idx 5 -- live value, not the defaults array) blocks only the RINGTONE
    // variant; a car alarm is external and always audible. ----
    case "distract"; case "pa": {_extra params [["_srcPos", [], [[]]], ["_variant", "alarm", [""]]];
        if (_srcPos isEqualTo []) then { _srcPos = getPosATL (if (isNull _hacker) then { player } else { _hacker }); };
        switch (_variant) do {case "ringtone": {if (missionNamespace getVariable ["AP_isRingEnabled", true]) then {[_srcPos] spawn {
                        params ["_p"];
                        for "_i" from 0 to 1 do {
                            playSound3D [getMissionPath "sounds\phonering.ogg", objNull, false, ATLToASL _p, 4, 1, 60];
                            uiSleep 3.2;};};};};
            case "horn": { playSound3D [getMissionPath "sounds\horns\hornBattle.ogg", objNull, false, ATLToASL _srcPos, 4, 1, 150]; };
            default { playSound3D ["A3\Sounds_F\sfx\alarm_independent.wss", objNull, false, ATLToASL _srcPos, 3, 1, 150]; };};};

    // ---- FLATLINE (Tier 4): a 5s full ragdoll. No chip softens it -- the ICE Firewall either ate the whole
    // hack server-side or it landed in full. Deliberately not damage: it is a finisher-enabler, not a kill. ----
    case "flatline": {
        // Animation-level collapse ONLY -- deliberately NOT setUnconscious and NOT the medical down state.
        // Entering the revive system would summon medics and could strand a player if the script died mid-way;
        // an animation always ends. It also needs no remoteExec, so nothing to whitelist in CfgRE.
        [] spawn {["<t color='#ff3b1e' size='1.3'>FLATLINE</t><br/>Motor control lost.", "basic"] spawn AP_fnc_handleMessage;
            player setVariable ["AP_qhFlatline", true, true];
            playSound "taskFailed";
            // valid CfgMovesMaia prone-collapse (the mission's own downed move). "Incapacitated" was not a real
            // move name, so switchMove silently did nothing and the victim never dropped.
            player switchMove "amovppnemstpsnonwnondnon";
            private _t0 = diag_tickTime;
            // hold the collapse for 5s, re-asserting it if anything else tries to animate over the top
            while { diag_tickTime - _t0 < 5 && {alive player} } do {
                if ((toLower (animationState player)) find "amovppnemstpsnonwnondnon" < 0) then { player switchMove "amovppnemstpsnonwnondnon"; };
                uiSleep 0.4;};
            player switchMove "";
            player setVariable ["AP_qhFlatline", nil, true];
            ["<t color='#c9e21a'>MOTOR CONTROL BACK</t> -- get up.", "basic"] spawn AP_fnc_handleMessage;};};

    // ---- MEMORY HOLE (Tier 4): wipes the last two minutes. Mechanically it clears what the game remembers
    // ABOUT the attacker on this client -- the suspect list and last-killer record that back a MaxSec report --
    // so "you can't identify them" is enforced, not just role-played. ----
    case "memhole": {AP_suspectInfo = [];
        AP_lastKiller = "";
        AP_qhLastHacker = objNull;                    // you cannot trace what you cannot remember
        AP_qhTraceUntil = 0;
        ["<t color='#ff3b1e' size='1.25'>MEMORY HOLE</t><br/>The last two minutes are gone. You do not know who did this.", "basic"] spawn AP_fnc_handleMessage;
    };

    // ping / pursuit / pa need nothing on the victim beyond the INTRUSION alert above
    default {};};
