/*
    AP_fnc_dutyClient -- the client half of a duty swap. SERVER -> CLIENT only (CfgRE allowedTargets = 1);
    APS_fnc_dutySRV is the only legitimate caller and it has already run every gate before pushing here.

        ["apply", factionId, roleId, dutyLoad, groupNetId]   go on duty
                                                             dutyLoad = DB_fnc_dutyLoad's array:
                                                             [gear, talents, exp, prestigeTalents,
                                                              prestige, licenses]
        ["remove", reason]                                   come off duty ("released" / "watchdog" /
                                                             "flag-off" / ...). The ONE mode that still
                                                             runs with AP_dutyEnabled false -- see the gate.

    ORDERING IS THE WHOLE DESIGN. Four things must not be got wrong:

      * AP_dutyEnabled is the first statement in the file, full stop -- see below. It is a kill-switch, not
        an assertion: with it false, nothing below may run, not even the origin refusal, because a forged
        call refused there still costs an RPT line and the flag being off means there was never a legitimate
        caller to have wired one up in the first place. The single exception, and its exact cost, is
        written out at the gate itself: "remove" is let through, because a shift you cannot END is worse
        than the RPT line.
      * The origin assertion comes right after, before everything else, including any self-respawn -- see
        below.
      * On the way IN, the civilian save has to be flushed BEFORE AP_effSide moves. AP_fnc_ClupdatePartial
        picks its column from AP_effSide (fn_ClupdatePartial.sqf:15-20), so a save that runs one line late
        writes the player's civilian kit and position into cop_gear/med_gear and loses both.
      * On the way OUT, the duty save has to be flushed BEFORE AP_effSide moves back, for the mirror-image
        reason -- and via a bare mode-3 call, because AP_fnc_saveGear only self-saves for civilians
        (fn_saveGear.sqf:57). Save first, flip second, every time.

    AP_dutySwapGuard is held across the whole swap so a second request (terminal spam, a server retry, a
    disconnect sweep racing a release) cannot interleave two half-applied states. It is APPLY-side only: a
    server "remove" that arrives mid-swap WAITS for the guard instead of being dropped, because a dropped
    remove leaves the player rostered-off on the server and still west + geared on the client. Every set of
    the guard arms a stamped 20s self-heal, because SQF has no `finally` and a runtime error inside either
    case body would otherwise leave the guard true for the rest of the session.
*/
// AP_dutyEnabled IS THE FIRST STATEMENT IN THE FILE -- before even the origin assertion below. It is a pure
// kill-switch: with the flag off there is no legitimate call to protect (APS_fnc_dutySRV's own "init" is
// gated on the same flag, per server_init.sqf, so nothing ever wires a real push to this function), and the
// origin gates below are not free -- each is a refusal a forged call can trigger on demand. Checking the
// flag first means a forged call arriving while it is off costs nothing at all: no message, no log, no DB
// write, not even the RPT breadcrumb the origin gates leave. Flag on is the only state in which those gates,
// or anything past them, may run -- with the single documented exception immediately below.
// ONE EXCEPTION, AND IT IS THE ONLY DELIBERATE LOOSENING IN THIS SYSTEM: mode "remove" is let through with
// the flag off, because REMOVAL MUST ALWAYS WORK. Turning the flag off at runtime is the admin kill-switch,
// and under a strict gate the server's own drain push (APS_fnc_dutySRV's flag-off sweep arm) would be
// dropped right here, on arrival -- leaving every rostered player side-west in a duty kit, with no terminal
// to clock off at because that action is flag-gated too, i.e. stranded until a relog that restores no
// civilian character at all. Refusing to come off duty is not a safe failure. "apply" stays shut with no
// exception: nothing may go ON duty while the flag is false, ever.
// WHAT THE LOOSENING COSTS, exactly. A forged "remove" arriving with the flag off now reaches the origin
// assertion below instead of dying one line above it, so it costs one diag_log line in the RECEIVING
// machine's own RPT -- no message, no DB write, nothing on the wire. It does not weaken the assertion: the
// sender must still be owner 2, the server, which no client can forge, so a forged remove is refused with
// the flag off exactly as it is with the flag on. The change is that flag-off now shares the RPT-breadcrumb
// exposure flag-on has always had and already accepts, instead of being free.
// Reading the mode before `params` is safe: `param [0, "", [""]]` types the slot via the third arg (BIKI --
// the two-arg form has no type check and returns a wrong-typed element as-is, it does not default it), so a
// malformed payload reads "" and takes the strict branch.
if (!(missionNamespace getVariable ["AP_dutyEnabled", false])
    && {(toLower (_this param [0, "", [""]])) isNotEqualTo "remove"}) exitWith {};

