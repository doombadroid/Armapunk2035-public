/*
    AP_fnc_hudEditOpen -- dialog 938400 onLoad: bridge the editor, dress the page, inject the
    drag overlay, register the two verbs. Spec: hudeditor.md §3.

        [_this select 0] spawn AP_fnc_hudEditOpen;    // dialog\hudEdit.hpp onLoad

    ---- NOTHING IS WRITTEN INTO hud.html, AND THAT IS A HARD RULE ---------------------------

    hud.html's own header says a designer re-drop replaces the whole document and preserves only
    the bridge shim element. Drag code written into that file would be silently lost on the next
    drop -- and the failure would look like "the editor stopped working" weeks later, with the
    commit that broke it being a routine art update. So everything the editor adds arrives at
    runtime:

      * the layout it starts from, as a plain array of [dx,dy,s] triples on window.APHE_INIT;
      * the overlay itself, from ui\html\hudedit.js, fetched by the PAGE through
        A3API.RequestFile.

    RequestFile AND NOT loadFile, deliberately. The arma-webui audit established that a loadFile
    refusal ABORTS the calling script at that line, and that the abort is NOT catchable -- measured
    across three page opens and five refusals with a try/catch that never fired once. The page's
    own shim already boots webui.js through A3API.RequestFile for exactly that reason, and
    ui\html\* is already in description.ext's allowedHTMLLoadURIs whitelist.

    That audit also concluded loadFile is "a disabled command in CLIENT contexts". It is not:
    THIS mission disabled it, in CfgDisabledCommands.hpp, at targets {0,0,0} inherited from the
    2020 client list (found and corrected 2026-09-02; clients are now {0,1,0}). RequestFile
    remains the right delivery path here for the reasons above -- the page fetches its own code,
    so a drop-in art update cannot silently lose it -- but the reason is architecture, not a
    platform limit that never existed.

    ---- THE PAYLOAD IS SYNTHETIC ON PURPOSE -------------------------------------------------

    #wplate is display:none until the page is told there is a bounty, and #chips is empty until
    it is told about regen or a pause. A player with a clean record opening the editor would
    therefore have two of the seven handles simply absent from the screen, with no way to know
    they existed. So the payload forces wanted, regen and paused on.

    It is built by AP_fnc_hudWebPush in its "edit" mode rather than assembled here, so the tile
    configuration, the marker kinds and the zoom stay in the ONE file that knows about them. A
    second copy would drift the first time the minimap changed, and the drift would show up as
    an editor whose map does not match the game's.

    ---- WHY THE VERBS LIVE HERE AND NOT ON THE LAYER ----------------------------------------

    The live HUD's shim is display-only on purpose: no call(), no verb registered against
    control 938301, and consequently no CfgRemoteExec entry for the HUD at all. Its header is
    explicit that there is no name a page-side script could reach SQF through.

    That is preserved exactly. hudLayoutSet and hudLayoutCancel are registered on THIS control
    (938401) and nowhere else -- the layer never gains a verb, and it never stops being
    receive-only. The editor's injected JS reaches SQF through window.WEBUI.call directly, which
    is the ordinary bridge every other dialog page in this mission uses.
*/

params [["_display", displayNull, [displayNull]]];
if (isNull _display) exitWith { diag_log "[HUDEDIT] open: null display"; false };

disableSerialization;
private _ctrl = _display displayCtrl 938401;
if (isNull _ctrl) exitWith {
    diag_log "[HUDEDIT] open: browser control 938401 missing";
    closeDialog 0;
    false
};

if !([_ctrl] call webui_fnc_init) exitWith {
    diag_log "[HUDEDIT] open: bridge init failed";
    closeDialog 0;
    false
};

// uiNamespace, not missionNamespace: a control stored in a namespace the engine serialises
// earns "does not support serialization" in the RPT, twice per occurrence. Same slot discipline
// as AP_hudWebCtrl.
uiNamespace setVariable ["AP_hudEditCtrl", _ctrl];

