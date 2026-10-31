params[["_caseType", "", [""]], "_jewelryData"];
switch (_caseType) do {case ("hackGate"): {
            // owner 2026-07-29 (maldenjewelry2.md #2): THE DRILL IS GONE. Every gate on this job is a
            // Sequence Breach now, this one included. It is the ANCHOR gate -- but since the owner's report
            // on b0131 it is no longer the ONLY gate that raises the alarm and starts the event: all six do,
            // through the one shared APS_fnc_jewelryEmporiumSRV _fnc_jewelStart. What still makes this one
            // the anchor is that its case does nothing else, and that a refused breach here leaves the gate
            // shut where a refused perimeter breach still opens its fence (the ruling is in that function).
            // Case renamed from "startDrill" -- there is no drill left to start, and the
            // only two callers were this file's own switch and fn_setupActions (initPlayerLocal calls only
            // "clientInit"). Buffer 10, the Fed perimeter-gate tier (core/actions/fn_openGate.sqf:31),
            // because this is the first move of a federal event and not a car door.
            // jewelCrowbar / jewelLaser stop being required anywhere in this file.
            // ORDER: every cheap local refusal FIRST, the minigame LAST, exactly as fn_openGate does --
            // otherwise a player spends 33 seconds on the Sequence Breach only to be told the shop is shut.
            if (SRV_jewelryEmporiumSRV param[1, false]) exitWith {
                ["The Jewelry Emporium is already being robbed!"] spawn AP_fnc_handleMessage};
            // 10 m, matching the scroll action's offer radius in fn_setupActions exactly: the option
            // must never be visible at a range this refuses. Was 6, which the owner's in-game test
            // proved unreachable -- standing against the gate measured 6.35 m, because `distance` runs
            // to the OBJECT ORIGIN and this gate's origin sits well inside its own geometry.
            // 2026-07-28: read GUARDED, like the two layers above it (both the registration wrap and the
            // action condition in fn_setupActions use missionNamespace getVariable ["AP_jewelGate",
            // objNull]). This was the last bare read of the global left in the chain, and the bare form
            // RAISES on a client that has not yet received the publicVariable where the guarded form
            // simply refuses -- on the one layer that runs after the player has already committed.
            private _jewelGate = missionNamespace getVariable ["AP_jewelGate", objNull];
            if (isNull _jewelGate || {(player distance _jewelGate) > 10}) exitWith {
                [2, "You are not at the emporium's back gate."] call AP_fnc_broadcast};
            if !(AP_effSide isEqualTo civilian) exitWith {};
            if (!(call AP_fnc_hasDeck)) exitWith {[2, "You need a Cyberdeck to do this."] call AP_fnc_broadcast};
            if !((vehicle player) isEqualTo player) exitWith {[2, "You cannot do this from within a vehicle."] call AP_fnc_broadcast};
            if (AP_action_in_use) exitWith {};
            if (dialog) exitWith {};   // the Sequence Breach opens its own dialog (fn_qhCuffHack.sqf:14)
            if ([] call AP_fnc_activeFederalEvent) exitWith {
                ["There is already another Federal Event happening.", "basic"] spawn AP_fnc_handleMessage;};
            if !([SRV_jewelryEmporiumSRV select 6] call AP_fnc_policeRequired) exitWith {};
            if (SRV_lastRobbery > (serverTime - (60 * 15))) exitWith {
                [2, format["Security is high due to a recent robbery and you cannot start the robbery. Try again in %1 minute(s).", ceil((SRV_lastRobbery - (serverTime - (60 * 15))) / 60)]] call AP_fnc_broadcast
            };
            if ((SRV_jewelryEmporiumSRV param[0, -1800]) > serverTime - 1800) exitWith {
                [format["The Jewelry Emporium has recently been breached! Try again in %1 minute(s).", ceil((((SRV_jewelryEmporiumSRV param[0, -1800]) + 1800) - serverTime) / 60)], "basic"] spawn AP_fnc_handleMessage;
            };
            AP_action_in_use = true;
            private _r = [10] call AP_fnc_cyberdeckSeq;
            AP_action_in_use = false;
            if !(_r isEqualTo 1) exitWith {
                if (_r isEqualTo 0) then {[2, "The trace caught you -- the gate stays shut."] call AP_fnc_broadcast;};
            };
            // re-read the shared state AFTER the minigame: someone else may have opened the job while this
            // player was in the buffer. The server re-decides all of it anyway (case "robberyStarted"
            // refuses an already-active event), this is only so the loser gets told rather than silently
            // ignored. The two uiSleep(random N) jitters the drill carried are gone with the drill: they
            // existed to decorrelate two bars finishing on the same tick, and the server's own
            // already-active guard is what actually resolves that race.
            if (SRV_jewelryEmporiumSRV param[1, false]) exitWith {
                ["The Jewelry Emporium is already being robbed!"] spawn AP_fnc_handleMessage};
            ["jewelrydrilled", 1] call AP_fnc_statArrUpdate; [
                ["robberyStarted", [player]], "APS_fnc_jewelryEmporiumSRV", 2] spawn AP_fnc_MP;};
        case ("perimeterGate"): {_jewelryData params[["_gate", objNull, [objNull]]];
                // owner 2026-07-29 (maldenjewelry2.md #1): the emporium's OTHER openings -- the back-alley
                // gate at A, the two concrete gates either side of B, the back-alley gate at C, and the
                // sixth one nobody listed 6 m from the anchor -- are sealed at boot and open only to a
                // Sequence Breach. Before this the compound could simply be walked into and the whole
                // heist walked past. Buffer 6, the ordinary breach tier (ATM / cuffs / car).
                //
                // owner 2026-07-29 (report on b0131): BREACHING ONE OF THESE NOW STARTS THE JOB.
                // This note used to read "These do NOT start the event and do NOT raise the alarm -- the
                // owner's rule is that the back gate is what does that". The owner reported that "breaching
                // any of the 2 gate doors on the building should let you start cracking the coffins", and
                // asked which of the six sealed gates he meant he answered ANY SEALED GATE. So the server
                // case this sends to now opens the gate AND runs the same start the anchor runs
                // (APS_fnc_jewelryEmporiumSRV _fnc_jewelStart), and the whole ruling -- why "starts the job"
                // rather than "quietly unlocks the loot", and why the gate still opens when the start is
                // refused -- is documented there rather than duplicated here.
                //
                // NOTHING ABOUT THIS CLIENT CASE CHANGES, and that is deliberate. It does NOT gain the
                // start's preconditions (the cop count, the fed-event lock, the 30-minute cooldown, the
                // cross-heist lockout) the way case "hackGate" above carries them, because a client-side
                // pre-check would REFUSE THE BREACH ENTIRELY on state the ruling says must not cost the
                // player their gate: those states stop the JOB, not the fence. The server opens the gate
                // first and then titleTexts the reason the job did not start. Keeping them out is also what
                // keeps this file's offer condition and its own refusal agreeing about state, which is the
                // rule the safe-loot entry in fn_setupActions had to be fixed for: both layers here test
                // civilian, deck, on foot, membership, not-the-anchor, still-sealed and 10 m, and nothing
                // else -- so a visible option can never be refused for a reason the offer did not test.
                //
                // BUFFER STAYS AT 6, deliberately left alone: the anchor uses 10 because it is "the first
                // move of a federal event", which all six gates now are, so there is an argument for raising
                // these to 10. That is a DIFFICULTY change and the owner has not asked for one -- raise it
                // only on his word, not as a side effect of this fix.
                // SAME RESTRAINT ON THE STAT: case "hackGate" bumps "jewelrydrilled" before it sends and
                // this case does not, so that counter now under-counts robbery STARTS -- it counts anchor
                // breaches, which is what it has always counted and what its name says. Left alone on
                // purpose. Bumping it here would silently change what a registered stat slot means (and it
                // feeds a title), and the heist already has a server-side completion counter in
                // "jewelryscompleted". Owner call, not a side effect of this fix.
                // THE ANCHOR IS EXCLUDED, here and in the offer condition. AP_jewelGates contains the
                // breach anchor too (the Fed's AP_fedGates does the same), and without the exclusion this
                // action would open the ONE gate whose job is to trip the alarm, silently, for free --
                // every guard in "robberyStarted" bypassed. That is the whole heist skipped, not a detail.
                if !(AP_effSide isEqualTo civilian) exitWith {};
                if (!(call AP_fnc_hasDeck)) exitWith {[2, "You need a Cyberdeck to do this."] call AP_fnc_broadcast};
                if !((vehicle player) isEqualTo player) exitWith {[2, "You cannot do this from within a vehicle."] call AP_fnc_broadcast};
                if (AP_action_in_use) exitWith {};
                if (dialog) exitWith {};
                private _gates = missionNamespace getVariable ["AP_jewelGates", []];
                private _anchor = missionNamespace getVariable ["AP_jewelGate", objNull];
                if (isNull _gate || {!(_gate in _gates)} || {_gate isEqualTo _anchor}) exitWith {
                    [2, "You are not at one of the emporium's perimeter gates."] call AP_fnc_broadcast};
                // 10 m, the SAME number the registration wrap and the offer condition in fn_setupActions
                // measure, for the same reason the anchor needed 10 rather than 6: `distance` runs to the
                // object origin and these gates' origins sit inside their own geometry.
                if ((player distance _gate) > 10) exitWith {
                    [2, "You are not at one of the emporium's perimeter gates."] call AP_fnc_broadcast};
                // bis_disabled_Door_1 is what APS_fnc_maldenJewelSRV's ["seal"] writes, with setVariable's
                // third argument, so every client holds it: 1 = sealed, 0 = open. Never judge a gate by
                // whether the vanilla "Open Door" option appears -- OpenDoor_1.condition tests the
                // ANIMATION PHASE and is offered on a perfectly locked gate. Only CloseDoor_1 reads the
                // lock flag. This trap has cost this build time twice.
                if ((_gate getVariable ["bis_disabled_Door_1", 0]) isNotEqualTo 1) exitWith {
                    [2, "That gate is already open."] call AP_fnc_broadcast};
                AP_action_in_use = true;
                private _r = [6] call AP_fnc_cyberdeckSeq;
                AP_action_in_use = false;
                if !(_r isEqualTo 1) exitWith {
                    if (_r isEqualTo 0) then {[2, "The trace caught you -- the gate stays shut."] call AP_fnc_broadcast;};
                };
                [["perimeterGate", [_gate]], "APS_fnc_jewelryEmporiumSRV", 2] spawn AP_fnc_MP;};
        case ("weldSafe"): {
                // owner 2026-07-29 (maldenjewelry2.md #2): the safe is a TERMINAL breach now and the
                // Plasma Cutter requirement is gone. Difficulty 2 -- the bank-vault tier, 6 commands
                // (fn_setupActions.sqf:782, fn_cyberdeckBank.sqf:26). Deliberately NOT 3: difficulty 3 is
                // the Fed dome's nine-command tier and the Reserve keeps it.
                // The client case name stays "weldSafe" because the SERVER case it sends to is still
                // "weldSafe" (fn_jewelryEmporiumSRV.sqf:188) -- keeping the two spelled the same is what
                // makes the pairing greppable. The player-facing label is "Breach Safe Terminal".
                // The object is read from AP_jewelSafe, GUARDED, rather than from AP_jewerlySafe.
                // AP_jewerlySafe is a ONE-TIME snapshot taken at initPlayerLocal.sqf:116; a client that
                // joined before that publicVariable landed holds objNull for the whole session, and the
                // old code then sent objNull to the server, which logs a "-SEC- safe object mismatch" row
                // against an innocent player into the table CLANKR auto-bans from.
                private _safeObj = missionNamespace getVariable ["AP_jewelSafe", objNull];
                if !(AP_effSide isEqualTo civilian) exitWith {};
                if (!(call AP_fnc_hasDeck)) exitWith {[2, "You need a Cyberdeck to do this."] call AP_fnc_broadcast};
                if !((vehicle player) isEqualTo player) exitWith {[2, "You cannot do this from within a vehicle."] call AP_fnc_broadcast};
                if (AP_action_in_use) exitWith {};
                if (dialog) exitWith {};
                // 5 m, the same radius the offer condition in fn_setupActions measures to the same object.
                if (isNull _safeObj || {(player distance _safeObj) > 5}) exitWith {
                    [2, "You are not at the emporium's safe."] call AP_fnc_broadcast};
                if !(SRV_jewelryEmporiumSRV param[2, false]) exitWith {   // #149: gate on safeDrilled [2] -- every display case done -- not the post-breach flag [3]
                    ["You have yet to meet the requirments for cracking this safe!"] spawn AP_fnc_handleMessage};
                if (SRV_jewelryEmporiumSRV param[3, false]) exitWith {
                    ["This safe is already open!", "basic"] spawn AP_fnc_handleMessage};
                AP_action_in_use = true;
                private _r = [2] call AP_fnc_cyberdeckTerm;
                AP_action_in_use = false;
                if !(_r isEqualTo 1) exitWith {
                    if (_r isEqualTo 0) then {[2, "The trace caught you -- the safe stays shut."] call AP_fnc_broadcast;};
                };
                // The AP_jewelWelder CLAIM the plasma-cutter bar used to write on the safe is gone with
                // the bar. It existed to stop a second player's 12-second cut paying out, and it was a
                // client-side reservation on a server-side payout -- the exact shape the 2026-07-24 audit
                // note in fn_jewelryEmporiumSRV.sqf:190 says is not a guard. The server's flat slot-3
                // done-flag check (:221) is what actually resolves two players finishing in the same tick,
                // and it logs that as the legitimate race it is rather than as a -SEC- row. The window
                // close still clears AP_jewelWelder server-side; that is now harmless dead state.
                if (SRV_jewelryEmporiumSRV param[3, false]) exitWith {};
                [["weldSafe", [_safeObj, player]], "APS_fnc_jewelryEmporiumSRV", 2] spawn AP_fnc_MP;};
        case ("breakGlassCase"): {_jewelryData params[["_oldCase", objNull, [objNull]]];
                // owner 2026-07-29 (maldenjewelry2.md #2): the Crowbar requirement and the 25-second pry
                // bar are both gone -- EIGHT separate Sequence Breaches, one per display case, the owner's
                // explicit choice with the cost accepted (12 minigames in a full run plus the safe's
                // terminal). Buffer 6, the ordinary breach tier: eight of them is already the cost, so
                // each one is a case of glass and not a vault.
                if !(SRV_jewelryEmporiumSRV param[4, false]) exitWith {   // #152: casesLootable [4], NOT safeDrilled [2] -- [2] now means "all 8 cases smashed, safe unlocked", so gating cases on it deadlocked the heist: no case could be smashed, so [2] never flipped. [4] goes true the instant the gate breach completes (APS_fnc_jewelryEmporiumSRV "robberyStarted"), which is exactly what the message below says.
                    ["You can't open this until the emporium has been breached!", "basic"] spawn AP_fnc_handleMessage;};
                if (AP_action_in_use) exitWith {};
                if (dialog) exitWith {};
                if !(AP_effSide isEqualTo civilian) exitWith {};
                if (!(call AP_fnc_hasDeck)) exitWith {[2, "You need a Cyberdeck to do this."] call AP_fnc_broadcast};
                if !((vehicle player) isEqualTo player) exitWith {[2, "You cannot do this from within a vehicle."] call AP_fnc_broadcast};
                if (isObjectHidden _oldCase) exitWith {};
                if (_oldCase getVariable["AP_jewelCaseLooted", false]) exitWith {};
                // #152: was a whitelist of the 14 Eden-named cases -- any OTHER Coffin_02_F display case
                // in the emporium silently no-op'd ("some glass cases do not give option to crack").
                // Accept any display case inside the emporium polygon instead.
                if !(((typeOf _oldCase) isEqualTo "Coffin_02_F") && {(getPosATL _oldCase) inPolygon AP_jewelryEmporiumPoly}) exitWith {};
                // 5 m: the offer condition in fn_setupActions offers at < 5 and this refuses past 5, so a
                // visible option can never be refused for the reason it was offered. The old bar had no
                // range refusal at all -- the offer was the only thing measuring.
                if ((player distance _oldCase) > 5) exitWith {
                    [2, "You are not at that display case."] call AP_fnc_broadcast};
                AP_action_in_use = true;
                private _r = [6] call AP_fnc_cyberdeckSeq;
                AP_action_in_use = false;
                if !(_r isEqualTo 1) exitWith {
                    if (_r isEqualTo 0) then {[2, "The trace caught you -- the case stays sealed."] call AP_fnc_broadcast;};
                };
                // re-read after the minigame: another player may have taken this case while this one was
                // in the buffer. The server re-decides it (case "createCase" refuses an already-looted
                // case), this only spares the loser a wasted -SEC-less rejection.
                if (_oldCase getVariable["AP_jewelCaseLooted", false]) exitWith {};
                ["jewelrycasesopened", 1] call AP_fnc_statArrUpdate; [
                    ["createCase", [_oldCase]], "APS_fnc_jewelryEmporiumSRV", 2] spawn AP_fnc_MP;};
        case ("loadJewelry"): {
                // owner 2026-07-29 (maldenjewelry2.md #3, #6): THE NEW STAGE. Looting the safe no longer
                // delivers the getaway -- loading it does. Two-minute bar at the crane, then the server
                // mints the Qilin with this player's haul plus 5 flat bonus bags. ONE loader, ONE load.
                //
                // Anchored on a PUBLISHED COORDINATE, not on an object, and that is not a shortcut.
                // Land_RepairDepot_01_tan_F is a fn_mapData.sqf row with _xIsServer = false: a per-client
                // createSimpleObject that the SERVER cannot see with nearestObjects and that the client
                // only holds while fn_dynamicMapSystem has that zone loaded. Copying the anchor gate's
                // boot resolver here would publish objNull and every layer of this stage would refuse for
                // ever, silently. AP_JEWEL_CRANEPOS is the same shape the Fed's dome terminal uses
                // (AP_FED_TERMPOS, fn_openVault.sqf:29-31).
                //
                // distance2D, not distance: the crane deck stands at ATL 3.838 and the Qilin pad below it
                // at 0.19 -- 3.65 m apart vertically -- so a loader may legitimately be standing on either
                // one. "At the crane" is a horizontal question. The count-isEqualTo-3 guard is what stops
                // a missing publicVariable from raising here instead of refusing.
                if !(AP_effSide isEqualTo civilian) exitWith {};
                if !((vehicle player) isEqualTo player) exitWith {[2, "You cannot do this from within a vehicle."] call AP_fnc_broadcast};
                if (AP_action_in_use) exitWith {};
                private _cranePos = missionNamespace getVariable ["AP_JEWEL_CRANEPOS", []];
                if ((count _cranePos) isNotEqualTo 3 || {(player distance2D _cranePos) > 10}) exitWith {
                    [2, "You are not at the emporium's loading crane."] call AP_fnc_broadcast};
                if !(SRV_jewelryEmporiumSRV param[1, false]) exitWith {
                    ["There is no Jewelry Emporium job running to load for.", "basic"] spawn AP_fnc_handleMessage};
                // THE REPEAT GUARD. AP_jewelLoaded, the SAME NAME the server publishes -- read guarded,
                // because it does not exist at all until the first robbery of the session starts.
                // It used to read `SRV_jewelryEmporiumSRV param [5, false, [false]]`, a slot the server has
                // never written: init.sqf:241 and the "robberyStarted" state stamp both put the NUMBER 0
                // there, so all three of this stage's repeat guards were dead AND the type-checked read of
                // a Number against a Bool logged an engine type error on every evaluation. One flag, one
                // name, both sides. The server carries the authoritative guard; this one is so the option
                // stops being offered and a second loader is told why.
                if (missionNamespace getVariable ["AP_jewelLoaded", false]) exitWith {
                    ["The getaway has already been loaded -- one load per job.", "basic"] spawn AP_fnc_handleMessage};
                // AP_inv_* read GUARDED. They are created for every configured item by
                // fn_virtItemCfg.sqf:416 case 0, but this same expression is what the OFFER CONDITION in
                // fn_setupActions evaluates, and there a nil read raises and deletes the scroll menu.
                // Both layers measure the same two counters so the option cannot appear and then refuse.
                private _bags = missionNamespace getVariable ["AP_inv_jewelBag", 0];
                private _hope = missionNamespace getVariable ["AP_inv_jewelHope", 0];
                if ((_bags + _hope) <= 0) exitWith {
                    ["You are not carrying anything worth loading.", "basic"] spawn AP_fnc_handleMessage};
                disableSerialization;
                5 cutRsc["AP_progress", "PLAIN"];
                private _display = uiNameSpace getVariable["AP_progress", displayNull];
                private _progressBar = _display displayCtrl 38201;
                private _progressText = _display displayCtrl 38202;
                AP_action_in_use = true;
                private _increment = 1;
                private _totalTime = 120;
                private _currentPoint = 0;
                private _loopDelay = _totalTime / floor(100 / _increment);
                private _text = format["Loading The Haul Into The Getaway"];
                private _startCount = 0;
                _progressBar progressSetPosition _startCount;
                // broadcast so the players around the crane see a two-minute job being done, not a man
                // standing still. _totalTime and not the drill's (_totalTime * 5): AP_fnc_handleAnim's
                // switchMove branch uiSleeps that delay on EVERY receiving machine before it clears the
                // pose, and the local clear below is not broadcast -- so an inflated delay leaves the
                // loader frozen in the animation on other people's screens long after the bar is done.
                _progressText ctrlSetText format["%1 (%2%3)", _text, _startCount, "%"]; [
                    ["Acts_carFixingWheel", _totalTime, "switchMove", player], "AP_fnc_handleAnim", (allPlayers select {
                        (_x distance player) <= 40})] spawn AP_fnc_MP;
                private _isSuccess =
                for "_i"
                from 0 to 1 step 0 do {uiSleep _loopDelay;
                    if (isNull _progressBar) exitWith {["You have failed to load the getaway", "basic"] spawn AP_fnc_handleMessage;
                        false};
                    _currentPoint = (progressPosition _progressBar) + (_increment / 100);
                    _progressBar progressSetPosition _currentPoint;
                    _progressText ctrlSetText format["%1 (%2%3)", _text, round(_currentPoint * 100), "%"];
                    if (_currentPoint >= 1) exitWith {true};
                    if (player getVariable ["AP_surrendered", false]) exitWith {   // #361: hands-up (TAB) cancels the load so you can comply
                        ["Loading interrupted -- hands up.", "basic"] spawn AP_fnc_handleMessage;
                        false};
                    if ((speed player) >= 3) exitWith {["You have failed to load the getaway", "basic"] spawn AP_fnc_handleMessage;
                        false};
                    if !(isNull objectParent player) exitWith {["You have failed to load the getaway", "basic"] spawn AP_fnc_handleMessage;
                        false};
                    if (!AP_action_in_use || !alive player) exitWith {
                        ["You have failed to load the getaway", "basic"] spawn AP_fnc_handleMessage;
                        false};
                    false;};
                ["", 0 , "switchMove", player] spawn AP_fnc_handleAnim;
                AP_action_in_use = false;
                5 cutText["", "PLAIN"];
                if !(_isSuccess) exitWith {};
                if (missionNamespace getVariable ["AP_jewelLoaded", false]) exitWith {
                    ["Someone else finished loading the getaway first -- nothing has left your inventory.", "basic"] spawn AP_fnc_handleMessage};
                // RE-READ the counters. Two minutes is long enough to have picked up another trophy or to
                // have been seized by MaxSec, and sending the pre-bar numbers would either short the
                // player or claim items they no longer hold.
                _bags = missionNamespace getVariable ["AP_inv_jewelBag", 0];
                _hope = missionNamespace getVariable ["AP_inv_jewelHope", 0];
                if ((_bags + _hope) <= 0) exitWith {
                    ["You are not carrying anything worth loading.", "basic"] spawn AP_fnc_handleMessage};
                // ============================================================================
                // REMOVE FIRST, *THEN* CLAIM WHAT WAS REMOVED. THE SERVER REFUNDS ANYTHING IT REFUSES.
                // This order was got wrong twice and the reasoning is worth keeping, because both wrong
                // answers look reasonable in isolation:
                //   * Cut 1 removed the items and sent, with no refund anywhere. Every server refusal --
                //     the window closing under the two-minute bar, a second loader winning the race, the
                //     weld gate that used to sit there -- destroyed the player's whole haul in silence.
                //   * Cut 2 inverted it: send the claim, wait for the server to publish an accept, remove
                //     on arrival. That fixed the loss and created a MINT, which is strictly worse. The
                //     server spawned and loaded the Qilin BEFORE these items left the inventory, so the
                //     0.25 s poll plus network RTT was a window in which a disconnect, a death or this
                //     function's own 15 s timeout left the player holding the haul while the Qilin already
                //     had a copy of it. The timeout path duplicated it EVERY time: the client gave up
                //     waiting, the server had already paid.
                //   * This cut removes first and relies on the server's refund, which
                //     APS_fnc_jewelryEmporiumSRV case "loadJewelry" now performs on every refusal and for
                //     the difference on a clamp. The asymmetry is the whole point: a refund that goes
                //     astray costs items the player chose to spend, while a payment made before the removal
                //     mints value out of nothing. Never reintroduce an accept-then-remove channel here.
                // NOTHING IS WAITED ON, so there is no timeout to duplicate through. The server's reply is
                // the refund itself plus a broadcast that says why -- every refusal in that case speaks.
                // The removal is the authority on what is claimed: whatever AP_fnc_handleInv actually
                // took is what gets sent, so the claim can never exceed what this inventory really held
                // even if the counters shifted between the re-read above and this line. handleInv returns
                // false rather than going negative, and a false return means nothing left, so the claim
                // drops that item to 0 and the server is never told about items still in the pocket.
                // ============================================================================
                private _sendBags = 0;
                private _sendHope = 0;
                if (_bags > 0 && {[false, "jewelBag", _bags] call AP_fnc_handleInv}) then {_sendBags = _bags;};
                if (_hope > 0 && {[false, "jewelHope", _hope] call AP_fnc_handleInv}) then {_sendHope = _hope;};
                // Removed nothing, so there is nothing to claim and nothing for the server to refund. Not
                // reachable from the two counter checks above except through a same-instant seizure.
                if ((_sendBags + _sendHope) <= 0) exitWith {
                    ["You are no longer carrying anything worth loading.", "basic"] spawn AP_fnc_handleMessage};
                [["loadJewelry", [_sendBags, _sendHope]], "APS_fnc_jewelryEmporiumSRV", 2] spawn AP_fnc_MP;
                // Worded as an offer handed over, not as a payment received: the server decides how much of
                // it the run actually produced, pays that into the Qilin and hands the rest straight back,
                // and it broadcasts its own message when it does. Promising a completed load here would be
                // a lie on the clamp path.
                [format ["Handed %1 bag(s)%2 to the crane.", _sendBags,
                    if (_sendHope > 0) then {" and the HOPE DIAMOND"} else {""}], "basic"] spawn AP_fnc_handleMessage;};
        case ("takeJewelryContents"): {_jewelryData params[["_cursorObject", objNull, [objNull]]];
                if ((typeOf _cursorObject) isNotEqualTo "Land_Trophy_01_gold_F") exitWith {};
                if ([true, "jewelBag", 1] call AP_fnc_handleInv) then {deleteVehicle _cursorObject;
                    // owner 2026-07-29: the haul's destination changed. It used to say "sell this to the
                    // African Warlord", which is still possible on foot, but the run's real payout is now
                    // the crane: the getaway Qilin does not exist until somebody loads it, and one load is
                    // all a job gets. Point at the stage that pays.
                    ["Carry this to the crane and load the getaway.", "basic"] spawn AP_fnc_handleMessage;} else {
                    ["You do not have room to grab the jewelry!", "basic"] spawn AP_fnc_handleMessage;};};
        case ("takeSafeContents"): {
                // owner 2026-07-29 (b0131 follow-up): the safe comes from the PUBLISHED ANCHOR, not from
                // the payload, and the range refusal is proximity to it. This case used to take an object
                // the caller's cursor had named and check only `typeOf`, which exits SILENTLY -- the one
                // path in this case that says nothing to the player. The offer condition in fn_setupActions
                // read cursorObject too, a frame earlier and separately, so an aim that drifted between the
                // condition and the fire produced a visible option that did precisely nothing when clicked.
                // The four gold trophies the weld drops 0.8 m in front of this safe are what the cursor
                // lands on while they are being collected, so that drift was likeliest at the one spot the
                // safe is looted from. The payload is empty now, like "weldSafe"'s.
                // The typeOf test is GONE rather than kept as a belt: AP_jewelSafeOpen is only ever the
                // Fridge_01_open_F the server creates at the weld, or objNull, and isNull covers objNull.
                // "weldSafe" reads AP_jewelSafe the same way and does not class-check it either. One fewer
                // copy of a classname to keep in step with the server.
                // READ GUARDED, and this matters more here than the guard on AP_jewelSafe: that name is
                // bound at boot, this one does not exist at all until the first weld of the session
                // (fn_jewelryEmporiumSRV.sqf:638/:677) and goes back to objNull when the window closes
                // (:402). fn_setupActions evaluates the same guarded expression in the offer condition,
                // where a bare read of an unset global RAISES and deletes every scroll entry after it.
                // 5 m, the same number the offer condition measures to the same object, and inside the
                // server's own 30 m slack (:835), so no layer can refuse what another offered. The gates
                // need 10 m because `distance` runs to the OBJECT ORIGIN and theirs sit deep inside their
                // geometry (6.35 m measured while touching the anchor gate). This one does not:
                // boundingBoxReal on Fridge_01_F.p3d -- the model both halves of the pair share, differing
                // only in the Door_1 animation phase -- is [[-0.291,-0.359,-0.519],[0.291,0.359,0.519]], a
                // 0.58 x 0.72 x 1.04 m box whose origin is its own centre, so nothing on its surface is
                // further than 0.69 m from what `distance` measures to. The open safe is created at
                // getPosATL AP_jewelSafe, so anyone who could weld this safe at < 5 m can loot it at < 5.
                private _openSafe = missionNamespace getVariable ["AP_jewelSafeOpen", objNull];
                if (isNull _openSafe || {(player distance _openSafe) > 5}) exitWith {
                    [2, "You are not at the emporium's open safe."] call AP_fnc_broadcast};
                if !(SRV_jewelryEmporiumSRV param[3, false]) exitWith {   // #149: safe contents need the safe BREACHED [3] (was [4], let you skip the terminal)
                    ["You are not able to open this safe!", "basic"] spawn AP_fnc_handleMessage;};
                // ============================================================================
                // owner 2026-07-29: THIS BRANCH NO LONGER GRANTS ANYTHING. It asks, and
                // APS_fnc_jewelryEmporiumSRV case "takeSafeContents" decides, clears the flags and grants.
                // WHY IT HAD TO MOVE. There was NO server case behind this action at all. This branch read
                // AP_jewelHopeInSafe off the safe, granted the diamond with its own AP_fnc_handleInv,
                // and cleared the flag with `setVariable [..., true]` -- a broadcast from a CLIENT, which
                // is neither instantaneous nor serialised. Two players who scrolled "Take Safe Loot" inside
                // that window both read the flag as set, both granted on their own machine, and both
                // broadcast the clear: TWO $108,000 diamonds out of one safe, and the window widens with
                // ping and with population. AP_safeLooted gated the jewelBag exactly the same way and had
                // exactly the same hole. A one-shot jackpot flag cannot live on the machine that benefits
                // from reading it late.
                // WHAT IS STILL DECIDED HERE, and why it is safe to: ROOM. Weight is client-side state the
                // server cannot see, so this branch works out what it could actually hold and asks for that
                // much. Lying can only cost the liar -- the server clamps both numbers to the 0-or-1 the
                // flags allow, so a forged ask wins exactly what an honest one wins, and then hands the
                // items to a client with no room for them.
                // THE ORDER-MATTERS RULE SURVIVES INTACT, and it must: the diamond is asked for first and
                // the bag is not asked for at all if the diamond will not fit. AP_safeLooted is a one-shot,
                // so a bag that fitted beside a diamond that did not would flag the safe looted with
                // $108,000 sealed inside it and no way back in. calWeightDiff is the same helper
                // AP_fnc_handleInv uses internally to decide what fits, called here WITHOUT mutating
                // anything, and the bag is measured against the weight the diamond will have taken.
                // DO NOT ALSO put jewelHope in the safe's AP_droppedItems. Two routes are $108,000 twice,
                // and that route cannot pay out at all: AP_fnc_pickupSelected re-derives the holder from
                // a two-class switch on cursorObject ("Land_Suitcase_F" / "Box_Syndicate_WpsLaunch_F") and
                // a Fridge_01_open_F matches neither, so the item lists in the pickup menu and can never be
                // taken out of it.
                // ============================================================================
                private _hopeHere = _openSafe getVariable["AP_jewelHopeInSafe", false];
                private _bagHere = !(_openSafe getVariable["AP_safeLooted", false]);
                if (!_hopeHere && {!_bagHere}) exitWith {
                    ["This safe has already been looted!", "basic"] spawn AP_fnc_handleMessage;};
                private _wantHope = 0;
                private _hopeWeight = 0;
                if (_hopeHere) then {
                    if ((["jewelHope", 1, AP_carryWeight, AP_maxWeight] call AP_fnc_calWeightDiff) >= 1) then {
                        _wantHope = 1;
                        _hopeWeight = (["getItemWeight", "jewelHope"] call AP_fnc_virtItemCfg);
                    };
                };
                // Flat and top-level: an exitWith inside the then {} above would leave only that block. The
                // diamond not fitting stops the whole take, bag included, for the one-shot reason above.
                if (_hopeHere && {_wantHope isEqualTo 0}) exitWith {
                    ["You do not have room for the Hope Diamond -- drop something and come back.", "basic"] spawn AP_fnc_handleMessage;};
                private _wantBag = 0;
                if (_bagHere && {(["jewelBag", 1, AP_carryWeight + _hopeWeight, AP_maxWeight] call AP_fnc_calWeightDiff) >= 1}) then {_wantBag = 1;};
                if ((_wantHope + _wantBag) isEqualTo 0) exitWith {
                    ["You do not have room to grab the jewelry bag!", "basic"] spawn AP_fnc_handleMessage;};
                // No player object in the payload: the server takes its subject from remoteExecutedOwner,
                // because a client-supplied name in a -SEC- row is how an innocent player gets framed into
                // the table CLANKR auto-bans from. The grant and the messages both come back from there.
                [["takeSafeContents", [_wantHope, _wantBag]], "APS_fnc_jewelryEmporiumSRV", 2] spawn AP_fnc_MP;};
        case ("clientInit"): {[{if (SRV_jewelryEmporiumSRV param[1, false]) then {
                    // owner 2026-07-28: read the emitter LIVE instead of trusting the init-time snapshot.
                    // AP_jewerlyEmporium is bound ONCE, at initPlayerLocal.sqf:98, from AP_jewelGate --
                    // so a client whose join ran before that publicVariable landed held objNull for the
                    // whole session and heard NO alarm at all, and this is the feature's only cue to
                    // uninvolved players nearby. Re-reading self-heals the moment the variable arrives.
                    // The gate stays the emitter rather than AP_jewelSafe: it sits INSIDE AP_JEWEL_POLY,
                    // 13.3 m from AP_JEWEL_CENTRE (nothing against say3D's 500 m maxDistance), and it is
                    // never hidden -- whereas the safe is hideObjectGlobal true from the breach until the
                    // window closes, which would risk silencing the alarm for the entire getaway.
                    private _alarmSrc = missionNamespace getVariable ["AP_jewelGate", objNull];
                    if !(isNull _alarmSrc) then {_alarmSrc say3D["jewelryAlarm", 500];};};
                }, [], 1.212] call AP_fnc_addPerFrameHandler;};
        // owner 2026-07-29: the second per-frame handler that used to live here is GONE with the plasma
        // cutter. It swept nearestObjects for a Land_ButaneTorch_F beside the safe every 1.1 s and played
        // "jewelrySafeTorchLoop" -- the cutting-torch ambience for a tool this heist no longer has, and
        // which nothing in the tree has ever spawned, so the loop could only ever have been silent. It
        // also seeded that sweep from the bare AP_jewerlySafe, which is objNull for any client that
        // joined before the safe's publicVariable landed.
        };