// SERVER ORIGIN IS MANDATORY, AND IT IS ASSERTED BEFORE EVERYTHING ELSE IN THE FILE. Two separate holes
// close here, and the order matters:
//   * CfgRE's allowedTargets restricts the TARGET, not the sender. allowedTargets = 1 says "clients may be
//     targeted", which a modified client satisfies by remote-executing this AT ITSELF (forge
//     ["apply","maxsec","all",<gear>,<netId>], join the published MaxSec group, take the loadout, never
//     appear on the server's roster) or AT A VICTIM (forge ["remove","released"] and knock somebody off
//     duty, or ["apply",...] and force a stranger into a forged loadout).
//   * remoteExecutedOwner does NOT survive a `spawn`. A `!canSuspend` self-respawn placed above this check
//     hands the re-entered copy a 0 and waves the whole call through, so the guard must be reached first --
//     and an unscheduled arrival is then a refusal, not a re-spawn, because the only legitimate delivery is
//     the server's remoteExec (fn_MP.sqf:34-35 sends _isCall = false for any non-local target), which is
//     always scheduled. Nothing in this tree calls AP_fnc_dutyClient locally; AP_fnc_dutyContext is the
//     local-path function.
// Both refusals are SILENT to every other machine, on purpose -- neither can log a trustworthy -SEC- row.
// Routing them through AP_fnc_MP + APS_fnc_logIt (the old behaviour) round-trips every forged call through
// the SERVER for a DB write, through the serialized extDB3 mutex, unthrottled -- and the row it produces
// names the LOCAL player as subject, i.e. attributes the attack to its VICTIM whenever the forgery targets
// someone else. fn_casinoReceive.sqf:11 is the repo's idiom for exactly this shape of refusal (a bare
// exitWith, no logIt, because client-side logging of a server-origin check cannot attribute correctly). A
// diag_log breadcrumb lands in this machine's own RPT only: worth having for a wiring bug, useless to an
// attacker, and nothing a victim's client can be made to spam into the DB.
if (remoteExecutedOwner isNotEqualTo 2) exitWith {
    diag_log format ["[AP-DUTY] BLOCKED dutyClient: sender owner %1 is not the server. args=%2", remoteExecutedOwner, _this];
};
if (!canSuspend) exitWith {
    diag_log format ["[AP-DUTY] BLOCKED dutyClient: unscheduled delivery. args=%1", _this];
};

params [["_mode", "", [""]]];
private _args = _this;   // captured for the case bodies: only outer PRIVATES are reliably in scope there
if (isNil "AP_onDuty") then { AP_onDuty = false; };
if (isNil "AP_dutyFaction") then { AP_dutyFaction = ""; };
if (isNil "AP_dutySwapGuard") then { AP_dutySwapGuard = false; };

// Guard set + stamped self-heal. The stamp is what makes the timer safe: a swap that finishes normally
// clears the flag, and a LATER swap that is still running when an EARLIER swap's timer fires is protected
// because the stamp no longer matches. Without the timer, one runtime error anywhere between the set and
// the clear locks the player out of the terminal AND out of the server's "remove" for the rest of the session.
private _fnc_guardOn = {
    AP_dutySwapGuardAt = diag_tickTime;
    AP_dutySwapGuard = true;
    [AP_dutySwapGuardAt] spawn {
        params ["_t0"];
        uiSleep 20;
        if (AP_dutySwapGuard && {(missionNamespace getVariable ["AP_dutySwapGuardAt", 0]) isEqualTo _t0}) then {
            AP_dutySwapGuard = false;
            diag_log format ["[AP-DUTY] swap guard self-cleared 20s after the swap that set it (t0 %1)", _t0];
        };
    };
};

