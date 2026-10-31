/*
    fn_deckQh.sqf — ICEBREAKER OS / TAL OS payloads.

    Two channels, matching the design handoff's contract:
        ["deck"]    -> loadout, library, chips, proxy
        ["targets"] -> what is in range right now

    ONE SCREEN, TWO SIDES. The catalogue is queried with "civ" or "cop" and the
    differences fall out of the data: cop rows carry an `auth` gate, civ rows
    carry the breach tools and the Proxy Chain. Nothing here branches on side
    beyond that.

    TIMING, because the design brief had it the other way round: ICE TRACE does
    NOT fire at cast start. APS_fnc_qhSRV sleeps the full upload first (line 130)
    and only then traces (line 139), so nothing has leaked while the bar is
    running -- the whole channel is the "will I get away with this" window. The
    victim learns immediately (INTRUSION DETECTED at cast start); the MaxSec do not.

    COP TOOLS NEVER SELF-REPORT. The trace is gated on `!_cop`, so an officer's
    own casts never emit one. TAL OS still RECEIVES them -- that is its grid feed.

    Usage:  private _payload = ["deck"] call AP_fnc_deckQh;
*/

params [["_what", "deck", [""]]];

private _cop  = AP_effSide isEqualTo west;
private _side = if (_cop) then { "cop" } else { "civ" };

// ---------------------------------------------------------------- targets ----
// Same rule as the console's own scan: players and vehicles within 220 m, nearest
// first. The console stops at four because it has four fixed controls; a page
// scrolls, so the cap here is only a sanity limit.
if (_what isEqualTo "targets") exitWith {
    private _found = [];
    {
        if (alive _x && { isPlayer _x } && { _x isNotEqualTo player }) then { _found pushBackUnique _x };
    } forEach (player nearEntities [["CAManBase"], 220]);
    {
        if (alive _x && { (_x isKindOf "Car") || (_x isKindOf "Air") || (_x isKindOf "Ship") || (_x isKindOf "Tank") }
            && { _x isNotEqualTo (vehicle player) }) then { _found pushBackUnique _x };
    } forEach (player nearEntities [["Car", "Air", "Ship", "Tank"], 220]);
    _found = [_found, [], { player distance _x }, "ASCEND"] call BIS_fnc_sortBy;
    if (count _found > 12) then { _found resize 12 };

    private _out = [];
    {
        private _o    = _x;
        private _isMan = _o isKindOf "CAManBase";
        private _veh  = objectParent _o;
        _out pushBack (createHashMapFromArray [
            // netId, so the page can hand an object back without ever holding one
            ["id",   netId _o],
            ["name", if (_isMan) then { [name _o] call AP_fnc_cleanName }
                     else { getText (configOf _o >> "displayName") }],
            ["kind", if (_isMan) then { "player" } else { "vehicle" }],
            ["dist", round (player distance _o)],
            ["l2",   if (_isMan) then { format ["%1", side _o] } else { typeOf _o }],
            // These are the EXACT variables APS_fnc_qhSRV's auth switch reads, so a
            // row that looks castable here is castable there. Guessing at them
            // would mean the screen and the server disagree about who is a valid
            // target, which is worse than showing nothing.
            ["flags", createHashMapFromArray [
                ["wanted",     _isMan && { (_o getVariable ["AP_wantedAmt", 0]) > 0 }],
                ["restrained", (_o getVariable ["AP_restrained", false]) || { _o getVariable ["AP_civRestrained", false] }],
                ["armed",      _isMan && { (primaryWeapon _o) isNotEqualTo "" }],
                ["driver",     _isMan && { !isNull _veh } && { (driver _veh) isEqualTo _o }],
                ["los",        (lineIntersectsSurfaces [eyePos player, eyePos _o, player, _o]) isEqualTo []]
            ]]
        ]);
    } forEach _found;
    _out
};

// ------------------------------------------------------------------- deck ----
private _mods  = player getVariable ["AP_cdMods", []];
private _slots = call AP_fnc_qhConsoleGet;

