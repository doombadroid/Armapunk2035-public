// SPDX-License-Identifier: MIT
/*
    fn_journal.sqf -- the client's single inbound door and the arma-webui
    bridge.

    WHY THIS EXISTS
      Two problems, solved in one place because they are the same problem.

      First, state arriving from the server has to do four things at once:
      replace the local view, arm the watchers for what is now active, disarm
      the watchers for what is not, and repaint. Spread across four entry
      points, those drift out of step -- the classic result is a quest that
      shows as abandoned in the UI while its watcher is still running and
      still reporting facts. So there is exactly one inbound verb, `sync`, it
      is a full replacement, and it does all four in a fixed order.

      Second, the journal page is optional. A mission that has not installed
      arma-webui, or that simply has not opened the page yet, must still play:
      quests still progress, native tasks still appear on the map, the server
      still pays. So every call into the web layer is guarded, the absence is
      logged exactly once, and nothing here is allowed to error per push --
      an error per repaint is how a missing optional dependency turns into an
      unreadable RPT and a bug report about something else entirely.

    WHAT IT DOES
      Verbs:
        ["init"]                          set up, detect arma-webui once
        ["open",   [_view, _arg]]         open the page, on a view
        ["attach", _ctrl]                 bind a browser control, register the
                                          page's verbs, push current state
        ["detach"]                        forget the control
        ["sync",   _records]              SERVER -> CLIENT: full state
        ["offers", [_giverId, _offers]]   SERVER -> CLIENT: a giver's board
        ["notice", [_kind, _id, _reason]] SERVER -> CLIENT: a refusal or a
                                          completion, for the UI to announce
        ["refresh"]                       recompute progress and push

      The server reaches this client with, e.g.:
        ["sync", _records] remoteExec ["aq_fnc_journal", _clientOwner];

    Usage:  ["open"] call aq_fnc_journal;
*/

params [
    ["_verb", "", [""]],
    ["_arg",  [],  ["", [], createHashMap, controlNull, objNull, 0]]
];

if (!hasInterface) exitWith { false };
// LOCAL PATCH (VENDORED.txt): whitelisted server->client, and a whitelist entry
// lets any client target any other. Only the server may drive it remotely.
if (isRemoteExecuted && {remoteExecutedOwner != 2}) exitWith { false };

if (isNil {localNamespace getVariable "aq_quests"})  then { localNamespace setVariable ["aq_quests", createHashMap]; };
// aq_jCtrl lives in uiNamespace, NOT missionNamespace. A control is not
// serializable, and the engine says so to the player's face -- "Variable
// 'aq_jctrl' does not support serialization and should not be stored in the
// mission namespace" arrives as a message box at mission start, which reads like
// a broken mission when nothing is actually wrong. uiNamespace is not serialized
// and is where displays and controls belong; it also outlives a mission restart,
// which is harmless here because the handle is re-set on open and cleared on
// close.
if (isNil "aq_jOffers") then { aq_jOffers = createHashMap; };   // giverId -> records
if (isNil "aq_jView")   then { aq_jView   = ["quests", ""]; };

// -------------------------------------------------------- webui detection
/*
    Detected once and remembered. arma-webui is a real, named dependency
    (github.com/doombadroid/arma-webui) and the journal page needs it, but the
    quest system does not: without it this whole file reduces to bookkeeping
    plus the native task mirror, which is a complete if plainer experience.
*/
private _haveWebui = {
    if (isNil "aq_webui") then {
        aq_webui = !(isNil "webui_fnc_push") && {!(isNil "webui_fnc_on")};
        if (!aq_webui) then {
            diag_log "[AQ] journal: arma-webui is not loaded, so the HTML journal is unavailable. Quests, progress and native tasks are unaffected. Install github.com/doombadroid/arma-webui to enable the page.";
        };
    };
    aq_webui
};

private _push = {
    params ["_channel", "_value"];
    if !(call _haveWebui) exitWith { false };
    private _jc = uiNamespace getVariable ["aq_jCtrl", controlNull];
    if (isNull _jc) exitWith { false };
    [_jc, _channel, _value] call webui_fnc_push;
};

