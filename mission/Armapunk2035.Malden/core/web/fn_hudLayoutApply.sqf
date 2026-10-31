/*
    AP_fnc_hudLayoutApply -- put a saved layout onto a live HUD page. Spec: hudeditor.md §2.

        [_ctrl] call AP_fnc_hudLayoutApply;             // apply the cached AP_hudLayout
        [_ctrl, _layout] call AP_fnc_hudLayoutApply;    // apply an explicit one (the editor)

    Works on ANY bridged control showing ui\html\hud.html -- the live title layer (938301) and
    the editor dialog's control (938401) are both fed through here, so the editor cannot drift
    from the thing it is editing.

    ---- WHY transform, AND WHY A STYLESHEET -------------------------------------------------

    Measured against hud.html, not reasoned about:

      * render() rewrites style.bottom on all three plates (line 285) and on #chips (line 308),
        every tick. Anything written to bottom/top/left is gone within 83 ms.
      * render() rewrites className on all three plates (line 288) and on #wplate (line 298).
        A class added from outside is wiped just as fast -- which is also why the editor's own
        outlines live on a separate overlay layer and never on the targets themselves.
      * transform is written NOWHERE on #stack, #p_*, #wplate, #chips or #mapwrap. The page's
        only transforms are on .seg i, #mrot, #mnorth, .ring and #mme -- children, or unrelated.

    So position rides on transform, and it arrives as an injected <style> element rather than as
    inline style, so there is no per-tick collision to lose and no !important war to fight for
    the ordinary case.

    THE PLATES ARE CHILDREN OF #stack, so a transform on #stack moves all four plus the wanted
    plate for free -- the group handle is ONE property, not five. #chips is a SIBLING of #stack
    (both position:fixed), so it has to add the group's variables to its own explicitly. That
    asymmetry is in the CSS below and it is the only reason the two are written differently.

    ---- SCALE (v2, hudeditor.md §9) --------------------------------------------------------------

    Each handle's third number is a uniform scale, and it rides in the SAME transform declaration
    as `scale(var(--apXs))`, with a fixed transform-origin: `right bottom` for everything anchored
    to the bottom-right corner (the stack, the plates, the wanted plate, the chips) and `left top`
    for the minimap. Three things in those rules are load-bearing:

      * MEMBERS DIVIDE THEIR TRANSLATE BY THE GROUP SCALE. A plate is a child of the scaled #stack,
        so a raw calc(var(--aphx)*100vw) would land at dx*vw*sg screen pixels and a saved member
        offset would mean something different at every group scale. Dividing by --apgs keeps every
        [dx,dy] a true screen fraction. The members' EFFECTIVE scale is sg*own for free, by nesting.
      * CHIPS RIDE THE SCALED STACK. #chips is a sibling: it neither inherits the group scale nor
        moves when the stack grows about its origin. So its scale is written as the product, and
        its Y gains -12.15rem*(sg-1): with the pin armed the chips' bottom is 14.15rem and the
        stack's is 2rem, so the chips sit 12.15rem above the stack's origin, and scaling the stack
        about that origin moves them by exactly that much. Both are right:2rem -- X is aligned.
      * THE PIN ARMS WHEN sg != 1 AS WELL AS IN BREAKOUT. Unscaled, a bounty shoves the plates and
        the chips up 3.15rem in lockstep. Scaled about right-bottom, the plates' shove is 3.15*sg on
        screen and the chips' is 3.15 -- they separate. Pinning removes the shove and makes the
        12.15rem constant exact. A MEMBER scale alone changes no `bottom`, so it does not arm it.

    ---- THE off REFLOW, AND WHEN IT GETS PINNED ---------------------------------------------

    When a bounty exists the page sets off = 3.15 and shoves the three plates and the chips up
    by that much, clearing bottom:0 for #wplate. Once a player has hand-placed the plates in a
    row that shift is a visible 3.15rem jump the moment they get wanted.

    Pinning bottom at the NO-bounty values is not available: #p_food sits at bottom:0 and
    #wplate is also at bottom:0 and 2.75rem tall, so they would overlap. The pin therefore uses
    the WANTED-PRESENT values, and the layout is then identical whether or not there is a
    bounty.

    AND THE PIN ONLY ARMS IN BREAKOUT MODE -- when at least one MEMBER offset (handles 1-5) is
    non-zero, i.e. the player has actually pulled something out of the stack. A player who never
    opened the editor, or who only moved the group or the minimap, gets the page's stock
    behaviour byte for byte. This is the difference between a feature that is opt-in and one
    that quietly changes every player's HUD, and it is worth the extra branch.

    An all-default layout (every offset 0, every scale 1) emits an EMPTY stylesheet rather than a set of translate(0,0) scale(1) rules.
    Same reason: a transform, even a zero one, makes the element a containing block for any
    position:fixed descendant. Nothing in hud.html has one today, so this is not a live bug --
    it is a trap left armed for whoever adds the first one, and clearing the sheet disarms it.
*/

