/*
    File: fn_casinoApp.sqf  (LooneyBin -- Casino phone app entry)
    What the "Casino" phone button calls. Thin launcher: restriction-gates the player then opens the
    casino GAME-SELECT LANDING (AP_fnc_casino "landing"), from which the player picks Blackjack /
    Coin Flip / Wheel / Slots / Roulette / Hi-Lo. This fn NEVER decides outcomes or credits money --
    all of that lives server-side in the per-game APS_fnc engines and the owner-2-gated receivers.
*/
if (!alive player) exitWith { ["You're in no state to gamble.","basic"] spawn AP_fnc_handleMessage };
if !(AP_effSide in [civilian, west, independent]) exitWith { ["You can't visit the casino right now.","basic"] spawn AP_fnc_handleMessage };
if (player getVariable ["AP_restrained", false]) exitWith { ["Your hands are restrained.","basic"] spawn AP_fnc_handleMessage };
if (player getVariable ["AP_casinoBanned", false]) exitWith { ["You have self-excluded from the casino. An admin must lift it.","basic"] spawn AP_fnc_handleMessage };

["landing", []] call AP_fnc_casino;
