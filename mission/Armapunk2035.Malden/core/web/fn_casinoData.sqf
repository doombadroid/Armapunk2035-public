/*
    fn_casinoData.sqf — one payload for the whole casino.

    NO NEW AUTHORITY. Every game already runs server-side -- APS_fnc_casinoSRV
    settles coinflip / wheel / slots / roulette / crash / hi-lo, APS_fnc_blackJackSRV
    settles blackjack, and both credit through receivers gated on
    remoteExecutedOwner == 2. The page sends the same INTENT the native dialog
    sends and draws whatever comes back. It never decides an outcome and it never
    touches a balance.

    The gate is copied from fn_casino's own _fnGate rather than re-invented, so
    the web tables refuse in exactly the cases the native ones do.

    Usage:  private _p = [] call AP_fnc_casinoData;
*/

// Same order and wording as fn_casino's gate. Empty string means "you may play".
private _gate = "";
if ((AP_is_arrested isEqualType []) && {(AP_is_arrested param [0, 0]) > 0}) then { _gate = "You can't gamble from a cell." };
if (_gate isEqualTo "" && {player getVariable ["AP_restrained", false]}) then { _gate = "Your hands are restrained." };
if (_gate isEqualTo "" && {!alive player || {AP_isDowned} || {AP_knockout}}) then { _gate = "You're in no state to gamble." };
if (_gate isEqualTo "" && {AP_inCombat}) then { _gate = "You can't gamble while in combat." };
if (_gate isEqualTo "" && {!(AP_effSide in [civilian, west, independent])}) then { _gate = "You can't play at the casino right now." };

if (isNil "AP_casBet")    then { AP_casBet = 10000 };
if (isNil "AP_wheelFree") then { AP_wheelFree = false };
if (isNil "AP_wheelCost") then { AP_wheelCost = 50000 };

// KEY NAMES ARE THE PAGES' CONTRACT, not this file's preference. The tables read
// balance / limits / wheel.freeAvailable; the first scaffold used bank / min+max /
// wheel.free and this payload was never moved over. Nothing errored: the landing
// set "$" + Math.round(undefined) into the balance, then defaultStatus() read
// cas.limits[0] off undefined and threw INSIDE the channel handler, which webui.js
// catches -- so renderFloor() never ran and the floor was simply empty. Both sets
// of names are emitted; the old ones cost nothing and bank/cash are worth having.
createHashMapFromArray [
    ["gate",    _gate],
    // The bet ladder and the 10k-500k clamp are fn_casino's, not this screen's.
    ["bet",     AP_casBet],
    ["chips",   [10000, 50000, 100000, 250000, 500000]],
    ["limits",  [10000, 500000]],
    ["min",     10000],
    ["max",     500000],
    // The casino settles against the BANK, so that is the balance a table shows.
    ["balance", AP_atmcash],
    ["bank",    AP_atmcash],
    ["cash",    AP_cash],
    ["games", [
        createHashMapFromArray [["id", "coinflip"], ["name", "COIN FLIP"],  ["blurb", "Heads or tails. Evens."]],
        createHashMapFromArray [["id", "hilo"],     ["name", "HI-LO"],      ["blurb", "Call the next card."]],
        createHashMapFromArray [["id", "blackjack"],["name", "BLACKJACK"],  ["blurb", "Hit, stand, double, split."]],
        createHashMapFromArray [["id", "holdem"],   ["name", "HOLD'EM"],    ["blurb", "Six seats, real players, no house hand."]],
        createHashMapFromArray [["id", "roulette"], ["name", "ROULETTE"],   ["blurb", "Colour, parity, or a straight number."]],
        createHashMapFromArray [["id", "slots"],    ["name", "SLOTS"],      ["blurb", "Three reels."]],
        createHashMapFromArray [["id", "crash"],    ["name", "CRASH"],      ["blurb", "Cash out before it busts."]],
        createHashMapFromArray [["id", "wheel"],    ["name", "THE WHEEL"],  ["blurb", "One spin. Cash, a vehicle, or nothing."]]
    ]],
    // wheel cost is server-authoritative and synced from its status render --
    // never a client literal, which is why fn_casino keeps AP_wheelCost at all
    ["wheel", createHashMapFromArray [
        ["freeAvailable", AP_wheelFree],
        ["free",          AP_wheelFree],
        ["cost",          AP_wheelCost]
    ]]
]
