/*
    AP_fnc_deathUiOpen -- is a death screen on this client's face right now?

        if ([] call AP_fnc_deathUiOpen) exitWith { false };

    ONE QUESTION, ONE ANSWER, SIX CALLERS. There are two death screens now -- the
    native dialog 7300 and the web dialog 938800 (ui\html\death.html) -- and six
    places in the tree ask "is the player looking at the death screen" for reasons
    that have nothing to do with which one it is:

        evh\fn_keyDownHandler.sqf   swallow every keybind except User12 while dead
        evh\fn_keyUpHandler.sqf     swallow key-up while dead (redeploy lives here)
        evh\fn_handleDowned.sqf     three reads: the stale-screen guard, the
                                    force-close on an ALIVE player, and the gate
                                    that decides a genuine down can start
        core\medical\fn_revived.sqf     close it on every revive path
        core\medical\fn_loveBombHeal.sqf close it on a heal

    Every one of those is a guard whose FALSE answer is silent: a keybind that
    should have been swallowed just works, a screen that should have closed just
    stays. Left as six literal `findDisplay 7300` tests, adding a second death
    display would have re-opened the Torch/Nikki class of bug (fn_revived's header)
    on the new display only, and the symptom would have been "keys work while dead"
    rather than anything naming a display id.

    This returns a BOOLEAN, not a display, because none of the callers want to touch
    controls -- they want to know the state. The two that close a screen close both,
    which is correct: only one can be open, so the other close is a no-op.
*/
!(isNull (findDisplay 7300)) || {!(isNull (findDisplay 938800))}
