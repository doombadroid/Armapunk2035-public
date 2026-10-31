/*
    File: fn_handleQuest.sqf  (AP_fnc_handleQuest)

    A NO-OP, deliberately kept.

    This was the legacy quest system's event chokepoint. The system itself went
    in the ArmaQuest migration; the function survived that only because Parole
    Papers rode it as its only event feed. Parole Papers has now been removed
    too, so nothing downstream of here does anything at all.

    It is kept, rather than deleted with its call sites, for one reason: those
    call sites are an asset, not debt. There are ~95 of them, spread across the
    whole mission, and each one is a line of code that already knows something
    happened -- a store robbed, a tree chopped, a lockpick used, a deck breached
    -- in exactly the shape ArmaQuest's `action` objective type consumes:

        ["action", "robstore", 1] call AP_fnc_handleQuest;
        ["action", "robstore", 1] call aq_fnc_event;      // what it becomes

    Rewiring them is a mechanical change worth doing when content needs those
    verbs. Deleting them would throw away the instrumentation and mean
    rediscovering all ~95 sites later. Note that about two thirds are embedded
    inside larger expressions rather than standing alone, so that rewiring wants
    care and a reviewed diff, not a blind sweep.

    Until then this returns immediately, costing one function call at sites that
    were already making one. It intentionally does NOT forward to aq_fnc_event:
    quests must not silently start counting verbs nobody authored content for.

    See ARMAQUEST_SPEC.md section 6 for the demand-driven instrumentation rule --
    a verb is wired when a quest references it, not before.
*/
