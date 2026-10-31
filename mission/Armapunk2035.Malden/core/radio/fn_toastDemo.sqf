/*
    AP_fnc_toastDemo  (LooneyBin, STRONGBOX) -- preview the notification "receipt slips" in-game. TEST ONLY.
    Fires sample slips through AP_fnc_hudToast so the owner can see the design. Colour is strictly semantic
    (green money / coral spend+danger / blue cop / brass neutral+phone), never decoration.
    _this = [_n]   1..5 = one slip;  0 / omitted = fire all five, staggered so they stack top-right.
    Wired to the owner-only "!toast" chat command (core\chatcom\settings\commands.hpp). Remove both when done.
*/
params [["_n", 0, [0]]];

// [ type, title, amount, sub ]
private _demos = [["money",  "Wire received",         "+$42,000",  "From Marcus Vega"],
    ["cop",    "Plate flagged by MaxSec",  "",          "Athira checkpoint"],
    ["danger", "Wanted level up",       "$18,500",   "Armed robbery logged"], ["debit",  "Bought MH-9 Hummingbird","-$45,000", "Altis Air"],
    ["phone",  "Incoming call",         "",          "The Broker"]];

if (_n >= 1 && {_n <= 5}) exitWith { (_demos select (_n - 1)) call AP_fnc_hudToast; };

// all five, staggered ~0.45s so they stack top-right
[_demos] spawn {params ["_demos"];
    { _x call AP_fnc_hudToast; uiSleep 0.45; } forEach _demos;};
