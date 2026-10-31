/*
    APS_fnc_bjChips  (Armapunk 2035, owner 2026-08-12) -- the powerup chip wallet for
    DEALERBOT's table. Runs on the SERVER. NOT in CfgRE: this is called by other server
    functions only, never by a client, which is the point -- a chip is an economy item and
    the client must never be able to grant itself one.

        ["load",    _uid]                  -> [[chipId, qty], ...]
        ["grant",   _uid, _chip, _n]       -> true   (UPSERT; also clears the pity counter)
        ["spend",   _uid, _chip, _n]       -> bool   (guarded; false if they do not have it)
        ["pity",    _uid]                  -> int    (dry wins since the last drop)
        ["pitybump",_uid]                  -> int    (a money win that dropped nothing)

    THE SPEND IS THE ANTI-DUPE. It is a single guarded UPDATE -- `qty = qty - n WHERE
    qty >= n` -- so two calls racing on the same chip cannot both succeed, and qty can
    never go negative. The caller checks the returned row count, not its own read.
*/
if (!isServer) exitWith { [] };
params [["_mode", "", [""]], ["_uid", "", [""]], ["_chip", "", [""]], ["_n", 1, [0]]];
// "roster" is a pure read of the catalogue and takes no uid. It used to fall
// foul of the guard below and return [] before the switch, so every chip drop
// exited on an "empty catalogue" that was never empty.
if (_uid isEqualTo "" && {(toLower _mode) isNotEqualTo "roster"}) exitWith { [] };

// THE CATALOGUE. ids, display names and tiers are the PAGE's, not this file's
// preference -- the locker does PU_META[w.id][2] with no guard, so an id the page
// does not know throws inside a channel handler, which webui.js swallows. The
// locker would just be empty and nothing would say why. (It shipped as "giftexe"
// here against the page's "gift"; that was one grant away from being a silent
// dead screen.)
//
// tier: 0 common, 1 rare, 2 LEGENDARY.
#define BJ_CATALOGUE [\
    ["peek","PEEK.EXE",0],       ["scramble","SCRAMBLE",0],     ["firewall","FIREWALL",0],\
    ["ghost","GHOST.SYS",0],     ["jackpot","JACKPOT",0],       ["nudge","NUDGE",0],\
    ["eject","EJECT",0],         ["feed","FEED",0],             ["purge","PURGE",0],\
    ["overclock","OVERCLOCK",1], ["siphon","SIPHON",1],         ["hardnudge","HARD NUDGE",1],\
    ["stand19","STAND.19",1],    ["brick","BRICK",1],           ["houseswap","HOUSE SWAP",1],\
    ["handshake","HANDSHAKE",1], ["mirror","MIRROR",1],         ["backstab","BACKSTAB",1],\
    ["rewire","REWIRE",1],       ["spite","SPITE",1],           ["aceinject","ACE.INJECT",1],\
    ["chipswap","CHIP SWAP",1],  ["flatline","FLATLINE",2],     ["gift","GIFT.EXE",2],\
    ["martyr","MARTYR",2],       ["cascade","CASCADE",2]\
]

private _roster = (BJ_CATALOGUE) apply { _x select 0 };

