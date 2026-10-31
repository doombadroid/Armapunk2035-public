/*
    fn_holdemCash.sqf  (AP_fnc_holdemCash) -- hold'em's DISPLAY SYNC. It is not a money authority.

    WHAT CHANGED, AND WHY IT MATTERS MORE THAN THE NAME SUGGESTS. This file used to BE the movement:
    APS_fnc_holdemSRV granted the seat and then ordered the player's own client to debit itself
    through here. That fixed the "eaten bet" direction the rest of the casino suffers (the server
    could refuse before any money moved) and opened the opposite one -- a client that never ran the
    order kept its money AND its seat, and the server's `log` row said it had paid. The engine now
    writes `players.bankacc` itself, reads the row back to confirm the movement, and logs on that
    confirmation. See APS_fnc_holdemSRV's _bankMove.

    SO WHAT IS LEFT HERE IS THE CACHE, and it is still mandatory. AP_atmcash is this machine's cached
    copy of the row the server just wrote (security.md 2.4). Two things break if it is not moved:
    the phone and the page header show a balance that is wrong until the next login, and -- the real
    one -- the client's own next periodic save SETs bankacc = AP_atmcash and writes the PRE-movement
    balance straight back over the server's write. Moving the cache is what makes the two converge,
    exactly as APS_fnc_gangBank documents at :136 for its AP_fnc_uC bump.

    IT DOES NOT SAVE. The old body fired [1] call AP_fnc_ClupdatePartial, an ABSOLUTE
    `bankacc = AP_atmcash` write, immediately behind the server's RELATIVE one -- so a client whose
    cache was stale for any other reason would clobber the server's write within the same second.
    The convergence above needs the cache moved, not the save forced; the client's own save cycle
    gets there on its own schedule and carries no extra race.

    Drop this call entirely and the money is still right -- only the display lags a login. That is
    the test of whether something is an authority, and this is not one.

    Why not AP_fnc_uC (["atm","add",n], which is what APS_fnc_gangBank uses for the same job):
    allowedTargets = 1 restricts the TARGET and not the sender and uC carries no origin assertion at
    all, so it is already reachable client to client. This file asserts owner 2. Nothing new gets
    built on uC.

    NOT GUARDED ON THE DIALOG BEING OPEN, deliberately: the cash-out that follows a player closing
    the table arrives after the display is gone, and it still has to land.

    Args: [_amt, _why]   _amt signed -- negative is money that left the bank.
*/

params [["_amt", 0, [0]], ["_why", "", [""]]];
// Server-origin gate: APS_fnc_bankMove (server, owner 2) is the ONLY legitimate caller -- since 2026-09-03 the
// primitive moves this cache for every bank movement it confirms (hold'em buy-ins and credits, the duty
// bounty payoff), so a caller of the primitive cannot leave the cache behind. Before that the push lived in
// hold'em's _cash and the buy-in skipped it: the bank on the phone never dropped, and the client's next
// absolute save refunded the buy-in into the row. A forged
// call cannot mint anything any more -- the bank row is the server's -- but it could still desync a
// player's display from it, and a wrong balance on the phone is a support ticket either way.
if (remoteExecutedOwner != 2) exitWith {};
_amt = round _amt;
if (_amt isEqualTo 0) exitWith {};

private _before = AP_atmcash;
// FLOORED AT ZERO. A negative AP_atmcash flows into the client's own DB save, so a cache that has
// somehow drifted below the debit is clamped rather than driven negative. This can no longer hide a
// real overdraft: the server refuses an unbacked debit against the ROW before it writes anything, so
// if this ever fires the cache was already wrong and the RPT line is the interesting part.
if (_amt < 0 && {(_before + _amt) < 0}) then {
    diag_log format ["[HOLDEM] display sync: debit $%1 exceeds cached bank $%2 (%3) -- cache was already adrift, floored at zero", abs _amt, _before, _why];
    _amt = -_before;
};
AP_atmcash = AP_atmcash + _amt;
AP_atmcashCacheB = ((AP_atmcash / 4) + 11);
// No AP_fnc_ClupdatePartial here -- see the header. The cache move is what converges; an absolute
// save fired behind the server's relative write is what clobbers it.

// The owner's money rig, off by default (AP_bjLedgerOn). It is named for blackjack because that is
// what it was written for, but all it does is print the bank before and after against the amount
// that was supposed to move and flag the drift -- which is exactly the check a display sync wants,
// so hold'em uses it rather than growing a second one.
[format ["holdem %1", _why], _amt, _before] call AP_fnc_bjLedgerNote;
