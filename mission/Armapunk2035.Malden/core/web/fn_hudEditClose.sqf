/*
    AP_fnc_hudEditClose -- dialog 938400 onUnload. Hand the HUD back.

        [] call AP_fnc_hudEditClose;    // dialog\hudEdit.hpp onUnload

    EVERY EXIT COMES THROUGH HERE, which is the point of putting it on onUnload rather than on
    the SAVE and CANCEL paths: Esc closes an Arma dialog without asking anybody, and so does
    anything else that tears a display down. A restore written only into the two buttons would
    leave a player who pressed Esc with no HUD at all for the rest of the session.

    CLEARING AP_hudEditActive IS THE WHOLE RESTORE. fn_hudWebInit's keeper asks once a second
    whether the layer should be up and fixes the answer, so the layer comes back within a second
    on its own, re-bridges, and re-applies the layout through AP_fnc_hudLayoutApply. There is no
    re-cut here and there should not be: a second cutter racing the keeper over the same layer
    is exactly the shape that feature was written to avoid.

    NOTHING IS SAVED HERE. Only the SAVE button writes, and it writes through the server. An
    unload that arrives without one -- Esc, CANCEL, a display destroyed under us -- is a cancel,
    and the live HUD simply comes back wearing whatever the database still holds.

    THE TWO PUSH GATES ARE CLEARED because they are signatures of the last payload SENT, and the
    last payload sent was the editor's synthetic one -- forced bounty, forced regen, forced
    pause. Left in place, the keeper's first real tick would compare the player's true state
    against that fake and, if it happened to match, send nothing at all: a HUD that renders and
    then never populates. Same reason fn_hudWebInit clears them on every fresh bridge.
*/

if (!hasInterface) exitWith { false };

uiNamespace setVariable ["AP_hudEditCtrl", controlNull];

AP_hudEditActive = false;
AP_hudWebLast = "";
AP_hudWebLastPos = "";

diag_log "[HUDEDIT] closed -- keeper will restore the layer";
true