// ------------------------------------------------------- payload building
/*
    One quest, rendered for the page. Progress and the one-line description
    come from the objective's own type -- the engine never knows what a type
    means, which is exactly why a type that cannot render itself is refused at
    registration.

    Global rather than local because the page's handlers run later, from the
    browser control, on a call stack that has none of this function's locals.
    compileFinal, so it is assigned once (LOCAL EDIT, VENDORED.txt): any client could otherwise
    publicVariable its own copy onto every machine.
*/
if !(isFinal "aq_fnc_journalPayload") then {aq_fnc_journalPayload = compileFinal {   // LOCAL EDIT: final, see VENDORED.txt
    params ["_rec"];
    private _questId = _rec getOrDefault ["id", ""];
    private _objOut  = [];

    private _order = _rec getOrDefault ["order", []];
    if (_order isEqualTo []) then {
        _order = ([_questId, "objectives"] call aq_fnc_cfgQuest) apply { _x select 0 };
    };

    {
        private _objId = _x;
        private _cfg   = [_questId, "objective", _objId] call aq_fnc_cfgQuest;
        private _type  = if (isNull _cfg) then { {} } else {
            (localNamespace getVariable "aq_types") getOrDefault [getText (_cfg >> "type"), {}]
        };

        private _cur = 0; private _max = 1; private _text = ""; private _desc = "";
        if !(_type isEqualTo {}) then {
            private _ctx = [_questId, _objId] call aq_fnc_ctx;
            if !(count _ctx isEqualTo 0) then {
                private _p = ["progress", _ctx] call _type;
                if (!isNil "_p" && {_p isEqualType []} && {count _p >= 3}) then {
                    _cur = _p select 0; _max = _p select 1; _text = _p select 2;
                };
                private _d = ["describe", _ctx] call _type;
                if (!isNil "_d" && {_d isEqualType ""}) then { _desc = _d; };
            };
        };

        /*
            The server's own figures win where it sent them. The type's
            `progress` verb is what fills the gap between two pushes -- a
            countdown that has to move between server ticks to be readable --
            but the number the player is shown when the server has just spoken
            must be the server's, or the journal and the payout can disagree
            about what "3 of 8" means. The client's local copy is a preview of
            the server's next answer, never a substitute for it.
        */
        private _rows = _rec getOrDefault ["progress", createHashMap];
        if (_rows isEqualType createHashMap) then {
            private _row = _rows getOrDefault [_objId, []];
            if (_row isEqualType [] && {count _row >= 3}) then {
                _cur = _row select 0; _max = _row select 1;
                if ((_row select 2) isEqualType "" && {(_row select 2) != ""}) then { _text = _row select 2; };
                if (_desc isEqualTo "") then { _desc = _text; };
            };
        };

        _objOut pushBack (createHashMapFromArray [
            ["id",       _objId],
            ["cur",      _cur],
            ["max",      _max],
            ["text",     _text],
            ["describe", _desc]
        ]);
    } forEach _order;

    // Seconds remaining, as the server sent it. The page anchors it to its own
    // clock at push time; nothing here tries to reconstruct an absolute stamp,
    // because the two machines share no clock to reconstruct it on.
    private _remaining = _rec getOrDefault ["remaining", 0];
    createHashMapFromArray [
        ["id",          _questId],
        ["state",       _rec getOrDefault ["state", ""]],
        ["title",       _rec getOrDefault ["title", ""]],
        ["summary",     _rec getOrDefault ["summary", ""]],
        ["description", _rec getOrDefault ["description", ""]],
        ["giver",       _rec getOrDefault ["giver", ""]],
        ["icon",        _rec getOrDefault ["icon", ""]],
        ["remaining",   if (_remaining > 0) then { _remaining } else { -1 }],
        ["objectives",  _objOut]
    ]
}};

private _pushQuests = {
    private _out = [];
    { _out pushBack ([_y] call aq_fnc_journalPayload); } forEach (localNamespace getVariable "aq_quests");
    ["quests", _out] call _push
};

