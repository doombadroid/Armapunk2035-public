/*
    AP_fnc_loonerReceive  (client) -- the server pushes the Looner feed here.
    Arg: [ [[id, name, message, minutesAgo, likes, verified, replyTo], ...] ]  (oldest -> newest).
    Stashes it, then repaints NETLINK if the deck is up.

    2026-09-04: repointed twice in one day. First from the native LoonyNet browser
    (dialog 936100, deleted) to a standalone NETLINK dialog; then to here, when that
    dialog turned out to be the wrong shape -- NETLINK is a VIEW INSIDE THE DECK
    (937500), so the push goes on the deck's own "netlink" channel like every other
    deck app's data.

    This is what makes every mutation land without the page patching itself:
    APS_fnc_loonerSRV rebroadcasts the whole feed after a post or a like, and it
    arrives here.
*/
if (isRemoteExecuted && {remoteExecutedOwner != 2}) exitWith {};   // server-origin only: CfgRE allowedTargets limits the target, never the sender
params [["_feed", [], [[]]]];
AP_loonerFeed = _feed;

if (isNull (findDisplay 937500)) exitWith {};
private _ctrl = uiNamespace getVariable ["WEBUI_ctrl", controlNull];
if (isNull _ctrl) exitWith {};
[_ctrl, "netlink", (["data"] call AP_fnc_deckNetlink)] call webui_fnc_push;
