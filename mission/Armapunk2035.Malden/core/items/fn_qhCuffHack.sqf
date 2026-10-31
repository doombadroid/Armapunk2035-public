// Altis Life game mechanic — fictional in-game "quickhack" ability, game logic only.
/*
    File: fn_qhCuffHack.sqf  (AP_fnc_qhCuffHack)
    LooneyBin 2026-07-22: CUFF CRACKER -- the deck quickhack that breaches your OWN restraints, "same as the
    car lockpick just for handcuffs". Free with the firmware flash. Runs the Sequence Breach minigame directly
    (fn_lockpick refuses to run while the caster is restrained, which is exactly when you need this), and on a
    clean breach frees you (the fn_jailMe unrestrain pattern). Reached with SHIFT+Y while cuffed -- no phone
    (blocked while restrained) and no goggles.
*/
if (!hasInterface) exitWith {};
if (!(call AP_fnc_hasDeck)) exitWith { ["You don't have a Cyberdeck.", "basic"] spawn AP_fnc_handleMessage; };
if (!(player getVariable ["AP_restrained", false]) && {!(player getVariable ["AP_civRestrained", false])}) exitWith {
    ["<t color='#c8f53a'>CUFF CRACKER</t> -- you're not restrained.", "basic"] spawn AP_fnc_handleMessage;};
if (dialog) exitWith {};   // the Sequence Breach opens its own dialog
// QUEST HOOKS. These lived in fn_qhConsoleFire.sqf, which called itself "the single
// place all four breach tools route through" -- true only of that console, which had
// no opener, so `qhbreach` could never actually fire. The console was deleted
// 2026-09-04 with the rest of the retired cyberdeck cluster; the hooks move HERE, to
// where a breach is actually attempted, so every surface (visor, launcher router,
// world action, keybind) counts rather than one retired dialog.
// Placed AFTER the gates on purpose: a refused attempt is not a breach.
["action", "qhbreach", 1] spawn AP_fnc_handleQuest;
["action", "breach_cuffs", 1] spawn AP_fnc_handleQuest;
["qhbreach", [1]] call aq_fnc_event;   // ArmaQuest: aq_fx2_breach


["<t color='#c8f53a'>CUFF CRACKER</t> -- jacking your restraints...", "basic"] spawn AP_fnc_handleMessage;
private _r = [6] call AP_fnc_cyberdeckSeq;   // 6-cell buffer -- roughly a car breach
if (_r isEqualTo 1) then {if (alive player) then {player switchMove "";
        player setVariable ["AP_escorting", false, true];
        player setVariable ["AP_transporting", false, true];
        player setVariable ["AP_restrained", false, true];
        player setVariable ["AP_civRestrained", false, true];
        detach player;};
    titleText ["Restraints cracked -- you're loose.", "PLAIN"];
    ["<t color='#c8f53a'>CUFFS CRACKED</t> -- you slipped the restraint.", "basic"] spawn AP_fnc_handleMessage;} else {
    ["<t color='#ff5a3c'>TRACE FAILED</t> -- the cuffs held. Try again.", "basic"] spawn AP_fnc_handleMessage;};
