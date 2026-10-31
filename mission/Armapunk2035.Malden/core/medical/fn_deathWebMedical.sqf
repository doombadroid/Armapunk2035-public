/*
    AP_fnc_deathWebMedical -- the death screen's two medical actions, for the web screen.

        private _r = [true]  call AP_fnc_deathWebMedical;   // REQUEST: page Trauma Team
        private _r = [false] call AP_fnc_deathWebMedical;   // ALLOW:   be revivable, page nobody
        // _r = [_ok, _msg]  -- _msg is rendered in the page's status strip either way

    This is fn_deathScreenMedicalButtonClick.sqf's work, with the two things that
    cannot cross into a browser removed and NOTHING ELSE CHANGED. That file is left
    untouched and still serves the native dialog, so flipping the kill switch gives
    back the old screen with the old code behind it.

    WHAT MOVED, AND THE DECISION BEHIND EACH:

    1. THE CONFIRMATION. The native path asks with BIS_fnc_GUIMessage, a separate
       engine display. The approved screen asks inline, in the page. So this
       function is only ever called AFTER the player confirmed, and it does not ask.
       THE DELIBERATE CONSEQUENCE, called out because it is a real behaviour change:
       cancelling a request used to leave the player REVIVABLE anyway, because the
       native function sets AP_revivable BEFORE it asks and its cancel is an
       exitWith after that write. Here a cancel never reaches SQF, so it sets
       nothing, pages nobody and starts no cooldown. That ordering was a consequence
       of statement order rather than a designed affordance -- "become revivable
       without paging anyone" is exactly what the Allow action is FOR, and a player
       who declined the request did not ask for it. A cancel is now a no-op. This is
       the one intentional divergence from existing behaviour in this feature.

    2. THE RECENT-REVIVE WARNING. Unchanged in meaning: it still WARNS and still
       does NOT stop the action (the native function's titleText is not an exitWith,
       and that is deliberate -- AP_next_revive gates the MEDIC's attempt in
       fn_revivePlayer, not the victim's willingness to be revived). It is returned
       as the page's status line instead of drawn with titleText, because a title
       layer does not composite above a browser control (core\web\README.md) and a
       warning the player cannot see is worse than no warning.

    3. THE COOLDOWNS ARE TIMESTAMPS, not a sleeping thread that re-enables controls.
       The native version spawns a thread that sleeps 120 s and then enables BOTH
       buttons whichever one was pressed, so an Allow press followed 10 s later by a
       Request press has two threads racing to re-enable. Here each action stamps
       its own deadline and the page renders whatever the push says, so the state is
       readable, idempotent under double clicks, and survives the page reloading.
       The RULE is unchanged and is the one the native buttons implement:
         request -> BOTH actions locked for 120 s
         allow   -> ONLY allow locked for 120 s

    The paged set is the same "(allPlayers - allDeadMen - player) filtered to
    independent or a cop whose role is medic/all" the native function and
    fn_doRespawn both use.
*/
params [["_doRequest", false, [false]]];

if (!AP_isDead) exitWith { [false, "YOU ARE NOT DEAD"] };
if (isNull AP_corpse) exitWith { [false, "NO BODY TO TREAT -- TRY AGAIN"] };
if (player getVariable ["AP_suicideVestDeath", false]) exitWith {
    [false, "NOTHING LEFT TO TREAT"]
};

// Authoritative cooldown gate. The page disables the buttons too, but the page is
// not trusted and a double click can arrive before the disable renders.
private _now = time;
if (_doRequest && {_now < (missionNamespace getVariable ["AP_deathReqUntil", -1])}) exitWith {
    [false, format ["REQUEST ON COOLDOWN -- %1 S", ceil ((missionNamespace getVariable ["AP_deathReqUntil", -1]) - _now)]]
};
if (!_doRequest && {_now < (missionNamespace getVariable ["AP_deathAllowUntil", -1])}) exitWith {
    [false, format ["ALLOW ON COOLDOWN -- %1 S", ceil ((missionNamespace getVariable ["AP_deathAllowUntil", -1]) - _now)]]
};

// The warning that does not stop anything -- see note 2 above.
private _warn = "";
if (_now < (player getVariable ["AP_next_revive", -1000])) then {
    _warn = format ["RECENTLY REVIVED -- A MEDIC MAY NOT BE ABLE TO REVIVE YOU FOR %1 S",
        ceil ((player getVariable ["AP_next_revive", -1000]) - _now)];
};

// Both actions make the body revivable. Verbatim from the native function, faction
// stamp included -- fn_revivePlayer reads AP_revivable and fn_revived reads AP_faction.
if !(AP_corpse getVariable ["AP_revivable", false]) then {
    AP_corpse setVariable ["AP_revivable", true, true];
    AP_corpse setVariable ["AP_faction", AP_effSide, true];
};

private _msg = "";
if (_doRequest) then {
    private _toSend = (allPlayers - [allDeadMen] - [player]) select {
        (side _x isEqualTo west && _x getVariable ["AP_unitCopRole", ""] in ["medic", "all"])
        || side _x isEqualTo independent
    };
    [[player, AP_corpse], "AP_fnc_sendRequestToMedic", _toSend] spawn AP_fnc_MP;
    player setVariable ["AP_medRequest", true];
    AP_deathReqUntil   = _now + 120;
    AP_deathAllowUntil = _now + 120;      // a request locks BOTH, as the native buttons do
    _msg = "LOCATION TRANSMITTED -- AWAITING A RESPONDER";
} else {
    AP_deathAllowUntil = _now + 120;      // allow locks only itself
    _msg = "REVIVE ALLOWED -- NO MEDIC HAS BEEN PAGED";
};

if (_warn isNotEqualTo "") then { _msg = format ["%1 / %2", _msg, _warn]; };
[true, _msg]