private _hack = {
    params ["_row"];
    _row params ["_id", "_name", "_blurb", "_icon", "", "_up", "_cd", "_range",
                 ["_los", false], ["_auth", ""], ["_kind", "player"], ["_chip", ""], ["_reqMod", -1]];
    // live cooldown, not the catalogue figure -- the screen has to say READY or
    // COOLDOWN 42s, and only the client knows which
    private _left = ((missionNamespace getVariable ["AP_qhCd_" + _id, 0]) - diag_tickTime) max 0;
    createHashMapFromArray [
        ["id", _id], ["name", _name], ["blurb", _blurb], ["glyph", _icon],
        ["up", _up], ["cd", _cd], ["range", _range], ["los", _los],
        ["auth", _auth], ["targetKind", _kind], ["counterChip", _chip],
        ["cdLeft",   round _left],
        // APS_fnc_qhSRV validates against range * 1.25 -- a small grace for
        // movement. Reporting the bare range would grey out casts that succeed.
        ["reach",    _range * 1.25],
        // a hack whose chip is not installed is not loadable at all
        ["unlocked", (_reqMod isEqualTo -1) || { _reqMod in _mods }]
    ]
};

private _library = ([_side] call AP_fnc_qhCfg) apply { [_x] call _hack };

// Civilian breach tools need no chip and are not part of the six ring slots.
private _tools = [];
if (!_cop) then {
    { _tools pushBack ([_x] call _hack); } forEach (missionNamespace getVariable ["AP_qhUtil", []]);
};

// Firewall chips: owned permanently, only TWO equipped. Ids 101-104 in AP_cdMods
// are the chip range; AP_fwChips is what is actually seated.
private _chipNames = createHashMapFromArray [
    ["scrambler",  "Scrambler"], ["opticfilter", "Optic Filter"], ["audiolimiter", "Audio Limiter"],
    ["hardenedfw", "Hardened Firmware"], ["deadbolt", "Deadbolt"], ["freqhop", "Freq-Hop"],
    ["icefw",      "ICE Firewall"]
];
private _equipped = player getVariable ["AP_fwChips", []];
private _owned = [];   // see the ICE block in the payload below -- _equipped is read there too
{
    _owned pushBack (createHashMapFromArray [
        ["id", _x], ["name", _chipNames getOrDefault [_x, _x]], ["equipped", _x in _equipped]
    ]);
} forEach (keys _chipNames);

createHashMapFromArray [
    ["side",     if (_cop) then { "cop" } else { "civ" }],
    ["slots",    _slots],
    ["tools",    _tools],
    ["library",  _library],
    ["chips",    createHashMapFromArray [["owned", _owned], ["equipped", _equipped], ["cap", 2]]],
    // Proxy Chain is a CONSUMABLE armed from the bag before casting, not a chip
    // and not a button -- there is nothing to press here, only a state to read.
    ["proxy",    createHashMapFromArray [
        ["armed",   player getVariable ["AP_proxyActive", false]],
        ["charges", missionNamespace getVariable ["AP_inv_proxychain", 0]]
    ]],
    // ---- ICE FIREWALL -------------------------------------------------------
    // Neither design file knows this exists, and it is the best counterplay in
    // the system, so it gets first-class state here.
    //
    // It is DEFENCE, not a hack: chip 108, seated like any firewall chip, and it
    // eats exactly ONE Tier 4 hack aimed at YOU (flatline / memhole) before
    // shattering. The server destroys and persists it, then stamps AP_iceRearm
    // five minutes out so a rich player cannot chain-replace a pocket-change
    // hard counter. The attacker still pays their charge either way.
    //
    // Three states the screen has to tell apart:
    //   SEATED     owned, installed and holding
    //   SHATTERED  it ate something; N seconds until another can be seated
    //   NONE       not owned or not installed
    ["ice", createHashMapFromArray [
        ["owned",  108 in _mods],
        ["seated", (108 in _mods) && { "icefw" in _equipped }],
        ["rearm",  round (((player getVariable ["AP_iceRearm", 0]) - serverTime) max 0)]
    ]]
    // owner 2026-09-05: the "firmware" field (ILLEGAL / STOCK) is GONE from this payload -- every civilian
    // runs ICEBREAKER now, so it was a constant. deck.html's DECK card lost the matching row.
]
