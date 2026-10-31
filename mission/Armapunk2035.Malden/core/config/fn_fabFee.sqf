params [["_key", "", [""]], ["_qty", 1, [0]]];
/*
    fn_fabFee.sqf  (AP_fnc_fabFee)  -- recursive backbone-material cost, and the schematic price
    derived from it.

        ["<outputClass>"] call AP_fnc_fabFee            -> [<backboneUnits>, "<ndPriceString>"]
        ["<outputClass>", <qty>] call AP_fnc_fabFee     -> same, scaled by qty

    WHAT THIS IS FOR. Nothing here charges anything to print. Production costs materials and time,
    never money (owner 2026-08-21). This walks a recipe tree counting how many units of ONE backbone
    material an item contains IN TOTAL -- including the units hidden inside its sub-components --
    and turns that into the price of the item's SCHEMATIC, in New Drachma. So the economy prices
    every unlock off one number, no price is authored per recipe, and changing a recipe reprices
    its schematic automatically.

    WHY RECURSION AND NOT THE TOP-LEVEL PARTS LIST. This is ported from a system where the same
    resolver priced 79 weapons with no price written down anywhere, and the direct-vs-recursive gap
    is the entire reason it worked: their AK-12's recipe listed 50 backbone units but the gun
    actually contained 55 once its receiver, stock and handguard were counted. A port that reads
    only the top-level list silently underprices every item that has sub-components -- which, here,
    is every weapon and vest.

    TWO FOOTGUNS FROM THE ORIGINAL, BOTH FIXED HERE.
      * Its multiplier was the literal 3000, matching a shop price it never read. Change the shop
        and the fee silently stopped tracking it. Ours comes from ["backbone"] call AP_fnc_fabCfg.
      * Its second line was `if (l_zz > 100) exitWith {0}`, which reads like a recursion depth
        guard and is not one -- l_zz was the player's GANG ID, so members of a recognised gang paid
        no fee at all, switched off by a subsystem the function never mentions. Deleted. The real
        cycle guard is _seen, below.

    ARITHMETIC IS INTEGER TEN-THOUSANDTHS, NEVER ND. fn_ndDebitSrv.sqf's header states the ledger
    rule: all ND arithmetic is SQL on DECIMAL(20,4), and SQF's 32-bit floats never touch it. 0.05
    is not exactly representable in binary, so `units * 0.05` drifts. We multiply integers (exact
    well past any unit count a recipe can reach) and render the string by division and modulo, so
    no float is ever involved and the output always satisfies fn_ndDebitSrv's `\d{1,14}(\.\d{1,4})?`
    validator -- which is also its SQL-injection guard, and which a float would fail outright the
    moment `format` chose scientific notation.
*/

(["backbone"] call AP_fnc_fabCfg) params [["_backbone", "", [""]], ["_tthPerUnit", 0, [0]]];
if (_backbone isEqualTo "" || {_tthPerUnit <= 0}) exitWith {[0, ""]};

// Walks the tree and returns the total backbone units in _k at quantity _n. _seen carries the
// ancestor chain so a recipe that (mis)lists itself, directly or through a loop, terminates
// instead of recursing until the engine kills the script.
// Everything inside works in BARE keys. Ingredients are stored as AP_inv_<item> while recipe keys
// are the bare output class, and mixing the two forms is the easy mistake here: compare a bare key
// against "AP_inv_filament" and the backbone test never fires, so every item silently prices at
// zero and filament itself counts as none of itself. Normalise on the way in, once.
private _count = {
    params [["_k", "", [""]], ["_n", 1, [0]], ["_seen", [], [[]]]];

    if (_k isEqualTo _backbone) exitWith {_n};

    private _row = ["getRecipe", _k] call AP_fnc_fabCfg;
    if (_row isEqualTo []) exitWith {0};        // a raw material that isn't the backbone: costs nothing
    if (_k in _seen) exitWith {0};              // cycle guard

    private _total = 0;
    private _chain = _seen + [_k];
    {
        _x params [["_ingVar", "", [""]], ["_ingQty", 0, [0]]];
        private _ingKey = if ((_ingVar select [0, 7]) isEqualTo "AP_inv_") then {_ingVar select [7]} else {_ingVar};
        _total = _total + ([_ingKey, _n * _ingQty, _chain] call _count);
    } forEach (_row select 1);

    _total
};

private _units = [_key, _qty, []] call _count;
if (_units <= 0) exitWith {[0, ""]};

// units -> ND string, entirely in integers.
private _tth   = _units * _tthPerUnit;
private _whole = floor (_tth / 10000);
private _frac  = _tth - (_whole * 10000);
private _fracS = str _frac;
while {count _fracS < 4} do {_fracS = "0" + _fracS};

[_units, format ["%1.%2", _whole, _fracS]]
