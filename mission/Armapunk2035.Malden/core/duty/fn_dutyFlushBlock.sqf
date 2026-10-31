/*
    AP_fnc_dutyFlushBlock -- "can this client persist its character RIGHT NOW?", answered as one string.

        call AP_fnc_dutyFlushBlock   ->   ""       a gear/position flush will actually reach the DB
                                          <reason> it will silently no-op

    A duty swap is two flushes and a stash: the civilian character is written to civ_gear on the way in and
    the duty character to cop_gear/med_gear on the way out. BOTH flushes are conditional and BOTH fail
    SILENTLY -- fn_saveGear.sqf:25 exits with no return value, and fn_ClupdatePartial.sqf's case 3 sets a
    private _exit flag and returns nothing either. A swap started in one of these states therefore persists
    nothing and then overwrites the un-persisted character with the other one. That is permanent kit loss
    with no error anywhere, which is why the terminal refuses BEFORE the request and AP_fnc_dutyClient
    re-checks AFTER the flush.

    One list, one file, because two copies of a list like this diverge on the first edit. It is the union of
    fn_saveGear.sqf:25 and fn_ClupdatePartial.sqf:50-61.

    TWO NEARBY CONDITIONS WERE CONSIDERED AND LEFT OUT ON PURPOSE. AP_lastSynced_gear's dedupe
    (fn_ClupdatePartial.sqf:63) is benign to omit: it skips the write only when the payload has not changed,
    and the DB already holds that exact packet, so nothing is lost by not treating it as a blocker. AP_shop_cam
    (fn_ClupdatePartial.sqf:14) is subsumed by the AP_clothing_store check below: the cam only exists while the
    clothing shop dialog is open (fn_clothingMenu.sqf), the same window AP_clothing_store already covers.

    THE respawn_west CLAUSE WAS INCLUDED, through PR6's first fix round, and is REMOVED HERE in the second --
    the comments in the two files it mirrored were stale about it. Both used to say the marker is absent so
    the guard is dead -- true of the Altis mission they were written for, NOT of this one: mission.sqm
    Item4304 originally put respawn_west at [7263.75, 7931.26]. So the "no gear save within 1000m" rule was
    LIVE on Malden, and it was the one blocker on this list that depended on where the player was standing
    rather than what state they were in. Verified against the shipped markers at that position: cop_spawn_2,
    the MaxSec terminal's own location, was ~5.06 km away, so the sign-on path looked clear -- but cop_spawn_1
    was ~246 m away and inside the zone, which is exactly the sort of thing a later PR moving a terminal
    would walk into silently.

    ...AND PR6 WALKED INTO IT, EXACTLY AS PREDICTED. The Trauma terminal stands at med_spawn_1, the main
    hospital, was 103 m from respawn_west's original position -- so this predicate refused every Trauma
    sign-on and clock-off, with the message above. The predicate was RIGHT; the anchor was wrong. All four
    respawn_* markers sat on civ_spawn_1, i.e. LA TRINITE TOWN CENTRE, because mission.sqm SHIPS all four
    respawn_* markers stacked there (Item4303-4306) -- they are a pre-spawn-menu holding spot, not the
    police base the Altis-era 1000 m rule assumes. Measured from [7263.75, 7931.26]: civ_spawn_1 0 m,
    med_spawn_1 103 m, cop_spawn_1 246 m; med_spawn_2/3/4 and cop_spawn_2 were all >4.4 km clear. The same
    ring meant no civilian standing anywhere in La Trinite had persisted gear since those anchors existed,
    which was a live pre-existing defect several times larger than the terminal it blocked.

    PR6'S FIRST FIX ROUND moved respawn_west only, to MaxSec HQ (cop_spawn_2's exact position) -- clearing
    the Trauma terminal (med_spawn_1 is now ~5.04 km away) but NOT the MaxSec sign-on, exactly as predicted
    two paragraphs up for cop_spawn_1: the MaxSec terminal now sits AT the anchor it moved to, ~0 m from
    ring centre, so it refused every MaxSec sign-on and clock-off in turn.

    THIS COMMIT is that second walk-into-it. The respawn_west clause above is REMOVED from this predictor --
    every caller of AP_fnc_dutyFlushBlock is part of the duty system, and a ring that must always fire for
    one terminal (MaxSec, 0 m) and can never fire for the other (Trauma, 5.04 km) predicts nothing useful
    either way. AP_dutyFlushBypass -- set by fn_dutyClient.sqf immediately around its own flush calls, both
    directions, cleared right after -- lets the swap's actual writes cross the matching clause in
    fn_saveGear.sqf and fn_ClupdatePartial.sqf's case 3 for real; see those two files for the mechanism. Any
    OTHER gear save near the base -- the periodic PFH tick, a spawn-in, fn_ClupdateRequest.sqf's own
    full-save pass -- reads AP_dutyFlushBypass as false (its default) and stays ring-blocked exactly as
    before: the ring still guards what it was built to guard against everything except the one swap that now
    has to cross it by design. respawn_civilian/guerrila/east are untouched and still stacked on civ_spawn_1,
    so the wider La Trinite gear-save defect remains: scoping the rule or moving those three anchors too is
    still an owner call.

    THE SCD HAND-OFF, and why it is not on the list. fn_ClupdatePartial.sqf:66-67 does not save an SCD
    officer's gear itself -- it re-enters as mode 17, which has its own guard pair. PR5 widened that guard to
    accept the "init" sentinel initPlayerLocal.sqf:59 assigns at login, matching case 3's (:47-50), so the
    two paths now block on identical conditions and this file describes both. Worth knowing for anyone
    re-deriving the list: the sentinel is transient in practice (core/configuration.sqf re-seeds
    AP_clothing_store to "" about a second and a half into core\init.sqf), so the widening is parity rather
    than a fix for something measured live -- but a guard that disagrees with the one that hands off to it is
    a trap either way, and mode 17 is the ONLY route an SCD shift's kit has to cop_gear.
    Mode 17's second guard -- AP_copRole must be "scd" -- is deliberately NOT mirrored here. It is not a
    blocker: it is the same condition that routed the save to mode 17 in the first place, so it cannot be
    false on any path that reaches it.
*/
if (AP_isDead || {!alive player}) exitWith { "you are down" };
if ((AP_is_arrested param [0, 0]) isEqualTo 1) exitWith { "you are serving a sentence" };
if (player getVariable ["AP_gunBroken", false]) exitWith { "your firing pin is removed" };
// respawn_west's 1000m clause is REMOVED here (PR6 fix round 2) -- see the header above. The base ring
// is still enforced for real, inside fn_saveGear.sqf and fn_ClupdatePartial.sqf's case 3; it has no
// predictor entry in this convenience list any more because AP_dutyFlushBypass makes it unconditionally
// pass for every caller of this function. Do not re-add a distance check here without re-reading why.
if !((missionNamespace getVariable ["AP_clothing_store", ""]) in ["", "init"]) exitWith { "a clothing store is open" };
if (missionNamespace getVariable ["AP_inEvent", false]) exitWith { "you are in an event" };
if (missionNamespace getVariable ["AP_activeMAXTAC", false]) exitWith { "MaxTac is active" };
if (missionNamespace getVariable ["AP_eviSpawn", false]) exitWith { "you are on an evidence spawn" };
if (missionNamespace getVariable ["AP_isActiveFirefighter", false]) exitWith { "you are on a firefighting callout" };
""
