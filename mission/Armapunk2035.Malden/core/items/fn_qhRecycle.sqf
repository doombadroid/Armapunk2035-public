// Altis Life game mechanic — fictional in-game "quickhack" ability, game logic only
/*
    File: fn_qhRecycle.sqf  (AP_fnc_qhRecycle)
    LooneyBin 2026-07-23: CHIP RECYCLER (owner spec) -- feed 3 hack chips, get 1 random Tier-3 chip back.
    The sink for duplicate loot chips: installing refuses a dupe and leaves the item in inventory, so dupes
    pile up. This melts any 3 hack-chip ITEMS -> a random T3 chip, smoothing the loot curve toward the
    tier money can't buy. PREFERS already-installed (useless) dupes so it never eats your last usable chip.
    Client removes the 3 (client-authoritative inventory, same boundary as assemble); the SERVER rolls +
    grants the random T3 (anti-mint), refund-safe. Reachable from the Kabuki Electronics scroll action.
*/
if !(call AP_fnc_hasDeck) exitWith { ["The chip recycler is ICEBREAKER-only, and ICEBREAKER is civilian-only.", "basic"] spawn AP_fnc_handleMessage; };

// every meltable hack chip -> its installed-hack id (to detect "already installed = a true dupe")
private _chipIds = createHashMapFromArray [["pingchip", 207], ["distractchip", 208], ["staticchip", 209], ["whiteoutchip", 210],
    ["stickychip", 211], ["jamchip", 212], ["wiretapchip", 213], ["crybabychip", 214],
    ["synapsechip", 215], ["leechchip", 216], ["shortchip", 217], ["eyespychip", 218], ["valetchip", 219],
    ["ghostplatechip", 201], ["blackoutdaemon", 202], ["flatlinecharge", 203], ["memoryholechip", 204],
    ["chauffeurchip", 206], ["puppetchip", 205]];
private _owned = player getVariable ["AP_cdMods", []];

// build a flat pool of held chip units, each tagged with whether it's an already-installed dupe
private _pool = [];   // [class, isDupe]
{private _cls = _x;
    private _n = missionNamespace getVariable [format ["AP_inv_%1", _cls], 0];
    private _dupe = (_chipIds get _cls) in _owned;
    for "_i" from 1 to _n do { _pool pushBack [_cls, _dupe]; };} forEach (keys _chipIds);

if (count _pool < 3) exitWith {
    ["Chip Recycler needs 3 hack chips to melt down. Loot more, or hang onto your duplicates.", "basic"] spawn AP_fnc_handleMessage;};

// spend already-installed dupes first, then usable chips; take the first 3
_pool = (_pool select { _x select 1 }) + (_pool select { !(_x select 1) });
private _take = _pool select [0, 3];

// remove exactly those 3 units
private _removed = 0; {if ([false, (_x select 0), 1] call AP_fnc_handleInv) then { _removed = _removed + 1; };} forEach _take;
if (_removed < 3) exitWith {
    // partial removal shouldn't happen (we counted first), but never call the server on a short feed
    ["Recycler jammed -- couldn't pull 3 chips. Nothing was consumed beyond what's shown.", "basic"] spawn AP_fnc_handleMessage;};

["<t color='#c9e21a'>CHIP RECYCLER</t> -- melting 3 chips...", "basic"] spawn AP_fnc_handleMessage;
[["recycleChips", player], "APS_fnc_cyberdeckSRV", 2] spawn AP_fnc_MP;   // server rolls + grants a random T3 chip