// Same stamped self-heal, same reason, for AP_dutyFlushBypass around the flush brackets below: SQF
// try/catch only catches an explicit `throw`, never a plain runtime error, so a runtime error inside a
// bracketed fn_saveGear / fn_ClupdatePartial call would otherwise strand this flag true for the rest of
// the session -- a silent, permanent bypass of the base's no-gear-save ring (fn_saveGear.sqf:25). 10s,
// not 20s: a flush is sub-second, so 10s is generous while nowhere near a real swap's duration.
private _fnc_flushBypassOn = {
    AP_dutyFlushBypassAt = diag_tickTime;
    AP_dutyFlushBypass = true;
    [AP_dutyFlushBypassAt] spawn {
        params ["_t0"];
        uiSleep 10;
        if (AP_dutyFlushBypass && {(missionNamespace getVariable ["AP_dutyFlushBypassAt", 0]) isEqualTo _t0}) then {
            AP_dutyFlushBypass = false;
            diag_log format ["[AP-DUTY] flush bypass self-cleared 10s after the flush that set it (t0 %1)", _t0];
        };
    };
};

// Applying a saved gear packet is NOT `setUnitLoadout <packet>`. fn_saveGear.sqf:45 builds a THREE-element
// wrapper -- [loadout, [virtualInventory, weight], uniform/backpack skin indices] -- and handing the whole
// wrapper to setUnitLoadout strips the player naked, after which the next save bakes the wreckage back into
// the column it came from. This is fn_loadGear.sqf:9-30's unpack (same destructure, same additive
// AP_fnc_handleInv restore, same AP_uniformBackpack_skins assignment) with one addition login does not
// need: the AP_inv_* counters and AP_carryWeight are zeroed FIRST. On connect they are already 0; a duty
// swap runs mid-session with the OTHER character's Y-inventory live, so without the wipe a cop would clock
// on carrying the civilian's contraband and clock off carrying the cop's. The wipe is fn_civLoadout.sqf:16-17
// verbatim. AP_gear is left holding the packet that was just applied, so the next mode-3 save writes THIS
// character rather than the one it replaced.
// Returns TRUE when it applied a packet, FALSE when the packet had no usable loadout element -- a
// never-written or corrupted gear column -- so the caller can fall back instead of leaving the player in
// the character it was about to replace.
private _fnc_applyGear = {
    params [["_packet", [], [[]]]];
    _packet params [["_armaItems", []], ["_virtualInv", [], [[]]], ["_textures", [-1, -1], [[]]]];
    if (!(_armaItems isEqualType []) || {_armaItems isEqualTo []}) exitWith { false };
    AP_carryWeight = 0;
    { missionNamespace setVariable [_x, 0]; } forEach ([1] call AP_fnc_virtItemCfg);
    // RE-BASELINE THE ITEM-COUNT MONITOR, or the wipe above silently blinds it. AP_invMonitor tracks the
    // virtual item total plus the AP_invRVar offset, and it is only ever moved by AP_fnc_handleInv. Zeroing
    // the AP_inv_* counters directly drops the real total to 0 while the monitor still carries the OTHER
    // character's, so the restore below (handleInv, which ADDS) leaves the slack inflated by the whole of
    // the character just swapped away from -- and it compounds on every swap, in both directions, because
    // this helper is what the "remove" arm uses to restore the civilian stash too. Inflated slack is the
    // permissive failure: fn_handleInv.sqf:25's `_totalItemsActual > (AP_invMonitor - AP_invRVar)` stops
    // catching a real dupe. Same idiom as fn_loginBonusGive.sqf:82-84 / fn_dropItems.sqf:19; the sum is 0
    // by construction one line after the wipe, and computing it rather than assigning AP_invRVar keeps it
    // correct if the wipe list and AP_invMonVars ever stop being the same set.
    private _invMonTotal = 0;
    { _invMonTotal = _invMonTotal + (missionNamespace getVariable [_x, 0]); } forEach AP_invMonVars;
    AP_invMonitor = _invMonTotal + AP_invRVar;
    player setUnitLoadout _armaItems;
    private _items = _virtualInv param [0, []];
    if (_items isEqualType [] && {_items isNotEqualTo []}) then {
        { _x params ["_item", "_amount"]; [true, _item, _amount] call AP_fnc_handleInv; } forEach _items;
    };
    AP_uniformBackpack_skins = _textures;
    // fn_loadGear.sqf:35 / fn_equipLoadout.sqf:121 idiom, copied faithfully: setUnitLoadout above rebuilds
    // the backpack as a fresh VISIBLE object even if the player had it hidden, and the setIdx re-skin (the
    // duty case's own post-swap spawn block) skips the invis bag because its skin index is -1. Re-hide it
    // here so a duty swap does not un-hide a backpack the shop already made invisible.
    if ((profileNamespace getVariable ["AP_invisBag", false]) && {(backpack player) isNotEqualTo ""}) then {[true] call AP_fnc_invisBag;};
    AP_gear = _packet;
    true
};