// ---------------------------------------------------------------------- the verbs --------
// The in-game browser console is unreachable (Esc closes the display instead of opening it), so
// a page that has something to say has to be able to say it into the RPT. Same verb the deck
// and the casino carry, and the only way the injection watchdog at the bottom of this file can
// report what went wrong.
[_ctrl, "log", {
    params [["_msg", "", [""]]];
    diag_log format ["[HUDEDIT] %1", _msg];
    createHashMapFromArray [["ok", true]]
}] call webui_fnc_on;

[_ctrl, "hudLayoutSet", {
    params [["_L", [], [[]]]];
    // The server validates independently and answers through AP_fnc_hudLayoutRecv, which is
    // what the LIVE layer will wear. Nothing here decides what was stored.
    ["set", _L] remoteExec ["APS_fnc_hudLayoutSRV", 2];
    // Spawned, not immediate: this handler's own return value still has to reach the page as an
    // ExecJS reply, and tearing the display down in the same frame loses it. A dropped reply is
    // harmless here, but a page left waiting on a promise that can never settle is not.
    [] spawn { uiSleep 0.1; closeDialog 0; };
    createHashMapFromArray [["ok", true], ["msg", "saved"]]
}] call webui_fnc_on;

[_ctrl, "hudLayoutCancel", {
    [] spawn { uiSleep 0.1; closeDialog 0; };
    createHashMapFromArray [["ok", true], ["msg", "cancelled"]]
}] call webui_fnc_on;

// ------------------------------------------------------------------- dress the page ------
// Once is enough: webui_fnc_exec holds every statement until the bridge is PROVEN (not merely
// until the page loaded), and webui.js's own on() replays the last value on a channel to a
// subscriber that arrives late. Whichever side wins the race, the page gets this payload.
["edit", _ctrl] call AP_fnc_hudWebPush;

// ------------------------------------------------------------------- inject the editor ---
private _L = missionNamespace getVariable ["AP_hudLayout", []];
_L = [_L] call AP_fnc_hudLayoutNorm;
private _js = "[" + ((_L apply {
    format ["[%1,%2,%3]", (_x select 0) toFixed 5, (_x select 1) toFixed 5, (_x select 2) toFixed 5]
}) joinString ",") + "]";

// Built entirely from numbers this file produced through toFixed and from literals written
// here. Nothing the player typed and nothing from the page is interpolated into it.
//
// THE PATH IS DOUBLED EXACTLY ONCE, AND COUNTING IT WRONG FAILS SILENTLY. SQF has no backslash
// escape, so the literal below reaches the browser character for character as
//     A3API.RequestFile('ui\\html\\hudedit.js')
// which is JS source for the runtime string ui\html\hudedit.js -- the single-backslash form the
// page's own shim already uses for webui\ui\webui.js, and the form the engine resolves. A third
// backslash would ask for ui\\html\\hudedit.js, which resolves to nothing and rejects the
// promise into __apheErr rather than throwing anywhere visible.
private _boot = "(function(){window.APHE_INIT=" + _js + ";"
    + "if(typeof A3API!=='undefined'&&A3API.RequestFile){"
    + "A3API.RequestFile('ui\\html\\hudedit.js')"
    + ".then(function(s){try{(0,eval)(s)}catch(e){window.__apheErr='eval: '+e}})"
    + ".catch(function(e){window.__apheErr='RequestFile: '+e});"
    + "}else{window.__apheErr='no A3API on this page';}})()";

[_ctrl, _boot] call webui_fnc_exec;

// The one thing that cannot be recovered from in here is the editor JS never arriving: the
// player would be looking at a HUD with no handles and no toolbar, and Esc would be the only
// way out (which does work -- onUnload restores the layer). Say so in the RPT, where the
// bootstrap's own error slots are readable, rather than leaving it to guesswork.
[] spawn {
    uiSleep 4;
    private _c = uiNamespace getVariable ["AP_hudEditCtrl", controlNull];
    if (isNull _c) exitWith {};
    [_c, "window.WEBUI&&window.WEBUI.call&&!window.APHE&&window.WEBUI.call('log',"
        + "['editor overlay did not arrive: '+(window.__apheErr||'no error reported')])"] call webui_fnc_exec;
};

diag_log format ["[HUDEDIT] open: bridged ctrl %1, layout %2", ctrlIDC _ctrl, _js];
true