switch (toLower _mode) do {

    // The drop roller needs names and tiers, and there must be exactly one copy
    // of them or they drift from the page's.
    case "roster": { BJ_CATALOGUE };

    case "load": {
        private _rows = [format ["SELECT chip, qty FROM casino_chips WHERE pid='%1' AND qty > 0", _uid], 2, true] call DB_fnc_asyncQuery;
        if (isNil "_rows" || {!(_rows isEqualType [])}) exitWith { [] };
        _rows apply { [format ["%1", _x param [0, ""]], _x param [1, 0]] }
    };

    case "grant": {
        if !(_chip in _roster) exitWith {
            diag_log format ["[BJCHIPS] refused unknown chip '%1' for %2", _chip, _uid]; false
        };
        if (_n < 1) exitWith { false };
        [format ["INSERT INTO casino_chips (pid, chip, qty) VALUES ('%1','%2',%3) ON CONFLICT (pid, chip) DO UPDATE SET qty = casino_chips.qty + %3", _uid, _chip, _n]] call DB_fnc_asyncQuery;
        // a drop resets the guarantee
        [format ["INSERT INTO casino_chip_pity (pid, dry_wins) VALUES ('%1',0) ON CONFLICT (pid) DO UPDATE SET dry_wins = 0", _uid]] call DB_fnc_asyncQuery;
        true
    };

    case "spend": {
        if !(_chip in _roster) exitWith { false };
        if (_n < 1) exitWith { false };

        // The guarded UPDATE is right and always was -- the WHERE is the lock, two
        // racing spends cannot both match, qty cannot go negative. The RETURN was
        // wrong: it read the remaining qty and answered `_left >= 0`, which is true
        // whether the decrement happened or not, and true again (via the 0 default)
        // when the row does not exist at all. So spend always said yes. That cost
        // nothing while chips did nothing; the moment they have effects it is
        // unlimited free plays off an empty pocket.
        //
        // Answer on the DELTA instead: what the row held before, minus what it
        // holds after. If our UPDATE did not match, the delta is 0 and this is
        // false, which is the only honest answer.
        private _qty = {
            params ["_u", "_c"];
            private _r = [format ["SELECT qty FROM casino_chips WHERE pid='%1' AND chip='%2'", _u, _c], 2, true] call DB_fnc_asyncQuery;
            if (isNil "_r" || {!(_r isEqualType [])}) exitWith { 0 };
            parseNumber format ["%1", (_r param [0, [0]]) param [0, 0]]
        };

        private _before = [_uid, _chip] call _qty;
        if (_before < _n) exitWith { false };   // cheap reject; the UPDATE is still the authority
        [format ["UPDATE casino_chips SET qty = qty - %3 WHERE pid='%1' AND chip='%2' AND qty >= %3", _uid, _chip, _n]] call DB_fnc_asyncQuery;
        private _after = [_uid, _chip] call _qty;
        (_before - _after) >= _n
    };

    // CHIP SWAP trades two pockets whole. The primary key is (pid, chip), so the
    // two sets cannot simply be reassigned past each other -- one of them has to
    // stand aside first. The parking pid is not a Steam64 and cannot collide with
    // a real one.
    case "swap": {
        private _other = _chip;   // second uid rides in the chip slot
        if (_other isEqualTo "" || {_other isEqualTo _uid}) exitWith { false };
        [format ["UPDATE casino_chips SET pid='__swap__' WHERE pid='%1'", _uid]] call DB_fnc_asyncQuery;
        [format ["UPDATE casino_chips SET pid='%1' WHERE pid='%2'", _uid, _other]] call DB_fnc_asyncQuery;
        [format ["UPDATE casino_chips SET pid='%1' WHERE pid='__swap__'", _other]] call DB_fnc_asyncQuery;
        true
    };

    case "pity": {
        private _rows = [format ["SELECT dry_wins FROM casino_chip_pity WHERE pid='%1'", _uid], 2, true] call DB_fnc_asyncQuery;
        parseNumber format ["%1", (_rows param [0, [0]]) param [0, 0]]
    };

    case "pitybump": {
        [format ["INSERT INTO casino_chip_pity (pid, dry_wins) VALUES ('%1',1) ON CONFLICT (pid) DO UPDATE SET dry_wins = casino_chip_pity.dry_wins + 1", _uid]] call DB_fnc_asyncQuery;
        private _rows = [format ["SELECT dry_wins FROM casino_chip_pity WHERE pid='%1'", _uid], 2, true] call DB_fnc_asyncQuery;
        parseNumber format ["%1", (_rows param [0, [0]]) param [0, 0]]
    };

    default { [] };
};
