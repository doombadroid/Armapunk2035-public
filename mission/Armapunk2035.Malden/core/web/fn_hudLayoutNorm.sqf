/*
    AP_fnc_hudLayoutNorm -- turn anything at all into a legal seven-pair HUD layout.

        private _L = [_maybeAnything] call AP_fnc_hudLayoutNorm;
        // -> [[gx,gy,gs],[hpx,hpy,hps],[h2ox,h2oy,h2os],[foodx,foody,foods],[wx,wy,ws],[cx,cy,cs],[mx,my,ms]]

    Handle order is hudeditor.md §1: group, hp, h2o, food, wanted, chips, minimap. dx/dy are
    viewport FRACTIONS in [-1, 1] -- not pixels and not rem, so a layout built at one resolution
    or UI scale lands in the same relative place at another. The third number is the handle's
    uniform SCALE in [0.25, 3] (hudeditor.md §9), default 1. v1 rows stored PAIRS; a pair reads as
    scale 1, which is why the third element is `param [2, 1]` and not `select 2`.

    THIS ONE CLAMPS. THE SERVER'S REJECTS. That asymmetry is deliberate and it is the whole
    reason there are two validators rather than one shared file. APS_fnc_hudLayoutSRV refuses a
    malformed payload whole, because repairing it would mean guessing which half was meant and
    writing the guess into an account row. Here there is nothing to guess with and nothing safe
    to refuse INTO: this function's answer is what the HUD gets positioned by, and returning
    "no" would leave the player with a HUD in an undefined state. So a missing pair reads as
    [0,0] -- the designer's own layout -- a wrong type reads as 0, and an out-of-range number is
    pulled back to the edge of the screen rather than dropped.

    NOTHING IS COMPILED. The input is already an SQF array by the time it arrives (the server
    parses the column with parseSimpleArray and sends a real array), and this function does
    arithmetic on it and nothing else. There is no code path here, or anywhere in this feature,
    that hands a stored value to compile.
*/

params [["_in", [], [[]]]];

private _out = [];
for "_i" from 0 to 6 do {
    private _p = _in param [_i, [0, 0]];
    private _x = 0;
    private _y = 0;
    private _s = 1;
    if (_p isEqualType [] && {(count _p) >= 2}) then {
        private _a = _p select 0;
        private _b = _p select 1;
        private _c = _p param [2, 1];
        // finite as well as isEqualType: a NaN or an infinity would sail through the type test
        // and then poison the CSS it is formatted into, which fails silently -- the transform
        // is simply dropped and the element does not move, with nothing on screen to say why.
        if (_a isEqualType 0 && {finite _a}) then { _x = (_a max -1) min 1 };
        if (_b isEqualType 0 && {finite _b}) then { _y = (_b max -1) min 1 };
        if (_c isEqualType 0 && {finite _c}) then { _s = (_c max 0.25) min 3 };
    };
    _out pushBack [_x, _y, _s];
};

_out