// ------------------------------------------------------------------ verbs
switch (toLower _verb) do {

    case "init": {
        call _haveWebui;
        true
    };

    // ----------------------------------------------------------- display
    case "open": {
        private _view = "quests"; private _sel = "";
        if (_arg isEqualType []) then {
            _view = _arg param [0, "quests", [""]];
            _sel  = _arg param [1, "", [""]];
        };
        aq_jView = [_view, _sel];

        if !(isNull (uiNamespace getVariable ["aq_jCtrl", controlNull])) exitWith {
            ["view", createHashMapFromArray [["view", _view], ["id", _sel]]] call _push;
            true
        };

        private _settings = (localNamespace getVariable ["aq_cfg", createHashMap]) getOrDefault ["settings", configNull];
        private _dlg = if (isText (_settings >> "journalDialog")) then {
            getText (_settings >> "journalDialog")
        } else { "AQ_Journal" };
        private _idd = if (isNumber (_settings >> "journalIdd")) then {
            getNumber (_settings >> "journalIdd")
        } else { 8100 };
        private _idc = if (isNumber (_settings >> "journalCtrl")) then {
            getNumber (_settings >> "journalCtrl")
        } else { 8101 };

        if !(createDialog _dlg) exitWith {
            // Not fatal, and not repeated: the map task list is still a
            // complete view of the same state.
            if (isNil "aq_jDlgWarned") then {
                aq_jDlgWarned = true;
                diag_log format ["[AQ] journal: dialog '%1' would not open, falling back to native tasks. Check that the journal dialog is included from description.ext, or set AQ_Settings >> journalDialog.", _dlg];
            };
            false
        };
        // The display is found by idd rather than remembered from
        // createDialog, which answers only a boolean.
        ["attach", ((findDisplay _idd) displayCtrl _idc)] call aq_fnc_journal;
        true
    };

    case "attach": {
        private _ctrl = if (_arg isEqualType controlNull) then { _arg } else { controlNull };
        if (isNull _ctrl) exitWith {
            diag_log "[AQ] journal: attach given a null control -- check AQ_Settings >> journalCtrl matches the browser control's idc";
            false
        };
        if !(call _haveWebui) exitWith { false };

        uiNamespace setVariable ["aq_jCtrl", _ctrl];
        [_ctrl] call webui_fnc_init;

        /*
            The page's verbs. Every one of them is a request, never a
            decision: accept and abandon are server round trips, and the page
            is explicitly untrusted -- anyone who can run JavaScript in it can
            call these with any arguments, exactly as they could from the
            debug console. That is fine, because the server re-checks
            everything; it would not be fine if any of these mutated state
            here.
        */
        /*
            The verb names are the page's, not this file's. ui/journal.html
            calls "select", "accept" and "abandon" and subscribes to the
            channels "quests" and "offers"; a bridge registering them under
            other names is a journal whose buttons reach nothing, with no error
            on either side. One spelling, and it is the page's.
        */
        [_ctrl, "quests", {
            private _out = [];
            { _out pushBack ([_y] call aq_fnc_journalPayload); } forEach (localNamespace getVariable "aq_quests");
            _out
        }] call webui_fnc_on;

        [_ctrl, "offers", {
            params [["_giverId", "", [""]]];
            (aq_jOffers getOrDefault [_giverId, []]) apply { [_x] call aq_fnc_journalPayload }
        }] call webui_fnc_on;

        [_ctrl, "accept", {
            params [["_questId", "", [""]], ["_giverId", "", [""]]];
            // The page sends only the quest id; the giver it came from is the
            // one whose board is open, which this client already knows.
            if (_giverId isEqualTo "") then { _giverId = if (isNil "aq_pendingGiver") then { "" } else { aq_pendingGiver }; };
            [_questId, _giverId] call aq_fnc_accept
        }] call webui_fnc_on;

        [_ctrl, "abandon", {
            params [["_questId", "", [""]]];
            [_questId] call aq_fnc_abandon
        }] call webui_fnc_on;

        [_ctrl, "select", {
            params [["_questId", "", [""]]];
            aq_jView = ["quests", _questId];
            // Selecting a quest in the page also moves the native task
            // marker, so the map agrees with the screen.
            ["select", _questId] call aq_fnc_task
        }] call webui_fnc_on;

        // Detach explicitly on close rather than relying on the control
        // reference going null with its display.
        // UNVERIFIED: a control of a destroyed display reads as null. If it
        // does not, this detach is what keeps pushes from going to a control
        // that no longer exists.
        [_ctrl, "close", { closeDialog 0; ["detach"] call aq_fnc_journal; true }] call webui_fnc_on;

        call _pushQuests;
        ["view", createHashMapFromArray [["view", aq_jView select 0], ["id", aq_jView select 1]]] call _push;
        true
    };

    case "detach": {
        uiNamespace setVariable ["aq_jCtrl", controlNull];
        true
    };

    // ------------------------------------------------- server -> client
    case "sync": {
        /*
            Full replacement, in a fixed order: disarm what is leaving before
            adopting the new set, then adopt, then arm what is now active,
            then mirror to tasks, then repaint. Any other order leaves a
            window where a watcher is running against a record that has been
            replaced underneath it.
        */
        private _records = if (_arg isEqualType []) then { _arg } else { [] };

        private _incoming = createHashMap;
        {
            if (_x isEqualType createHashMap) then {
                private _id = _x getOrDefault ["id", ""];
                if !(_id isEqualTo "") then { _incoming set [_id, _x]; };
            };
        } forEach _records;

        // 1. leaving, or no longer active
        {
            private _id = _x;
            private _stillActive = false;
            private _new = _incoming getOrDefault [_id, createHashMap];
            if !(count _new isEqualTo 0) then {
                _stillActive = (_new getOrDefault ["state", ""]) isEqualTo "active";
            };
            if (!_stillActive) then {
                {
                    [_id, _x select 0] call aq_fnc_disarmObjective;
                } forEach ([_id, "objectives"] call aq_fnc_cfgQuest);
            };
        } forEach (keys (localNamespace getVariable "aq_quests"));

        // 2. adopt. Objective state maps carried over from the previous
        //    record when the server did not send one, so a push that only
        //    changes a quest's state does not wipe watcher-local counters.
        {
            private _id  = _x;
            private _new = _y;
            private _old = (localNamespace getVariable "aq_quests") getOrDefault [_id, createHashMap];
            if (isNil { _new get "objectives" }) then {
                _new set ["objectives", _old getOrDefault ["objectives", createHashMap]];
            };
            (localNamespace getVariable "aq_quests") set [_id, _new];
        } forEach _incoming;

        { if (isNil { _incoming get _x }) then { (localNamespace getVariable "aq_quests") deleteAt _x; }; } forEach (keys (localNamespace getVariable "aq_quests"));

        // 3. arm what is active now (armObjective is a no-op when already
        //    armed). Walked over a copy of the key list, because arming
        //    creates the objective state maps as it goes.
        {
            private _id = _x;
            if ((((localNamespace getVariable "aq_quests") getOrDefault [_id, createHashMap]) getOrDefault ["state", ""]) isEqualTo "active") then {
                {
                    [_id, _x select 0] call aq_fnc_armObjective;
                } forEach ([_id, "objectives"] call aq_fnc_cfgQuest);
            };
        } forEach (keys (localNamespace getVariable "aq_quests"));

        // 4 and 5
        ["sync", _records] call aq_fnc_task;
        call _pushQuests;
        true
    };

    case "offers": {
        private _giverId = _arg param [0, "", [""]];
        private _offers  = _arg param [1, [], [[]]];
        if (_giverId isEqualTo "") exitWith {
            diag_log "[AQ] journal: offers push with no giver id";
            false
        };
        aq_jOffers set [_giverId, _offers];

        private _giverCfg  = aq_idxGiver getOrDefault [_giverId, configNull];
        private _giverName = if (isNull _giverCfg) then { _giverId } else {
            [_giverCfg >> "name"] call aq_fnc_text
        };

        // Offer records are not adopted into aq_quests: an offer is not a
        // quest this player holds, and describing one must not be able to
        // touch the state of one they do.
        // "giverName" rather than "name": the page reads the giver id from
        // "giver" and the display name from "giverName", and a payload carrying
        // only "giver" makes the header show a class name.
        ["offers", createHashMapFromArray [
            ["giver",     _giverId],
            ["giverName", _giverName],
            ["offers",    _offers apply { [_x] call aq_fnc_journalPayload }]
        ]] call _push;
        true
    };

    case "notice": {
        private _kind   = _arg param [0, "", [""]];
        private _id     = _arg param [1, "", [""]];
        private _reason = _arg param [2, "", [""]];
        ["notice", createHashMapFromArray [
            ["kind",   _kind],
            ["id",     _id],
            ["reason", [_reason] call aq_fnc_text]
        ]] call _push;
        // Announced natively too, because the page may not be open and a
        // refusal the player never sees is a refusal they will report as a
        // bug.
        if !(_reason isEqualTo "") then { systemChat ([_reason] call aq_fnc_text); };
        true
    };

    case "refresh": { call _pushQuests };

    default {
        diag_log format ["[AQ] journal: unknown verb '%1'", _verb];
        false
    };
}