switch (toLower _mode) do {

    case "apply": {
        // Slot 3 is DB_fnc_dutyLoad's WHOLE payload now, not just the gear packet: the duty character's
        // talents, exp, prestige tree and licences ride along with its kit, because a shift that loads one
        // without the others is a half-restored character (see that file's header). Positional and growable
        // at the tail.
        _args params [["_m", "", [""]], ["_faction", "", [""]], ["_role", "", [""]], ["_dutyLoad", [], [[]]], ["_grpNet", "", [""]]];
        private _dutyGear = _dutyLoad param [0, []];
        if !(_dutyGear isEqualType []) then { _dutyGear = []; };
        if (AP_dutySwapGuard) exitWith {
            diag_log "[AP-DUTY] dutyClient apply ignored: a swap is already in flight";
        };
        if (AP_onDuty) exitWith {
            diag_log format ["[AP-DUTY] apply %1 ignored: already on duty as %2", _faction, AP_dutyFaction];
        };
        private _row = [_faction] call AP_fnc_dutyCfg;
        if (_row isEqualTo []) exitWith { diag_log format ["[AP-DUTY] apply refused: unknown faction %1", _faction]; };

        // Resolve the shared group BEFORE touching any state, so a failure leaves the player exactly as
        // they were. The netId in the payload is the authority; the published fallback covers a client that
        // somehow missed it. There is no createGroup fallback on purpose -- a private group would defeat
        // the persistent-shared-group design and put the player on a side nobody else's duty group sees.
        private _grp = if (_grpNet isEqualTo "") then { grpNull } else { groupFromNetId _grpNet };
        if (isNull _grp) then {
            _grp = groupFromNetId (missionNamespace getVariable [format ["%1Net", _row select 2], ""]);
        };
        if (isNull _grp) exitWith {
            ["MaxSec/TT duty roster is not ready. Try again in a moment.", "basic"] spawn AP_fnc_handleMessage;
            [["nak", _faction, "nogroup"], "APS_fnc_dutySRV", 2] spawn AP_fnc_MP;
        };

        call _fnc_guardOn;

        // Flush the civilian character while AP_effSide still says civilian: gear (mode 3) -- half of
        // the pair fn_initCiv.sqf:179's 240s loop persists. Position (mode 10) is DELIBERATELY not
        // flushed here (PR10): clocking on must never move the civilian character's saved position.
        // The in-world return spot is the stash (slot 1, teleported back at clock-off), and the DB
        // `position` column keeps the civ character's own last real save -- so a disconnect mid-shift
        // logs the civilian back in where their civ life left off, not at the HQ terminal. (The held
        // landing-deploy case never wrote it anyway -- fn_ClupdatePartial.sqf's PR9 spawn-hold guard.)
        // AP_dutyFlushBypass brackets ONLY this flush: respawn_west now sits AT the MaxSec HQ terminal
        // (fn_dutyFlushBlock.sqf's header has the full trace), so this civ-gear save is called from right on
        // top of the base's 1000m no-gear-save ring and would otherwise be eaten by fn_saveGear.sqf:7-8 and
        // fn_ClupdatePartial.sqf's case 3 exactly like the terminal action itself used to be. Cleared right
        // after so nothing else that happens to run before the guard drops (below) can ride the exemption.
        call _fnc_flushBypassOn;
        [true] call AP_fnc_saveGear;
        // ...and mode 4, the STANDARD talent tree + exp. It is flushed here for the same reason as the gear:
        // the block below overwrites AP_side_talents/AP_side_exp with the duty character's, and unlike gear
        // those two have no periodic writer of their own -- only this mode, sent on respec/learn
        // (fn_respec.sqf:7, fn_deckTreeAction.sqf:57), and the full save. Any civilian exp earned since the
        // last of those would be overwritten un-persisted. Same ordering rule as everything else on this
        // path: while AP_effSide still says civilian, so it lands in civ_talents/civ_exp.
        [4] call AP_fnc_ClupdatePartial;
        AP_dutyFlushBypass = false;
        AP_dutyFlushBypassAt = 0;

        // ...and then confirm the flush could actually have landed. Both halves of it fail silently, so the
        // only honest check is to re-evaluate their own conditions. Nothing has been mutated yet at this
        // point, so the abort is clean: drop the guard and nak, and the server rolls the roster entry back
        // (APS_fnc_dutySRV "nak" honours it because the entry is unconfirmed and seconds old).
        // The stash is the WHOLE civilian packet AP_fnc_saveGear just rebuilt, not a bare loadout: the
        // virtual inventory and the clothing skins have to come back on clock-off too, and they only
        // round-trip if they are stashed in the same shape they are applied in. An unusable packet is
        // treated as a blocked flush -- going on duty without a restorable civilian character is the one
        // thing this function must never do.
        private _blocked = call AP_fnc_dutyFlushBlock;
        private _civPacket = +(missionNamespace getVariable ["AP_gear", []]);
        if (_blocked isEqualTo "" && {(_civPacket param [0, []]) isEqualTo []}) then { _blocked = "your kit could not be captured"; };
        if (_blocked isNotEqualTo "") exitWith {
            AP_dutySwapGuard = false;
            [format ["Duty swap aborted -- your kit could not be saved (%1).", _blocked], "basic"] spawn AP_fnc_handleMessage;
            [["nak", _faction, format ["flush blocked: %1", _blocked]], "APS_fnc_dutySRV", 2] spawn AP_fnc_MP;
            diag_log format ["[AP-DUTY] apply %1 aborted: civ flush blocked (%2)", _faction, _blocked];
        };

        // Slot 2 is the CIVILIAN's progression, stashed for exactly the same reason as slot 0's kit: the six
        // globals below are "whichever character is live", the duty load is about to overwrite them, and
        // nothing else on the client remembers what the civilian's were. Missing it, a clock-off would leave
        // the cop's trees live on a civilian and the next full save would write them into civ_talents/civ_exp
        // -- the talent equivalent of the civ_gear loss this whole stash exists to prevent.
        // PR9: SLOT 1 IS EMPTY WHEN THERE IS NOWHERE TO PUT THEM BACK. A shift can now be taken from the
        // LANDING SCREEN, i.e. before the player has ever spawned -- they are still frozen on the 50 km
        // mission.sqm slot (initPlayerLocal.sqf:8-19), so getPosATL here is not a place, it is the hold.
        // Restoring it at clock-off would setPosATL the player to 50 km with simulation ON, which is the
        // exact free-fall this subsystem's spawn hold exists to prevent. An empty slot means "leave them
        // where they are", which is already what the watchdog and disconnect removes do.
        private _stashPos = if (missionNamespace getVariable ["AP_spawnHold", false]) then { [] }
                            else { getPosATL player };
        AP_dutyStash = [_civPacket, _stashPos, [
            missionNamespace getVariable ["AP_side_talents", []],
            missionNamespace getVariable ["AP_side_exp", 0],
            missionNamespace getVariable ["AP_cop_talents", []],
            missionNamespace getVariable ["AP_prestige", 0],
            missionNamespace getVariable ["AP_medic_talents", []],
            missionNamespace getVariable ["AP_medic_exp", 0]
        ]];

        [player] joinSilent _grp;

        AP_onDuty = true;
        AP_dutyFaction = _faction;
        AP_copRole = if ((_row select 0) isEqualTo "maxsec") then { _role } else { "" };

        // PROGRESSION BEFORE CONTEXT, and that order is load-bearing: AP_fnc_dutyContext derives
        // AP_track_radius by reading AP_cop_talents (the old cop init's switch verbatim), so setting the
        // tree afterwards would leave every officer on the 1400 m default for the whole shift. The globals
        // are the same ones fn_requestReceived seeds at login (:43-45) and core\configuration.sqf defaults,
        // so every downstream talent gate reads the duty character without knowing duty exists. The trauma pair is named oddly in this tree and it is not a typo: AP_medic_exp holds the TT
        // PRESTIGE CURRENCY (medic_prestige) and AP_medic_talents the TT prestige tree (medic_talents), while
        // the medic STANDARD tree is AP_side_talents/AP_side_exp out of med_talents/med_exp.
        AP_side_talents = _dutyLoad param [1, []];
        AP_side_exp     = _dutyLoad param [2, 0];
        if ((_row select 0) isEqualTo "maxsec") then {
            AP_cop_talents = _dutyLoad param [3, []];
            AP_prestige    = _dutyLoad param [4, 0];
        } else {
            AP_medic_talents = _dutyLoad param [3, []];
            AP_medic_exp     = _dutyLoad param [4, 0];
        };

        // LICENCES, slot 5. Same shape and same application as login's: fn_requestReceived.sqf:223 walks
        // the [full-var-name, bool] pairs from the side's <side>_licenses column and setVariables each one.
        // Nothing has to be saved or restored around this, and that is a property of the naming, not luck:
        // fn_licenseCfg.sqf builds every name as `license_<civ|cop|med>_<id>` off its own side column, so a
        // duty load writes only license_cop_* / license_med_* and never touches the license_civ_* set login
        // put there. On the way out AP_fnc_dutyContext moves AP_effSide back to civilian, and every reader
        // of a cop licence is co-gated on that (fn_copVehicles.sqf:59-79, fn_copShops.sqf:40), so the
        // stale-looking `true` left behind cannot open anything. Guarded per entry the same way login is --
        // a malformed row must not undefine a global (SQF: `setVariable [x, nil]` deletes it).
        {
            if (_x isEqualType [] && {count _x >= 2}) then { missionNamespace setVariable [_x select 0, _x select 1]; };
        } forEach (_dutyLoad param [5, []]);

        [] call AP_fnc_dutyContext;

        // Saved duty kit wins; otherwise the faction's default loadout. The default-loadout branch gets the
        // same virtual-inventory wipe (fn_copLoadout / fn_medicLoadout only strip PHYSICAL gear) and then
        // rebuilds AP_gear itself, so both branches leave AP_gear describing the duty character.
        if !([_dutyGear] call _fnc_applyGear) then {
            AP_carryWeight = 0;
            { missionNamespace setVariable [_x, 0]; } forEach ([1] call AP_fnc_virtItemCfg);
            // Same re-baseline as _fnc_applyGear's -- this branch does the identical wipe and then lets the
            // faction's default loadout add through handleInv. See that comment for why it matters.
            private _invMonTotal = 0;
            { _invMonTotal = _invMonTotal + (missionNamespace getVariable [_x, 0]); } forEach AP_invMonVars;
            AP_invMonitor = _invMonTotal + AP_invRVar;
            call (_row select 8);
            [false] call AP_fnc_saveGear;
        };
        [] spawn {
            uiSleep 0.5;
            [uniform player, "setUniform", ""] call AP_fnc_clothingTextures;
            if !(backpack player isEqualTo "") then { [backpack player, "setBackpack", ""] call AP_fnc_clothingTextures; };
            [] call AP_fnc_hudUpdate;
        };

        AP_dutySwapGuard = false;
        [["ack", _faction], "APS_fnc_dutySRV", 2] spawn AP_fnc_MP;
        [format ["You are on duty: %1 (%2).", toUpper _faction, _role], "basic"] spawn AP_fnc_handleMessage;
    };

    case "remove": {
        _args params [["_m", "", [""]], ["_reason", "released", [""]]];
        // A server-initiated remove is NEVER dropped. An apply landing at the same moment as a watchdog
        // rollback, or a release racing the disconnect sweep, used to hit the swap guard and be discarded --
        // which leaves the server's roster and the client's state permanently disagreeing, with the player
        // still west and geared. Wait the in-flight swap out instead, and proceed regardless after 15s
        // (a guard still held then is a stuck guard, and the self-heal above is about to clear it anyway).
        private _t0 = diag_tickTime;
        if (AP_dutySwapGuard) then {
            waitUntil { uiSleep 0.5; !AP_dutySwapGuard || {diag_tickTime > (_t0 + 15)} };
        };
        if (!AP_onDuty) exitWith {
            diag_log format ["[AP-DUTY] remove (%1) ignored: not on duty", _reason];
        };
        private _faction = AP_dutyFaction;
        call _fnc_guardOn;

        // Duty gear -> cop_gear/med_gear, while AP_effSide is still the duty side. AP_fnc_saveGear with
        // false only rebuilds AP_gear (it self-saves for civilians only), so the mode-3 send is explicit.
        // A blocked flush is logged rather than refused: unlike the way in, there is nothing safe to abort
        // to -- the server has already de-rostered this player, so the swap has to complete either way.
        private _blocked = call AP_fnc_dutyFlushBlock;
        if (_blocked isNotEqualTo "") then {
            diag_log format ["[AP-DUTY] remove (%1): duty flush will not persist (%2) -- proceeding, kit for this shift is not saved", _reason, _blocked];
        };
        // AP_dutyFlushBypass brackets this flush too -- same base-ring problem as the clock-on side (see that
        // comment), reached here via the explicit mode-3 send since AP_fnc_saveGear's own auto-push only
        // fires for civilians. Off in the same statement group, before anything else in this case can run.
        call _fnc_flushBypassOn;
        [false] call AP_fnc_saveGear;
        [3] call AP_fnc_ClupdatePartial;
        // Mirror of the clock-on flush: mode 4 while AP_effSide is still the duty side, so the shift's
        // talents and exp land in cop_talents/cop_exp (or med_) rather than being discarded by the restore
        // two blocks down. Prestige (modes 16/23) needs no flush here -- fn_addPrestige / fn_earnPrestige /
        // fn_deckTreeAction each persist on spend, so it is never carried un-saved.
        [4] call AP_fnc_ClupdatePartial;
        AP_dutyFlushBypass = false;
        AP_dutyFlushBypassAt = 0;

        AP_onDuty = false;
        AP_dutyFaction = "";
        // CIVILIAN PROGRESSION BACK, before the flip and before anything can persist. AP_side_talents /
        // AP_side_exp currently describe the DUTY character; the moment AP_effSide is civilian again the
        // next full save (DB_fnc_updateRequest) writes them into civ_talents/civ_exp, and the roster entry
        // that would have routed them elsewhere is already gone -- the server deleted it before pushing this
        // remove. So the restore has to happen here, not after the context call.
        // A malformed stash is left ALONE rather than defaulted: writing [] / 0 over a real civilian tree is
        // the loss this is preventing, and a zero-length restore would be indistinguishable from one. The
        // reachable-shape argument is that AP_dutyStash's slot 2 is written in the same statement as slot 0,
        // and an apply that never got that far never set AP_onDuty, so the guard above would have exited.
        private _prog = (missionNamespace getVariable ["AP_dutyStash", []]) param [2, []];
        if (_prog isEqualType [] && {(count _prog) >= 6}) then {
            AP_side_talents  = _prog select 0;
            AP_side_exp      = _prog select 1;
            AP_cop_talents   = _prog select 2;
            AP_prestige      = _prog select 3;
            AP_medic_talents = _prog select 4;
            AP_medic_exp     = _prog select 5;
        } else {
            diag_log format ["[AP-DUTY] remove (%1): no usable progression stash -- civilian talents/exp NOT restored, leaving the duty character's live. RELOG advised.", _reason];
        };
        [] call AP_fnc_dutyContext;   // AP_effSide -> civilian, unit vars cleared, side chat restored

        // Groups: back to the gang if there is one (fn_initGang.sqf:1 gates on AP_effSide, which the call
        // above has already moved), otherwise a fresh throwaway civilian group. deleteWhenEmpty = true is
        // the PR1 convention for every non-persistent group.
        [player] joinSilent (createGroup [civilian, true]);
        if !(AP_gang_data isEqualTo []) then { [] call AP_fnc_initGang; };

        private _stash = missionNamespace getVariable ["AP_dutyStash", []];
        // loadout + virtual inventory + skins, all three. If the stash is unusable (an apply that half-ran
        // before this PR, a swap guard that timed out mid-flight) there is NO safe local recovery -- see the
        // `!_restored` branch below for why falling back to AP_fnc_civLoadout was exactly the loss this
        // whole function exists to prevent.
        private _restored = [_stash param [0, []]] call _fnc_applyGear;
        if (!_restored) then {
            // NOT AP_fnc_civLoadout. That function is not a display-only default: it ENDS with
            // `[true] call AP_fnc_saveGear` (fn_civLoadout.sqf:25), and AP_effSide is already civilian here
            // (the dutyContext call above already flipped it), so calling it would persist a freshly
            // generated default kit into civ_gear immediately -- overwriting the real civilian kit the
            // clock-on flush wrote to that same row minutes ago. That is precisely the loss the
            // `if (_restored)` guard below this comment was written to prevent, and it cannot: the guard
            // only stops the REDUNDANT save in THIS function, and is powerless against one buried inside a
            // function it calls.
            // So: touch nothing. _fnc_applyGear's `false` return is its FIRST line, before setUnitLoadout
            // ever runs, so the player is untouched -- still standing there wearing the duty kit. Uglier
            // than a civilian default, but it is not a save, so civ_gear stays exactly as the clock-on
            // flush left it and a relog restores it through the normal login read. Tell the player that
            // plainly, with this file's strongest existing message idiom: "servernotice" is the one
            // priority-15 handleMessage type in the tree (fn_handleMessage.sqf), so it cannot be buried
            // under a queue of lower-priority "basic" toasts the way the rest of this file's messages can.
            diag_log format ["[AP-DUTY] remove (%1): no usable civilian stash -- NOT falling back to civLoadout (it self-saves and would overwrite civ_gear with a fresh default). Player left in duty kit; civ_gear row is untouched.", _reason];
            ["Gear restore failed -- RELOG to recover your civilian kit; it is safe in the database.", "servernotice"] spawn AP_fnc_handleMessage;
        };
        // Position is only restored on a player-initiated clock-off. A watchdog rollback or a
        // disconnect-driven remove fires with the unit somewhere the stash never described, and
        // teleporting them to a minutes-old spot would be worse than leaving them where they are.
        // PR9: ...and an EMPTY slot 1 is "leave them where they are" too, not a position. `count >= 2` was
        // the whole test; a shift taken at the landing stashes [] there deliberately (see the clock-on
        // side), and setPosATL [] throws rather than no-opping.
        if (_reason isEqualTo "released" && {(_stash param [1, []]) isNotEqualTo []}) then {
            player setPosATL (_stash select 1);
        };
        // AP_gear now describes the civilian again, so persist it immediately rather than leaving the duty
        // packet live in AP_gear until fn_initCiv.sqf:179's 240s tick -- a disconnect inside that window
        // would otherwise write the duty kit into civ_gear.
        // ONLY when the stash actually restored, though: on the fallback path above the player is left
        // wearing the DUTY kit with AP_gear still describing it (from the pre-flip `[false] saveGear` at
        // this case's top), and a save here would write THAT into civ_gear -- the same loss by a different
        // door. Their real civilian kit is untouched in the row.
        // Bypass bracketed here too -- a "released" clock-off just set the player back down at the stash
        // position two statements up, which is the terminal (the whole reason this save needs it at all).
        call _fnc_flushBypassOn;
        if (_restored) then { [true] call AP_fnc_saveGear; };
        AP_dutyFlushBypass = false;
        AP_dutyFlushBypassAt = 0;
        AP_dutyStash = [];

        [] spawn {
            uiSleep 0.5;
            [uniform player, "setUniform", ""] call AP_fnc_clothingTextures;
            if !(backpack player isEqualTo "") then { [backpack player, "setBackpack", ""] call AP_fnc_clothingTextures; };
            [] call AP_fnc_hudUpdate;
        };

        AP_dutySwapGuard = false;
        [["ackoff", _faction, _reason], "APS_fnc_dutySRV", 2] spawn AP_fnc_MP;
        [format ["You are off duty (%1).", _reason], "basic"] spawn AP_fnc_handleMessage;
    };

    default { diag_log format ["[AP-DUTY] dutyClient: unknown mode %1", _mode]; };
};