params [["_ctrl", controlNull, [controlNull]], ["_layout", [], [[]]]];
if (isNull _ctrl) exitWith { false };

private _src = if (_layout isEqualTo []) then {
    missionNamespace getVariable ["AP_hudLayout", []]
} else { _layout };
private _L = [_src] call AP_fnc_hudLayoutNorm;

// Handle order -> CSS variable prefix. g group, h hp, w h2o, f food, b wanted (Bounty), c
// chips, m minimap. Short because every one of them is formatted into the statement twice.
private _keys = ["g", "h", "w", "f", "b", "c", "m"];

private _vars = "";
private _moved = false;
{
    private _key = _x;                          // "g", "h", ... -- forEach's own _x
    private _p = _L select _forEachIndex;
    private _dx = _p select 0;
    private _dy = _p select 1;
    private _s = _p select 2;
    if (!(_dx isEqualTo 0) || {!(_dy isEqualTo 0)} || {!(_s isEqualTo 1)}) then { _moved = true };
    // toFixed, NOT a bare %1. SQF's format renders a small enough number in exponent form
    // ("1e-005"), which is not a CSS number: the whole custom-property declaration would be
    // dropped and the element would simply not move, with nothing on screen to say why.
    _vars = _vars + format ["--ap%1x:%2;--ap%1y:%3;--ap%1s:%4;", _key, _dx toFixed 5, _dy toFixed 5, _s toFixed 5];
} forEach _keys;

// Handles 1-5 are the group's MEMBERS (hp, h2o, food, wanted, chips). Any one of them off zero
// means the stack has been broken apart and the reflow has to be pinned. The group itself (0)
// and the minimap (6) move whole things and leave the internal geometry alone -- but a SCALED
// group separates the plates' shove from the chips' (see the header), so that pins too.
private _breakout = !(((_L select 0) select 2) isEqualTo 1);
for "_i" from 1 to 5 do {
    private _p = _L select _i;
    if (!((_p select 0) isEqualTo 0) || {!((_p select 1) isEqualTo 0)}) then { _breakout = true };
};

private _css = "";
if (_moved) then {
    _css = ":root{" + _vars + "}"
        + "#stack{transform-origin:right bottom;transform:translate(calc(var(--apgx)*100vw),calc(var(--apgy)*100vh)) scale(var(--apgs))}"
        + "#p_hp{transform-origin:right bottom;transform:translate(calc(var(--aphx)*100vw/var(--apgs)),calc(var(--aphy)*100vh/var(--apgs))) scale(var(--aphs))}"
        + "#p_h2o{transform-origin:right bottom;transform:translate(calc(var(--apwx)*100vw/var(--apgs)),calc(var(--apwy)*100vh/var(--apgs))) scale(var(--apws))}"
        + "#p_food{transform-origin:right bottom;transform:translate(calc(var(--apfx)*100vw/var(--apgs)),calc(var(--apfy)*100vh/var(--apgs))) scale(var(--apfs))}"
        + "#wplate{transform-origin:right bottom;transform:translate(calc(var(--apbx)*100vw/var(--apgs)),calc(var(--apby)*100vh/var(--apgs))) scale(var(--apbs))}"
        // The one that adds the group in by hand -- see the header. calc REQUIRES the spaces
        // around the + and the -; without them the whole expression is invalid and silently
        // dropped. The 12.15rem term is what keeps the chips above a scaled stack.
        + "#chips{transform-origin:right bottom;transform:translate(calc((var(--apgx) + var(--apcx))*100vw),calc((var(--apgy) + var(--apcy))*100vh - 12.15rem*(var(--apgs) - 1))) scale(calc(var(--apgs)*var(--apcs)))}"
        + "#mapwrap{transform-origin:left top;transform:translate(calc(var(--apmx)*100vw),calc(var(--apmy)*100vh)) scale(var(--apms))}";

    if (_breakout) then {
        // 5.90 + 3.15, 2.95 + 3.15, 0.00 + 3.15, 11.0 + 3.15 -- the page's own bottoms with
        // off applied. BARS order is hp, h2o, food and the page uses (2 - i) * 2.95, so hp is
        // the TOP plate at 5.9rem and food is the bottom one at 0.
        _css = _css
            + "#p_hp{bottom:9.05rem!important}"
            + "#p_h2o{bottom:6.1rem!important}"
            + "#p_food{bottom:3.15rem!important}"
            + "#chips{bottom:14.15rem!important}";
    };
};

// The statement is built entirely from numbers this file produced through toFixed and from
// literals written above it, so there is no quote, backslash or newline that could reach the
// JS string -- which is what makes a plain single-quoted literal safe here. Nothing the player
// typed, and nothing from the page, is ever interpolated into an ExecJS statement in this
// feature.
private _js = "(function(){var d=document,s=d.getElementById('apLay');"
    + "if(!s){s=d.createElement('style');s.id='apLay';(d.head||d.documentElement).appendChild(s);}"
    + "s.textContent='" + _css + "';})()";

[_ctrl, _js] call webui_fnc_exec
