/*
    AP_fnc_hudLayoutRecv -- the server's answer to a get or a set. Cache it, wear it.

        [_layout] remoteExec ["AP_fnc_hudLayoutRecv", _client];    // server side only

    CfgRE gives this allowedTargets = 1, so only the server can send it. It carries no identity
    and touches nothing but this client's own HUD, so the worst a forged one could do is move
    the sender's own plates -- but it stays server-only anyway, because there is no reason for a
    client to be able to reach it and every reason not to widen a whitelist without one.

    THE SERVER'S ANSWER IS THE TRUTH, INCLUDING AFTER A SET. The editor does not apply what it
    thinks it saved; it applies what comes back through here. A value the server clamped,
    refused, or failed to write therefore shows up on screen as what is actually stored, rather
    than leaving the player looking at a layout the database does not have.

    NORMALISED AGAIN ON ARRIVAL even though the server validated it. AP_fnc_hudLayoutNorm is
    cheap, it is the single definition of what a layout IS, and the alternative is trusting that
    two files will stay in step forever. It clamps rather than rejects -- see its header for why
    the client's validator and the server's are deliberately opposites.

    NOT profileNamespace. The cache is a missionNamespace global of plain numbers, rebuilt from
    the database on every login. Nothing in this feature writes the profile or calls
    saveProfileNamespace, and nothing in it compiles anything.
*/

if (isRemoteExecuted && {remoteExecutedOwner != 2}) exitWith {};   // server-origin only: CfgRE allowedTargets limits the target, never the sender
params [["_raw", [], [[]]]];
if (!hasInterface) exitWith { false };

AP_hudLayout = [_raw] call AP_fnc_hudLayoutNorm;

// THE LIVE LAYER ONLY, NEVER THE EDITOR. While the editor is open the page's layout belongs to
// the person dragging it: the editor owns its own stylesheet and drives the variables inline,
// and an answer landing mid-edit -- a late get from before the dialog opened, say -- would
// otherwise throw away work in progress with no way to get it back. The editor reads the saved
// layout exactly once, at open, from AP_fnc_hudEditOpen.
private _live = uiNamespace getVariable ["AP_hudWebCtrl", controlNull];
if (!isNull _live) then { [_live, AP_hudLayout] call AP_fnc_hudLayoutApply; };

true
